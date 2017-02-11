-- Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2015.3 (lin64) Build 1368829 Mon Sep 28 20:06:39 MDT 2015
-- Date        : Fri Feb 10 18:03:36 2017
-- Host        : rdsrv117 running 64-bit Red Hat Enterprise Linux Server release 6.8 (Santiago)
-- Command     : write_vhdl -force -mode synth_stub
--               /u/re/ruckman/projects/git/amc-carrier-project-template/firmware/submodules/surf/protocols/salt/xilinxUltraScale/txonly/images/SaltUltraScaleTxOnly_00000001.vhd
-- Design      : SaltUltraScaleTxOnly
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcku040-ffva1156-2-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SaltUltraScaleTxOnly is
  Port ( 
    txp : out STD_LOGIC;
    txn : out STD_LOGIC;
    clk125m : in STD_LOGIC;
    clk625 : in STD_LOGIC;
    clk312 : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    sgmii_clk_r : out STD_LOGIC;
    sgmii_clk_f : out STD_LOGIC;
    sgmii_clk_en : out STD_LOGIC;
    speed_is_10_100 : in STD_LOGIC;
    speed_is_100 : in STD_LOGIC;
    gmii_txd : in STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_tx_en : in STD_LOGIC;
    gmii_tx_er : in STD_LOGIC;
    gmii_rxd : out STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_rx_dv : out STD_LOGIC;
    gmii_rx_er : out STD_LOGIC;
    gmii_isolate : out STD_LOGIC;
    configuration_vector : in STD_LOGIC_VECTOR ( 4 downto 0 );
    status_vector : out STD_LOGIC_VECTOR ( 15 downto 0 );
    reset : in STD_LOGIC;
    signal_detect : in STD_LOGIC
  );

end SaltUltraScaleTxOnly;

architecture stub of SaltUltraScaleTxOnly is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "txp,txn,clk125m,clk625,clk312,mmcm_locked,sgmii_clk_r,sgmii_clk_f,sgmii_clk_en,speed_is_10_100,speed_is_100,gmii_txd[7:0],gmii_tx_en,gmii_tx_er,gmii_rxd[7:0],gmii_rx_dv,gmii_rx_er,gmii_isolate,configuration_vector[4:0],status_vector[15:0],reset,signal_detect";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "gig_ethernet_pcs_pma_v15_1_0,Vivado 2015.3";
begin
end;
