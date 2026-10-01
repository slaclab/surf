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
// Flat SystemVerilog SimLink Stream wrapper for the Icarus and Verilator
// backends: a raw leaf passthrough with no pacer, TDEST/TID/TSTRB, resize, or
// channel mux. Compose multiple channels yourself by instantiating one
// wrapper per channel at PORT_NUM_G + 2*chan. TUSER follows the raw SimLink
// convention: 8 bits per byte lane, with SSI SOF carried in bit 1 of lane 0
// on the first beat of a frame and EOFE carried in bit 0 of the last kept
// lane.
//////////////////////////////////////////////////////////////////////////////

module RogueTcpStreamWrap #(
   parameter int PORT_NUM_G    = 9000,
   parameter bit SSI_EN_G      = 1'b1,
   parameter int TDATA_BYTES_G = 8
) (
   input  logic axisClk,
   input  logic axisRst,

   // Slave Port (HDL-to-software)
   input  logic        sAxisTValid,
   input  logic [(TDATA_BYTES_G*8)-1:0] sAxisTData,
   input  logic [TDATA_BYTES_G-1:0]     sAxisTKeep,
   input  logic [(TDATA_BYTES_G*8)-1:0] sAxisTUser,
   input  logic        sAxisTLast,
   output logic        sAxisTReady,

   // Master Port (software-to-HDL)
   output logic        mAxisTValid,
   output logic [(TDATA_BYTES_G*8)-1:0] mAxisTData,
   output logic [TDATA_BYTES_G-1:0]     mAxisTKeep,
   output logic [(TDATA_BYTES_G*8)-1:0] mAxisTUser,
   output logic        mAxisTLast,
   input  logic        mAxisTReady
);

   initial begin
      if (PORT_NUM_G < 1024 || PORT_NUM_G > 49151)
         $fatal(1, "%m: PORT_NUM_G=%0d out of range 1024..49151", PORT_NUM_G);
      if (TDATA_BYTES_G < 1 || TDATA_BYTES_G > 128)
         $fatal(1, "%m: TDATA_BYTES_G=%0d out of range 1..128", TDATA_BYTES_G);
   end

   RogueTcpStream #(
      .TDATA_BYTES_G (TDATA_BYTES_G)
   ) U_RogueTcpStream (
      .clock   (axisClk),
      .reset   (axisRst),
      .portNum (16'(PORT_NUM_G)),
      .ssi     (SSI_EN_G),

      .obValid (mAxisTValid),
      .obReady (mAxisTReady),
      .obData  (mAxisTData),
      .obUser  (mAxisTUser),
      .obKeep  (mAxisTKeep),
      .obLast  (mAxisTLast),

      .ibValid (sAxisTValid),
      .ibReady (sAxisTReady),
      .ibData  (sAxisTData),
      .ibUser  (sAxisTUser),
      .ibKeep  (sAxisTKeep),
      .ibLast  (sAxisTLast)
   );

endmodule
