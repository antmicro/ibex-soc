# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

TOPLEVEL_LANG ?= verilog
SIM           ?= verilator

ifeq ($(SIM),verilator)
  EXTRA_ARGS += -Wno-fatal
  EXTRA_ARGS += --trace --trace-structs -O3
endif

IBEX := $(ROOT)/third_party/ibex
OPENTITAN := $(ROOT)/third_party/opentitan

# Include paths
EXTRA_ARGS += -I$(ROOT)/rtl
EXTRA_ARGS += -I$(OPENTITAN)/hw/ip/prim/rtl

# Packages (need to be before test sources and in correct order)
VERILOG_SOURCES += $(ROOT)/rtl/pkg/top_pkg.sv
VERILOG_SOURCES += $(ROOT)/rtl/pkg/mem_pkg.sv

# Ibex common sources
VERILOG_SOURCES += $(OPENTITAN)/hw/ip/prim/rtl/prim_mubi_pkg.sv
VERILOG_SOURCES += $(OPENTITAN)/hw/ip/prim/rtl/prim_secded_pkg.sv
VERILOG_SOURCES += $(OPENTITAN)/hw/ip/prim/rtl/prim_util_pkg.sv
VERILOG_SOURCES += $(OPENTITAN)/hw/ip/tlul/rtl/tlul_pkg.sv

# Common RTL sources
VERILOG_SOURCES += $(shell find $(OPENTITAN)/hw/ip/tlul/rtl/ -name "*.sv" -not -name "*lc*")

# Test sources
VERILOG_SOURCES += $(SOURCES)

# Make cocotb search for modules in the test's path
SIM_CMD_PREFIX := PYTHONPATH="$(CURDIR)" $(SIM_CMD_PREFIX)

include $(shell cocotb-config --makefiles)/Makefile.sim

