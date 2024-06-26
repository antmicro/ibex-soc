CURDIR:=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ROOT_DIR:=$(CURDIR)
IBEX_DIR:=$(ROOT_DIR)/third_party/ibex
OPENTITAN_DIR:=$(ROOT_DIR)/third_party/opentitan
RTL_DIR:=$(ROOT_DIR)/rtl
BUILD_DIR:=$(ROOT_DIR)/build
RUN_DIR:=$(BUILD_DIR)/run
TESTS_DIR:=$(ROOT_DIR)/tests
SRC_DIR:=$(ROOT_DIR)/src
PHY_CONFIG ?= $(SRC_DIR)/standalone-dfi.yml
XILINX_UNISIM_LIBRARY = $(ROOT_DIR)/third_party/XilinxUnisimLibrary/verilog/src

PKG_SOURCES := \
    $(RTL_DIR)/pkg/top_pkg.sv \
    $(RTL_DIR)/pkg/mem_pkg.sv \
    $(IBEX_DIR)/rtl/ibex_pkg.sv \
    $(IBEX_DIR)/rtl/ibex_tracer_pkg.sv \
    $(IBEX_DIR)/dv/uvm/core_ibex/common/prim/prim_pkg.sv \
    $(shell find $(OPENTITAN_DIR)/hw/ip/prim/rtl/ -name "*_pkg.sv") \
    $(shell find $(RTL_DIR) -name "*_pkg.sv" -not -path "*/pkg/*") \
    $(OPENTITAN_DIR)/hw/ip/uart/rtl/uart_reg_pkg.sv \
    $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_pkg.sv

IBEX_SOURCES := \
    $(shell find $(IBEX_DIR)/rtl/ -name "*.sv" -not -name "*pkg*") \
    $(IBEX_DIR)/dv/uvm/core_ibex/common/prim/prim_buf.sv \
    $(IBEX_DIR)/dv/uvm/core_ibex/common/prim/prim_clock_gating.sv \
    $(IBEX_DIR)/dv/uvm/core_ibex/common/prim/prim_flop.sv \
    $(OPENTITAN_DIR)/hw/ip/prim_generic/rtl/prim_generic_flop.sv \
    $(OPENTITAN_DIR)/hw/ip/prim_generic/rtl/prim_generic_buf.sv \
    $(OPENTITAN_DIR)/hw/ip/prim_generic/rtl/prim_generic_clock_gating.sv

OPENTITAN_SOURCES := \
    $(shell find $(OPENTITAN_DIR)/hw/ip/prim/rtl/ -name "*.sv" -not -name "*pkg*" -not -name "*edn*" -not -name "*lc*" -not -name "*_clock_gp_mux2.sv") \
    $(shell find $(OPENTITAN_DIR)/hw/ip/uart/rtl/ -name "*.sv" -not -name "*pkg*") \
    $(shell find $(OPENTITAN_DIR)/hw/ip/tlul/rtl/ -name "*.sv" -not -name "*pkg*" -not -name "*lc*")

RDL_SOURCES := \
    $(BUILD_DIR)/dfi_gpio/dfi_gpio_csr_pkg.sv \
    $(BUILD_DIR)/dfi_gpio/dfi_gpio_csr.sv

SOURCES := $(shell find $(RTL_DIR) -name "*.sv" -not -name "*pkg*" -not -name "*sim*") \
    $(RTL_DIR)/sim/sim_rom.sv \
    $(RTL_DIR)/sim/sim_ram.sv

SIM_SOURCES := $(shell find $(RTL_DIR) -name "sim*.sv" -not -name "*pkg*" -not -name "*sim_r*m.sv")

UNISIM_SOURCES := \
    $(XILINX_UNISIM_LIBRARY)/glbl.v \
    $(XILINX_UNISIM_LIBRARY)/unisims/IOBUF.v \
    $(XILINX_UNISIM_LIBRARY)/unisims/OBUFDS.v \
    $(XILINX_UNISIM_LIBRARY)/unisims/IOBUFDS.v \
    $(XILINX_UNISIM_LIBRARY)/unisims/FDCE.v \
    $(XILINX_UNISIM_LIBRARY)/unisims/FDPE.v \
    $(XILINX_UNISIM_LIBRARY)/unisims/BUFG.v \
    $(XILINX_UNISIM_LIBRARY)/unisims/IDELAYCTRL.v

INCLUDES := \
    $(IBEX_DIR)/rtl \
    $(OPENTITAN_DIR)/hw/ip/prim/rtl \
    $(IBEX_DIR)/vendor/lowrisc_ip/dv/sv/dv_utils

GENERATED := generated/gateware/phy_core.v

all: gen verilator-build

$(ROOT_DIR)/third_party/XilinxUnisimLibrary/xul_patch.ok:
	cd $(ROOT_DIR)/third_party/XilinxUnisimLibrary/ && \
    git restore . && \
    git apply ../00-xul_fdpe_fix.patch && \
    cd - && touch $@

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(GENERATED): $(ROOT_DIR)/third_party/XilinxUnisimLibrary/xul_patch.ok | $(BUILD_DIR)
	python3 $(SRC_DIR)/gen.py --output-dir $(BUILD_DIR)/generated --name phy_core \
	$(PHY_CONFIG)

$(BUILD_DIR)/filelist.f: $(BUILD_DIR)/$(GENERATED) | $(BUILD_DIR)
	@rm -rf $@
	@$(foreach f,$(PKG_SOURCES),       echo   "$(f)" >> $@;)
	@$(foreach f,$(IBEX_SOURCES),      echo   "$(f)" >> $@;)
	@$(foreach f,$(OPENTITAN_SOURCES), echo   "$(f)" >> $@;)
	@$(foreach f,$(RDL_SOURCES),       echo   "$(f)" >> $@;)
	@$(foreach f,$(SOURCES),           echo   "$(f)" >> $@;)
	@$(foreach f,$(INCLUDES),          echo "-I$(f)" >> $@;)
	@echo $< >> $@

$(RDL_SOURCES):
	peakrdl regblock $(RTL_DIR)/gpio.rdl -o $(BUILD_DIR)/dfi_gpio --cpuif passthrough

gen: $(BUILD_DIR)/filelist.f $(SOURCES) $(RDL_SOURCES) | $(BUILD_DIR)

$(BUILD_DIR)/verilator.ok: $(BUILD_DIR)/filelist.f gen $(SIM_SOURCES) $(UNISIM_SOURCES) | $(BUILD_DIR)
	@verilator --version
	verilator --Mdir $(BUILD_DIR)/verilator --cc --exe --top-module sim_top \
        -DRVFI=1 \
        -Wno-fatal \
        -Wno-BLKANDNBLK \
        --timing \
        --trace --trace-structs \
        --bbox-unsup \
        --report-unoptflat \
        --prof-cfuncs -CFLAGS -DVL_DEBUG \
        $(shell cat $<) $(UNISIM_SOURCES) $(SIM_SOURCES) ../../src/testbench.cpp
	$(MAKE) -C $(BUILD_DIR)/verilator -f Vsim_top.mk
	@touch $@

verilator-build: $(BUILD_DIR)/verilator.ok

$(RUN_DIR):
	mkdir -p $(RUN_DIR)

firmware-build: | $(RUN_DIR)
	mkdir -p $(RUN_DIR)/sim/fw
	cd $(RUN_DIR)/sim && $(MAKE) -f $(ROOT_DIR)/fw/Makefile build
	cp $(RUN_DIR)/sim/fw/fw.hex $(RUN_DIR)/sim/fw/rom.hex

sim-firmware: verilator-build firmware-build | $(RUN_DIR)
	cp $(RUN_DIR)/sim/fw/fw.hex $(RUN_DIR)/sim/fw/rom.hex
	cd $(RUN_DIR)/sim/fw && $(BUILD_DIR)/verilator/Vsim_top

RTL_TESTS := $(shell find $(TESTS_DIR)/rtl/ -mindepth 1 -maxdepth 1 -type d -not -path "*/__pycache__" -printf "%f ")

define rtl_test_target
rtl-test-$(1): $(RDL_SOURCES) | $(RUN_DIR)
	mkdir -p $(RUN_DIR)/rtl/$(1)
	cd $(RUN_DIR)/rtl/$(1) && $$(MAKE) -f $(TESTS_DIR)/rtl/$(1)/Makefile sim
endef

$(foreach test,$(RTL_TESTS),$(eval $(call rtl_test_target,$(test))))

rtl-tests: $(addprefix rtl-test-,$(RTL_TESTS))

SIM_TESTS := $(shell find $(TESTS_DIR)/src/ -mindepth 1 -maxdepth 1 -type d -printf "%f ")

define sim_test_target
sim-test-$(1): verilator-build | $(RUN_DIR)
	mkdir -p $(RUN_DIR)/sim/$(1)
	cd $(RUN_DIR)/sim && $$(MAKE) -f $(TESTS_DIR)/src/$(1)/Makefile build
	cp $(RUN_DIR)/sim/$(1)/$(1).hex $(RUN_DIR)/sim/$(1)/rom.hex
	cd $(RUN_DIR)/sim/$(1) && $(BUILD_DIR)/verilator/Vsim_top
	cd $(RUN_DIR)/sim/$(1) && $$(MAKE) -f $(TESTS_DIR)/src/$(1)/Makefile check
endef

$(foreach test,$(SIM_TESTS),$(eval $(call sim_test_target,$(test))))

sim-tests: $(addprefix sim-test-,$(SIM_TESTS))

tests: rtl-tests sim-tests

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(RUN_DIR)
	rm $(ROOT_DIR)/third_party/XilinxUnisimLibrary/xul_patch.ok

.PHONY: gen verilator-build rtl-tests sim-tests tests clean
