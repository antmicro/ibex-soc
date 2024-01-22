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
  localparam Bytes       = DW / 8;

  // The memory
  (* ram_style = "block" *)
  logic [DW-1:0] mem [SIZE];

  // Write logic
  integer i;
  always @(posedge clk_i) begin
    if (rst_ni && we) begin
      for (i=0; i<Bytes; i++) begin : gen_write_byte
        if (wmask[i]) begin
          mem[addr[EffectiveAw-1:0]][i*8 +: 8] <= wdata[i*8 +: 8];
        end
      end
    end
  end

  // Read logic
  always @(posedge clk_i) begin
    if (rst_ni && !we) begin
      rdata  <= mem[addr[EffectiveAw-1:0]];
      rvalid <= req;
    end
  end


endmodule
