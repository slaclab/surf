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
// DPI-C leaf for the Rogue-TCP AXI-Lite memory model under Verilator, derived
// from the xsim DPI leaf. The DPI imports are byte-identical to xsim's so the
// unmodified xsim C adapters link against this leaf as-is. Every rising edge
// stages the DPI outputs into same-named `_c` bit-typed temporaries, then
// publishes each output port with exactly one nonblocking assignment, so the
// value the C model decides at edge N behaves like a flop and is race-free.
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

   import "DPI-C" function chandle rogueTcpMemoryCreate();
   import "DPI-C" function void rogueTcpMemoryDestroy(input chandle handle);
   import "DPI-C" function int rogueTcpMemoryUpdate
     (input  chandle    handle,
      input  bit        reset,
      input  bit [15:0] portNum,
      output bit [31:0] araddr,
      output bit [2:0]  arprot,
      output bit        arvalid,
      output bit        rready,
      input  bit        arready,
      input  bit [31:0] rdata,
      input  bit [1:0]  rresp,
      input  bit        rvalid,
      output bit [31:0] awaddr,
      output bit [2:0]  awprot,
      output bit        awvalid,
      output bit [31:0] wdata,
      output bit [3:0]  wstrb,
      output bit        wvalid,
      output bit        bready,
      input  bit        awready,
      input  bit        wready,
      input  bit [1:0]  bresp,
      input  bit        bvalid);

   chandle handle = null;

   bit [31:0] araddr_c;
   bit [2:0]  arprot_c;
   bit        arvalid_c;
   bit        rready_c;
   bit [31:0] awaddr_c;
   bit [2:0]  awprot_c;
   bit        awvalid_c;
   bit [31:0] wdata_c;
   bit [3:0]  wstrb_c;
   bit        wvalid_c;
   bit        bready_c;

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
      if (handle == null) begin
         handle = rogueTcpMemoryCreate();
         if (handle == null) $fatal(1, "%m: rogueTcpMemoryCreate failed");
      end

      if (rogueTcpMemoryUpdate(handle, reset, portNum,
                               araddr_c, arprot_c, arvalid_c, rready_c, arready, rdata, rresp, rvalid,
                               awaddr_c, awprot_c, awvalid_c, wdata_c, wstrb_c, wvalid_c, bready_c, awready, wready, bresp, bvalid) == 0) begin
         $fatal(1, "%m: rogueTcpMemoryUpdate failed");
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
      if (handle != null) rogueTcpMemoryDestroy(handle);
   end

endmodule
