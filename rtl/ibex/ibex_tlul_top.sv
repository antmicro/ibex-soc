// Copyright Antmicro.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Ibex RISC-V core
 *
 * 32 bit RISC-V core supporting the RV32I + optionally EMC instruction sets.
 * Instruction and data bus are 32 bit wide TileLink-UL (TL-UL).
 */

`ifdef RISCV_FORMAL
  `define RVFI
`endif

`include "prim_assert.sv"

module ibex_tlul_top import ibex_pkg::*; import tlul_pkg::*; import prim_mubi_pkg::*; #(
  parameter bit           PMPEnable        = 1'b0,
  parameter int unsigned  PMPGranularity   = 0,
  parameter int unsigned  PMPNumRegions    = 4,
  parameter int unsigned  MHPMCounterNum   = 0,
  parameter int unsigned  MHPMCounterWidth = 40,
  parameter bit           RV32E            = 1'b0,
  parameter rv32m_e       RV32M            = RV32MSingleCycle,
  parameter rv32b_e       RV32B            = RV32BNone,
  parameter regfile_e     RegFile          = RegFileFF,
  parameter bit           BranchTargetALU  = 1'b0,
  parameter bit           WritebackStage   = 1'b0,
  parameter bit           ICache           = 1'b0,
  parameter bit           ICacheECC        = 1'b0,
  parameter bit           ICacheScramble   = 1'b0,
  parameter bit           BranchPredictor  = 1'b0,
  parameter bit           DbgTriggerEn     = 1'b0,
  parameter int unsigned  DbgHwBreakNum    = 1,
  parameter lfsr_seed_t   RndCnstLfsrSeed  = RndCnstLfsrSeedDefault,
  parameter lfsr_perm_t   RndCnstLfsrPerm  = RndCnstLfsrPermDefault,
  parameter int unsigned  DmHaltAddr       = 32'h1A110800,
  parameter int unsigned  DmExceptionAddr  = 32'h1A110808,
  parameter bit           PipeLine         = 1'b0,
  parameter logic [SCRAMBLE_KEY_W-1:0]   RndCnstIbexKey   = RndCnstIbexKeyDefault,
  parameter logic [SCRAMBLE_NONCE_W-1:0] RndCnstIbexNonce = RndCnstIbexNonceDefault
) (
  // Clock and Reset
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic        test_en_i,
  input  logic        scan_rst_ni,
  input  prim_ram_1p_pkg::ram_1p_cfg_t ram_cfg_i,

  input  logic [31:0] hart_id_i,
  input  logic [31:0] boot_addr_i,

  // Instruction memory interface
  output tl_h2d_t     corei_tl_h_o,
  input  tl_d2h_t     corei_tl_h_i,

  // Data memory interface
  output tl_h2d_t     cored_tl_h_o,
  input  tl_d2h_t     cored_tl_h_i,

  // Interrupt inputs
  input  logic        irq_software_i,
  input  logic        irq_timer_i,
  input  logic        irq_external_i,
  input  logic [14:0] irq_fast_i,
  input  logic        irq_nm_i,

  // Debug Interface
  input  logic            debug_req_i,
  output crash_dump_t     crash_dump_o,
  output logic            double_fault_seen_o,

  // Scrambling Interface
  input  logic                         scramble_key_valid_i,
  input  logic [SCRAMBLE_KEY_W-1:0]    scramble_key_i,
  input  logic [SCRAMBLE_NONCE_W-1:0]  scramble_nonce_i,
  output logic                         scramble_req_o,

  // RISC-V Formal Interface
  // Does not comply with the coding standards of _i/_o suffixes, but follows
  // the convention of RISC-V Formal Interface Specification.
`ifdef RVFI
  output logic                         rvfi_valid,
  output logic [63:0]                  rvfi_order,
  output logic [31:0]                  rvfi_insn,
  output logic                         rvfi_trap,
  output logic                         rvfi_halt,
  output logic                         rvfi_intr,
  output logic [ 1:0]                  rvfi_mode,
  output logic [ 1:0]                  rvfi_ixl,
  output logic [ 4:0]                  rvfi_rs1_addr,
  output logic [ 4:0]                  rvfi_rs2_addr,
  output logic [ 4:0]                  rvfi_rs3_addr,
  output logic [31:0]                  rvfi_rs1_rdata,
  output logic [31:0]                  rvfi_rs2_rdata,
  output logic [31:0]                  rvfi_rs3_rdata,
  output logic [ 4:0]                  rvfi_rd_addr,
  output logic [31:0]                  rvfi_rd_wdata,
  output logic [31:0]                  rvfi_pc_rdata,
  output logic [31:0]                  rvfi_pc_wdata,
  output logic [31:0]                  rvfi_mem_addr,
  output logic [ 3:0]                  rvfi_mem_rmask,
  output logic [ 3:0]                  rvfi_mem_wmask,
  output logic [31:0]                  rvfi_mem_rdata,
  output logic [31:0]                  rvfi_mem_wdata,
  output logic [31:0]                  rvfi_ext_mip,
  output logic                         rvfi_ext_nmi,
  output logic                         rvfi_ext_debug_req,
  output logic [63:0]                  rvfi_ext_mcycle,
`endif

  // CPU Control Signals
  input  ibex_mubi_t                   fetch_enable_i,
  output logic                         alert_minor_o,
  output logic                         alert_major_internal_o,
  output logic                         alert_major_bus_o,
  output logic                         core_sleep_o
);

  import tlul_pkg::*;

  localparam bit FifoPass = PipeLine ? 1'b0 : 1'b1;
  localparam int unsigned FifoDepth = PipeLine ? 2 : 0;
  localparam int NumOutstandingReqs = ICache ? 8 : 2;

  // Instruction interface (internal)
  logic        instr_req;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;
  logic [6:0]  instr_rdata_intg;
  logic        instr_err;

  // Data interface (internal)
  logic        data_req;
  logic        data_gnt;
  logic        data_rvalid;
  logic        data_we;
  logic [3:0]  data_be;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [6:0]  data_wdata_intg;
  logic [31:0] data_rdata;
  logic [6:0]  data_rdata_intg;
  logic        data_err;

  ibex_top #(
    .PMPEnable(PMPEnable),
    .PMPGranularity(PMPGranularity),
    .PMPNumRegions(PMPNumRegions),
    .MHPMCounterNum(MHPMCounterNum),
    .MHPMCounterWidth(MHPMCounterWidth),
    .RV32E(RV32E),
    .RV32M(RV32M),
    .RV32B(RV32B),
    .RegFile(RegFile),
    .BranchTargetALU(BranchTargetALU),
    .WritebackStage(WritebackStage),
    .ICache(ICache),
    .ICacheECC(ICacheECC),
    .BranchPredictor(BranchPredictor),
    .DbgTriggerEn(DbgTriggerEn),
    .DbgHwBreakNum(DbgHwBreakNum),
    .ICacheScramble(ICacheScramble),
    .RndCnstLfsrSeed(RndCnstLfsrSeed),
    .RndCnstLfsrPerm(RndCnstLfsrPerm),
    .DmHaltAddr(DmHaltAddr),
    .DmExceptionAddr(DmExceptionAddr),
    .RndCnstIbexKey(RndCnstIbexKey),
    .RndCnstIbexNonce(RndCnstIbexNonce)
  ) u_ibex_top_base (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .test_en_i(test_en_i),
    .scan_rst_ni(scan_rst_ni),
    .ram_cfg_i(ram_cfg_i),

    .hart_id_i(hart_id_i),
    .boot_addr_i(boot_addr_i),

    .instr_req_o(instr_req),
    .instr_gnt_i(instr_gnt),
    .instr_rvalid_i(instr_rvalid),
    .instr_addr_o(instr_addr),
    .instr_rdata_i(instr_rdata),
    .instr_rdata_intg_i(instr_rdata_intg),
    .instr_err_i(instr_err),

    .data_req_o(data_req),
    .data_gnt_i(data_gnt),
    .data_rvalid_i(data_rvalid),
    .data_we_o(data_we),
    .data_be_o(data_be),
    .data_addr_o(data_addr),
    .data_wdata_o(data_wdata),
    .data_wdata_intg_o(data_wdata_intg),
    .data_rdata_i(data_rdata),
    .data_rdata_intg_i(data_rdata_intg),
    .data_err_i(data_err),

    .irq_software_i(irq_software_i),
    .irq_timer_i(irq_timer_i),
    .irq_external_i(irq_external_i),
    .irq_fast_i(irq_fast_i),
    .irq_nm_i(irq_nm_i),

    .scramble_key_valid_i(scramble_key_valid_i),
    .scramble_key_i(scramble_key_i),
    .scramble_nonce_i(scramble_nonce_i),
    .scramble_req_o(scramble_req_o),

    .debug_req_i(debug_req_i),
    .crash_dump_o(crash_dump_o),
    .double_fault_seen_o(double_fault_seen_o),

`ifdef RVFI
    .rvfi_valid(rvfi_valid),
    .rvfi_order(rvfi_order),
    .rvfi_insn(rvfi_insn),
    .rvfi_trap(rvfi_trap),
    .rvfi_halt(rvfi_halt),
    .rvfi_intr(rvfi_intr),
    .rvfi_mode(rvfi_mode),
    .rvfi_ixl(rvfi_ixl),
    .rvfi_rs1_addr(rvfi_rs1_addr),
    .rvfi_rs2_addr(rvfi_rs2_addr),
    .rvfi_rs3_addr(rvfi_rs3_addr),
    .rvfi_rs1_rdata(rvfi_rs1_rdata),
    .rvfi_rs2_rdata(rvfi_rs2_rdata),
    .rvfi_rs3_rdata(rvfi_rs3_rdata),
    .rvfi_rd_addr(rvfi_rd_addr),
    .rvfi_rd_wdata(rvfi_rd_wdata),
    .rvfi_pc_rdata(rvfi_pc_rdata),
    .rvfi_pc_wdata(rvfi_pc_wdata),
    .rvfi_mem_addr(rvfi_mem_addr),
    .rvfi_mem_rmask(rvfi_mem_rmask),
    .rvfi_mem_wmask(rvfi_mem_wmask),
    .rvfi_mem_rdata(rvfi_mem_rdata),
    .rvfi_mem_wdata(rvfi_mem_wdata),
    .rvfi_ext_mip(rvfi_ext_mip),
    .rvfi_ext_nmi(rvfi_ext_nmi),
    .rvfi_ext_debug_req(rvfi_ext_debug_req),
    .rvfi_ext_mcycle(rvfi_ext_mcycle),
    .rvfi_ext_nmi_int(),
    .rvfi_ext_debug_mode(),
    .rvfi_ext_mhpmcounters(),
    .rvfi_ext_mhpmcountersh(),
    .rvfi_ext_ic_scr_key_valid(),
    .rvfi_ext_irq_valid(),
    .rvfi_ext_rf_wr_suppress(),
`endif

    .fetch_enable_i(fetch_enable_i),
    .alert_minor_o(alert_minor_o),
    .alert_major_internal_o(alert_major_internal_o),
    .alert_major_bus_o(alert_major_bus_o),
    .core_sleep_o(core_sleep_o)
  );

  logic [6:0]  instr_wdata_intg;
  logic [top_pkg::TL_DW-1:0] unused_data;
  assign {instr_wdata_intg, unused_data} = prim_secded_pkg::prim_secded_inv_39_32_enc('0);

  tl_h2d_t tl_i_ibex2fifo;
  tl_d2h_t tl_i_fifo2ibex;

  wire intg_err_tl_adapter_host_i_ibex_nc;

  tlul_adapter_host #(
    .MAX_REQS(NumOutstandingReqs),
    .EnableDataIntgGen(1'b1)
  ) tl_adapter_host_i_ibex (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .req_i        (instr_req),
    .instr_type_i (MuBi4True),
    .gnt_o        (instr_gnt),
    .addr_i       (instr_addr),
    .we_i         (1'b0),
    .wdata_i      (32'b0),
    .wdata_intg_i (instr_wdata_intg),
    .be_i         (4'hF),
    .valid_o      (instr_rvalid),
    .rdata_o      (instr_rdata),
    .rdata_intg_o (instr_rdata_intg),
    .err_o        (instr_err),
    .intg_err_o   (intg_err_tl_adapter_host_i_ibex_nc),
    .tl_o         (tl_i_ibex2fifo),
    .tl_i         (tl_i_fifo2ibex));

  wire spare_req_fifo_i_nc, spare_rsp_fifo_i_nc,
       spare_req_fifo_d_nc, spare_rsp_fifo_d_nc;

  tlul_fifo_sync #(
    .ReqPass(FifoPass),
    .RspPass(FifoPass),
    .ReqDepth(FifoDepth),
    .RspDepth(FifoDepth)
  ) fifo_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tl_h_i      (tl_i_ibex2fifo),
    .tl_h_o      (tl_i_fifo2ibex),
    .tl_d_o      (corei_tl_h_o),
    .tl_d_i      (corei_tl_h_i),
    .spare_req_i (1'b0),
    .spare_req_o (spare_req_fifo_i_nc),
    .spare_rsp_i (1'b0),
    .spare_rsp_o (spare_rsp_fifo_i_nc)
  );

  tl_h2d_t tl_d_ibex2fifo;
  tl_d2h_t tl_d_fifo2ibex;

  wire intg_err_tl_adapter_host_d_ibex_nc;

  tlul_adapter_host #(
    .MAX_REQS(2),
    .EnableDataIntgGen(1'b1)
  ) tl_adapter_host_d_ibex (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .req_i        (data_req),
    .instr_type_i (MuBi4False),
    .gnt_o        (data_gnt),
    .addr_i       (data_addr),
    .we_i         (data_we),
    .wdata_i      (data_wdata),
    .wdata_intg_i (data_wdata_intg),
    .be_i         (data_be),
    .valid_o      (data_rvalid),
    .rdata_o      (data_rdata),
    .rdata_intg_o (data_rdata_intg),
    .err_o        (data_err),
    .intg_err_o   (intg_err_tl_adapter_host_d_ibex_nc),
    .tl_o         (tl_d_ibex2fifo),
    .tl_i         (tl_d_fifo2ibex)
  );

  tlul_fifo_sync #(
    .ReqPass(FifoPass),
    .RspPass(FifoPass),
    .ReqDepth(FifoDepth),
    .RspDepth(FifoDepth)
  ) fifo_d (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tl_h_i      (tl_d_ibex2fifo),
    .tl_h_o      (tl_d_fifo2ibex),
    .tl_d_o      (cored_tl_h_o),
    .tl_d_i      (cored_tl_h_i),
    .spare_req_i (1'b0),
    .spare_req_o (spare_req_fifo_d_nc),
    .spare_rsp_i (1'b0),
    .spare_rsp_o (spare_rsp_fifo_d_nc)
  );

endmodule
