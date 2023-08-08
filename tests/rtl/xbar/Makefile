# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ROOT   := $(realpath $(CURDIR)/../../..)

SOURCES  = $(ROOT)/rtl/xbar.sv
SOURCES += $(CURDIR)/wrapper.sv

TOPLEVEL = wrapper
MODULE   = test

include $(CURDIR)/../common.mk

