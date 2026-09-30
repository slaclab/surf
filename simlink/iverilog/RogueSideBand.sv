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
// Icarus VPI leaf for the Rogue side-band model. Ports match the shared
// backend contract exactly, so the flat SV wrapper instantiates this module
// identically to every other simulator's leaf. $rogueSideBandUpdate writes
// every output into a same-named `_c` local through its VPI write-back
// argument; the nonblocking assignment that follows is this leaf's ONLY
// register stage, exactly like a flop.
//////////////////////////////////////////////////////////////////////////////

module RogueSideBand (
   input  logic        clock,
   input  logic        reset,
   input  logic [15:0] portNum,

   input  logic [7:0]  txOpCode,
   input  logic        txOpCodeEn,
   input  logic [7:0]  txRemData,
   output logic [7:0]  rxOpCode,
   output logic        rxOpCodeEn,
   output logic [7:0]  rxRemData
);

   int handle = 0;

   logic [7:0] rxOpCode_c;
   logic       rxOpCodeEn_c;
   logic [7:0] rxRemData_c;

   initial begin
      rxOpCode   = '0;
      rxOpCodeEn = 1'b0;
      rxRemData  = '0;
   end

   always @(posedge clock) begin
      if (handle == 0) begin
         handle = $rogueSideBandCreate();
         if (handle == 0) $fatal(1, "%m: $rogueSideBandCreate failed");
      end

      if (!$rogueSideBandUpdate(handle, reset, portNum, txOpCode, txOpCodeEn, txRemData,
                                rxOpCode_c, rxOpCodeEn_c, rxRemData_c)) begin
         $fatal(1, "%m: $rogueSideBandUpdate failed");
      end

      rxOpCode   <= rxOpCode_c;
      rxOpCodeEn <= rxOpCodeEn_c;
      rxRemData  <= rxRemData_c;
   end

   final begin
      if (handle != 0) $rogueSideBandDestroy(handle);
   end

endmodule
