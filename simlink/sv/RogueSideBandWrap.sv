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
// Flat SystemVerilog SimLink SideBand wrapper for the Icarus and Verilator
// backends: a raw 1:1 port map onto the side-band leaf, keeping the existing
// VHDL port names.
//////////////////////////////////////////////////////////////////////////////

module RogueSideBandWrap #(
   parameter int PORT_NUM_G = 9000
) (
   input  logic       sysClk,
   input  logic       sysRst,

   input  logic [7:0] txOpCode,
   input  logic       txOpCodeEn,
   input  logic [7:0] txRemData,
   output logic [7:0] rxOpCode,
   output logic       rxOpCodeEn,
   output logic [7:0] rxRemData
);

   initial begin
      if (PORT_NUM_G < 1024 || PORT_NUM_G > 49151)
         $fatal(1, "%m: PORT_NUM_G=%0d out of range 1024..49151", PORT_NUM_G);
   end

   RogueSideBand U_RogueSideBand (
      .clock      (sysClk),
      .reset      (sysRst),
      .portNum    (16'(PORT_NUM_G)),
      .txOpCode   (txOpCode),
      .txOpCodeEn (txOpCodeEn),
      .txRemData  (txRemData),
      .rxOpCode   (rxOpCode),
      .rxOpCodeEn (rxOpCodeEn),
      .rxRemData  (rxRemData)
   );

endmodule
