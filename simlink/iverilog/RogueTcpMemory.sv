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
// Icarus VPI leaf for the Rogue-TCP AXI-Lite memory model. Ports match the
// shared backend contract exactly, so the flat SV wrapper instantiates this
// module identically to every other simulator's leaf. $rogueTcpMemoryUpdate
// writes every output into a same-named `_c` local through its VPI
// write-back argument; the nonblocking assignment that follows is this
// leaf's ONLY register stage, exactly like a flop.
//////////////////////////////////////////////////////////////////////////////

module RogueTcpMemory (
   input  logic        clock,
   input  logic        reset,
   input  logic [15:0] portNum,

   output logic [31:0] araddr,
   output logic [2:0]  arprot,
   output logic        arvalid,
   output logic        rready,
   input  logic        arready,
   input  logic [31:0] rdata,
   input  logic [1:0]  rresp,
   input  logic        rvalid,

   output logic [31:0] awaddr,
   output logic [2:0]  awprot,
   output logic        awvalid,
   output logic [31:0] wdata,
   output logic [3:0]  wstrb,
   output logic        wvalid,
   output logic        bready,
   input  logic        awready,
   input  logic        wready,
   input  logic [1:0]  bresp,
   input  logic        bvalid
);

   int handle = 0;

   logic [31:0] araddr_c;
   logic [2:0]  arprot_c;
   logic        arvalid_c;
   logic        rready_c;
   logic [31:0] awaddr_c;
   logic [2:0]  awprot_c;
   logic        awvalid_c;
   logic [31:0] wdata_c;
   logic [3:0]  wstrb_c;
   logic        wvalid_c;
   logic        bready_c;

   initial begin
      araddr  = '0;
      arprot  = '0;
      arvalid = 1'b0;
      rready  = 1'b0;
      awaddr  = '0;
      awprot  = '0;
      awvalid = 1'b0;
      wdata   = '0;
      wstrb   = '0;
      wvalid  = 1'b0;
      bready  = 1'b0;
   end

   always @(posedge clock) begin
      if (handle == 0) begin
         handle = $rogueTcpMemoryCreate();
         if (handle == 0) $fatal(1, "%m: $rogueTcpMemoryCreate failed");
      end

      if (!$rogueTcpMemoryUpdate(handle, reset, portNum,
                                 araddr_c, arprot_c, arvalid_c, rready_c, arready, rdata, rresp, rvalid,
                                 awaddr_c, awprot_c, awvalid_c, wdata_c, wstrb_c, wvalid_c, bready_c,
                                 awready, wready, bresp, bvalid)) begin
         $fatal(1, "%m: $rogueTcpMemoryUpdate failed");
      end

      araddr  <= araddr_c;
      arprot  <= arprot_c;
      arvalid <= arvalid_c;
      rready  <= rready_c;
      awaddr  <= awaddr_c;
      awprot  <= awprot_c;
      awvalid <= awvalid_c;
      wdata   <= wdata_c;
      wstrb   <= wstrb_c;
      wvalid  <= wvalid_c;
      bready  <= bready_c;
   end

   final begin
      if (handle != 0) $rogueTcpMemoryDestroy(handle);
   end

endmodule
