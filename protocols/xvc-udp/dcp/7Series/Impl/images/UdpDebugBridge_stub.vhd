-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
-- Date        : Wed Jun 26 13:12:21 2019
-- Host        : rdsrv223 running 64-bit Red Hat Enterprise Linux Server release 6.10 (Santiago)
-- Command     : write_vhdl -force -mode synth_stub
--               /u/re/ruckman/projects/dpm-remote-ibert-tester/firmware/submodules/xvc-udp-debug-bridge/dcp/7Series/Impl/images/UdpDebugBridge_stub.vhd
-- Design      : UdpDebugBridge
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z045ffg900-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UdpDebugBridge is
  Port (
    axisClk : in STD_LOGIC;
    axisRst : in STD_LOGIC;
    \mAxisReq[tValid]\ : in STD_LOGIC;
    \mAxisReq[tData]\ : in STD_LOGIC_VECTOR ( 511 downto 0 );
    \mAxisReq[tStrb]\ : in STD_LOGIC_VECTOR ( 63 downto 0 );
    \mAxisReq[tKeep]\ : in STD_LOGIC_VECTOR ( 63 downto 0 );
    \mAxisReq[tLast]\ : in STD_LOGIC;
    \mAxisReq[tDest]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
    \mAxisReq[tId]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
    \mAxisReq[tUser]\ : in STD_LOGIC_VECTOR ( 511 downto 0 );
    \sAxisReq[tReady]\ : out STD_LOGIC;
    \mAxisTdo[tValid]\ : out STD_LOGIC;
    \mAxisTdo[tData]\ : out STD_LOGIC_VECTOR ( 511 downto 0 );
    \mAxisTdo[tStrb]\ : out STD_LOGIC_VECTOR ( 63 downto 0 );
    \mAxisTdo[tKeep]\ : out STD_LOGIC_VECTOR ( 63 downto 0 );
    \mAxisTdo[tLast]\ : out STD_LOGIC;
    \mAxisTdo[tDest]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
    \mAxisTdo[tId]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
    \mAxisTdo[tUser]\ : out STD_LOGIC_VECTOR ( 511 downto 0 );
    \sAxisTdo[tReady]\ : in STD_LOGIC
  );

end UdpDebugBridge;

architecture stub of UdpDebugBridge is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "axisClk,axisRst,\mAxisReq[tValid]\,\mAxisReq[tData]\[511:0],\mAxisReq[tStrb]\[63:0],\mAxisReq[tKeep]\[63:0],\mAxisReq[tLast]\,\mAxisReq[tDest]\[7:0],\mAxisReq[tId]\[7:0],\mAxisReq[tUser]\[511:0],\sAxisReq[tReady]\,\mAxisTdo[tValid]\,\mAxisTdo[tData]\[511:0],\mAxisTdo[tStrb]\[63:0],\mAxisTdo[tKeep]\[63:0],\mAxisTdo[tLast]\,\mAxisTdo[tDest]\[7:0],\mAxisTdo[tId]\[7:0],\mAxisTdo[tUser]\[511:0],\sAxisTdo[tReady]\";
begin
end;
