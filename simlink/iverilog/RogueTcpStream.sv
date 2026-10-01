//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
//
// Icarus VPI leaf for the Rogue-TCP AXI-Stream model. Ports match the shared
// backend contract exactly (clock, reset, portNum, ssi, ob*, ib*) so the flat
// SV wrapper instantiates this module identically to every other simulator's
// leaf. $rogueTcpStreamUpdate writes every output into a same-named `_c`
// local through its VPI write-back argument; the nonblocking assignment that
// follows is this leaf's ONLY register stage, so the value the C model
// decides at a rising edge becomes visible right after that edge, exactly
// like a flop, never a cycle later and never through a second register
// layer.
//////////////////////////////////////////////////////////////////////////////

module RogueTcpStream #(
   parameter int TDATA_BYTES_G = 8
) (
   input  logic        clock,
   input  logic        reset,
   input  logic [15:0] portNum,
   input  logic        ssi,

   output logic        obValid,
   input  logic        obReady,
   output logic [(TDATA_BYTES_G*8)-1:0] obData,
   output logic [(TDATA_BYTES_G*8)-1:0] obUser,
   output logic [TDATA_BYTES_G-1:0]     obKeep,
   output logic        obLast,

   input  logic        ibValid,
   output logic        ibReady,
   input  logic [(TDATA_BYTES_G*8)-1:0] ibData,
   input  logic [(TDATA_BYTES_G*8)-1:0] ibUser,
   input  logic [TDATA_BYTES_G-1:0]     ibKeep,
   input  logic        ibLast
);

   int handle = 0;

   logic        obValid_c;
   logic [(TDATA_BYTES_G*8)-1:0] obData_c;
   logic [(TDATA_BYTES_G*8)-1:0] obUser_c;
   logic [TDATA_BYTES_G-1:0]     obKeep_c;
   logic        obLast_c;
   logic        ibReady_c;

   initial begin
      obValid = 1'b0;
      obData  = '0;
      obUser  = '0;
      obKeep  = '0;
      obLast  = 1'b0;
      ibReady = 1'b0;
   end

   always @(posedge clock) begin
      if (handle == 0) begin
         handle = $rogueTcpStreamCreate();
         if (handle == 0) $fatal(1, "%m: $rogueTcpStreamCreate failed");
      end

      if (!$rogueTcpStreamUpdate(handle, TDATA_BYTES_G, reset, portNum, ssi, obReady,
                                 obValid_c, obData_c, obUser_c, obKeep_c, obLast_c,
                                 ibValid, ibReady_c, ibData, ibUser, ibKeep, ibLast)) begin
         $fatal(1, "%m: $rogueTcpStreamUpdate failed");
      end

      obValid <= obValid_c;
      obData  <= obData_c;
      obUser  <= obUser_c;
      obKeep  <= obKeep_c;
      obLast  <= obLast_c;
      ibReady <= ibReady_c;
   end

   final begin
      if (handle != 0) $rogueTcpStreamDestroy(handle);
   end

endmodule
