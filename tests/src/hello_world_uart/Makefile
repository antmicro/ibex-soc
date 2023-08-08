# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

SOURCES = ../crt0.S \
          main.c

TARGET  = hello_world_uart

include $(CURDIR)/../common.mk

# Decode UART output using sigrok
uart.txt: uart.bin
	sigrok-cli \
	    -I binary:numchannels=1:samplerate=10000 \
	    -i $< \
	    -P uart:baudrate=625:format=ascii \
	    -B uart=rx >$@

# Compare
check: uart.txt
	echo "Hello World!" | diff $< -
