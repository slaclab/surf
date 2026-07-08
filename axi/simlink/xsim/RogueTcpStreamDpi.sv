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
// SV DPI leaf for the Rogue-TCP AXI-Stream model under Vivado xsim. Ports stay
// logic-typed for clean VHDL interop; only the DPI import's formal arguments
// are 2-state bit/bit-vector (SV auto-narrows 4-state logic to 2-state bit at
// the call site). Drives the DPI-C adapter (RogueTcpStream.c) once per rising
// clock edge, mirroring the GHDL backend's per-edge update process.
//////////////////////////////////////////////////////////////////////////////

module RogueTcpStreamDpi (
   input  logic        clock,
   input  logic        reset,
   input  logic [15:0] portNum,
   input  logic        ssi,

   output logic        obValid,
   input  logic        obReady,
   output logic [31:0] obDataLow,
   output logic [31:0] obDataHigh,
   output logic [31:0] obUserLow,
   output logic [31:0] obUserHigh,
   output logic [7:0]  obKeep,
   output logic        obLast,

   input  logic        ibValid,
   output logic        ibReady,
   input  logic [31:0] ibDataLow,
   input  logic [31:0] ibDataHigh,
   input  logic [31:0] ibUserLow,
   input  logic [31:0] ibUserHigh,
   input  logic [7:0]  ibKeep,
   input  logic        ibLast
);

   import "DPI-C" function void rogueTcpStreamUpdate
     (input  bit        reset,
      input  bit [15:0] portNum,
      input  bit        ssi,
      input  bit        obReady,
      output bit        obValid,
      output bit [31:0] obDataLow,
      output bit [31:0] obDataHigh,
      output bit [31:0] obUserLow,
      output bit [31:0] obUserHigh,
      output bit [7:0]  obKeep,
      output bit        obLast,
      input  bit        ibValid,
      output bit        ibReady,
      input  bit [31:0] ibDataLow,
      input  bit [31:0] ibDataHigh,
      input  bit [31:0] ibUserLow,
      input  bit [31:0] ibUserHigh,
      input  bit [7:0]  ibKeep,
      input  bit        ibLast);

   always_ff @(posedge clock) begin
      rogueTcpStreamUpdate(reset, portNum, ssi, obReady,
                            obValid, obDataLow, obDataHigh, obUserLow, obUserHigh, obKeep, obLast,
                            ibValid, ibReady, ibDataLow, ibDataHigh, ibUserLow, ibUserHigh, ibKeep, ibLast);
   end

endmodule
