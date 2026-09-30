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
// DPI-C leaf for the Rogue side-band model under Verilator, derived from the
// xsim DPI leaf. The DPI imports are byte-identical to xsim's so the unmodified
// xsim C adapters link against this leaf as-is. Every rising edge stages the
// DPI outputs into same-named `_c` bit-typed temporaries, then publishes each
// output port with exactly one nonblocking assignment, so the value the C
// model decides at edge N behaves like a flop and is race-free.
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

   import "DPI-C" function chandle rogueSideBandCreate();
   import "DPI-C" function void rogueSideBandDestroy(input chandle handle);
   import "DPI-C" function int rogueSideBandUpdate
     (input  chandle    handle,
      input  bit        reset,
      input  bit [15:0] portNum,
      input  bit [7:0]  txOpCode,
      input  bit        txOpCodeEn,
      input  bit [7:0]  txRemData,
      output bit [7:0]  rxOpCode,
      output bit        rxOpCodeEn,
      output bit [7:0]  rxRemData);

   chandle handle = null;

   bit [7:0] rxOpCode_c;
   bit       rxOpCodeEn_c;
   bit [7:0] rxRemData_c;

   initial begin
      rxOpCode   = '0;
      rxOpCodeEn = 1'b0;
      rxRemData  = '0;
   end

   always @(posedge clock) begin
      if (handle == null) begin
         handle = rogueSideBandCreate();
         if (handle == null) $fatal(1, "%m: rogueSideBandCreate failed");
      end

      if (rogueSideBandUpdate(handle, reset, portNum, txOpCode, txOpCodeEn, txRemData,
                              rxOpCode_c, rxOpCodeEn_c, rxRemData_c) == 0) begin
         $fatal(1, "%m: rogueSideBandUpdate failed");
      end

      rxOpCode   <= rxOpCode_c;
      rxOpCodeEn <= rxOpCodeEn_c;
      rxRemData  <= rxRemData_c;
   end

   final begin
      if (handle != null) rogueSideBandDestroy(handle);
   end

endmodule
