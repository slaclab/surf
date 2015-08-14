-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4EnginePkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-11
-- Last update: 2015-08-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package IpV4EnginePkg is

   -- Used for both Ethernet frames and IP/MAC AXIS buses
   constant IP_ENGINE_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);
   
   -- Only used for IP/MAC AXIS buses
   constant IP_MAC_MASTER_INIT_C : AxiStreamMasterType := (
      tValid => '0',
      tData  => (others => '0'),
      tStrb  => (others => '1'),
      tKeep  => (others => '1'),
      tLast  => '1',-- single word transfers
      tDest  => (others => '0'),
      tId    => (others => '0'),
      tUser  => (others => '0'));    

   constant BROADCAST_MAC_C   : slv(47 downto 0) := (others=>'1');

   constant ARP_TYPE_C        : slv(15 downto 0) := x"0608";-- EtherType = ARP = 0x0806
   constant IPV4_TYPE_C       : slv(15 downto 0) := x"0008";-- EtherType = IPV4 = 0x0800
   constant VLAN_TYPE_C       : slv(15 downto 0) := x"0081";-- EtherType = VLAN = 0x8100
   
   constant HARDWWARE_TYPE_C : slv(15 downto 0) := x"0100";-- HardwareType = ETH = 0x0001
   constant PROTOCOL_TYPE_C  : slv(15 downto 0) := x"0008";-- ProtocolType = IP  = 0x0800

   constant HARDWWARE_LEN_C  : slv(7 downto 0)  := x"06";  -- HardwareLength = 6 (6 Bytes/MAC)
   constant PROTOCOL_LEN_C   : slv(7 downto 0)  := x"04";  -- ProtocolLength = 4 (6 Bytes/IP)
   
   constant ARP_REQ_C       : slv(15 downto 0) := x"0100"; -- OpCode = ARP Request  = 0x0001
   constant ARP_REPLY_C     : slv(15 downto 0) := x"0200"; -- OpCode = ARP Reply    = 0x0002
   
   constant UDP_C : slv(7 downto 0) := x"11";
   constant TCP_C : slv(7 downto 0) := x"06";

end package;
