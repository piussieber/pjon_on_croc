// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Ludwig Itschner <litschner@student.ethz.ch>


/// The OBI interfaces used in Croc and and iDMA a slightly different.
/// This module converts a obi_req_t and obi_rsp_t to mgr_obi_req_t and mgr_obi_rsp_t.

module obi_interface_adapter #(  
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic,
  parameter type mgr_obi_req_t    = logic,
  parameter type mgr_obi_rsp_t    = logic
) (
  // OBI (DMA type)
  input obi_req_t req_i,
  output obi_rsp_t rsp_o,

  // Croc OBI
  output mgr_obi_req_t req_o,
  input mgr_obi_rsp_t rsp_i
); 
  
  // Request
  assign req_o.req          = req_i.req;
  assign req_o.a.addr       = req_i.a.addr;
  assign req_o.a.we         = req_i.a.we;
  assign req_o.a.be         = req_i.a.be;
  assign req_o.a.wdata      = req_i.a.wdata;
  assign req_o.a.aid        = req_i.a.aid;
  assign req_o.a.a_optional = req_i.a.a_optional;

  // Response
  assign rsp_o.r.rdata      = rsp_i.r.rdata;
  assign rsp_o.r.rid        = rsp_i.r.rid;
  assign rsp_o.r.err        = rsp_i.r.err;
  assign rsp_o.r.r_optional = rsp_i.r.r_optional;
  assign rsp_o.gnt          = rsp_i.gnt;
  assign rsp_o.rvalid       = rsp_i.rvalid;

endmodule
