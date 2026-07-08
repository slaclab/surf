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
// SV DPI leaf for the Rogue-TCP AXI-Lite memory model under Vivado xsim. Ports
// stay logic-typed for clean VHDL interop; only the DPI import's formal
// arguments are 2-state bit/bit-vector (SV auto-narrows 4-state logic to
// 2-state bit at the call site). Drives the DPI-C adapter (RogueTcpMemory.c)
// once per rising clock edge, mirroring the GHDL backend's per-edge update
// process.
//////////////////////////////////////////////////////////////////////////////

module RogueTcpMemoryDpi (
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

   import "DPI-C" function void rogueTcpMemoryUpdate
     (input  bit        reset,
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

   always_ff @(posedge clock) begin
      rogueTcpMemoryUpdate(reset, portNum,
                            araddr, arprot, arvalid, rready, arready, rdata, rresp, rvalid,
                            awaddr, awprot, awvalid, wdata, wstrb, wvalid, bready, awready, wready, bresp, bvalid);
   end

endmodule
