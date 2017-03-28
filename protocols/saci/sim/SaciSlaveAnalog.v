//////////////////////////////////////////////////////////////////////////////
// File       : SaciSlaveAnalog.vhd
// Company    : SLAC National Accelerator Laboratory
// Created    : 2016-06-17
// Last update: 2016-06-17
//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

// Edge Module Definition
module SaciSlaveAnalog 
    (input wire  CLK,
     input wire  RST,
     input wire  ack,

     output wire addr_0,
     output wire addr_1,
     output wire addr_2,
     output wire addr_3,
     output wire addr_4,
     output wire addr_5,
     output wire addr_6,
     output wire addr_7,
     output wire addr_8,
     output wire addr_9,
     output wire addr_10,
     output wire addr_11,

     output wire cmd_0,
     output wire cmd_1,
     output wire cmd_2,
     output wire cmd_3,
     output wire cmd_4,
     output wire cmd_5,
     output wire cmd_6,
     
     output wire exec,
     
     input wire  rdData_0,
     input wire  rdData_1,
     input wire  rdData_2,
     input wire  rdData_3,
     input wire  rdData_4,
     input wire  rdData_5,
     input wire  rdData_6,
     input wire  rdData_7,
     input wire  rdData_8,
     input wire  rdData_9,
     input wire  rdData_10,
     input wire  rdData_11,
     input wire  rdData_12,
     input wire  rdData_13,
     input wire  rdData_14,
     input wire  rdData_15,
     input wire  rdData_16,
     input wire  rdData_17,
     input wire  rdData_18,
     input wire  rdData_19,
     input wire  rdData_20,
     input wire  rdData_21,
     input wire  rdData_22,
     input wire  rdData_23,
     input wire  rdData_24,
     input wire  rdData_25,
     input wire  rdData_26,
     input wire  rdData_27,
     input wire  rdData_28,
     input wire  rdData_29,
     input wire  rdData_30,
     input wire  rdData_31,
     
     output wire readL,
     input wire  rstL,
     output wire rstOutL,
     input wire  saciCmd, 
     output wire saciRsp,
     input wire  saciSelL,

     output wire wrData_0,
     output wire wrData_1,
     output wire wrData_2,
     output wire wrData_3,
     output wire wrData_4,
     output wire wrData_5,
     output wire wrData_6,
     output wire wrData_7,
     output wire wrData_8,
     output wire wrData_9,
     output wire wrData_10,
     output wire wrData_11,
     output wire wrData_12,
     output wire wrData_13,
     output wire wrData_14,
     output wire wrData_15,
     output wire wrData_16,
     output wire wrData_17,
     output wire wrData_18,
     output wire wrData_19,
     output wire wrData_20,
     output wire wrData_21,
     output wire wrData_22,
     output wire wrData_23,
     output wire wrData_24,
     output wire wrData_25,
     output wire wrData_26,
     output wire wrData_27,
     output wire wrData_28,
     output wire wrData_29,
     output wire wrData_30,
     output wire wrData_31

   );
   
	       
   
endmodule 
