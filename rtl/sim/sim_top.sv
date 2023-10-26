// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module sim_top import mem_pkg::*; import top_pkg::*; ();

  // Clock generation
  logic clk;
  initial clk <= 1'b0;
  always #0.5 clk <= !clk;

  // Reset generation
  logic rst_n;
  initial rst_n <= 1'b0;
  always @(posedge clk) rst_n <= 1'b1;

  // Memory buses
  mem_pkg::mem_h2d_t rom_h2d;
  mem_pkg::mem_d2h_t rom_d2h;
  mem_pkg::mem_h2d_t ram_h2d;
  mem_pkg::mem_d2h_t ram_d2h;

  logic uart_tx;

  glbl glbl();

  // DUT top
  top u_top (
    .clk_i      (clk),
    .rst_ni     (rst_n),

    .rom_o      (rom_h2d),
    .rom_i      (rom_d2h),
    .ram_o      (ram_h2d),
    .ram_i      (ram_d2h),

    .tx         (uart_tx),
    .rx         (1'b1)
  );

  // ROM memory model
  sim_rom # (
    .AW         (top_pkg::MEM_AW),
    .DW         (top_pkg::MEM_DW),
    .SIZE       (1024 * 128),   // 128kB
    .FILE       ("rom.hex")
  ) u_rom (
    .clk_i      (clk),
    .rst_ni     (rst_n),

    .req        (rom_h2d.req & !rom_h2d.we),
    .addr       (rom_h2d.addr),
    .rdata      (rom_d2h.data),
    .rvalid     (rom_d2h.valid)  
  );

  assign rom_d2h.gnt    = 1'b1;
  assign rom_d2h.error  = 2'b00;

  // RAM memory model
  sim_ram # (
    .AW         (top_pkg::MEM_AW),
    .DW         (top_pkg::MEM_DW),
    .SIZE       (1024 * 128)    // 128kB
  ) u_ram (
    .clk_i      (clk),
    .rst_ni     (rst_n),

    .req        (ram_h2d.req),
    .we         (ram_h2d.we),
    .addr       (ram_h2d.addr),
    .wdata      (ram_h2d.data),
    .wmask      (ram_h2d.mask),
    .rdata      (ram_d2h.data),
    .rvalid     (ram_d2h.valid)  
  );

  assign ram_d2h.gnt    = 1'b1;
  assign ram_d2h.error  = 2'b00;

  // "stdout"
  integer stdout_fp;
  initial stdout_fp = $fopen("stdout.txt", "wb");

  logic [7:0] stdout;
  always @(posedge clk)
    if (rst_n)
      if (ram_h2d.req && ram_h2d.we && ram_h2d.addr == {top_pkg::MEM_AW{1'b1}}) begin

        // Latch the byte
        stdout = ram_h2d.data[7:0];

        // When writing 0x00 or 0x80 - 0xFF terminate
        if (ram_h2d.data[7:0] == 8'h00 || ram_h2d.data[7:0] >= 8'h80) begin
            $finish();
        // Otherwise write to stdout and file
        end else begin
            $fwrite(stdout_fp, "%c", ram_h2d.data[7:0]);
            $write("%c", ram_h2d.data[7:0]);
            $fflush();
        end
      end

  // UART waveform dump
  integer uart_fp;
  initial uart_fp = $fopen("uart.bin", "wb");

  always @(posedge clk) begin
    $fwrite(uart_fp, "%c", uart_tx);
  end

endmodule
