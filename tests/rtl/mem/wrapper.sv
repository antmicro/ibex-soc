// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

// Since it is impossible to access signals of a packed SystemVerilog struct
// in Verilator this module is needed to "unwrap" the signals.

module wrapper import top_pkg::*; import tlul_pkg::*; import mem_pkg::*; (

    // Clock and reset
    input  wire clk_i,
    input  wire rst_ni,

    // TileLink
    input  logic                           tl_i_a_valid,
    input  tl_a_op_e                       tl_i_a_opcode,
    input  logic                  [2:0]    tl_i_a_param,
    input  logic  [top_pkg::TL_SZW-1:0]    tl_i_a_size,
    input  logic  [top_pkg::TL_AIW-1:0]    tl_i_a_source,
    input  logic  [top_pkg::TL_AW -1:0]    tl_i_a_address,
    input  logic  [top_pkg::TL_DBW-1:0]    tl_i_a_mask,
    input  logic  [top_pkg::TL_DW -1:0]    tl_i_a_data,
    input  tl_a_user_t                     tl_i_a_user,
    input  logic                           tl_i_d_ready,

    output logic                           tl_o_d_valid,
    output tl_d_op_e                       tl_o_d_opcode,
    output logic                  [2:0]    tl_o_d_param,
    output logic  [top_pkg::TL_SZW-1:0]    tl_o_d_size,   // Bouncing back a_size
    output logic  [top_pkg::TL_AIW-1:0]    tl_o_d_source,
    output logic  [top_pkg::TL_DIW-1:0]    tl_o_d_sink,
    output logic  [top_pkg::TL_DW -1:0]    tl_o_d_data,
    output tl_d_user_t                     tl_o_d_user,
    output logic                           tl_o_d_error,
    output logic                           tl_o_a_ready,

    output logic                           rom_o_req,
    output logic                           rom_o_we,
    output logic [top_pkg::MEM_AW   - 1:0] rom_o_addr,
    output logic [top_pkg::MEM_DW   - 1:0] rom_o_data,
    output logic [top_pkg::MEM_DW/8 - 1:0] rom_o_mask,

    input  logic                           rom_i_gnt,
    input  logic                           rom_i_valid,
    input  logic [top_pkg::MEM_DW   - 1:0] rom_i_data,
    input  logic [1:0]                     rom_i_error, // 2 bit error [1]: Uncorrectable, [0]: Correctable

    output logic                           ram_o_req,
    output logic                           ram_o_we,
    output logic [top_pkg::MEM_AW   - 1:0] ram_o_addr,
    output logic [top_pkg::MEM_DW   - 1:0] ram_o_data,
    output logic [top_pkg::MEM_DW/8 - 1:0] ram_o_mask,

    input  logic                           ram_i_gnt,
    input  logic                           ram_i_valid,
    input  logic [top_pkg::MEM_DW   - 1:0] ram_i_data,
    input  logic [1:0]                     ram_i_error  // 2 bit error [1]: Uncorrectable, [0]: Correctable
);

  tlul_pkg::tl_h2d_t tl_i;
  tlul_pkg::tl_d2h_t tl_o;

  mem_pkg::mem_h2d_t rom_o;
  mem_pkg::mem_d2h_t rom_i;

  mem_pkg::mem_h2d_t ram_o;
  mem_pkg::mem_d2h_t ram_i;

  assign tl_i.a_valid   = tl_i_a_valid;
  assign tl_i.a_opcode  = tl_i_a_opcode;
  assign tl_i.a_param   = tl_i_a_param;
  assign tl_i.a_size    = tl_i_a_size;
  assign tl_i.a_source  = tl_i_a_source;
  assign tl_i.a_address = tl_i_a_address;
  assign tl_i.a_mask    = tl_i_a_mask;
  assign tl_i.a_data    = tl_i_a_data;
  assign tl_i.a_user    = tl_i_a_user;
  assign tl_i.d_ready   = tl_i_d_ready;

  assign tl_o_d_valid   = tl_o.d_valid;
  assign tl_o_d_opcode  = tl_o.d_opcode;
  assign tl_o_d_param   = tl_o.d_param;
  assign tl_o_d_size    = tl_o.d_size;
  assign tl_o_d_source  = tl_o.d_source;
  assign tl_o_d_sink    = tl_o.d_sink;
  assign tl_o_d_data    = tl_o.d_data;
  assign tl_o_d_user    = tl_o.d_user;
  assign tl_o_d_error   = tl_o.d_error;
  assign tl_o_a_ready   = tl_o.a_ready;

  assign rom_o_req      = rom_o.req;
  assign rom_o_we       = rom_o.we;
  assign rom_o_addr     = rom_o.addr;
  assign rom_o_data     = rom_o.data;
  assign rom_o_mask     = rom_o.mask;

  assign rom_i.gnt      = rom_i_gnt;
  assign rom_i.valid    = rom_i_valid;
  assign rom_i.data     = rom_i_data;
  assign rom_i.error    = rom_i_error;

  assign ram_o_req      = ram_o.req;
  assign ram_o_we       = ram_o.we;
  assign ram_o_addr     = ram_o.addr;
  assign ram_o_data     = ram_o.data;
  assign ram_o_mask     = ram_o.mask;

  assign ram_i.gnt      = ram_i_gnt;
  assign ram_i.valid    = ram_i_valid;
  assign ram_i.data     = ram_i_data;
  assign ram_i.error    = ram_i_error;

  mem u_mem (
      .*
  );

endmodule
