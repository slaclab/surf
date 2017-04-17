-------------------------------------------------------------------------------
-- File       : EthMacPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-21
-- Last update: 2016-10-20
-------------------------------------------------------------------------------
-- Description: Ethernet MAC Package File
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

package EthMacPkg is

   -- Default MAC is 01:03:00:56:44:00
   constant EMAC_ADDR_INIT_C : slv(47 downto 0) := x"020300564400";

   -- EtherTypes
   constant ARP_TYPE_C  : slv(15 downto 0) := x"0608";  -- EtherType = ARP = 0x0806
   constant IPV4_TYPE_C : slv(15 downto 0) := x"0008";  -- EtherType = IPV4 = 0x0800
   constant VLAN_TYPE_C : slv(15 downto 0) := x"0081";  -- EtherType = VLAN = 0x8100

   -- IPV4 Protocol Constants
   constant UDP_C  : slv(7 downto 0) := x"11";  -- Protocol = UDP  = 0x11
   constant TCP_C  : slv(7 downto 0) := x"06";  -- Protocol = TCP  = 0x06
   constant ICMP_C : slv(7 downto 0) := x"01";  -- Protocol = ICMP = 0x01

   -- DHCP Constants
   constant DHCP_CPORT : slv(15 downto 0) := x"4400";  -- Port = 68 = 0x0044
   constant DHCP_SPORT : slv(15 downto 0) := x"4300";  -- Port = 67 = 0x0043   

   -- First TUSER Bits
   constant EMAC_FRAG_BIT_C   : integer := 0;
   constant EMAC_SOF_BIT_C    : integer := 1;
   
   -- Last TUSER Bits
   constant EMAC_EOFE_BIT_C   : integer := 0;
   constant EMAC_IPERR_BIT_C  : integer := 1;
   constant EMAC_TCPERR_BIT_C : integer := 2;
   constant EMAC_UDPERR_BIT_C : integer := 3;

   -- Ethernet AXI Stream Configuration
   constant EMAC_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 4,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);   

   -- Generic XMAC Configuration
   type EthMacConfigType is record
      macAddress  : slv(47 downto 0);
      filtEnable  : sl;
      pauseEnable : sl;
      pauseTime   : slv(15 downto 0);
      ipCsumEn    : sl;
      tcpCsumEn   : sl;
      udpCsumEn   : sl;
      dropOnPause : sl;
   end record EthMacConfigType;
   constant ETH_MAC_CONFIG_INIT_C : EthMacConfigType := (
      macAddress  => EMAC_ADDR_INIT_C,
      filtEnable  => '1',
      pauseEnable => '1',
      pauseTime   => x"00FF",
      ipCsumEn    => '1',
      tcpCsumEn   => '1',
      udpCsumEn   => '1',
      dropOnPause => '0');
   type EthMacConfigArray is array (natural range<>) of EthMacConfigType;

   -- Generic XMAC Status
   type EthMacStatusType is record
      rxFifoDropCnt : sl;
      rxPauseCnt    : sl;
      txPauseCnt    : sl;
      rxCountEn     : sl;
      rxOverFlow    : sl;
      rxCrcErrorCnt : sl;
      txCountEn     : sl;
      txUnderRunCnt : sl;
      txNotReadyCnt : sl;
   end record EthMacStatusType;
   constant ETH_MAC_STATUS_INIT_C : EthMacStatusType := (
      rxFifoDropCnt => '0',
      rxPauseCnt    => '0',
      txPauseCnt    => '0',
      rxCountEn     => '0',
      rxOverFlow    => '0',
      rxCrcErrorCnt => '0',
      txCountEn     => '0',
      txUnderRunCnt => '0',
      txNotReadyCnt => '0');
   type EthMacStatusArray is array (natural range<>) of EthMacStatusType;

   constant EMAC_CSUM_PIPELINE_C : natural := 3;
   type EthMacCsumAccumType is record
      step : slv(EMAC_CSUM_PIPELINE_C downto 0);
      sum1 : Slv32Array(1 downto 0);
      sum3 : slv(31 downto 0);
      sum5 : slv(15 downto 0);
   end record EthMacCsumAccumType;
   constant ETH_MAC_CSUM_ACCUM_INIT_C : EthMacCsumAccumType := (
      step => (others => '0'),
      sum1 => (others => (others => '0')),
      sum3 => (others => '0'),
      sum5 => (others => '0'));
   type EthMacCsumAccumArray is array (natural range<>) of EthMacCsumAccumType;

   function EthPortArrayBigEndian (portNum : PositiveArray; portSize : positive) return Slv16Array;
   
   procedure GetEthMacCsum (
      -- Input 
      udpDet  : in    sl;
      last    : in    sl;
      hdr     : in    Slv8Array(19 downto 0);  -- IPv4 Header
      tKeep   : in    slv(15 downto 0);        -- TCP/Data tKeep
      tData   : in    slv(127 downto 0);       -- TCP/Data tKeep      
      len     : in    slv(15 downto 0);
      ibcsum  : in    slv(15 downto 0);        -- TCP/UDP checksum to compare
      -- Summation/Accumulation Signals
      r       : in    EthMacCsumAccumArray(1 downto 0);
      v       : inout EthMacCsumAccumArray(1 downto 0);
      -- Results
      ipValid : inout sl;
      ipCsum  : inout slv(15 downto 0);
      valid   : inout sl;
      csum    : inout slv(15 downto 0));  

end package EthMacPkg;

package body EthMacPkg is

   function EthPortArrayBigEndian (portNum : PositiveArray; portSize : positive) return Slv16Array is
      variable i      : natural;
      variable vec    : slv(15 downto 0);
      variable retVar : Slv16Array((portSize-1) downto 0);
   begin
      for i in (portSize-1) downto 0 loop
         -- Convert the NaturalArray into 16-bit SLV
         vec                    := toSlv(portNum(i), 16);
         -- Convert to big Endian
         retVar(i)(15 downto 8) := vec(7 downto 0);
         retVar(i)(7 downto 0)  := vec(15 downto 8);
      end loop;
      return retVar;
   end function;
   
   procedure GetEthMacCsum (
      -- Input 
      udpDet  : in    sl;
      last    : in    sl;
      hdr     : in    Slv8Array(19 downto 0);  -- IPv4 Header
      tKeep   : in    slv(15 downto 0);        -- TCP/Data tKeep
      tData   : in    slv(127 downto 0);       -- TCP/Data tData      
      len     : in    slv(15 downto 0);        -- TCP/Data length      
      ibcsum  : in    slv(15 downto 0);        -- TCP/UDP checksum to compare
      -- Summation/Accumulation Signals
      r       : in    EthMacCsumAccumArray(1 downto 0);
      v       : inout EthMacCsumAccumArray(1 downto 0);
      -- Results
      ipValid : inout sl;
      ipCsum  : inout slv(15 downto 0);
      valid   : inout sl;
      csum    : inout slv(15 downto 0)) is   
      variable i       : natural;
      variable header  : Slv32Array(9 downto 0);
      variable data    : Slv32Array(7 downto 0);
      variable hdrCsum : slv(15 downto 0);
      variable lenProt : slv(31 downto 0);
      variable sum0A   : Slv32Array(3 downto 0);
      variable sum0B   : Slv32Array(3 downto 0);
      variable sum2A   : Slv32Array(1 downto 0);
      variable sum2B   : slv(31 downto 0);
      variable sum3    : Slv32Array(1 downto 0);
      variable sum3A   : Slv32Array(1 downto 0);
      variable sum3B   : Slv32Array(1 downto 0);
      variable sum4    : Slv32Array(1 downto 0);
   begin
      -- Convert to 32-bit (little Endian) words
      lenProt := x"0000" & len;
      for i in 9 downto 0 loop
         header(i) := x"00000000";
         -- Check for inbound checksum
         if i = 5 then
            -- Mask off and Save Header Checksum
            hdrCsum(15 downto 8) := hdr(2*i+0);
            hdrCsum(7 downto 0)  := hdr(2*i+1);
         else
            header(i)(15 downto 8) := hdr(2*i+0);
            header(i)(7 downto 0)  := hdr(2*i+1);
         end if;
      end loop;
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
      v(0).step(0) := last;
      v(1).step(0) := last;
      for i in 3 downto 0 loop
         sum0A(i) := header(2*i+0) + header(2*i+1);
         sum0B(i) := data(2*i+0) + data(2*i+1);
      end loop;

      -- Summation: Level1
      for i in 1 downto 0 loop
         v(0).sum1(i) := sum0A(2*i+0) + sum0A(2*i+1);
         v(1).sum1(i) := sum0B(2*i+0) + sum0B(2*i+1);
      end loop;

      -- Summation: Level2
      v(0).step(1) := r(0).step(0);
      v(1).step(1) := r(1).step(0);
      sum2A(0)     := r(0).sum1(0) + r(0).sum1(1);
      sum2A(1)     := header(8) + header(9);
      sum2B        := r(1).sum1(0) + r(1).sum1(1);

      -- Summation: Level3      
      v(0).sum3 := sum2A(0) + sum2A(1);

      -- Check if we need to reset the accumulator
      if r(0).step(1) = '1' then
         v(1).sum3 := (others => '0');
      else
         -- Summation/Accumulation: Level3 
         v(1).sum3 := r(1).sum3 + sum2B;
      end if;

      -- Summation: Level4
      v(0).step(2) := r(0).step(1);
      v(1).step(2) := r(1).step(1);
      sum3(0)      := r(0).sum3;
      sum3(1)      := r(1).sum3 + lenProt;
      for i in 1 downto 0 loop
         sum3A(i)(31 downto 16) := x"0000";
         sum3A(i)(15 downto 0)  := sum3(i)(31 downto 16);
         sum3B(i)(31 downto 16) := x"0000";
         sum3B(i)(15 downto 0)  := sum3(i)(15 downto 0);
         sum4(i)                := sum3A(i) + sum3B(i);
      end loop;

      -- Summation: Level5
      for i in 1 downto 0 loop
         v(i).sum5 := sum4(i)(31 downto 16) + sum4(i)(15 downto 0);
      end loop;

      -- Perform 1's complement
      v(0).step(3) := r(0).step(2);
      v(1).step(3) := r(1).step(2);
      ipCsum       := not(r(0).sum5);
      csum         := not(r(1).sum5);
      
      -- UDP checksum is calculated using one's complement arithmetic (RFC 793).
      -- UDP has a special case where 0x0000 is reserved for "no checksum computed". 
      -- Thus 0x0000 is illegal and when calculated following the standard 
      -- algorithm, replaced with 0xFFFF.
      if (udpDet = '1') and (csum = x"0000") then
         csum := x"FFFF";         
      end if;

      -- Check for valid inbound checksum
      if (ipCsum = hdrCsum) then
         ipValid := '1';
      else
         ipValid := '0';
      end if;

      -- Check for UDP special case of 0x0000 checksum
      if (udpDet = '1') and (ibcsum = x"0000") then
         valid := '1';
      -- check the standard checksum calculation
      elsif (ibcsum = csum) then
         valid := '1';
      -- Else not a valid checksum
      else
         valid := '0';
      end if;

   end procedure;

end package body EthMacPkg;
