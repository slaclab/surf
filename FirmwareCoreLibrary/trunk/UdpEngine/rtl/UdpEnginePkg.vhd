-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : UdpEnginePkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-11
-- Last update: 2015-08-25
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

package UdpEnginePkg is

   -- Note: This function assumes the AXIS bus is IP_ENGINE_CONFIG_C
   function Axis32BitEndianConvert (
      master : AxiStreamMasterType)
      return AxiStreamMasterType;
   
   procedure GetUdpChecksum (
      -- Inbound tKeep and tData
      tKeep      : in    slv(15 downto 0);
      tData      : in    slv(127 downto 0);
      -- Summation Signals
      sum0Reg    : in    Slv32Array(3 downto 0);
      sum0       : inout Slv32Array(3 downto 0);
      sum1Reg    : in    Slv32Array(1 downto 0);
      sum1       : inout Slv32Array(1 downto 0);
      sum2Reg    : in    slv(31 downto 0);
      sum2       : inout slv(31 downto 0);
      -- Accumulation Signals
      accumReg   : in    slv(31 downto 0);
      accum      : inout slv(31 downto 0);
      -- Checksum generation and comparsion
      ibValid    : inout sl;
      ibChecksum : in    slv(15 downto 0);
      checksum   : inout slv(15 downto 0));  

end package UdpEnginePkg;

package body UdpEnginePkg is

   -- Note: This function assumes the AXIS bus is IP_ENGINE_CONFIG_C
   function Axis32BitEndianConvert (
      master : AxiStreamMasterType)
      return AxiStreamMasterType
   is
      variable i    : natural;
      variable swap : AxiStreamMasterType;
      variable ret  : AxiStreamMasterType;
   begin
      ret.tValid := master.tValid;
      ret.tStrb  := master.tStrb;
      ret.tLast  := master.tLast;
      ret.tDest  := master.tDest;
      ret.tId    := master.tId;
      ret.tUser  := master.tUser;
      -- Byte Swapping
      for i in 3 downto 0 loop
         swap.tKeep((4*i)+0)                    := master.tKeep(4*i);
         swap.tKeep((4*i)+1)                    := master.tKeep(4*i);
         swap.tKeep((4*i)+2)                    := master.tKeep(4*i);
         swap.tKeep((4*i)+3)                    := master.tKeep(4*i);
         swap.tData((32*i)+31 downto (32*i)+24) := master.tData((32*i)+7 downto (32*i)+0);
         swap.tData((32*i)+23 downto (32*i)+16) := master.tData((32*i)+15 downto (32*i)+8);
         swap.tData((32*i)+15 downto (32*i)+8)  := master.tData((32*i)+23 downto (32*i)+16);
         swap.tData((32*i)+7 downto (32*i)+0)   := master.tData((32*i)+31 downto (32*i)+24);
      end loop;
      -- Word Swapping
      if swap.tKeep(12) = '1' then
         ret.tKeep(15 downto 12)  := swap.tKeep(3 downto 0);
         ret.tKeep(11 downto 8)   := swap.tKeep(7 downto 4);
         ret.tKeep(7 downto 4)    := swap.tKeep(11 downto 8);
         ret.tKeep(3 downto 0)    := swap.tKeep(15 downto 12);
         ret.tData(127 downto 96) := swap.tData(31 downto 0);
         ret.tData(95 downto 64)  := swap.tData(63 downto 32);
         ret.tData(63 downto 32)  := swap.tData(95 downto 64);
         ret.tData(31 downto 0)   := swap.tData(127 downto 96);
      elsif swap.tKeep(8) = '1' then
         ret.tKeep(15 downto 12)  := (others => '0');
         ret.tKeep(11 downto 8)   := swap.tKeep(3 downto 0);
         ret.tKeep(7 downto 4)    := swap.tKeep(7 downto 4);
         ret.tKeep(3 downto 0)    := swap.tKeep(11 downto 8);
         ret.tData(127 downto 96) := (others => '0');
         ret.tData(95 downto 64)  := swap.tData(31 downto 0);
         ret.tData(63 downto 32)  := swap.tData(63 downto 32);
         ret.tData(31 downto 0)   := swap.tData(95 downto 64);
      elsif swap.tKeep(4) = '1' then
         ret.tKeep(15 downto 8)   := (others => '0');
         ret.tKeep(7 downto 4)    := swap.tKeep(3 downto 0);
         ret.tKeep(3 downto 0)    := swap.tKeep(7 downto 4);
         ret.tData(127 downto 64) := (others => '0');
         ret.tData(63 downto 32)  := swap.tData(31 downto 0);
         ret.tData(31 downto 0)   := swap.tData(63 downto 32);
      else
         ret.tKeep(15 downto 4)   := (others => '0');
         ret.tKeep(3 downto 0)    := swap.tKeep(3 downto 0);
         ret.tData(127 downto 32) := (others => '0');
         ret.tData(31 downto 0)   := swap.tData(31 downto 0);
      end if;
      return ret;
   end function;
   
   procedure GetUdpChecksum (
      -- Inbound tKeep and tData
      tKeep      : in    slv(15 downto 0);
      tData      : in    slv(127 downto 0);
      -- Summation Signals
      sum0Reg    : in    Slv32Array(3 downto 0);
      sum0       : inout Slv32Array(3 downto 0);
      sum1Reg    : in    Slv32Array(1 downto 0);
      sum1       : inout Slv32Array(1 downto 0);
      sum2Reg    : in    slv(31 downto 0);
      sum2       : inout slv(31 downto 0);
      -- Accumulation Signals
      accumReg   : in    slv(31 downto 0);
      accum      : inout slv(31 downto 0);
      -- Checksum generation and comparsion
      ibValid    : inout sl;
      ibChecksum : in    slv(15 downto 0);
      checksum   : inout slv(15 downto 0)) is
      variable i    : natural;
      variable data : Slv32Array(7 downto 0);
      variable sum4 : slv(15 downto 0);
   begin
      -- Convert to 32-bit (little endian) words
      for i in 7 downto 0 loop
         data(i) := x"00000000";
         -- Check tKeep for big endian upper byte of 16-bit word
         if tKeep((2*i)+0) = '1' then
            data(i)(15 downto 8) := tData((8*((2*i)+0))+7 downto (8*((2*i)+0))+0);
         end if;
         -- Check tKeep for big endian lower byte of 16-bit word 
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
         sum1(i) := sum0Reg(2*i+0) + sum0Reg(2*i+1);
      end loop;

      -- Summation: Level2
      sum2 := sum1Reg(0) + sum1Reg(1);

      -- Accumulation
      accum := accumReg + sum2Reg;

      -- Summation: Level4
      sum4 := accumReg(31 downto 16) + accumReg(15 downto 0);

      -- Perform 1's complement
      checksum := not(sum4);

      -- Check for valid inbound checksum
      if checksum = ibChecksum then
         ibValid := '1';
      else
         ibValid := '0';
      end if;
      
   end procedure;

end package body UdpEnginePkg;
