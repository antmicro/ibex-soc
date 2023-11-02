// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module phy_wrapper
    import top_pkg::*;
    import tlul_pkg::*;
    import prim_mubi_pkg::*;
    import phy_csr_pkg::*;
(
  // Clock and reset
  input  logic clk_i,
  input  logic rst_ni,

  // Crossbar TileLink port
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o
);

wire cpuif_req;
wire cpuif_req_is_wr;
wire [3:0] cpuif_addr;
wire [31:0] cpuif_wr_data;
wire [3:0] cpuif_wr_byte_en;
wire cpuif_req_stall_wr;
wire cpuif_req_stall_rd;
wire cpuif_rd_ack;
wire cpuif_rd_err;
wire [31:0] cpuif_rd_data;
wire cpuif_wr_ack;
wire cpuif_wr_err;

wire [6:0] zq_config;
wire zq_cal_en;
wire comparator_out;

phy_csr_pkg::phy_csr__in_t hwif_in;
phy_csr_pkg::phy_csr__out_t hwif_out;

assign hwif_in.phy_feedback.comparator_out.next = comparator_out;
assign zq_config = hwif_out.zq_config.zq_config.value;
assign zq_cal_en = hwif_out.zq_cal.zq_cal_en.value;

phy_backend u_phy_backend (
  .zq_config(zq_config),
  .zq_cal_en(zq_cal_en),
  .comparator_out(comparator_out)
);

phy_csr u_phy_csr (
  .clk(clk_i),
  .rst(~rst_ni),

  // Inputs
  .s_cpuif_req(cpuif_req | cpuif_req_is_wr),
  .s_cpuif_req_is_wr(cpuif_req_is_wr),
  .s_cpuif_addr(cpuif_addr),
  .s_cpuif_wr_data(cpuif_wr_data),
  .s_cpuif_wr_biten({{8{cpuif_wr_byte_en[3]}},
                     {8{cpuif_wr_byte_en[2]}},
                     {8{cpuif_wr_byte_en[1]}},
                     {8{cpuif_wr_byte_en[0]}}
                    }),

  // Outputs
  .s_cpuif_req_stall_wr(cpuif_req_stall_wr),
  .s_cpuif_req_stall_rd(cpuif_req_stall_rd),
  .s_cpuif_rd_ack(cpuif_rd_ack),
  .s_cpuif_rd_err(cpuif_rd_err),
  .s_cpuif_rd_data(cpuif_rd_data),
  .s_cpuif_wr_ack(cpuif_wr_ack),
  .s_cpuif_wr_err(cpuif_wr_err),

  .hwif_in(hwif_in),
  .hwif_out(hwif_out)
);

tlul_adapter_reg #(
  .RegAw(top_pkg::TL_AW),
  .RegDw(top_pkg::TL_DW),
  .EnableRspIntgGen(1'b1),
  .EnableDataIntgGen(1'b1)
) u_tlul_adapter_reg (
  .clk_i(clk_i),
  .rst_ni(rst_ni),

  .tl_i(tl_i),
  .tl_o(tl_o),

  .en_ifetch_i(MuBi4False),
  .intg_error_o(),

  .re_o(cpuif_req),
  .we_o(cpuif_req_is_wr),
  .addr_o(cpuif_addr),
  .wdata_o(cpuif_wr_data),
  .be_o(cpuif_wr_byte_en),
  .busy_i(cpuif_req_stall_wr | cpuif_req_stall_rd),
  .rdata_i(cpuif_rd_data),
  .error_i(cpuif_rd_err | cpuif_wr_err)
);

endmodule
