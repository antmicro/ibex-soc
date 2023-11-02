// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module top 
    import top_pkg::*;
    import mem_pkg::*;
    import tlul_pkg::*;
(
    // Clock and reset
    input  wire clk_i,
    input  wire rst_ni,

    // ROM interface
    output mem_pkg::mem_h2d_t rom_o,
    input  mem_pkg::mem_d2h_t rom_i,
    // RAM interface
    output mem_pkg::mem_h2d_t ram_o,
    input  mem_pkg::mem_d2h_t ram_i,

    // UART
    output logic tx,
    input  logic rx,

    // DFI memory training interface
    input  logic dfi_init_start_i,
    output logic dfi_init_done_o
);

  // CPU TileLink bus
  tlul_pkg::tl_h2d_t tl_cpu_h2d;
  tlul_pkg::tl_d2h_t tl_cpu_d2h;

  // External TileLink bus
  tlul_pkg::tl_h2d_t tl_ext_h2d;
  tlul_pkg::tl_d2h_t tl_ext_d2h;

  // CPU
  cpu u_cpu (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),

    .tl_o           (tl_cpu_h2d),
    .tl_i           (tl_cpu_d2h),

    .core_rst_ni    (rst_ni),
    .boot_addr_i    (32'h80000000), // FIXME: Temporary.
    .fetch_enable_i (1'b1),
    .timer_irq_i    (1'b0)
  );

  // Memory TileLink bus
  tlul_pkg::tl_h2d_t tl_mem_h2d;
  tlul_pkg::tl_d2h_t tl_mem_d2h;

  // Device TileLink buses
  tlul_pkg::tl_h2d_t tl_dev_h2d[7];
  tlul_pkg::tl_d2h_t tl_dev_d2h[7];

  // System bus crossbar
  xbar u_xbar (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),

    .tl_h_i         ('{tl_ext_h2d, tl_cpu_h2d}),
    .tl_h_o         ('{tl_ext_d2h, tl_cpu_d2h}),

    .tl_m_i         (tl_mem_d2h),
    .tl_m_o         (tl_mem_h2d),

    .tl_d_i         (tl_dev_d2h),
    .tl_d_o         (tl_dev_h2d)
  );

  // System memory interface
  mem u_mem (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),

    .tl_i           (tl_mem_h2d),
    .tl_o           (tl_mem_d2h),

    .rom_o          (rom_o),
    .rom_i          (rom_i),

    .ram_o          (ram_o),
    .ram_i          (ram_i)
  );

  // DFI memory training GPIO interface
  dfi_gpio u_dfi_gpio (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),

    .tl_i             (tl_dev_h2d[0]),
    .tl_o             (tl_dev_d2h[0]),

    .dfi_init_start_i (dfi_init_start_i),
    .dfi_init_done_o  (dfi_init_done_o)
  );

  // UART
  uart u_uart (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),

    .tl_i           (tl_dev_h2d[1]),
    .tl_o           (tl_dev_d2h[1]),

    .cio_rx_i       (rx),
    .cio_tx_o       (tx),
    .cio_tx_en_o    (), // Unused for now

    .intr_tx_watermark_o    (),
    .intr_rx_watermark_o    (),
    .intr_tx_empty_o        (),
    .intr_rx_overflow_o     (),
    .intr_rx_frame_err_o    (),
    .intr_rx_break_err_o    (),
    .intr_rx_timeout_o      (),
    .intr_rx_parity_err_o   ()
  );

  // DFI memory training GPIO interface
  phy_wrapper u_phy_wrapper (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),

    .tl_i             (tl_dev_h2d[2]),
    .tl_o             (tl_dev_d2h[2])
  );
endmodule
