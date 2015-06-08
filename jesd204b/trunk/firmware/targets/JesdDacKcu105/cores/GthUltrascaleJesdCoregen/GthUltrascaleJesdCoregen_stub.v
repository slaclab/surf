// Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2014.4 (lin64) Build 1071353 Tue Nov 18 16:48:31 MST 2014
// Date        : Mon Jun  8 14:33:53 2015
// Host        : rdusr207 running 64-bit Red Hat Enterprise Linux Server release 5.11 (Tikanga)
// Command     : write_verilog -force -mode synth_stub
//               /u1/ulegat/jesd204b/build/JesdDacKcu105/JesdDacKcu105_project.srcs/sources_1/ip/GthUltrascaleJesdCoregen/GthUltrascaleJesdCoregen_stub.v
// Design      : GthUltrascaleJesdCoregen
// Purpose     : Stub declaration of top-level module interface
// Device      : xcku040-ffva1156-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "GthUltrascaleJesdCoregen_gtwizard_top,Vivado 2014.4" *)
module GthUltrascaleJesdCoregen(gtwiz_userclk_tx_active_in, gtwiz_userclk_rx_active_in, gtwiz_reset_clk_freerun_in, gtwiz_reset_all_in, gtwiz_reset_tx_pll_and_datapath_in, gtwiz_reset_tx_datapath_in, gtwiz_reset_rx_pll_and_datapath_in, gtwiz_reset_rx_datapath_in, gtwiz_reset_rx_cdr_stable_out, gtwiz_reset_tx_done_out, gtwiz_reset_rx_done_out, gtwiz_userdata_tx_in, gtwiz_userdata_rx_out, gtrefclk00_in, qpll0lock_out, qpll0outclk_out, qpll0outrefclk_out, gthrxn_in, gthrxp_in, rx8b10ben_in, rxcommadeten_in, rxmcommaalignen_in, rxpcommaalignen_in, rxpolarity_in, rxusrclk_in, rxusrclk2_in, tx8b10ben_in, txctrl0_in, txctrl1_in, txctrl2_in, txpolarity_in, txusrclk_in, txusrclk2_in, gthtxn_out, gthtxp_out, rxbyteisaligned_out, rxbyterealign_out, rxcommadet_out, rxctrl0_out, rxctrl1_out, rxctrl2_out, rxctrl3_out, rxoutclk_out, rxpmaresetdone_out, txoutclk_out, txpmaresetdone_out)
/* synthesis syn_black_box black_box_pad_pin="gtwiz_userclk_tx_active_in[0:0],gtwiz_userclk_rx_active_in[0:0],gtwiz_reset_clk_freerun_in[0:0],gtwiz_reset_all_in[0:0],gtwiz_reset_tx_pll_and_datapath_in[0:0],gtwiz_reset_tx_datapath_in[0:0],gtwiz_reset_rx_pll_and_datapath_in[0:0],gtwiz_reset_rx_datapath_in[0:0],gtwiz_reset_rx_cdr_stable_out[0:0],gtwiz_reset_tx_done_out[0:0],gtwiz_reset_rx_done_out[0:0],gtwiz_userdata_tx_in[63:0],gtwiz_userdata_rx_out[63:0],gtrefclk00_in[0:0],qpll0lock_out[0:0],qpll0outclk_out[0:0],qpll0outrefclk_out[0:0],gthrxn_in[1:0],gthrxp_in[1:0],rx8b10ben_in[1:0],rxcommadeten_in[1:0],rxmcommaalignen_in[1:0],rxpcommaalignen_in[1:0],rxpolarity_in[1:0],rxusrclk_in[1:0],rxusrclk2_in[1:0],tx8b10ben_in[1:0],txctrl0_in[31:0],txctrl1_in[31:0],txctrl2_in[15:0],txpolarity_in[1:0],txusrclk_in[1:0],txusrclk2_in[1:0],gthtxn_out[1:0],gthtxp_out[1:0],rxbyteisaligned_out[1:0],rxbyterealign_out[1:0],rxcommadet_out[1:0],rxctrl0_out[31:0],rxctrl1_out[31:0],rxctrl2_out[15:0],rxctrl3_out[15:0],rxoutclk_out[1:0],rxpmaresetdone_out[1:0],txoutclk_out[1:0],txpmaresetdone_out[1:0]" */;
  input [0:0]gtwiz_userclk_tx_active_in;
  input [0:0]gtwiz_userclk_rx_active_in;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [0:0]gtwiz_reset_all_in;
  input [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  input [0:0]gtwiz_reset_tx_datapath_in;
  input [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  input [0:0]gtwiz_reset_rx_datapath_in;
  output [0:0]gtwiz_reset_rx_cdr_stable_out;
  output [0:0]gtwiz_reset_tx_done_out;
  output [0:0]gtwiz_reset_rx_done_out;
  input [63:0]gtwiz_userdata_tx_in;
  output [63:0]gtwiz_userdata_rx_out;
  input [0:0]gtrefclk00_in;
  output [0:0]qpll0lock_out;
  output [0:0]qpll0outclk_out;
  output [0:0]qpll0outrefclk_out;
  input [1:0]gthrxn_in;
  input [1:0]gthrxp_in;
  input [1:0]rx8b10ben_in;
  input [1:0]rxcommadeten_in;
  input [1:0]rxmcommaalignen_in;
  input [1:0]rxpcommaalignen_in;
  input [1:0]rxpolarity_in;
  input [1:0]rxusrclk_in;
  input [1:0]rxusrclk2_in;
  input [1:0]tx8b10ben_in;
  input [31:0]txctrl0_in;
  input [31:0]txctrl1_in;
  input [15:0]txctrl2_in;
  input [1:0]txpolarity_in;
  input [1:0]txusrclk_in;
  input [1:0]txusrclk2_in;
  output [1:0]gthtxn_out;
  output [1:0]gthtxp_out;
  output [1:0]rxbyteisaligned_out;
  output [1:0]rxbyterealign_out;
  output [1:0]rxcommadet_out;
  output [31:0]rxctrl0_out;
  output [31:0]rxctrl1_out;
  output [15:0]rxctrl2_out;
  output [15:0]rxctrl3_out;
  output [1:0]rxoutclk_out;
  output [1:0]rxpmaresetdone_out;
  output [1:0]txoutclk_out;
  output [1:0]txpmaresetdone_out;
endmodule
