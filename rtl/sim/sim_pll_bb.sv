// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module PLLE2_ADV #(
	CLKFBOUT_MULT   = 4'd12,
	CLKIN1_PERIOD	= 10.0,
	CLKOUT0_DIVIDE  = 5'd16,
	CLKOUT0_PHASE   = 1'd0,
	CLKOUT1_DIVIDE  = 4'd8,
	CLKOUT1_PHASE   = 1'd0,
	CLKOUT2_DIVIDE  = 2'd2,
	CLKOUT2_PHASE   = 1'd0,
	CLKOUT3_DIVIDE  = 3'd6,
	CLKOUT3_PHASE   = 1'd0,
	DIVCLK_DIVIDE   = 1'd1,
	REF_JITTER1     = 0.01,
	STARTUP_WAIT    = "FALSE"
)(
	input logic     CLKFBIN,
	input logic     CLKIN1,
	input logic     PWRDWN,
	input logic     RST,

	output logic    CLKFBOUT,
	output logic    CLKOUT0,
	output logic    CLKOUT1,
	output logic    CLKOUT2,
	output logic    CLKOUT3,
	output logic    LOCKED
);

initial CLKOUT1 = 1'b0;
always #0.25   CLKOUT1 <= !CLKOUT1;

initial CLKOUT2 = 1'b0;
always #0.03125  CLKOUT2 <= !CLKOUT2;

initial CLKOUT3 = 1'b0;
always #0.09375 CLKOUT3 <= !CLKOUT3;

assign CLKOUT0 = CLKIN1;
assign LOCKED = 1'b1;

endmodule

