# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ROOT   := $(realpath $(CURDIR)/../../..)

SOURCES  = $(ROOT)/build/dfi_gpio/dfi_gpio_csr_pkg.sv \
		$(ROOT)/build/dfi_gpio/dfi_gpio_csr.sv \
		$(ROOT)/rtl/dfi_gpio.sv
SOURCES += $(CURDIR)/wrapper.sv

TOPLEVEL = wrapper
MODULE   = test

include $(CURDIR)/../common.mk
