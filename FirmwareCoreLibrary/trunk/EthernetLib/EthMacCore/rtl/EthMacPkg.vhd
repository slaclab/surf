-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE/40GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacPkg.vhd
-- Author     : Ryan Herbst  <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-21
-- Last update: 2016-09-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package EthMacPkg is

   -- Default MAC is 01:03:00:56:44:00
   constant EMAC_ADDR_INIT_C : slv(47 downto 0) := x"020300564400";

   -- EOF Bit
   constant EMAC_SOF_BIT_C    : integer := 1;
   constant EMAC_EOFE_BIT_C   : integer := 0;
   constant EMAC_IPERR_BIT_C  : integer := 1;
   constant EMAC_TCPERR_BIT_C : integer := 2;
   constant EMAC_UDPERR_BIT_C : integer := 3;

   -- Ethernet AXI Stream Configuration
   constant EMAC_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 4,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);   

   -- Generic XMAC Configuration
   type EthMacConfigType is record
      macAddress    : slv(47 downto 0);
      filtEnable    : sl;
      pauseEnable   : sl;
      pauseTime     : slv(15 downto 0);
      interFrameGap : slv(3 downto 0);
      txShift       : slv(3 downto 0);
      rxShift       : slv(3 downto 0);
      ipCsumEn      : sl;
      tcpCsumEn     : sl;
      udpCsumEn     : sl;
      dropOnPause   : sl;
   end record EthMacConfigType;

   constant ETH_MAC_CONFIG_INIT_C : EthMacConfigType := (
      macAddress    => EMAC_ADDR_INIT_C,
      filtEnable    => '1',
      pauseEnable   => '1',
      pauseTime     => x"00FF",
      interFrameGap => x"3",
      txShift       => (others => '0'),
      rxShift       => (others => '0'),
      ipCsumEn      => '1',
      tcpCsumEn     => '1',
      udpCsumEn     => '1',
      dropOnPause   => '0');

   type EthMacConfigArray is array (natural range<>) of EthMacConfigType;

   -- Generic XMAC Status
   type EthMacStatusType is record
      rxPauseCnt     : sl;
      vlanRxPauseCnt : slv(7 downto 0);
      txPauseCnt     : sl;
      vlanTxPauseCnt : slv(7 downto 0);
      rxCountEn      : sl;
      rxOverFlow     : sl;
      rxCrcErrorCnt  : sl;
      txCountEn      : sl;
      txUnderRunCnt  : sl;
      txNotReadyCnt  : sl;
   end record EthMacStatusType;

   constant ETH_MAC_STATUS_INIT_C : EthMacStatusType := (
      rxPauseCnt     => '0',
      vlanRxPauseCnt => (others => '0'),
      txPauseCnt     => '0',
      vlanTxPauseCnt => (others => '0'),
      rxCountEn      => '0',
      rxOverFlow     => '0',
      rxCrcErrorCnt  => '0',
      txCountEn      => '0',
      txUnderRunCnt  => '0',
      txNotReadyCnt  => '0');

   type EthMacStatusArray is array (natural range<>) of EthMacStatusType;

   -- EtherTypes
   constant ARP_TYPE_C  : slv(15 downto 0) := x"0608";  -- EtherType = ARP = 0x0806
   constant IPV4_TYPE_C : slv(15 downto 0) := x"0008";  -- EtherType = IPV4 = 0x0800
   constant VLAN_TYPE_C : slv(15 downto 0) := x"0081";  -- EtherType = VLAN = 0x8100

   -- IPV4 Protocol Constants
   constant UDP_C  : slv(7 downto 0) := x"11";  -- Protocol = UDP  = 0x11
   constant TCP_C  : slv(7 downto 0) := x"06";  -- Protocol = TCP  = 0x06
   constant ICMP_C : slv(7 downto 0) := x"01";  -- Protocol = ICMP = 0x01
   
   procedure GetIpV4Summation (
      -- Header data
      hdr : in    Slv8Array(19 downto 0);
      -- Summation Signals
      var : inout Slv32Array(1 downto 0));     

   procedure GetIpV4Checksum (
      -- Header data and summation Signals
      hdr   : in    Slv8Array(19 downto 0);
      reg   : in    Slv32Array(1 downto 0);
      -- Checksum generation and comparison
      valid : inout sl;
      csum  : inout slv(15 downto 0));  

   procedure GetTcpUdpAccumulator (
      -- Inbound tKeep and tData
      tKeep : in    slv(15 downto 0);
      tData : in    slv(127 downto 0);
      -- Accumulation Signals
      reg   : in    slv(31 downto 0);
      var   : inout slv(31 downto 0));      

   procedure GetTcpUdpChecksum (
      -- Input stream
      accum   : in    slv(31 downto 0);
      len     : in    slv(15 downto 0);
      -- Checksum generation and comparison
      hdrCsum : in    slv(15 downto 0);
      valid   : inout sl;
      csum    : inout slv(15 downto 0));    

end package EthMacPkg;

package body EthMacPkg is

   procedure GetIpV4Summation (
      -- Header data
      hdr : in    Slv8Array(19 downto 0);
      -- Summation Signals
      var : inout Slv32Array(1 downto 0)) is
      variable i      : natural;
      variable header : Slv32Array(9 downto 0);
      variable sum0   : Slv32Array(3 downto 0);
      variable sum1   : Slv32Array(1 downto 0);
   begin
      -- Convert to 32-bit (little Endian) words
      for i in 9 downto 0 loop
         header(i)(31 downto 16) := x"0000";
         -- Check for inbound checksum
         if i = 5 then
            -- Mask off the inbound checksum
            header(i)(15 downto 0) := x"0000";
         else
            header(i)(15 downto 8) := hdr(2*i+0);
            header(i)(7 downto 0)  := hdr(2*i+1);
         end if;
      end loop;

      -- Summation: Level0
      for i in 3 downto 0 loop
         sum0(i) := header(2*i+0) + header(2*i+1);
      end loop;

      -- Summation: Level1
      for i in 1 downto 0 loop
         sum1(i) := sum0(2*i+0) + sum0(2*i+1);
      end loop;

      -- Summation: Level2
      var(0) := sum1(0) + sum1(1);
      var(1) := header(8) + header(9);
      
   end procedure;

   procedure GetIpV4Checksum (
      -- Header data and summation Signals
      hdr   : in    Slv8Array(19 downto 0);
      reg   : in    Slv32Array(1 downto 0);
      -- Checksum generation and comparison
      valid : inout sl;
      csum  : inout slv(15 downto 0)) is
      variable hdrCsum : slv(15 downto 0);
      variable sum3    : slv(31 downto 0);
      variable sum3A   : slv(31 downto 0);
      variable sum3B   : slv(31 downto 0);
      variable sum4    : slv(31 downto 0);
      variable sum5    : slv(15 downto 0);
   begin

      -- Inbound checksum
      hdrCsum(15 downto 8) := hdr(10);
      hdrCsum(7 downto 0)  := hdr(11);

      -- Summation: Level3
      sum3 := reg(0) + reg(1);

      -- Summation: Level4
      sum3A(31 downto 16) := x"0000";
      sum3A(15 downto 0)  := sum3(31 downto 16);
      sum3B(31 downto 16) := x"0000";
      sum3B(15 downto 0)  := sum3(15 downto 0);
      sum4                := sum3A + sum3B;

      -- Summation: Level5
      sum5 := sum4(31 downto 16) + sum4(15 downto 0);

      -- Perform 1's complement
      csum := not(sum5);

      -- Check for valid inbound checksum
      if (csum = hdrCsum) then
         valid := '1';
      else
         valid := '0';
      end if;
      
   end procedure;
   
   procedure GetTcpUdpAccumulator (
      -- Inbound tKeep and tData
      tKeep : in    slv(15 downto 0);
      tData : in    slv(127 downto 0);
      -- Accumulation Signals
      reg   : in    slv(31 downto 0);
      var   : inout slv(31 downto 0)) is
      variable i    : natural;
      variable data : Slv32Array(7 downto 0);
      variable sum0 : Slv32Array(3 downto 0);
      variable sum1 : Slv32Array(1 downto 0);
      variable sum2 : slv(31 downto 0);
   begin
      -- Convert to 32-bit (little Endian) words
      for i in 7 downto 0 loop
         data(i) := x"00000000";
         -- Check tKeep for big Endian upper byte of 16-bit word
         if tKeep((2*i)+0) = '1' then
            data(i)(15 downto 8) := tData((8*((2*i)+0))+7 downto (8*((2*i)+0))+0);
         end if;
         -- Check tKeep for big Endian lower byte of 16-bit word 
         if tKeep((2*i)+1) = '1' then
            data(i)(7 downto 0) := tData((8*((2*i)+1))+7 downto (8*((2*i)+1))+0);
         end if;
      end loop;

      -- Summation: Level0
      for i in 3 downto 0 loop
         sum0(i) := data(2*i+0) + data(2*i+1);
      end loop;

      -- Summation: Level1
      for i in 1 downto 0 loop
         sum1(i) := sum0(2*i+0) + sum0(2*i+1);
      end loop;

      -- Summation: Level2
      sum2 := sum1(0) + sum1(1);

      -- Accumulation: Level3
      var := reg + sum2;

   end procedure;
   
   procedure GetTcpUdpChecksum (
      -- Input stream
      accum   : in    slv(31 downto 0);
      len     : in    slv(15 downto 0);
      -- Checksum generation and comparison
      hdrCsum : in    slv(15 downto 0);
      valid   : inout sl;
      csum    : inout slv(15 downto 0)) is
      variable i     : natural;
      variable data  : slv(31 downto 0);
      variable sum3  : slv(31 downto 0);
      variable sum3A : slv(31 downto 0);
      variable sum3B : slv(31 downto 0);
      variable sum4  : slv(31 downto 0);
      variable sum5  : slv(15 downto 0);
   begin

      -- Convert to 32-bit (little Endian) words
      data := x"0000" & len;

      -- Summation: Level3
      sum3 := accum + data;

      -- Summation: Level4
      sum3A(31 downto 16) := x"0000";
      sum3A(15 downto 0)  := sum3(31 downto 16);
      sum3B(31 downto 16) := x"0000";
      sum3B(15 downto 0)  := sum3(15 downto 0);
      sum4                := sum3A + sum3B;

      -- Summation: Level5
      sum5 := sum4(31 downto 16) + sum4(15 downto 0);

      -- Perform 1's complement
      if (sum5 = x"FFFF") then
         csum := sum5;
      -- Note: The UDP checksum is calculated using one's complement arithmetic (RFC 793), 
      --       and 0xffff is equivalent to 0x0000; they are -0 and +0 respectively.
      else
         csum := not(sum5);
      end if;

      -- Check for valid inbound checksum
      if (csum = hdrCsum) then
         valid := '1';
      else
         valid := '0';
      end if;
      
   end procedure;

end package body EthMacPkg;
