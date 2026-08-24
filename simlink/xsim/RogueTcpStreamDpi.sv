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
// the call site). Each elaborated leaf retains its own DPI chandle and drives
// the corresponding C-owned model once per rising clock edge, mirroring the
// GHDL backend's per-instance update process.
//////////////////////////////////////////////////////////////////////////////

module RogueTcpStreamDpi #(
   parameter integer TDATA_BYTES_G = 8
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

   import "DPI-C" function chandle rogueTcpStreamCreate();
   import "DPI-C" function void rogueTcpStreamDestroy(input chandle handle);
   import "DPI-C" function int rogueTcpStreamUpdate
     (input  chandle    handle,
      input  int        dataBytes,
      input  bit        reset,
      input  bit [15:0] portNum,
      input  bit        ssi,
      input  bit        obReady,
      output bit        obValid,
      output bit [(TDATA_BYTES_G*8)-1:0] obData,
      output bit [(TDATA_BYTES_G*8)-1:0] obUser,
      output bit [TDATA_BYTES_G-1:0]     obKeep,
      output bit        obLast,
      input  bit        ibValid,
      output bit        ibReady,
      input  bit [(TDATA_BYTES_G*8)-1:0] ibData,
      input  bit [(TDATA_BYTES_G*8)-1:0] ibUser,
      input  bit [TDATA_BYTES_G-1:0]     ibKeep,
      input  bit        ibLast);

   chandle handle = null;

   always @(posedge clock) begin
      if (handle == null) begin
         handle = rogueTcpStreamCreate();
         if (handle == null) $fatal(1, "%m: rogueTcpStreamCreate failed");
      end

      if (!rogueTcpStreamUpdate(handle, TDATA_BYTES_G, reset, portNum, ssi, obReady,
                                obValid, obData, obUser, obKeep, obLast,
                                ibValid, ibReady, ibData, ibUser, ibKeep, ibLast)) begin
         $fatal(1, "%m: rogueTcpStreamUpdate failed");
      end
   end

   final begin
      if (handle != null) rogueTcpStreamDestroy(handle);
   end

endmodule
