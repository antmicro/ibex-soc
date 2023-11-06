# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

SOURCES = ../crt0.S \
          main.c

TARGET  = phy_csr_uart

include $(CURDIR)/../common.mk

LITEX_PATH = $(shell python $(CURDIR)/../find_litex.py)
LITEX_IBEX_HEADERS = $(abspath $(LITEX_PATH)/../soc/cores/cpu/ibex)
LITEX_SW_HEADERS = $(abspath $(LITEX_PATH)/../soc/software/include)

INCLUDE_DIRS = \
	-I$(abspath $(CURDIR)/../../../build/generated/software/include) \
	-I$(abspath $(CURDIR)/../../../build/generated/software/include/generated) \
	-I$(LITEX_IBEX_HEADERS) \
	-I$(LITEX_SW_HEADERS)

CFLAGS += -DCONFIG_CSR_DATA_WIDTH=32 $(INCLUDE_DIRS)

# Decode UART output using sigrok
uart.txt: uart.bin
	sigrok-cli \
	    -I binary:numchannels=1:samplerate=10000 \
	    -i $< \
	    -P uart:baudrate=625:format=ascii \
	    -B uart=rx >$@

# Compare
check: uart.txt
	cat $(CURDIR)/golden.txt | diff $< -
