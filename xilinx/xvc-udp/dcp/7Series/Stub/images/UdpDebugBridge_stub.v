// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
// Date        : Tue Apr 15 08:30:37 2025
// Host        : rdsrv403 running 64-bit Ubuntu 22.04.5 LTS
// Command     : write_verilog -force -mode synth_stub
//               /sdf/home/r/ruckman/project/SimpleExamples/Simple-10GbE-RUDP-KCU105-Example/firmware/submodules/surf/xilinx/xvc-udp/dcp/7Series/Stub/images/UdpDebugBridge_stub.v
// Design      : UdpDebugBridge
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z045ffg900-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module UdpDebugBridge(axisClk, axisRst, \mAxisReq[tValid] ,
  \mAxisReq[tData] , \mAxisReq[tStrb] , \mAxisReq[tKeep] , \mAxisReq[tLast] ,
  \mAxisReq[tDest] , \mAxisReq[tId] , \mAxisReq[tUser] , \sAxisReq[tReady] ,
  \mAxisTdo[tValid] , \mAxisTdo[tData] , \mAxisTdo[tStrb] , \mAxisTdo[tKeep] ,
  \mAxisTdo[tLast] , \mAxisTdo[tDest] , \mAxisTdo[tId] , \mAxisTdo[tUser] ,
  \sAxisTdo[tReady] )
/* synthesis syn_black_box black_box_pad_pin="axisClk,axisRst,\mAxisReq[tValid] ,\mAxisReq[tData] [1023:0],\mAxisReq[tStrb] [127:0],\mAxisReq[tKeep] [127:0],\mAxisReq[tLast] ,\mAxisReq[tDest] [7:0],\mAxisReq[tId] [7:0],\mAxisReq[tUser] [1023:0],\sAxisReq[tReady] ,\mAxisTdo[tValid] ,\mAxisTdo[tData] [1023:0],\mAxisTdo[tStrb] [127:0],\mAxisTdo[tKeep] [127:0],\mAxisTdo[tLast] ,\mAxisTdo[tDest] [7:0],\mAxisTdo[tId] [7:0],\mAxisTdo[tUser] [1023:0],\sAxisTdo[tReady] " */;
  input axisClk;
  input axisRst;
  input \mAxisReq[tValid] ;
  input [1023:0]\mAxisReq[tData] ;
  input [127:0]\mAxisReq[tStrb] ;
  input [127:0]\mAxisReq[tKeep] ;
  input \mAxisReq[tLast] ;
  input [7:0]\mAxisReq[tDest] ;
  input [7:0]\mAxisReq[tId] ;
  input [1023:0]\mAxisReq[tUser] ;
  output \sAxisReq[tReady] ;
  output \mAxisTdo[tValid] ;
  output [1023:0]\mAxisTdo[tData] ;
  output [127:0]\mAxisTdo[tStrb] ;
  output [127:0]\mAxisTdo[tKeep] ;
  output \mAxisTdo[tLast] ;
  output [7:0]\mAxisTdo[tDest] ;
  output [7:0]\mAxisTdo[tId] ;
  output [1023:0]\mAxisTdo[tUser] ;
  input \sAxisTdo[tReady] ;
endmodule
