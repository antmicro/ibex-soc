#include <stdint.h>
#include "csr.h"

// Base address of the UART peripheral
volatile uint32_t* uart_regs = (volatile uint32_t *)0xC0001000;

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

int uart_init() {
    uint32_t nco = 0xFFFF; // Max possible baudrate

    uart_regs[UART_CTRL_REG]      = (nco << 16) | 1; // Set baudrate, enable TX
    uart_regs[UART_FIFO_CTRL_REG] = 0x3;             // Reset FIFOs
}

void uart_putc(char c) {
    // Wait for empty space in the TX FIFO
    while ((uart_regs[UART_FIFO_STATUS_REG] & 0xFF) >= 32);
    // Write the character
    uart_regs[UART_WDATA_REG] = c;
}

int uart_tx_busy() {
    return !(uart_regs[UART_STATUS_REG] & (1 << 3));
}

int main(int argc, char* argv[]) {

    const char* str1 = "rst:";
    const char* str2 = "wr lvl EN:";
    int ddr_rst = 0;
    int ddr_wlevel_en = 0;

    // Initialize UART
    uart_init();

    // Write a string
    for (int i=0; str1[i]; ++i) {
        uart_putc(str1[i]);
    }
    ddrphy_rst_write(1);
    ddr_rst = ddrphy_rst_read();
    uart_putc(ddr_rst + 48);
    uart_putc('\n');
    // Wait for transmission of all the characters
    while (uart_tx_busy());

    // Write a string
    for (int i=0; str1[i]; ++i) {
        uart_putc(str1[i]);
    }
    ddrphy_rst_write(0);
    ddr_rst = ddrphy_rst_read();
    uart_putc(ddr_rst + 48);
    uart_putc('\n');
    // Wait for transmission of all the characters
    while (uart_tx_busy());

    // Write a string
    for (int i=0; str2[i]; ++i) {
        uart_putc(str2[i]);
    }
    ddrphy_wlevel_en_write(1);
    ddr_wlevel_en = ddrphy_wlevel_en_read();
    uart_putc(ddr_wlevel_en + 48);
    uart_putc('\n');
    // Wait for transmission of all the characters
    while (uart_tx_busy());

    // Write a string
    for (int i=0; str2[i]; ++i) {
        uart_putc(str2[i]);
    }
    ddrphy_wlevel_en_write(0);
    ddr_wlevel_en = ddrphy_wlevel_en_read();
    uart_putc(ddr_wlevel_en + 48);
    uart_putc('\n');
    // Wait for transmission of all the characters
    while (uart_tx_busy());

    return 0;
}
