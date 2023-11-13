# Copyright lowRISC contributors.
# Copyright Antmicro, Ltd. <www.antmicro.com>
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

/* Magic address used to communicate with a simulator */
.equ TOHOST, 0x801FFFFC  # "stdout" address


/*** exception vector table ***/

.section .text.init.enter, "ax"
.option norvc;

  // All unimplemented interrupts/exceptions go to the default_exc_handler.
.org 0x00
.rept 31
  jal x0, default_exc_handler
.endr


/*** start ***/

.org 0x80
_start:
.section .text.init.enter
.option rvc
.option nopic
.option push
.option norelax
.global _start
.extern _cstart

  /* set all RV32E registers to zero */
  mv  x1, x0
  mv  x2, x1
  mv  x3, x1
  mv  x4, x1
  mv  x5, x1
  mv  x6, x1
  mv  x7, x1
  mv  x8, x1
  mv  x9, x1
  mv x10, x1
  mv x11, x1
  mv x12, x1
  mv x13, x1
  mv x14, x1
  mv x15, x1

  /* stack initilization */
  la    sp, __stack
  la    gp, __global_pointer$

.option pop

  /* jump to C part of init code */
  j     _cstart


/*** exception handlers ***/

default_exc_handler:
  j . # TODO: Write TOHOST an error code to signal the exception
