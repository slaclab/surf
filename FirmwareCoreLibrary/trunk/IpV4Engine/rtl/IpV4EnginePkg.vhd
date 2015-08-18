-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4EnginePkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-11
-- Last update: 2015-08-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package IpV4EnginePkg is

   constant IP_ENGINE_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);

   -- EtherTypes
   constant ARP_TYPE_C  : slv(15 downto 0) := x"0608";  -- EtherType = ARP = 0x0806
   constant IPV4_TYPE_C : slv(15 downto 0) := x"0008";  -- EtherType = IPV4 = 0x0800
   constant VLAN_TYPE_C : slv(15 downto 0) := x"0081";  -- EtherType = VLAN = 0x8100

   -- IPV4 Protocol Constants
   constant UDP_C : slv(7 downto 0) := x"11";  -- Protocol = UDP = 0x11
   constant TCP_C : slv(7 downto 0) := x"06";  -- Protocol = TCP = 0x06

   procedure GetIpV4Checksum (
      hdr      : in    Slv8Array(19 downto 0);
      sum0     : inout Slv32Array(3 downto 0);
      sum1     : inout Slv32Array(1 downto 0);
      sum2     : inout Slv32Array(1 downto 0);
      sum3     : inout slv(31 downto 0);
      ibValid  : inout sl;
      checksum : inout slv(15 downto 0));  

end package IpV4EnginePkg;

package body IpV4EnginePkg is

   procedure GetIpV4Checksum (
      hdr      : in    Slv8Array(19 downto 0);
      sum0     : inout Slv32Array(3 downto 0);
      sum1     : inout Slv32Array(1 downto 0);
      sum2     : inout Slv32Array(1 downto 0);
      sum3     : inout slv(31 downto 0);
      ibValid  : inout sl;
      checksum : inout slv(15 downto 0)) is
      variable i          : natural;
      variable ibChecksum : slv(15 downto 0);
      variable header     : Slv32Array(9 downto 0);
      variable sum4       : slv(15 downto 0);
   begin
      -- Convert to 32-bit (little endian) words
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
         sum1(i) := sum0(2*i+0) + sum0(2*i+1);
      end loop;

      -- Summation: Level2
      sum2(0) := sum1(0) + sum1(1);
      sum2(1) := header(8) + header(9);

      -- Summation: Level3
      sum3 := sum2(0) + sum2(1);

      -- Summation: Level4
      sum4 := sum3(31 downto 16) + sum3(15 downto 0);

      -- Perform 1's complement
      checksum := not(sum4);

      -- Check for valid inbound checksum
      if checksum = ibChecksum then
         ibValid := '1';
      else
         ibValid := '0';
      end if;
      
   end procedure;

end package body IpV4EnginePkg;
