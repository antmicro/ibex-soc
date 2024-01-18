// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module dram_phy_soc_top 
    import top_pkg::*;
    import mem_pkg::*;
    import tlul_pkg::*;
(
    // Clock and reset inputs
    input  wire clk_i,
    input  wire rst_ni,

    // Clock and reset outputs
    output wire clk_1x_o,
    output wire rst_1x_o,

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
    output logic dfi_init_done_o,

    // DDR memory
    output wire [ 5:0] ddram_ca,
    output wire        ddram_cs,
    inout  wire [15:0] ddram_dq,
    inout  wire [ 1:0] ddram_dqs_p,
    inout  wire [ 1:0] ddram_dqs_n,
    inout  wire [ 1:0] ddram_dmi,
    output wire        ddram_clk_p,
    output wire        ddram_clk_n,
    output wire        ddram_cke,
    output wire        ddram_odt,
    output wire        ddram_reset_n,

    // DDR PHY
    input  wire        dfi_cke_p0,
    input  wire        dfi_reset_n_p0,
    input  wire        dfi_mode_2n_p0,
    output wire        dfi_alert_n_w0,
    input  wire [16:0] dfi_address_p0,
    input  wire [ 5:0] dfi_bank_p0,
    input  wire        dfi_cas_n_p0,
    input  wire        dfi_cs_n_p0,
    input  wire        dfi_ras_n_p0,
    input  wire        dfi_act_n_p0,
    input  wire        dfi_odt_p0,
    input  wire        dfi_we_n_p0,
    input  wire [31:0] dfi_wrdata_p0,
    input  wire        dfi_wrdata_en_p0,
    input  wire [ 3:0] dfi_wrdata_mask_p0,
    input  wire        dfi_rddata_en_p0,
    output wire [31:0] dfi_rddata_w0,
    output wire        dfi_rddata_valid_w0,
    input  wire        dfi_cke_p1,
    input  wire        dfi_reset_n_p1,
    input  wire        dfi_mode_2n_p1,
    output wire        dfi_alert_n_w1,
    input  wire [16:0] dfi_address_p1,
    input  wire [ 5:0] dfi_bank_p1,
    input  wire        dfi_cas_n_p1,
    input  wire        dfi_cs_n_p1,
    input  wire        dfi_ras_n_p1,
    input  wire        dfi_act_n_p1,
    input  wire        dfi_odt_p1,
    input  wire        dfi_we_n_p1,
    input  wire [31:0] dfi_wrdata_p1,
    input  wire        dfi_wrdata_en_p1,
    input  wire [ 3:0] dfi_wrdata_mask_p1,
    input  wire        dfi_rddata_en_p1,
    output wire [31:0] dfi_rddata_w1,
    output wire        dfi_rddata_valid_w1,
    input  wire        dfi_cke_p2,
    input  wire        dfi_reset_n_p2,
    input  wire        dfi_mode_2n_p2,
    output wire        dfi_alert_n_w2,
    input  wire [16:0] dfi_address_p2,
    input  wire [ 5:0] dfi_bank_p2,
    input  wire        dfi_cas_n_p2,
    input  wire        dfi_cs_n_p2,
    input  wire        dfi_ras_n_p2,
    input  wire        dfi_act_n_p2,
    input  wire        dfi_odt_p2,
    input  wire        dfi_we_n_p2,
    input  wire [31:0] dfi_wrdata_p2,
    input  wire        dfi_wrdata_en_p2,
    input  wire [ 3:0] dfi_wrdata_mask_p2,
    input  wire        dfi_rddata_en_p2,
    output wire [31:0] dfi_rddata_w2,
    output wire        dfi_rddata_valid_w2,
    input  wire        dfi_cke_p3,
    input  wire        dfi_reset_n_p3,
    input  wire        dfi_mode_2n_p3,
    output wire        dfi_alert_n_w3,
    input  wire [16:0] dfi_address_p3,
    input  wire [ 5:0] dfi_bank_p3,
    input  wire        dfi_cas_n_p3,
    input  wire        dfi_cs_n_p3,
    input  wire        dfi_ras_n_p3,
    input  wire        dfi_act_n_p3,
    input  wire        dfi_odt_p3,
    input  wire        dfi_we_n_p3,
    input  wire [31:0] dfi_wrdata_p3,
    input  wire        dfi_wrdata_en_p3,
    input  wire [ 3:0] dfi_wrdata_mask_p3,
    input  wire        dfi_rddata_en_p3,
    output wire [31:0] dfi_rddata_w3,
    output wire        dfi_rddata_valid_w3,
    input  wire        dfi_cke_p4,
    input  wire        dfi_reset_n_p4,
    input  wire        dfi_mode_2n_p4,
    output wire        dfi_alert_n_w4,
    input  wire [16:0] dfi_address_p4,
    input  wire [ 5:0] dfi_bank_p4,
    input  wire        dfi_cas_n_p4,
    input  wire        dfi_cs_n_p4,
    input  wire        dfi_ras_n_p4,
    input  wire        dfi_act_n_p4,
    input  wire        dfi_odt_p4,
    input  wire        dfi_we_n_p4,
    input  wire [31:0] dfi_wrdata_p4,
    input  wire        dfi_wrdata_en_p4,
    input  wire [ 3:0] dfi_wrdata_mask_p4,
    input  wire        dfi_rddata_en_p4,
    output wire [31:0] dfi_rddata_w4,
    output wire        dfi_rddata_valid_w4,
    input  wire        dfi_cke_p5,
    input  wire        dfi_reset_n_p5,
    input  wire        dfi_mode_2n_p5,
    output wire        dfi_alert_n_w5,
    input  wire [16:0] dfi_address_p5,
    input  wire [ 5:0] dfi_bank_p5,
    input  wire        dfi_cas_n_p5,
    input  wire        dfi_cs_n_p5,
    input  wire        dfi_ras_n_p5,
    input  wire        dfi_act_n_p5,
    input  wire        dfi_odt_p5,
    input  wire        dfi_we_n_p5,
    input  wire [31:0] dfi_wrdata_p5,
    input  wire        dfi_wrdata_en_p5,
    input  wire [ 3:0] dfi_wrdata_mask_p5,
    input  wire        dfi_rddata_en_p5,
    output wire [31:0] dfi_rddata_w5,
    output wire        dfi_rddata_valid_w5,
    input  wire        dfi_cke_p6,
    input  wire        dfi_reset_n_p6,
    input  wire        dfi_mode_2n_p6,
    output wire        dfi_alert_n_w6,
    input  wire [16:0] dfi_address_p6,
    input  wire [ 5:0] dfi_bank_p6,
    input  wire        dfi_cas_n_p6,
    input  wire        dfi_cs_n_p6,
    input  wire        dfi_ras_n_p6,
    input  wire        dfi_act_n_p6,
    input  wire        dfi_odt_p6,
    input  wire        dfi_we_n_p6,
    input  wire [31:0] dfi_wrdata_p6,
    input  wire        dfi_wrdata_en_p6,
    input  wire [ 3:0] dfi_wrdata_mask_p6,
    input  wire        dfi_rddata_en_p6,
    output wire [31:0] dfi_rddata_w6,
    output wire        dfi_rddata_valid_w6,
    input  wire        dfi_cke_p7,
    input  wire        dfi_reset_n_p7,
    input  wire        dfi_mode_2n_p7,
    output wire        dfi_alert_n_w7,
    input  wire [16:0] dfi_address_p7,
    input  wire [ 5:0] dfi_bank_p7,
    input  wire        dfi_cas_n_p7,
    input  wire        dfi_cs_n_p7,
    input  wire        dfi_ras_n_p7,
    input  wire        dfi_act_n_p7,
    input  wire        dfi_odt_p7,
    input  wire        dfi_we_n_p7,
    input  wire [31:0] dfi_wrdata_p7,
    input  wire        dfi_wrdata_en_p7,
    input  wire [ 3:0] dfi_wrdata_mask_p7,
    input  wire        dfi_rddata_en_p7,
    output wire [31:0] dfi_rddata_w7,
    output wire        dfi_rddata_valid_w7
);

  // CPU TileLink bus
  tlul_pkg::tl_h2d_t tl_cpu_h2d;
  tlul_pkg::tl_d2h_t tl_cpu_d2h;

  // External TileLink bus
  tlul_pkg::tl_h2d_t tl_ext_h2d;
  tlul_pkg::tl_d2h_t tl_ext_d2h;

  // CRG
  wire clk_idelay;
  wire rst_idelay;
  wire clk_sys;
  wire rst_sys;
  wire clk_sys2x;
  wire rst_sys2x;
  wire clk_sys8x;
  wire rst_sys8x;
  wire rst_sys_n;

  assign rst_sys_n = ~rst_sys;
  assign clk_1x_o = clk_sys;
  assign rst_1x_o = rst_sys;

  // CPU
  cpu u_cpu (
    .clk_i          (clk_sys),
    .rst_ni         (rst_sys_n),

    .tl_o           (tl_cpu_h2d),
    .tl_i           (tl_cpu_d2h),

    .core_rst_ni    (rst_sys_n),
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
    .clk_i          (clk_sys),
    .rst_ni         (rst_sys_n),

    .tl_h_i         ('{tl_ext_h2d, tl_cpu_h2d}),
    .tl_h_o         ('{tl_ext_d2h, tl_cpu_d2h}),

    .tl_m_i         (tl_mem_d2h),
    .tl_m_o         (tl_mem_h2d),

    .tl_d_i         (tl_dev_d2h),
    .tl_d_o         (tl_dev_h2d)
  );

  // System memory interface
  mem u_mem (
    .clk_i          (clk_sys),
    .rst_ni         (rst_sys_n),

    .tl_i           (tl_mem_h2d),
    .tl_o           (tl_mem_d2h),

    .rom_o          (rom_o),
    .rom_i          (rom_i),

    .ram_o          (ram_o),
    .ram_i          (ram_i)
  );

  // DFI memory training GPIO interface
  dfi_gpio u_dfi_gpio (
    .clk_i            (clk_sys),
    .rst_ni           (rst_sys_n),

    .tl_i             (tl_dev_h2d[0]),
    .tl_o             (tl_dev_d2h[0]),

    .dfi_init_start_i (dfi_init_start_i),
    .dfi_init_done_o  (dfi_init_done_o)
  );

  // UART
  uart u_uart (
    .clk_i          (clk_sys),
    .rst_ni         (rst_sys_n),

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

  // PHY
  phy u_phy (
    .clk(clk_i),
    .rst(~rst_ni),

    .tl_i(tl_dev_h2d[2]),
    .tl_o(tl_dev_d2h[2]),

    .*
  );

endmodule
