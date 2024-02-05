#include <stdio.h>

int uart_init(unsigned int baud);
int uart_putc(char c, FILE * f);
int uart_tx_busy();
