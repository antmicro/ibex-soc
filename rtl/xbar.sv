// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module xbar import top_pkg::*; import tlul_pkg::*; # (
  parameter   M = 2,    // Master count
  parameter   N = 7     // Device count (excluding memory)
)(
  // Clock and reset
  input  logic clk_i,
  input  logic rst_ni,

  // Upstream TileLink ports
  input  tlul_pkg::tl_h2d_t tl_h_i[M],
  output tlul_pkg::tl_d2h_t tl_h_o[M],

  // Downstream TileLink ports for memory
  input  tlul_pkg::tl_d2h_t tl_m_i,
  output tlul_pkg::tl_h2d_t tl_m_o,

  // Downstream TileLink ports for peripherals
  input  tlul_pkg::tl_d2h_t tl_d_i[N],
  output tlul_pkg::tl_h2d_t tl_d_o[N]
);

  tlul_pkg::tl_h2d_t tl_h2d;
  tlul_pkg::tl_d2h_t tl_d2h;

  // TileLink master port mux M:1
  tlul_socket_m1 #(
    .M        (M),
    .HReqPass ({M{1'b0}}),
    .HRspPass ({M{1'b0}}),
    .DReqPass (1'b0),
    .DRspPass (1'b0)
  ) u_tlul_m1 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),

    .tl_h_i         (tl_h_i),
    .tl_h_o         (tl_h_o),

    .tl_d_i         (tl_d2h),
    .tl_d_o         (tl_h2d)
  );

  // Address decoder
  localparam LogN    = $clog2(N+1);
  localparam Invalid = {(LogN+1){1'b1}};

  logic [top_pkg::TL_AW-1:0] dev_address;

  logic sel_memory;
  logic sel_device;

  logic [N:0] dev_select_onehot;

  assign dev_address = tl_h2d.a_address;
  assign sel_memory  = (dev_address[31:30] == 2'b10); // 0x80000000 - 0xBFFFFFFF
  assign sel_device  = (dev_address[31:30] == 2'b11); // 0xC0000000 - 0xFFFFFFFF

  // Memory space
  assign dev_select_onehot[0] = sel_memory & ~sel_device;

  // Assign 1kB space for each device starting from 0xC0000000
  generate for (genvar i=0; i<N; i++)
    assign dev_select_onehot[i+1] = sel_device & (dev_address[29:10] == i);
  endgenerate

  // One-hot to binary
  logic [LogN:0] dev_select;
  always_comb begin
    dev_select = Invalid;
    for (int i=0; i<(N+1); i++) begin
      if (dev_select_onehot == (1 << i)) begin
        dev_select = i;
      end
    end
  end

  // TileLink slave port mux 1:N
  tlul_pkg::tl_h2d_t tl_dev_h2d[N+1];
  tlul_pkg::tl_d2h_t tl_dev_d2h[N+1];

  generate
    assign tl_dev_d2h[0] = tl_m_i;
    assign tl_m_o        = tl_dev_h2d[0];

    for (genvar i=1; i<=N; i++) begin
      assign tl_dev_d2h[i] = tl_d_i[i-1];
      assign tl_d_o[i-1]   = tl_dev_h2d[i];
    end
  endgenerate

  tlul_socket_1n #(
    .N              (N+1),
    .ExplicitErrs   (1'b1),
    .DReqPass       ({N{1'b0}}),
    .DRspPass       ({N{1'b0}}),
    .HReqPass       (1'b0),
    .HRspPass       (1'b0)
  ) u_tlul_n1 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),

    .tl_h_i         (tl_h2d),
    .tl_h_o         (tl_d2h),

    .tl_d_i         (tl_dev_d2h),
    .tl_d_o         (tl_dev_h2d),

    .dev_select_i   (dev_select)
  );

endmodule
