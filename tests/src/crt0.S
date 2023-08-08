# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

/* Magic address used to communicate with a simulator */
.equ TOHOST, 0x801FFFFC  # "stdout" address

.section .text

default_exc_handler:
  j . # TODO: Write TOHOST an error code to signal the exception

reset_handler:

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
  la    x2, _stack_start

_start:
  .global _start

  /* clear BSS */
  la    t0, _bss_start
  la    t1, _bss_end
  bge   t0, t1, zero_loop_end
zero_loop:
  sw    x0, 0(t0)
  addi  t0, t0, 4
  ble   t0, t1, zero_loop
zero_loop_end:

  /* jump to main program entry point (argc = argv = 0) */
  addi  x10, x0, 0
  addi  x11, x0, 0
  jal   x1, main

  /* Exit simulation */
  li t0, TOHOST
  li t1, 0x00
  sw t1, 0(t0)

  /* If execution ends up here just put the core to sleep */
sleep_loop:
  wfi
  j sleep_loop

/* =================================================== [ exceptions ] === */
/* This section has to be down here, since we have to disable rvc for it  */

  .section .vectors, "ax"
  .option norvc;

  // All unimplemented interrupts/exceptions go to the default_exc_handler.
  .org 0x00
  .rept 31
  jal x0, default_exc_handler
  .endr

  // reset vector
  .org 0x80
  jal x0, reset_handler
