/* Copyright Antmicro 2023
 * SPDX-License-Identifier: Apache-2.0
 */

#include <liblitedram/sdram.h>

int main(void)
{
    uart_init();
    sdram_init();

    return 0;
}
