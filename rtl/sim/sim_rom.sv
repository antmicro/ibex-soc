// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module sim_rom # (
    parameter AW   = 32,
    parameter DW   = 32,
    parameter SIZE = 1024,
    parameter FILE = ""
)(
    // Clock and reset
    input  logic clk_i,
    input  logic rst_ni,

    // Memory interface
    input  logic            req,
    input  logic [AW-1:0]   addr,
    output logic [DW-1:0]   rdata,
    output logic            rvalid
);

  localparam EffectiveAw = $clog2(SIZE);
  localparam Bytes       = DW / 8;

  // The memory
  logic [7:0] mem [SIZE];
  initial $readmemh(FILE, mem);

  // Read logic
  wire [DW-1:0] data;
  generate for (genvar i=0; i<Bytes; i++)
    assign data[8*(i+1)-1:8*i] = mem[(addr[EffectiveAw-1:0] << 2) | i];
  endgenerate

  always @(posedge clk_i)
    if (rst_ni) begin
      rdata  <= data;
      rvalid <= req;
    end

endmodule

