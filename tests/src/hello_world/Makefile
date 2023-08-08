# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

SOURCES = hello_world.S
TARGET  = hello_world

include $(CURDIR)/../common.mk

check: stdout.txt
	echo "Hello World!" | diff $< -
