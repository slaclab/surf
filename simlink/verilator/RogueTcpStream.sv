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
// DPI-C leaf for the Rogue-TCP AXI-Stream model under Verilator, derived from
// the xsim DPI leaf. The DPI imports call the exact same unmodified xsim C
// adapter (rogueTcpStreamCreate/Update/Destroy) with the same argument order,
// qualifiers, and dataBytes-driven runtime width contract. Unlike xsim's
// import, the wide vector arguments are declared at the shared core's fixed
// maximum width (ROGUE_TCP_STREAM_MAX_DATA_BYTES = 128 bytes) rather than
// (TDATA_BYTES_G*8)-1:0, because Verilator -- correctly, per IEEE 1800
// 35.5.5 -- requires every SV import of the same DPI function name to share
// one C prototype across the whole design; this leaf is elaborated at both
// 8 and 128 bytes in the shared traffic testbench, and a per-instance
// parameterized import width is therefore rejected as a duplicate
// declaration with conflicting signatures. The C adapter only ever reads or
// writes the first dataBytes/4 words of these pointers (see
// RogueTcpStream.c), so the extra width is inert at every configured size;
// only the low TDATA_BYTES_G*8 (resp. TDATA_BYTES_G) bits of each max-width
// temporary carry meaning to/from the real port. Every rising edge stages
// the DPI outputs into these max-width `_c` temporaries, then publishes each
// port-width output with exactly one nonblocking assignment, so the value
// the C model decides at edge N behaves like a flop and is race-free.
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

   // Matches the shared core's ROGUE_TCP_STREAM_MAX_DATA_BYTES (see
   // simlink/shared/RogueTcpStreamModel.h); the DPI call's wide vector
   // arguments are always this width regardless of TDATA_BYTES_G.
   localparam int MAX_DATA_BYTES_C = 128;

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
      output bit [(MAX_DATA_BYTES_C*8)-1:0] obData,
      output bit [(MAX_DATA_BYTES_C*8)-1:0] obUser,
      output bit [MAX_DATA_BYTES_C-1:0]     obKeep,
      output bit        obLast,
      input  bit        ibValid,
      output bit        ibReady,
      input  bit [(MAX_DATA_BYTES_C*8)-1:0] ibData,
      input  bit [(MAX_DATA_BYTES_C*8)-1:0] ibUser,
      input  bit [MAX_DATA_BYTES_C-1:0]     ibKeep,
      input  bit        ibLast);

   chandle handle = null;

   bit        obValid_c;
   bit [(MAX_DATA_BYTES_C*8)-1:0] obData_c;
   bit [(MAX_DATA_BYTES_C*8)-1:0] obUser_c;
   bit [MAX_DATA_BYTES_C-1:0]     obKeep_c;
   bit        obLast_c;
   bit        ibReady_c;

   initial begin
      obValid = 1'b0;
      obData  = '0;
      obUser  = '0;
      obKeep  = '0;
      obLast  = 1'b0;
      ibReady = 1'b0;
   end

   always @(posedge clock) begin
      if (handle == null) begin
         handle = rogueTcpStreamCreate();
         if (handle == null) $fatal(1, "%m: rogueTcpStreamCreate failed");
      end

      if (rogueTcpStreamUpdate(handle, TDATA_BYTES_G, reset, portNum, ssi, obReady,
                               obValid_c, obData_c, obUser_c, obKeep_c, obLast_c,
                               ibValid, ibReady_c,
                               {{(MAX_DATA_BYTES_C*8-TDATA_BYTES_G*8){1'b0}}, ibData},
                               {{(MAX_DATA_BYTES_C*8-TDATA_BYTES_G*8){1'b0}}, ibUser},
                               {{(MAX_DATA_BYTES_C-TDATA_BYTES_G){1'b0}}, ibKeep},
                               ibLast) == 0) begin
         $fatal(1, "%m: rogueTcpStreamUpdate failed");
      end

      obValid <= obValid_c;
      obData  <= obData_c[(TDATA_BYTES_G*8)-1:0];
      obUser  <= obUser_c[(TDATA_BYTES_G*8)-1:0];
      obKeep  <= obKeep_c[TDATA_BYTES_G-1:0];
      obLast  <= obLast_c;
      ibReady <= ibReady_c;
   end

   final begin
      if (handle != null) rogueTcpStreamDestroy(handle);
   end

endmodule
