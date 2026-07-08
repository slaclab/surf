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
// the call site). Drives the DPI-C adapter (RogueSideBand.c) once per rising
// clock edge, mirroring the GHDL backend's per-edge update process.
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

   import "DPI-C" function void rogueSideBandUpdate
     (input  bit        reset,
      input  bit [15:0] portNum,
      input  bit [7:0]  txOpCode,
      input  bit        txOpCodeEn,
      input  bit [7:0]  txRemData,
      output bit [7:0]  rxOpCode,
      output bit        rxOpCodeEn,
      output bit [7:0]  rxRemData);

   always_ff @(posedge clock) begin
      rogueSideBandUpdate(reset, portNum, txOpCode, txOpCodeEn, txRemData,
                           rxOpCode, rxOpCodeEn, rxRemData);
   end

endmodule
