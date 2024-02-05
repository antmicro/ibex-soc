#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

#include "soc.h"

// Base address of the UART peripheral
volatile uint32_t* uart_regs = (uint32_t *)0xC0001000;

// From https://opentitan.org/book/hw/ip/uart/doc/registers.html
#define UART_INTR_STATE_REG      (0x0  / 4)
#define UART_INTR_ENABLE_REG     (0x4  / 4)
#define UART_INTR_TEST_REG       (0x8  / 4)
#define UART_ALERT_TEST_REG      (0xc  / 4)
#define UART_CTRL_REG            (0x10 / 4)
#define UART_STATUS_REG          (0x14 / 4)
#define UART_RDATA_REG           (0x18 / 4)
#define UART_WDATA_REG           (0x1c / 4)
#define UART_FIFO_CTRL_REG       (0x20 / 4)
#define UART_FIFO_STATUS_REG     (0x24 / 4)
#define UART_OVRD_REG            (0x28 / 4)
#define UART_VAL_REG             (0x2c / 4)
#define UART_TIMEOUT_CTRL_REG    (0x30 / 4)

unsigned int uart_nco(unsigned int baud, unsigned long clk)
{
    unsigned long long dividend = ((unsigned long long)baud) << (UART_CTRL_NCO_WIDTH + 4);
    unsigned long long quotient = dividend / clk;
    return (unsigned int)quotient;
}

int uart_init(unsigned int baud) {
    unsigned int nco = uart_nco(baud, SOC_CLOCK_HZ);

    uart_regs[UART_CTRL_REG]      = (nco << 16) | 1; // Set baudrate, enable TX
    uart_regs[UART_FIFO_CTRL_REG] = 0x3;             // Reset FIFOs
}

int uart_putc(char c, FILE * stream) {
    (void) stream;
    // Wait for empty space in the TX FIFO
    while ((uart_regs[UART_FIFO_STATUS_REG] & 0xFF) >= 32);
    // Write the character
    uart_regs[UART_WDATA_REG] = c;

    return c;
}

int uart_tx_busy() {
    return !(uart_regs[UART_STATUS_REG] & (1 << 3));
}

static FILE __stdio = FDEV_SETUP_STREAM(uart_putc, NULL, NULL, _FDEV_SETUP_WRITE);
FILE *const stdin = &__stdio;
__strong_reference(stdin, stdout);
__strong_reference(stdin, stderr);
