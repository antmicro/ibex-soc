// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module sim_ram # (
    parameter AW   = 32,
    parameter DW   = 32,
    parameter SIZE = 1024
)(
    // Clock and reset
    input  logic clk_i,
    input  logic rst_ni,

    // Memory interface
    input  logic            req,
    input  logic            we,
    input  logic [AW-1:0]   addr,
    input  logic [DW-1:0]   wdata,
    input  logic [DW/8-1:0] wmask,
    output logic [DW-1:0]   rdata,
    output logic            rvalid
);

  localparam EffectiveAw = $clog2(SIZE);

  // The memory
  logic [DW-1:0] mem [SIZE];
  logic [DW-1:0] mask;

  // Per-bit mask
  for (genvar i = 0; i < DW; i++)
    assign mask[i] = wmask[i / 8];

  // Write logic
  always @(posedge clk_i)
    if (rst_ni && we)
      mem[addr[EffectiveAw-1:0]] <= (mem[addr[EffectiveAw-1:0]] & ~mask) |
                                    (wdata & mask);

  // Read logic
  always @(posedge clk_i)
    if (rst_ni && !we) begin
      rdata  <= mem[addr[EffectiveAw-1:0]];
      rvalid <= req;
    end

endmodule

