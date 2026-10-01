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
// Flat SystemVerilog SimLink Memory wrapper for the Icarus and Verilator
// backends: a raw 1:1 port map onto the AXI-Lite master leaf, with no crossbar
// or slave-side logic of its own.
//////////////////////////////////////////////////////////////////////////////

module RogueTcpMemoryWrap #(
   parameter int PORT_NUM_G = 9000
) (
   input  logic axilClk,
   input  logic axilRst,

   // Read address channel
   output logic [31:0] axilArAddr,
   output logic [2:0]  axilArProt,
   output logic        axilArValid,
   input  logic        axilArReady,

   // Read data channel
   input  logic [31:0] axilRData,
   input  logic [1:0]  axilRResp,
   input  logic        axilRValid,
   output logic        axilRReady,

   // Write address channel
   output logic [31:0] axilAwAddr,
   output logic [2:0]  axilAwProt,
   output logic        axilAwValid,
   input  logic        axilAwReady,

   // Write data channel
   output logic [31:0] axilWData,
   output logic [3:0]  axilWStrb,
   output logic        axilWValid,
   input  logic        axilWReady,

   // Write response channel
   input  logic [1:0]  axilBResp,
   input  logic        axilBValid,
   output logic        axilBReady
);

   initial begin
      if (PORT_NUM_G < 1024 || PORT_NUM_G > 49151)
         $fatal(1, "%m: PORT_NUM_G=%0d out of range 1024..49151", PORT_NUM_G);
   end

   RogueTcpMemory U_RogueTcpMemory (
      .clock   (axilClk),
      .reset   (axilRst),
      .portNum (16'(PORT_NUM_G)),

      .araddr  (axilArAddr),
      .arprot  (axilArProt),
      .arvalid (axilArValid),
      .rready  (axilRReady),
      .arready (axilArReady),
      .rdata   (axilRData),
      .rresp   (axilRResp),
      .rvalid  (axilRValid),

      .awaddr  (axilAwAddr),
      .awprot  (axilAwProt),
      .awvalid (axilAwValid),
      .wdata   (axilWData),
      .wstrb   (axilWStrb),
      .wvalid  (axilWValid),
      .bready  (axilBReady),
      .awready (axilAwReady),
      .wready  (axilWReady),
      .bresp   (axilBResp),
      .bvalid  (axilBValid)
   );

endmodule
