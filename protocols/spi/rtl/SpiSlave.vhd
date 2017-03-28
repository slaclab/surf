-------------------------------------------------------------------------------
-- File       : SpiSlave.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-27
-- Last update: 2014-03-14
-------------------------------------------------------------------------------
-- Description: Generic SPI Slave Module
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;

entity SpiSlave is
   generic (
      TPD_G       : time     := 1 ns;
      CPOL_G      : sl       := '0';
      CPHA_G      : sl       := '1';
      WORD_SIZE_G : positive := 16);
   port (
      clk : in sl;
      rst : in sl;

      sclk : in  sl;
      mosi : in  sl;
      miso : out sl;
      selL : in  sl;

      rdData : in slv(WORD_SIZE_G-1 downto 0);
      rdStb  : in sl;

      wrData : out slv(WORD_SIZE_G-1 downto 0);
      wrStb  : out sl);

end entity SpiSlave;

architecture rtl of SpiSlave is

   constant MAX_COUNT_C : integer := WORD_SIZE_G-1;

   type RegType is
   record
      -- Input sync and edge detection regs
      mosiLast : sl;
      sclkLast : sl;
      selLLast : sl;

      --Internal Shift regs and counters
      shiftReg : slv(WORD_SIZE_G downto 0);
      shiftCnt : slv(log2(WORD_SIZE_G)-1 downto 0);
      gotSclk  : sl;

      -- Outputs
      wrStb : sl;
   end record;

   constant REG_INIT_C : RegType := (
      mosiLast => '0',
      sclkLast => '0',
      selLLast => '1',
      shiftReg => (others => '0'),
      shiftCnt => toSlv(MAX_COUNT_C, log2(WORD_SIZE_G)),
      gotSclk  => '0',
      wrStb    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal mosiSync : sl;
   signal sclkSync : sl;
   signal selLSync : sl;

begin

   SEL_SYNCHRONIZER : entity work.Synchronizer
      generic map (
         TPD_G  => TPD_G,
         STAGES_G => 3,
         INIT_G => "111")
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => selL,
         dataOut => selLSync);

   SCLK_SYNCHRONIZER : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => sclk,
         dataOut => sclkSync);

   MOSI_SYNCHRONIZER : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => mosi,
         dataOut => mosiSync);

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
      
   end process seq;


   comb : process (mosiSync, r, rdData, rdStb, rst, sclkSync, selLSync) is
      variable v : RegType;

      impure function isLeadingEdge
         return boolean is
      begin
         return selLSync = '0' and r.sclkLast = CPOL_G and sclkSync = not CPOL_G;
      end function;

      impure function isTrailingEdge
         return boolean is
      begin
         return selLSync = '0' and r.sclkLast = not CPOL_G and sclkSync = CPOL_G;
      end function;

      -- Shift a new bit out
      procedure shift is
      begin
         v.shiftReg := r.shiftReg(WORD_SIZE_G-1 downto 0) & '0';
      end procedure;

      -- Clock in the current mosi bit and increment counter
      procedure sample is
      begin
         v.shiftReg(0) := mosiSync;

         v.shiftCnt := r.shiftCnt + 1;
         if (r.shiftCnt = MAX_COUNT_C) then
            v.shiftCnt := (others => '0');
         end if;
      end procedure;
      
   begin
      v := r;

      v.sclkLast := sclkSync;
      v.mosiLast := mosiSync;
      v.selLLast := selLSync;

      -- CPHA_G = 0 is a special case
      -- Do a shift on falling edge of selL
      if (CPHA_G = '0' and r.selLLast = '1' and selLSync = '0') then
         shift;
      end if;

      if (isLeadingEdge) then
         v.gotSclk := '1';
         if (CPHA_G = '1') then
            shift;
         elsif (CPHA_G = '0') then
            sample;
         end if;
      end if;

      if (isTrailingEdge) then
         if (CPHA_G = '1') then
            sample;
         elsif (CPHA_G = '0' and r.shiftCnt /= MAX_COUNT_C) then
            shift;
         end if;
      end if;

      -- Assert wrStb when max count reached
      if (r.shiftCnt = MAX_COUNT_C and isTrailingEdge and r.gotSclk = '1') then
         v.wrStb := '1';
      end if;

      -- Read strobe only allowed when Write strobe is high
      if (r.wrStb = '1' and (rdStb = '1' or isLeadingEdge)) then
         v.wrStb                            := '0';
         v.shiftReg(WORD_SIZE_G-1 downto 0) := rdData;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Outputs
      miso <= 'Z';
      if (selLSync = '0') then
         miso <= r.shiftReg(WORD_SIZE_G);
      end if;

      wrData <= r.shiftReg(WORD_SIZE_G-1 downto 0);
      wrStb  <= r.wrStb;

   end process;

end architecture rtl;
