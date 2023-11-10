# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR = $(CURDIR)/../build

SOURCES = main.c \
    liblitedram/sdram.c liblitedram/bist.c \
    liblitedram/sdram_dbg.c liblitedram/sdram_spd.c \
    liblitedram/utils.c liblitedram/accessors.c liblitedram/sdram_rcd.c \
    liblitedram/ddr5_training.c liblitedram/ddr5_helpers.c
TARGET  = fw

TOOLCHAIN ?= riscv64-unknown-elf
LDSCRIPT  ?= $(CURDIR)/link.ld
ARCH      ?= rv32e
ABI       ?= ilp32e

OBJS     = $(addprefix $(TARGET)/,$(patsubst %.S,%.o,$(filter %.S,$(SOURCES))))
OBJS    += $(addprefix $(TARGET)/,$(patsubst %.c,%.o,$(filter %.c,$(SOURCES))))

CFLAGS   = -march=$(ARCH) -mabi=$(ABI) --specs=picolibc.specs --crt0=hosted
CFLAGS  += -I$(BUILD_DIR)/generated/software/include -I$(CURDIR) -I$(CURDIR)/include
ASFLAGS  = $(CFLAGS)

VPATH = $(CURDIR)

$(TARGET)/liblitedram:
	mkdir -p $@

$(TARGET): $(TARGET)/liblitedram
	mkdir -p $@

$(TARGET)/%.o : %.S | $(TARGET)
	$(TOOLCHAIN)-gcc $(ASFLAGS) -c $< -o $@

$(TARGET)/%.o : %.c | $(TARGET)
	$(TOOLCHAIN)-gcc $(CFLAGS) -c $< -o $@

$(TARGET)/$(TARGET).elf: $(OBJS) | $(TARGET)
	$(TOOLCHAIN)-gcc $(CFLAGS) -T$(LDSCRIPT) $^ -o $@

$(TARGET)/$(TARGET).hex: $(TARGET)/$(TARGET).elf
	$(TOOLCHAIN)-objcopy --change-addresses -0x80000000 -O verilog $< $@

$(TARGET)/$(TARGET).lst: $(TARGET)/$(TARGET).elf
	$(TOOLCHAIN)-objdump -S $< >$@

$(TARGET)/$(TARGET).sym: $(TARGET)/$(TARGET).elf
	$(TOOLCHAIN)-nm -B -n $< >$@

build: $(TARGET)/$(TARGET).hex $(TARGET)/$(TARGET).lst $(TARGET)/$(TARGET).sym

clean:
	rm -rf $(OBJS)
	rm -rf $(TARGET)

.PHONY: build clean
