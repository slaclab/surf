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
// SV DPI leaf for the Rogue side-band model under Vivado xsim. Ports stay
// logic-typed for clean VHDL interop; only the DPI import's formal arguments
// are 2-state bit/bit-vector (SV auto-narrows 4-state logic to 2-state bit at
// the call site). Each elaborated leaf retains its own DPI chandle and drives
// the corresponding C-owned model once per rising clock edge, mirroring the
// GHDL backend's per-instance update process.
//////////////////////////////////////////////////////////////////////////////

module RogueSideBandDpi (
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

   always @(posedge clock) begin
      if (handle == null) begin
         handle = rogueSideBandCreate();
         if (handle == null) $fatal(1, "%m: rogueSideBandCreate failed");
      end

      if (!rogueSideBandUpdate(handle, reset, portNum, txOpCode, txOpCodeEn, txRemData,
                               rxOpCode, rxOpCodeEn, rxRemData)) begin
         $fatal(1, "%m: rogueSideBandUpdate failed");
      end
   end

   final begin
      if (handle != null) rogueSideBandDestroy(handle);
   end

endmodule
