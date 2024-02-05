/* Copyright Antmicro 2023
 * SPDX-License-Identifier: Apache-2.0
 */

#include <liblitedram/sdram.h>
#include "uart.h"
#include "dfi_gpio.h"

volatile uint32_t* dfi_gpio_regs = (uint32_t *)REG_DFI_GPIO;

int main(void)
{
    uart_init(115200);
    puts("TRISTAN DDR/DFI PHY (Gen 2)");

    for (;;) {
        dfi_gpio_regs[DFI_GPIO_INIT_DONE] = 0x00;
        while (dfi_gpio_regs[DFI_GPIO_INIT_START] == 0) {}

        sdram_init();

        dfi_gpio_regs[DFI_GPIO_INIT_DONE] = 0x01;
        while (dfi_gpio_regs[DFI_GPIO_INIT_START] == 1) {}
    }

    return 0;
}
