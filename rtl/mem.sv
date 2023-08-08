// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module mem import mem_pkg::*; import prim_mubi_pkg::*; (

    // Clock and reset
    input  wire clk_i,
    input  wire rst_ni,

    // TileLink
    input  tlul_pkg::tl_h2d_t tl_i,
    output tlul_pkg::tl_d2h_t tl_o,

    // ROM
    output mem_pkg::mem_h2d_t rom_o,
    input  mem_pkg::mem_d2h_t rom_i,
    // RAM
    output mem_pkg::mem_h2d_t ram_o,
    input  mem_pkg::mem_d2h_t ram_i
);

  parameter  logic [31:0] SPLIT_SIZE = 32'h0002_0000; // 128KiB by default
  localparam integer SelBit = $clog2(SPLIT_SIZE);

  // Memory address decoder
  //
  // The decoder uses a single bit to distinguish between ROM and RAM access.
  // Therefore ROM and RAM spaces will be interleaved and of SPLIT_SIZE size.
  logic  mem_select;
  assign mem_select = tl_i.a_address[SelBit];

  // TileLink mux
  tlul_pkg::tl_d2h_t    tl_d2h_mem [2];
  tlul_pkg::tl_h2d_t    tl_h2d_mem [2];

  tlul_socket_1n #(
    .N                      (2),
    .ExplicitErrs           (1'b0)
  ) u_tlul_mux (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),

    .tl_h_i                 (tl_i),
    .tl_h_o                 (tl_o),

    .tl_d_i                 (tl_d2h_mem),
    .tl_d_o                 (tl_h2d_mem),

    .dev_select_i           (mem_select)
  );

  // ROM adapter
  tlul_adapter_sram #(
    .SramAw                 (top_pkg::MEM_AW),
    .SramDw                 (top_pkg::MEM_DW),
    .EnableRspIntgGen       (1'b1),
    .ErrOnWrite             (1'b1)
  ) u_tlul_rom (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),

    .en_ifetch_i            (MuBi4True),

    .tl_i                   (tl_h2d_mem[0]),
    .tl_o                   (tl_d2h_mem[0]),

    .req_o                  (rom_o.req),
    .gnt_i                  (rom_i.gnt),
    .we_o                   (),
    .addr_o                 (rom_o.addr),
    .wdata_o                (),
    .wmask_o                (),
    .rdata_i                (rom_i.data),
    .rvalid_i               (rom_i.valid),
    .rerror_i               (rom_i.error),
    .intg_error_o           ()
  );

  assign rom_o.we   = 'd0;
  assign rom_o.data = 'd0;
  assign rom_o.mask = 'd0;

  // RAM adapter
  logic [top_pkg::MEM_DW - 1:0] ram_o_mask;

  tlul_adapter_sram #(
    .SramAw                 (top_pkg::MEM_AW),
    .SramDw                 (top_pkg::MEM_DW),
    .EnableRspIntgGen       (1'b1)
  ) u_tlul_ram (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),

    .en_ifetch_i            (MuBi4False),

    .tl_i                   (tl_h2d_mem[1]),
    .tl_o                   (tl_d2h_mem[1]),

    .req_o                  (ram_o.req),
    .gnt_i                  (ram_i.gnt),
    .we_o                   (ram_o.we),
    .addr_o                 (ram_o.addr),
    .wdata_o                (ram_o.data),
    .wmask_o                (ram_o_mask),
    .rdata_i                (ram_i.data),
    .rvalid_i               (ram_i.valid),
    .rerror_i               (ram_i.error),
    .intg_error_o           ()
  );

  // The TileLink SRAM adapter provides mask per data bit. Convert the mask to
  // per data byte format.
  for (genvar i = 0; i < top_pkg::MEM_DW / 8; i++) begin
    assign ram_o.mask[i] = |ram_o_mask[8*i+1:8*i];
  end

endmodule
