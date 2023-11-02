# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ROOT   := $(realpath $(CURDIR)/../../..)

SOURCES  = $(ROOT)/build/phy/phy_csr_pkg.sv \
		$(ROOT)/build/phy/phy_csr.sv \
		$(ROOT)/rtl/phy_backend.sv \
		$(ROOT)/rtl/phy_wrapper.sv
SOURCES += $(CURDIR)/wrapper.sv

TOPLEVEL = wrapper
MODULE   = test

include $(CURDIR)/../common.mk
