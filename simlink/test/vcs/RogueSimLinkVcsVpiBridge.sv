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
// - Expose the shared VHDL traffic top's flattened signals through a VCS VPI
//   top without adding stimulus or protocol behavior.
// - Let the common cocotb scenario drive and check every signal; the bridge is
//   successful only when mixed-language elaboration preserves all mappings.
//
// Test-only VPI bridge for the VCS active-traffic regression. Cocotb's VCS
// integration supports VPI rather than a VHDL VHPI top, so this module exposes
// only plain SystemVerilog signals and instantiates the shared GHDL/VCS VHDL
// traffic topology below them. The Rogue leaves inside that topology retain
// their independent production VHPI callbacks.
//////////////////////////////////////////////////////////////////////////////

module RogueSimLinkVcsVpiBridge;

   logic         clock;
   logic         reset;
   logic [15:0]  streamPort0;
   logic [15:0]  streamPort1;
   logic [15:0]  streamPort2;
   logic [15:0]  streamPort3;
   logic [3:0]   streamObReady;
   wire  [255:0] streamObData;
   wire  [31:0]  streamObKeep;
   wire  [3:0]   streamObLast;
   logic [3:0]   streamIbValid;
   logic [255:0] streamIbData;
   logic [31:0]  streamIbKeep;
   logic [3:0]   streamIbLast;
   logic [15:0]  memoryPort0;
   logic [15:0]  memoryPort1;
   wire  [63:0]  memoryArAddr;
   logic [1:0]   memoryArReady;
   logic [63:0]  memoryRData;
   logic [3:0]   memoryRResp;
   logic [1:0]   memoryRValid;
   wire  [63:0]  memoryAwAddr;
   wire  [1:0]   memoryAwValid;
   wire  [63:0]  memoryWData;
   wire  [1:0]   memoryWValid;
   logic [1:0]   memoryAwReady;
   logic [1:0]   memoryWReady;
   logic [3:0]   memoryBResp;
   logic [1:0]   memoryBValid;
   logic [15:0]  sideBandPort0;
   logic [15:0]  sideBandPort1;
   logic [15:0]  sideBandTxCode;
   logic [1:0]   sideBandTxEn;
   logic [15:0]  sideBandTxData;
   wire  [15:0]  sideBandRxCode;
   wire  [15:0]  sideBandRxData;
   wire          streamObValid0;
   wire          streamIbReady0;
   wire          streamObValid1;
   wire          streamIbReady1;
   wire          streamObValid2;
   wire          streamIbReady2;
   wire          streamObValid3;
   wire          streamIbReady3;
   wire          memoryArValid0;
   wire          memoryBReady0;
   wire          memoryArValid1;
   wire          memoryBReady1;
   wire          sideBandRxEn0;
   wire          sideBandRxEn1;

   RogueSimLinkMultiInstanceHarness U_DUT (
      .clock          (clock),
      .reset          (reset),
      .streamPort0    (streamPort0),
      .streamPort1    (streamPort1),
      .streamPort2    (streamPort2),
      .streamPort3    (streamPort3),
      .streamObReady  (streamObReady),
      .streamObData   (streamObData),
      .streamObKeep   (streamObKeep),
      .streamObLast   (streamObLast),
      .streamIbValid  (streamIbValid),
      .streamIbData   (streamIbData),
      .streamIbKeep   (streamIbKeep),
      .streamIbLast   (streamIbLast),
      .memoryPort0    (memoryPort0),
      .memoryPort1    (memoryPort1),
      .memoryArAddr   (memoryArAddr),
      .memoryArReady  (memoryArReady),
      .memoryRData    (memoryRData),
      .memoryRResp    (memoryRResp),
      .memoryRValid   (memoryRValid),
      .memoryAwAddr   (memoryAwAddr),
      .memoryAwValid  (memoryAwValid),
      .memoryWData    (memoryWData),
      .memoryWValid   (memoryWValid),
      .memoryAwReady  (memoryAwReady),
      .memoryWReady   (memoryWReady),
      .memoryBResp    (memoryBResp),
      .memoryBValid   (memoryBValid),
      .sideBandPort0  (sideBandPort0),
      .sideBandPort1  (sideBandPort1),
      .sideBandTxCode (sideBandTxCode),
      .sideBandTxEn   (sideBandTxEn),
      .sideBandTxData (sideBandTxData),
      .sideBandRxCode (sideBandRxCode),
      .sideBandRxData (sideBandRxData),
      .streamObValid0 (streamObValid0),
      .streamIbReady0 (streamIbReady0),
      .streamObValid1 (streamObValid1),
      .streamIbReady1 (streamIbReady1),
      .streamObValid2 (streamObValid2),
      .streamIbReady2 (streamIbReady2),
      .streamObValid3 (streamObValid3),
      .streamIbReady3 (streamIbReady3),
      .memoryArValid0 (memoryArValid0),
      .memoryBReady0  (memoryBReady0),
      .memoryArValid1 (memoryArValid1),
      .memoryBReady1  (memoryBReady1),
      .sideBandRxEn0  (sideBandRxEn0),
      .sideBandRxEn1  (sideBandRxEn1));

endmodule
