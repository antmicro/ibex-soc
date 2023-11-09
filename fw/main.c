/* Copyright Antmicro 2023
 * SPDX-License-Identifier: Apache-2.0
 */

int main(void)
{
    return 0;
}

void exit(int status)
{
    volatile char* sim_out = (volatile char*)0x801FFFFC;

    if (status != 0) *sim_out = 0xff;
    else *sim_out = 0x00;

    for (;;) {}
}
