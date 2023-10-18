// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

// Since it is impossible to access signals of a packed SystemVerilog struct
// in Verilator this module is needed to "unwrap" the signals.

module wrapper
  import top_pkg::*;
  import tlul_pkg::*;
  import dfi_gpio_csr_pkg::*;
(
  // Clock and reset
  input  wire clk_i,
  input  wire rst_ni,

  // TileLink
  input  logic                           tl_gpio_i_a_valid,
  input  tl_a_op_e                       tl_gpio_i_a_opcode,
  input  logic                  [2:0]    tl_gpio_i_a_param,
  input  logic  [top_pkg::TL_SZW-1:0]    tl_gpio_i_a_size,
  input  logic  [top_pkg::TL_AIW-1:0]    tl_gpio_i_a_source,
  input  logic  [top_pkg::TL_AW -1:0]    tl_gpio_i_a_address,
  input  logic  [top_pkg::TL_DBW-1:0]    tl_gpio_i_a_mask,
  input  logic  [top_pkg::TL_DW -1:0]    tl_gpio_i_a_data,
  input  tl_a_user_t                     tl_gpio_i_a_user,
  input  logic                           tl_gpio_i_d_ready,

  output logic                           tl_gpio_o_d_valid,
  output tl_d_op_e                       tl_gpio_o_d_opcode,
  output logic                  [2:0]    tl_gpio_o_d_param,
  output logic  [top_pkg::TL_SZW-1:0]    tl_gpio_o_d_size,   // Bouncing back a_size
  output logic  [top_pkg::TL_AIW-1:0]    tl_gpio_o_d_source,
  output logic  [top_pkg::TL_DIW-1:0]    tl_gpio_o_d_sink,
  output logic  [top_pkg::TL_DW -1:0]    tl_gpio_o_d_data,
  output tl_d_user_t                     tl_gpio_o_d_user,
  output logic                           tl_gpio_o_d_error,
  output logic                           tl_gpio_o_a_ready,

  // DFI GPIOs
  input  logic                           dfi_init_start_i,
  output logic                           dfi_init_done_o
);

  tlul_pkg::tl_h2d_t tl_i;
  tlul_pkg::tl_d2h_t tl_o;

  assign tl_i.a_valid   = tl_gpio_i_a_valid;
  assign tl_i.a_opcode  = tl_gpio_i_a_opcode;
  assign tl_i.a_param   = tl_gpio_i_a_param;
  assign tl_i.a_size    = tl_gpio_i_a_size;
  assign tl_i.a_source  = tl_gpio_i_a_source;
  assign tl_i.a_address = tl_gpio_i_a_address;
  assign tl_i.a_mask    = tl_gpio_i_a_mask;
  assign tl_i.a_data    = tl_gpio_i_a_data;
  assign tl_i.a_user    = tl_gpio_i_a_user;
  assign tl_i.d_ready   = tl_gpio_i_d_ready;

  assign tl_gpio_o_d_valid   = tl_o.d_valid;
  assign tl_gpio_o_d_opcode  = tl_o.d_opcode;
  assign tl_gpio_o_d_param   = tl_o.d_param;
  assign tl_gpio_o_d_size    = tl_o.d_size;
  assign tl_gpio_o_d_source  = tl_o.d_source;
  assign tl_gpio_o_d_sink    = tl_o.d_sink;
  assign tl_gpio_o_d_data    = tl_o.d_data;
  assign tl_gpio_o_d_user    = tl_o.d_user;
  assign tl_gpio_o_d_error   = tl_o.d_error;
  assign tl_gpio_o_a_ready   = tl_o.a_ready;

  dfi_gpio u_dfi_gpio (
      .*
  );

endmodule
