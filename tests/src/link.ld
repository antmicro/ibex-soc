/* Copyright Antmicro 2023 */
/* SPDX-License-Identifier: Apache-2.0 */

OUTPUT_ARCH(riscv)

MEMORY {
    ROM (rx)    : ORIGIN = 0x80000000, LENGTH = 128k
    RAM (rwx)   : ORIGIN = 0x80020000, LENGTH = 128k
}

/* Stack information variables */
_min_stack   = 0x2000; /* 8K - minimum stack space to reserve */
_stack_start = ORIGIN(RAM) + LENGTH(RAM) - _min_stack;

/* Entry point */
_entry_point = _vectors_start + 0x80;
ENTRY(_entry_point)

SECTIONS {

    .vectors : ALIGN(4)
    {
		_vectors_start = .;
        KEEP(*(.vectors))
	    _vectors_end = .;
    } >ROM

    .text : ALIGN(4) {
        . = 0x80;
        *(.text.init)
        *(.text*)
    } >ROM

    .rodata : ALIGN(4) {
        *(.rodata*)
    } >ROM

    .data : ALIGN(4) {
        *(.data*)
    } >ROM

    .bss : ALIGN(4) {
        _bss_start = .;
        *(.bss*)
        _bss_end = .;
    } >RAM
}

_stack = ORIGIN(RAM) + LENGTH(RAM) - 16;
