// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

// Since it is impossible to access signals of a packed SystemVerilog struct
// in Verilator this module is needed to "unwrap" the signals.

`define TLUL_H2D(dir, pfx)                            \
  dir logic                        ``pfx``_a_valid,   \
  dir tl_a_op_e                    ``pfx``_a_opcode,  \
  dir logic                  [2:0] ``pfx``_a_param,   \
  dir logic  [top_pkg::TL_SZW-1:0] ``pfx``_a_size,    \
  dir logic  [top_pkg::TL_AIW-1:0] ``pfx``_a_source,  \
  dir logic  [top_pkg::TL_AW -1:0] ``pfx``_a_address, \
  dir logic  [top_pkg::TL_DBW-1:0] ``pfx``_a_mask,    \
  dir logic  [top_pkg::TL_DW -1:0] ``pfx``_a_data,    \
  dir tl_a_user_t                  ``pfx``_a_user,    \
  dir logic                        ``pfx``_d_ready,

`define TLUL_D2H(dir, pfx)                            \
  dir logic                        ``pfx``_d_valid,   \
  dir tl_d_op_e                    ``pfx``_d_opcode,  \
  dir logic                  [2:0] ``pfx``_d_param,   \
  dir logic  [top_pkg::TL_SZW-1:0] ``pfx``_d_size,    \
  dir logic  [top_pkg::TL_AIW-1:0] ``pfx``_d_source,  \
  dir logic  [top_pkg::TL_DIW-1:0] ``pfx``_d_sink,    \
  dir logic  [top_pkg::TL_DW -1:0] ``pfx``_d_data,    \
  dir tl_d_user_t                  ``pfx``_d_user,    \
  dir logic                        ``pfx``_d_error,   \
  dir logic                        ``pfx``_a_ready,

`define TLUL_H2D_INP(pfx)                             \
  tlul_pkg::tl_h2d_t ``pfx``;                         \
  assign ``pfx``.a_valid   = ``pfx``_a_valid;         \
  assign ``pfx``.a_opcode  = ``pfx``_a_opcode;        \
  assign ``pfx``.a_param   = ``pfx``_a_param;         \
  assign ``pfx``.a_size    = ``pfx``_a_size;          \
  assign ``pfx``.a_source  = ``pfx``_a_source;        \
  assign ``pfx``.a_address = ``pfx``_a_address;       \
  assign ``pfx``.a_mask    = ``pfx``_a_mask;          \
  assign ``pfx``.a_data    = ``pfx``_a_data;          \
  assign ``pfx``.a_user    = ``pfx``_a_user;          \
  assign ``pfx``.d_ready   = ``pfx``_d_ready;

`define TLUL_H2D_OUT(pfx)                             \
  tlul_pkg::tl_h2d_t ``pfx``;                         \
  assign ``pfx``_a_valid   = ``pfx``.a_valid;         \
  assign ``pfx``_a_opcode  = ``pfx``.a_opcode;        \
  assign ``pfx``_a_param   = ``pfx``.a_param;         \
  assign ``pfx``_a_size    = ``pfx``.a_size;          \
  assign ``pfx``_a_source  = ``pfx``.a_source;        \
  assign ``pfx``_a_address = ``pfx``.a_address;       \
  assign ``pfx``_a_mask    = ``pfx``.a_mask;          \
  assign ``pfx``_a_data    = ``pfx``.a_data;          \
  assign ``pfx``_a_user    = ``pfx``.a_user;          \
  assign ``pfx``_d_ready   = ``pfx``.d_ready;

`define TLUL_D2H_INP(pfx)                             \
  tlul_pkg::tl_d2h_t ``pfx``;                         \
  assign ``pfx``.d_valid   = ``pfx``_d_valid;         \
  assign ``pfx``.d_opcode  = ``pfx``_d_opcode;        \
  assign ``pfx``.d_param   = ``pfx``_d_param;         \
  assign ``pfx``.d_size    = ``pfx``_d_size;          \
  assign ``pfx``.d_source  = ``pfx``_d_source;        \
  assign ``pfx``.d_sink    = ``pfx``_d_sink;          \
  assign ``pfx``.d_data    = ``pfx``_d_data;          \
  assign ``pfx``.d_user    = ``pfx``_d_user;          \
  assign ``pfx``.d_error   = ``pfx``_d_error;         \
  assign ``pfx``.a_ready   = ``pfx``_a_ready;

`define TLUL_D2H_OUT(pfx)                             \
  tlul_pkg::tl_d2h_t ``pfx``;                         \
  assign ``pfx``_d_valid   = ``pfx``.d_valid;         \
  assign ``pfx``_d_opcode  = ``pfx``.d_opcode;        \
  assign ``pfx``_d_param   = ``pfx``.d_param;         \
  assign ``pfx``_d_size    = ``pfx``.d_size;          \
  assign ``pfx``_d_source  = ``pfx``.d_source;        \
  assign ``pfx``_d_sink    = ``pfx``.d_sink;          \
  assign ``pfx``_d_data    = ``pfx``.d_data;          \
  assign ``pfx``_d_user    = ``pfx``.d_user;          \
  assign ``pfx``_d_error   = ``pfx``.d_error;         \
  assign ``pfx``_a_ready   = ``pfx``.a_ready;

// ============================================================================

module wrapper import top_pkg::*; import tlul_pkg::*; (

    // Upstream TileLink ports
    `TLUL_H2D(input,  tl_h0_i)
    `TLUL_D2H(output, tl_h0_o)

    `TLUL_H2D(input,  tl_h1_i)
    `TLUL_D2H(output, tl_h1_o)

    // Downstream TileLink ports for memory
    `TLUL_D2H(input,  tl_m_i)
    `TLUL_H2D(output, tl_m_o)

    // Downstream TileLink ports for peripherals
    `TLUL_D2H(input,  tl_d0_i)
    `TLUL_H2D(output, tl_d0_o)

    `TLUL_D2H(input,  tl_d1_i)
    `TLUL_H2D(output, tl_d1_o)

    `TLUL_D2H(input,  tl_d2_i)
    `TLUL_H2D(output, tl_d2_o)

    `TLUL_D2H(input,  tl_d3_i)
    `TLUL_H2D(output, tl_d3_o)

    `TLUL_D2H(input,  tl_d4_i)
    `TLUL_H2D(output, tl_d4_o)

    `TLUL_D2H(input,  tl_d5_i)
    `TLUL_H2D(output, tl_d5_o)

    `TLUL_D2H(input,  tl_d6_i)
    `TLUL_H2D(output, tl_d6_o)

    // Clock and reset
    input  wire clk_i,
    input  wire rst_ni
);

  // Upstream TileLink ports
  `TLUL_H2D_INP(tl_h0_i)
  `TLUL_D2H_OUT(tl_h0_o)

  `TLUL_H2D_INP(tl_h1_i)
  `TLUL_D2H_OUT(tl_h1_o)

  tlul_pkg::tl_h2d_t tl_h_i[2];
  tlul_pkg::tl_d2h_t tl_h_o[2];

  assign tl_h_i  = '{tl_h0_i, tl_h1_i};
  assign tl_h0_o = tl_h_o[0];
  assign tl_h1_o = tl_h_o[1];

  // Downstream TileLink ports for memory
  `TLUL_D2H_INP(tl_m_i)
  `TLUL_H2D_OUT(tl_m_o)

  // Downstream TileLink ports for peripherals
  `TLUL_D2H_INP(tl_d0_i)
  `TLUL_H2D_OUT(tl_d0_o)

  `TLUL_D2H_INP(tl_d1_i)
  `TLUL_H2D_OUT(tl_d1_o)

  `TLUL_D2H_INP(tl_d2_i)
  `TLUL_H2D_OUT(tl_d2_o)

  `TLUL_D2H_INP(tl_d3_i)
  `TLUL_H2D_OUT(tl_d3_o)

  `TLUL_D2H_INP(tl_d4_i)
  `TLUL_H2D_OUT(tl_d4_o)

  `TLUL_D2H_INP(tl_d5_i)
  `TLUL_H2D_OUT(tl_d5_o)

  `TLUL_D2H_INP(tl_d6_i)
  `TLUL_H2D_OUT(tl_d6_o)

  tlul_pkg::tl_d2h_t tl_d_i[7];
  tlul_pkg::tl_h2d_t tl_d_o[7];

  assign tl_d_i  = '{tl_d0_i, tl_d1_i, tl_d2_i, tl_d3_i,
                     tl_d4_i, tl_d5_i, tl_d6_i};

  assign tl_d0_o = tl_d_o[0];
  assign tl_d1_o = tl_d_o[1];
  assign tl_d2_o = tl_d_o[2];
  assign tl_d3_o = tl_d_o[3];
  assign tl_d4_o = tl_d_o[4];
  assign tl_d5_o = tl_d_o[5];
  assign tl_d6_o = tl_d_o[6];

  xbar #(.M(2), .N(7)) u_xbar (
    .*
  );

endmodule
