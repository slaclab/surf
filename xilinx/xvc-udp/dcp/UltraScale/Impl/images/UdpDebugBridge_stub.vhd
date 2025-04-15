-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
-- Date        : Tue Apr 15 08:37:58 2025
-- Host        : rdsrv403 running 64-bit Ubuntu 22.04.5 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /sdf/home/r/ruckman/project/SimpleExamples/Simple-10GbE-RUDP-KCU105-Example/firmware/submodules/surf/xilinx/xvc-udp/dcp/UltraScale/Impl/images/UdpDebugBridge_stub.vhd
-- Design      : UdpDebugBridge
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcku040-ffva1156-2-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UdpDebugBridge is
  Port (
    axisClk : in STD_LOGIC;
    axisRst : in STD_LOGIC;
    \mAxisReq[tValid]\ : in STD_LOGIC;
    \mAxisReq[tData]\ : in STD_LOGIC_VECTOR ( 1023 downto 0 );
    \mAxisReq[tStrb]\ : in STD_LOGIC_VECTOR ( 127 downto 0 );
    \mAxisReq[tKeep]\ : in STD_LOGIC_VECTOR ( 127 downto 0 );
    \mAxisReq[tLast]\ : in STD_LOGIC;
    \mAxisReq[tDest]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
    \mAxisReq[tId]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
    \mAxisReq[tUser]\ : in STD_LOGIC_VECTOR ( 1023 downto 0 );
    \sAxisReq[tReady]\ : out STD_LOGIC;
    \mAxisTdo[tValid]\ : out STD_LOGIC;
    \mAxisTdo[tData]\ : out STD_LOGIC_VECTOR ( 1023 downto 0 );
    \mAxisTdo[tStrb]\ : out STD_LOGIC_VECTOR ( 127 downto 0 );
    \mAxisTdo[tKeep]\ : out STD_LOGIC_VECTOR ( 127 downto 0 );
    \mAxisTdo[tLast]\ : out STD_LOGIC;
    \mAxisTdo[tDest]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
    \mAxisTdo[tId]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
    \mAxisTdo[tUser]\ : out STD_LOGIC_VECTOR ( 1023 downto 0 );
    \sAxisTdo[tReady]\ : in STD_LOGIC
  );

end UdpDebugBridge;

architecture stub of UdpDebugBridge is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "axisClk,axisRst,\mAxisReq[tValid]\,\mAxisReq[tData]\[1023:0],\mAxisReq[tStrb]\[127:0],\mAxisReq[tKeep]\[127:0],\mAxisReq[tLast]\,\mAxisReq[tDest]\[7:0],\mAxisReq[tId]\[7:0],\mAxisReq[tUser]\[1023:0],\sAxisReq[tReady]\,\mAxisTdo[tValid]\,\mAxisTdo[tData]\[1023:0],\mAxisTdo[tStrb]\[127:0],\mAxisTdo[tKeep]\[127:0],\mAxisTdo[tLast]\,\mAxisTdo[tDest]\[7:0],\mAxisTdo[tId]\[7:0],\mAxisTdo[tUser]\[1023:0],\sAxisTdo[tReady]\";
begin
end;
