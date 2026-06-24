//-----------------------------------------------------------------------------
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//-----------------------------------------------------------------------------
// Thin Verilog top shim wrapping the VHDL RoCEv2AxiStreamRdmaWrapper.
//
// VCS mixed-language VPI only enumerates *Verilog* instances as candidate
// roots; the VHDL top (RoCEv2AxiStreamRdmaWrapper) is invisible to cocotb, so
// elaborating the VHDL entity as top yields "Can not find root handle". This
// shim gives the VPI a Verilog root: cocotb binds here and cocotbext-axi drives
// these plain Verilog ports, which pass straight through to the VHDL entity.
//
// This is a SIM-ONLY testbench file (lives under tests/, never synthesized).
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module RoCEv2EngineTbTop (
   input  wire         clk,
   input  wire         rst,
   // Inbound PRBS payload stream
   input  wire         S_AXIS_TVALID,
   input  wire [255:0] S_AXIS_TDATA,
   input  wire [31:0]  S_AXIS_TKEEP,
   input  wire         S_AXIS_TLAST,
   output wire         S_AXIS_TREADY,
   // obUdp: UDP responses INTO the engine (TB drives go-back-N ACK/NAK)
   input  wire         S_OBUDP_TVALID,
   input  wire [255:0] S_OBUDP_TDATA,
   input  wire [31:0]  S_OBUDP_TKEEP,
   input  wire         S_OBUDP_TLAST,
   input  wire [1:0]   S_OBUDP_TUSER,
   output wire         S_OBUDP_TREADY,
   // ibUdp: UDP requests OUT of the engine (TB observes = transmissions)
   output wire         M_IBUDP_TVALID,
   output wire [255:0] M_IBUDP_TDATA,
   output wire [31:0]  M_IBUDP_TKEEP,
   output wire         M_IBUDP_TLAST,
   output wire [1:0]   M_IBUDP_TUSER,
   input  wire         M_IBUDP_TREADY,
   // AXI-Lite slave
   input  wire [31:0]  S_AXIL_AWADDR,
   input  wire [2:0]   S_AXIL_AWPROT,
   input  wire         S_AXIL_AWVALID,
   output wire         S_AXIL_AWREADY,
   input  wire [31:0]  S_AXIL_WDATA,
   input  wire [3:0]   S_AXIL_WSTRB,
   input  wire         S_AXIL_WVALID,
   output wire         S_AXIL_WREADY,
   output wire [1:0]   S_AXIL_BRESP,
   output wire         S_AXIL_BVALID,
   input  wire         S_AXIL_BREADY,
   input  wire [31:0]  S_AXIL_ARADDR,
   input  wire [2:0]   S_AXIL_ARPROT,
   input  wire         S_AXIL_ARVALID,
   output wire         S_AXIL_ARREADY,
   output wire [31:0]  S_AXIL_RDATA,
   output wire [1:0]   S_AXIL_RRESP,
   output wire         S_AXIL_RVALID,
   input  wire         S_AXIL_RREADY
);

   RoCEv2AxiStreamRdmaWrapper u_wrapper (
      .clk            (clk),
      .rst            (rst),
      .S_AXIS_TVALID  (S_AXIS_TVALID),
      .S_AXIS_TDATA   (S_AXIS_TDATA),
      .S_AXIS_TKEEP   (S_AXIS_TKEEP),
      .S_AXIS_TLAST   (S_AXIS_TLAST),
      .S_AXIS_TREADY  (S_AXIS_TREADY),
      .S_OBUDP_TVALID (S_OBUDP_TVALID),
      .S_OBUDP_TDATA  (S_OBUDP_TDATA),
      .S_OBUDP_TKEEP  (S_OBUDP_TKEEP),
      .S_OBUDP_TLAST  (S_OBUDP_TLAST),
      .S_OBUDP_TUSER  (S_OBUDP_TUSER),
      .S_OBUDP_TREADY (S_OBUDP_TREADY),
      .M_IBUDP_TVALID (M_IBUDP_TVALID),
      .M_IBUDP_TDATA  (M_IBUDP_TDATA),
      .M_IBUDP_TKEEP  (M_IBUDP_TKEEP),
      .M_IBUDP_TLAST  (M_IBUDP_TLAST),
      .M_IBUDP_TUSER  (M_IBUDP_TUSER),
      .M_IBUDP_TREADY (M_IBUDP_TREADY),
      .S_AXIL_AWADDR  (S_AXIL_AWADDR),
      .S_AXIL_AWPROT  (S_AXIL_AWPROT),
      .S_AXIL_AWVALID (S_AXIL_AWVALID),
      .S_AXIL_AWREADY (S_AXIL_AWREADY),
      .S_AXIL_WDATA   (S_AXIL_WDATA),
      .S_AXIL_WSTRB   (S_AXIL_WSTRB),
      .S_AXIL_WVALID  (S_AXIL_WVALID),
      .S_AXIL_WREADY  (S_AXIL_WREADY),
      .S_AXIL_BRESP   (S_AXIL_BRESP),
      .S_AXIL_BVALID  (S_AXIL_BVALID),
      .S_AXIL_BREADY  (S_AXIL_BREADY),
      .S_AXIL_ARADDR  (S_AXIL_ARADDR),
      .S_AXIL_ARPROT  (S_AXIL_ARPROT),
      .S_AXIL_ARVALID (S_AXIL_ARVALID),
      .S_AXIL_ARREADY (S_AXIL_ARREADY),
      .S_AXIL_RDATA   (S_AXIL_RDATA),
      .S_AXIL_RRESP   (S_AXIL_RRESP),
      .S_AXIL_RVALID  (S_AXIL_RVALID),
      .S_AXIL_RREADY  (S_AXIL_RREADY)
   );

endmodule
