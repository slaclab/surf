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
// Test methodology:
// - Expose the VHDL Memory relaunch harness through a plain VCS VPI top.
// - Add no stimulus or lifecycle behavior; cocotb drives and checks every
//   signal while the production VHDL leaf continues to use VHPI.
//////////////////////////////////////////////////////////////////////////////

module RogueSimLinkMemoryRelaunchBridge;

   logic        clock;
   logic        reset;
   logic [15:0] portNum;
   wire  [31:0] araddr;
   wire         arvalid;
   logic        arready;
   logic [31:0] rdata;
   logic [1:0]  rresp;
   logic        rvalid;
   wire  [31:0] awaddr;
   wire         awvalid;
   wire  [31:0] wdata;
   wire         wvalid;
   logic        awready;
   logic        wready;
   logic [1:0]  bresp;
   logic        bvalid;
   wire         bready;

   RogueSimLinkMemoryRelaunchHarness U_DUT (
      .clock   (clock),
      .reset   (reset),
      .portNum (portNum),
      .araddr  (araddr),
      .arvalid (arvalid),
      .arready (arready),
      .rdata   (rdata),
      .rresp   (rresp),
      .rvalid  (rvalid),
      .awaddr  (awaddr),
      .awvalid (awvalid),
      .wdata   (wdata),
      .wvalid  (wvalid),
      .awready (awready),
      .wready  (wready),
      .bresp   (bresp),
      .bvalid  (bvalid),
      .bready  (bready));

endmodule
