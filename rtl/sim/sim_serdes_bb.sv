// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module ISERDESE2 (O, Q1, Q2, Q3, Q4, Q5, Q6, Q7, Q8, SHIFTOUT1, SHIFTOUT2, BITSLIP, CE1, CE2, CLK, CLKB, CLKDIV, CLKDIVP, D, DDLY, DYNCLKDIVSEL, DYNCLKSEL, OCLK, OCLKB, OFB, RST, SHIFTIN1, SHIFTIN2);
  parameter DATA_RATE = "DDR";
  parameter integer DATA_WIDTH = 4;
  parameter DYN_CLKDIV_INV_EN = "FALSE";
  parameter DYN_CLK_INV_EN = "FALSE";
  parameter [0:0] INIT_Q1 = 1'b0;
  parameter [0:0] INIT_Q2 = 1'b0;
  parameter [0:0] INIT_Q3 = 1'b0;
  parameter [0:0] INIT_Q4 = 1'b0;
  parameter INTERFACE_TYPE = "MEMORY";
  parameter IOBDELAY = "NONE";
  parameter [0:0] IS_CLKB_INVERTED = 1'b0;
  parameter [0:0] IS_CLKDIVP_INVERTED = 1'b0;
  parameter [0:0] IS_CLKDIV_INVERTED = 1'b0;
  parameter [0:0] IS_CLK_INVERTED = 1'b0;
  parameter [0:0] IS_D_INVERTED = 1'b0;
  parameter [0:0] IS_OCLKB_INVERTED = 1'b0;
  parameter [0:0] IS_OCLK_INVERTED = 1'b0;

  `ifdef XIL_TIMING //Simprim
  parameter LOC = "UNPLACED";
  `endif
  parameter integer NUM_CE = 2;
  parameter OFB_USED = "FALSE";
  parameter SERDES_MODE = "MASTER";
  parameter [0:0] SRVAL_Q1 = 1'b0;
  parameter [0:0] SRVAL_Q2 = 1'b0;
  parameter [0:0] SRVAL_Q3 = 1'b0;
  parameter [0:0] SRVAL_Q4 = 1'b0;

  output O;
  output Q1;
  output Q2;
  output Q3;
  output Q4;
  output Q5;
  output Q6;
  output Q7;
  output Q8;
  output SHIFTOUT1;
  output SHIFTOUT2;

  input BITSLIP;
  input CE1;
  input CE2;
  input CLK;
  input CLKB;
  input CLKDIV;
  input CLKDIVP;
  input D;
  input DDLY;
  input DYNCLKDIVSEL;
  input DYNCLKSEL;
  input OCLK;
  input OCLKB;
  input OFB;
  input RST;
  input SHIFTIN1;
  input SHIFTIN2;
endmodule

module B_ISERDESE2 #(
    parameter DATA_RATE = "DDR",
    parameter integer DATA_WIDTH = 4,
    parameter DYN_CLKDIV_INV_EN = "FALSE",
    parameter DYN_CLK_INV_EN = "FALSE",
    parameter [0:0] INIT_Q1 = 1'b0,
    parameter [0:0] INIT_Q2 = 1'b0,
    parameter [0:0] INIT_Q3 = 1'b0,
    parameter [0:0] INIT_Q4 = 1'b0,
    parameter INTERFACE_TYPE = "MEMORY",
    parameter IOBDELAY = "NONE",
    parameter integer NUM_CE = 2,
    parameter OFB_USED = "FALSE",
    parameter SERDES_MODE = "MASTER",
    parameter [0:0] SRVAL_Q1 = 1'b0,
    parameter [0:0] SRVAL_Q2 = 1'b0,
    parameter [0:0] SRVAL_Q3 = 1'b0,
    parameter [0:0] SRVAL_Q4 = 1'b0
)(
    output O,
    output Q1,
    output Q2,
    output Q3,
    output Q4,
    output Q5,
    output Q6,
    output Q7,
    output Q8,
    output SHIFTOUT1,
    output SHIFTOUT2,

    input BITSLIP,
    input CE1,
    input CE2,
    input CLK,
    input CLKB,
    input CLKDIV,
    input CLKDIVP,
    input D,
    input DDLY,
    input DYNCLKDIVSEL,
    input DYNCLKSEL,
    input OCLK,
    input OCLKB,
    input OFB,
    input RST,
    input SHIFTIN1,
    input SHIFTIN2,
    input GSR
);
endmodule

module OSERDESE2 (OFB, OQ, SHIFTOUT1, SHIFTOUT2, TBYTEOUT, TFB, TQ, CLK, CLKDIV, D1, D2, D3, D4, D5, D6, D7, D8, OCE, RST, SHIFTIN1, SHIFTIN2, T1, T2, T3, T4, TBYTEIN, TCE);
  parameter DATA_RATE_OQ = "DDR";
  parameter DATA_RATE_TQ = "DDR";
  parameter integer DATA_WIDTH = 4;
  parameter [0:0] INIT_OQ = 1'b0;
  parameter [0:0] INIT_TQ = 1'b0;
  parameter [0:0] IS_CLKDIV_INVERTED = 1'b0;
  parameter [0:0] IS_CLK_INVERTED = 1'b0;
  parameter [0:0] IS_D1_INVERTED = 1'b0;
  parameter [0:0] IS_D2_INVERTED = 1'b0;
  parameter [0:0] IS_D3_INVERTED = 1'b0;
  parameter [0:0] IS_D4_INVERTED = 1'b0;
  parameter [0:0] IS_D5_INVERTED = 1'b0;
  parameter [0:0] IS_D6_INVERTED = 1'b0;
  parameter [0:0] IS_D7_INVERTED = 1'b0;
  parameter [0:0] IS_D8_INVERTED = 1'b0;
  parameter [0:0] IS_T1_INVERTED = 1'b0;
  parameter [0:0] IS_T2_INVERTED = 1'b0;
  parameter [0:0] IS_T3_INVERTED = 1'b0;
  parameter [0:0] IS_T4_INVERTED = 1'b0;


  `ifdef XIL_TIMING //Simprim
  parameter LOC = "UNPLACED";
  `endif
  parameter SERDES_MODE = "MASTER";
  parameter [0:0] SRVAL_OQ = 1'b0;
  parameter [0:0] SRVAL_TQ = 1'b0;
  parameter TBYTE_CTL = "FALSE";
  parameter TBYTE_SRC = "FALSE";
  parameter integer TRISTATE_WIDTH = 4;

  output OFB;
  output OQ;
  output SHIFTOUT1;
  output SHIFTOUT2;
  output TBYTEOUT;
  output TFB;
  output TQ;

  input CLK;
  input CLKDIV;
  input D1;
  input D2;
  input D3;
  input D4;
  input D5;
  input D6;
  input D7;
  input D8;
  input OCE;
  input RST;
  input SHIFTIN1;
  input SHIFTIN2;
  input T1;
  input T2;
  input T3;
  input T4;
  input TBYTEIN;
  input TCE;
endmodule

module B_OSERDESE2 #(
    parameter DATA_RATE_OQ = "DDR",
    parameter DATA_RATE_TQ = "DDR",
    parameter integer DATA_WIDTH = 4,
    parameter [0:0] INIT_OQ = 1'b0,
    parameter [0:0] INIT_TQ = 1'b0,
    parameter SERDES_MODE = "MASTER",
    parameter [0:0] SRVAL_OQ = 1'b0,
    parameter [0:0] SRVAL_TQ = 1'b0,
    parameter TBYTE_CTL = "FALSE",
    parameter TBYTE_SRC = "FALSE",
    parameter integer TRISTATE_WIDTH = 4
)(
    output OFB,
    output OQ,
    output SHIFTOUT1,
    output SHIFTOUT2,
    output TBYTEOUT,
    output TFB,
    output TQ,

    input CLK,
    input CLKDIV,
    input D1,
    input D2,
    input D3,
    input D4,
    input D5,
    input D6,
    input D7,
    input D8,
    input OCE,
    input RST,
    input SHIFTIN1,
    input SHIFTIN2,
    input T1,
    input T2,
    input T3,
    input T4,
    input TBYTEIN,
    input TCE,
    input GSR
);
endmodule

module IDELAYE2 (CNTVALUEOUT, DATAOUT, C, CE, CINVCTRL, CNTVALUEIN, DATAIN, IDATAIN, INC, LD, LDPIPEEN, REGRST);
    parameter CINVCTRL_SEL = "FALSE";
    parameter DELAY_SRC = "IDATAIN";
    parameter HIGH_PERFORMANCE_MODE    = "FALSE";
    parameter IDELAY_TYPE  = "FIXED";
    parameter integer IDELAY_VALUE = 0;
    parameter [0:0] IS_C_INVERTED = 1'b0;
    parameter [0:0] IS_DATAIN_INVERTED = 1'b0;
    parameter [0:0] IS_IDATAIN_INVERTED = 1'b0;
    parameter PIPE_SEL = "FALSE";
    parameter real REFCLK_FREQUENCY = 200.0;
    parameter SIGNAL_PATTERN    = "DATA";

`ifdef XIL_TIMING
    parameter LOC = "UNPLACED";
    parameter integer SIM_DELAY_D = 0;
`endif // ifdef XIL_TIMING

`ifndef XIL_TIMING
    integer DELAY_D=0;
`endif // ifndef XIL_TIMING

    output [4:0] CNTVALUEOUT;
    output DATAOUT;

    input C;
    input CE;
    input CINVCTRL;
    input [4:0] CNTVALUEIN;
    input DATAIN;
    input IDATAIN;
    input INC;
    input LD;
    input LDPIPEEN;
    input REGRST;
endmodule

module ODELAYE2 (CNTVALUEOUT, DATAOUT, C, CE, CINVCTRL, CLKIN, CNTVALUEIN, INC, LD, LDPIPEEN, ODATAIN, REGRST);
    parameter CINVCTRL_SEL = "FALSE";
    parameter DELAY_SRC = "ODATAIN";
    parameter HIGH_PERFORMANCE_MODE    = "FALSE";
    parameter [0:0] IS_C_INVERTED = 1'b0;
    parameter [0:0] IS_ODATAIN_INVERTED = 1'b0;
    parameter ODELAY_TYPE  = "FIXED";
    parameter integer ODELAY_VALUE = 0;
    parameter PIPE_SEL = "FALSE";
    parameter real REFCLK_FREQUENCY = 200.0;
    parameter SIGNAL_PATTERN    = "DATA";

`ifdef XIL_TIMING
    parameter LOC = "UNPLACED";
    parameter integer SIM_DELAY_D = 0;
    localparam DELAY_D = (ODELAY_TYPE == "VARIABLE") ? SIM_DELAY_D : 0;
`endif // ifdef XIL_TIMING

`ifndef XIL_TIMING
    integer DELAY_D=0;
`endif // ifndef XIL_TIMING

    output [4:0] CNTVALUEOUT;
    output DATAOUT;

    input C;
    input CE;
    input CINVCTRL;
    input CLKIN;
    input [4:0] CNTVALUEIN;
    input INC;
    input LD;
    input LDPIPEEN;
    input ODATAIN;
    input REGRST;
endmodule
