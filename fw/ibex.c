/* Copyright Antmicro 2023
 * SPDX-License-Identifier: Apache-2.0
 */

#define CRT0_EXIT
#include "crt0.h"

extern void __attribute__((used)) __section(".init")
_cstart(void)
{
	__start();
}

__attribute__((__noreturn__)) void _exit(int status)
{
    volatile char * sim_out = (volatile char*)0x801FFFFC;

    if (status != 0) *sim_out = 0xff;
    else *sim_out = 0x00;

    for (;;) {}
}
