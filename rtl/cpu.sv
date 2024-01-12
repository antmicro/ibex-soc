// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module cpu import ibex_pkg::*; import tlul_pkg::*; (

    // Clock and reset
    input  wire clk_i,
    input  wire rst_ni,

    // TileLink
    output tlul_pkg::tl_h2d_t tl_o,
    input  tlul_pkg::tl_d2h_t tl_i,

    // Misc core signals
    input  wire         core_rst_ni,
    input  wire [31:0]  boot_addr_i, // First instruction executed is at boot_addr_i + 0x80
    input  wire         fetch_enable_i,
    input  wire         timer_irq_i
  );

  // Host TileLink signals
  tlul_pkg::tl_h2d_t tl_h2d_core [2];
  tlul_pkg::tl_d2h_t tl_d2h_core [2];

  // Unused core signals
  wire scramble_req_nc;
  wire double_fault_seen_nc;
  wire alert_minor_nc,     alert_major_internal_nc,
       alert_major_bus_nc, core_sleep_nc;

  ibex_pkg::crash_dump_t crash_dump_nc;

  // Ibex core
  ibex_tlul_top #(
    .ICacheScramble         (1'b0),
    .PMPEnable              (1'b0),
    .PMPGranularity         (0),
    .PMPNumRegions          (4),
    .MHPMCounterNum         (0),
    .MHPMCounterWidth       (40),
    .RV32E                  (1'b1),
    .RV32M                  (ibex_pkg::RV32MNone),
    .RV32B                  (ibex_pkg::RV32BNone),
    .RegFile                (ibex_pkg::RegFileFPGA),
    .BranchTargetALU        (1'b0),
    .ICache                 (1'b0),
    .ICacheECC              (1'b0),
    .WritebackStage         (1'b0),
    .BranchPredictor        (1'b0),
    .DbgTriggerEn           (1'b0),
    .DmHaltAddr             (32'h00100000), // TODO
    .DmExceptionAddr        (32'h00100000)  // TODO

  ) u_top (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni | core_rst_ni),

    .test_en_i              ('b0),
    .scan_rst_ni            (1'b1),
    .ram_cfg_i              ('b0),

    .hart_id_i              (32'b0),
    .boot_addr_i            (boot_addr_i),

    .cored_tl_h_o           (tl_h2d_core[0]),
    .cored_tl_h_i           (tl_d2h_core[0]),
    .corei_tl_h_o           (tl_h2d_core[1]),
    .corei_tl_h_i           (tl_d2h_core[1]),

    .irq_software_i         (1'b0),
    .irq_timer_i            (timer_irq_i),
    .irq_external_i         (1'b0),
    .irq_fast_i             (15'b0),
    .irq_nm_i               (1'b0),

    .scramble_key_valid_i   ('0),
    .scramble_key_i         ('0),
    .scramble_nonce_i       ('0),
    .scramble_req_o         (scramble_req_nc),

    .debug_req_i            ('b0),
    .crash_dump_o           (crash_dump_nc),
    .double_fault_seen_o    (double_fault_seen_nc),

    .fetch_enable_i         (fetch_enable_i ? ibex_pkg::IbexMuBiOn:
                                              ibex_pkg::IbexMuBiOff),

    .alert_minor_o          (alert_minor_nc),
    .alert_major_internal_o (alert_major_internal_nc),
    .alert_major_bus_o      (alert_major_bus_nc),
    .core_sleep_o           (core_sleep_nc)
  );

  // TileLink mux. Bridges instruction and data buses together.
  tlul_socket_m1 #(.M(2)) u_tlul_mux (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),

    .tl_d_i                 (tl_i),
    .tl_d_o                 (tl_o),

    .tl_h_i                 (tl_h2d_core),
    .tl_h_o                 (tl_d2h_core)
  );

endmodule
