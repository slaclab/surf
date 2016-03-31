-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4EnginePkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-11
-- Last update: 2015-12-03
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

package IpV4EnginePkg is

   constant IP_ENGINE_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16,TKEEP_NORMAL_C,TUSER_FIRST_LAST_C);

   -- EtherTypes
   constant ARP_TYPE_C  : slv(15 downto 0) := x"0608";  -- EtherType = ARP = 0x0806
   constant IPV4_TYPE_C : slv(15 downto 0) := x"0008";  -- EtherType = IPV4 = 0x0800
   constant VLAN_TYPE_C : slv(15 downto 0) := x"0081";  -- EtherType = VLAN = 0x8100

   -- IPV4 Protocol Constants
   constant UDP_C : slv(7 downto 0) := x"11";  -- Protocol = UDP = 0x11
   constant TCP_C : slv(7 downto 0) := x"06";  -- Protocol = TCP = 0x06

   procedure GetIpV4Checksum (
      hdr      : in    Slv8Array(19 downto 0);
      sum0Reg  : in    Slv32Array(3 downto 0);
      sum0     : inout Slv32Array(3 downto 0);
      sum1Reg  : in    Slv32Array(1 downto 0);
      sum1     : inout Slv32Array(1 downto 0);
      sum2Reg  : in    Slv32Array(1 downto 0);
      sum2     : inout Slv32Array(1 downto 0);
      sum3Reg  : in    slv(31 downto 0);
      sum3     : inout slv(31 downto 0);
      sum4Reg  : in    slv(31 downto 0);
      sum4     : inout slv(31 downto 0);
      ibValid  : inout sl;
      checksum : inout slv(15 downto 0));  

end package IpV4EnginePkg;

package body IpV4EnginePkg is

   procedure GetIpV4Checksum (
      hdr      : in    Slv8Array(19 downto 0);
      sum0Reg  : in    Slv32Array(3 downto 0);
      sum0     : inout Slv32Array(3 downto 0);
      sum1Reg  : in    Slv32Array(1 downto 0);
      sum1     : inout Slv32Array(1 downto 0);
      sum2Reg  : in    Slv32Array(1 downto 0);
      sum2     : inout Slv32Array(1 downto 0);
      sum3Reg  : in    slv(31 downto 0);
      sum3     : inout slv(31 downto 0);
      sum4Reg  : in    slv(31 downto 0);
      sum4     : inout slv(31 downto 0);
      ibValid  : inout sl;
      checksum : inout slv(15 downto 0)) is
      variable i          : natural;
      variable ibChecksum : slv(15 downto 0);
      variable header     : Slv32Array(9 downto 0);
      variable sum3RegA   : slv(31 downto 0);
      variable sum3RegB   : slv(31 downto 0);
      variable sum5       : slv(15 downto 0);
   begin
      -- Convert to 32-bit (little Endian) words
      for i in 9 downto 0 loop
         header(i)(31 downto 16) := x"0000";
         -- Check for inbound checksum
         if i = 5 then
            header(i)(15 downto 0)  := x"0000";  -- Mask off the inbound checksum
            ibChecksum(15 downto 8) := hdr(2*i+0);
            ibChecksum(7 downto 0)  := hdr(2*i+1);
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
         sum1(i) := sum0Reg(2*i+0) + sum0Reg(2*i+1);
      end loop;

      -- Summation: Level2
      sum2(0) := sum1Reg(0) + sum1Reg(1);
      sum2(1) := header(8) + header(9);

      -- Summation: Level3
      sum3 := sum2Reg(0) + sum2Reg(1);

      -- Summation: Level4
      sum3RegA(31 downto 16) := x"0000";
      sum3RegA(15 downto 0)  := sum3Reg(31 downto 16);
      sum3RegB(31 downto 16) := x"0000";
      sum3RegB(15 downto 0)  := sum3Reg(15 downto 0);
      sum4                   := sum3RegA + sum3RegB;

      -- Summation: Level5
      sum5 := sum4Reg(31 downto 16) + sum4Reg(15 downto 0);

      -- Perform 1's complement
      checksum := not(sum5);

      -- Check for valid inbound checksum
      if checksum = ibChecksum then
         ibValid := '1';
      else
         ibValid := '0';
      end if;
      
   end procedure;

end package body IpV4EnginePkg;
