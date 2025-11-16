// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

`include "register_interface/typedef.svh"
`include "obi/typedef.svh"

package user_pkg;

  ////////////////////////////////
  // User Manager Address maps //
  ///////////////////////////////
  
  // None


  /////////////////////////////////////
  // User Subordinate Address maps ////
  /////////////////////////////////////

  localparam int unsigned NumUserDomainSubordinates = 3;

  localparam bit [31:0] UserRomAddrOffset   = croc_pkg::UserBaseAddr; // 32'h2000_0000;
  localparam bit [31:0] UserRomAddrRange    = 32'h0000_1000;          // every subordinate has at least 4KB
  localparam bit [31:0] UserPJDLAddrOffset  = croc_pkg::UserBaseAddr + 32'h0000_1000;
  localparam bit [31:0] UserPJDLAddrRange   = 32'h0000_1000;
  localparam bit [31:0] UserDMAAddrOffset  = croc_pkg::UserBaseAddr + 32'h0000_2000;
  localparam bit [31:0] UserDMAAddrRange   = 32'h0000_1000;

  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates; // number of address rules in the decoder
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1; // additional OBI error, used for signal arrays

  // Enum for bus indices
  typedef enum int {
    UserError = 0,
    UserRom = 1,
    UserPJDL = 2,
    UserDMA = 3

  } user_demux_outputs_e;

  // Address rules given to address decoder
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{idx:UserRom, start_addr: UserRomAddrOffset, end_addr: UserRomAddrOffset + UserRomAddrRange},
    '{idx:UserPJDL, start_addr: UserPJDLAddrOffset, end_addr: UserPJDLAddrOffset + UserPJDLAddrRange},
    '{idx:UserDMA, start_addr: UserDMAAddrOffset, end_addr: UserDMAAddrOffset + UserDMAAddrRange}
  };

endpackage
