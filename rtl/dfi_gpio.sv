// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

module dfi_gpio
    import top_pkg::*;
    import tlul_pkg::*;
    import prim_mubi_pkg::*;
    import dfi_gpio_csr_pkg::*;
(
  // Clock and reset
  input  logic clk_i,
  input  logic rst_ni,

  // Crossbar TileLink port
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,

  // DFI GPIOs
  input  logic dfi_init_start_i,
  output logic dfi_init_done_o
);

localparam int AW = 3;

wire cpuif_req;
wire cpuif_req_is_wr;
wire     [AW-1:0] cpuif_addr;
wire    [TL_DW:0] cpuif_wr_data;
wire [TL_DBW-1:0] cpuif_wr_byte_en;
wire cpuif_req_stall_wr;
wire cpuif_req_stall_rd;
wire cpuif_rd_ack;
wire cpuif_rd_err;
wire    [TL_DW:0] cpuif_rd_data;
wire cpuif_wr_ack;
wire cpuif_wr_err;

dfi_gpio_csr_pkg::dfi_gpio_csr__in_t hwif_in;
dfi_gpio_csr_pkg::dfi_gpio_csr__out_t hwif_out;

assign hwif_in.init_start.start.next = dfi_init_start_i;
assign dfi_init_done_o = hwif_out.init_done.done.value;

dfi_gpio_csr u_dfi_gpio_csr (
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
  .RegAw(AW),
  .RegDw(TL_DW),
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
