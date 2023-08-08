// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

package mem_pkg;

  typedef struct packed {
    logic                           req;
    logic                           we;
    logic [top_pkg::MEM_AW   - 1:0] addr;
    logic [top_pkg::MEM_DW   - 1:0] data;
    logic [top_pkg::MEM_DW/8 - 1:0] mask;
  } mem_h2d_t;

  typedef struct packed {
    logic                           gnt;
    logic                           valid;
    logic [top_pkg::MEM_DW   - 1:0] data;
    logic [1:0]                     error; // 2 bit error [1]: Uncorrectable, [0]: Correctable
  } mem_d2h_t;

endpackage
