-------------------------------------------------------------------------------
-- File       : Ad9249.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-11-14
-- Last update: 2016-12-06
-------------------------------------------------------------------------------
-- Description: AD9249 Module
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

library UNISIM;
use UNISIM.vcomponents.all;

use work.StdRtlPkg.all;

entity Ad9249 is

   generic (
      TPD_G            : time    := 1 ns;
      CLK_PERIOD_G     : time    := 24 ns;
      DIVCLK_DIVIDE_G  : integer := 1;
      CLKFBOUT_MULT_G  : integer := 49;
      CLK_DCO_DIVIDE_G : integer := 49;
      CLK_FCO_DIVIDE_G : integer := 7);

   port (
      clkP : in    sl;
      clkN : in    sl;
      vin  : in    RealArray(15 downto 0);
      dP   : out   slv(15 downto 0);
      dN   : out   slv(15 downto 0);
      dcoP : out   slv(1 downto 0);
      dcoN : out   slv(1 downto 0);
      fcoP : out   slv(1 downto 0);
      fcoN : out   slv(1 downto 0);
      sclk : in    sl;
      sdio : inout sl;
      csb  : in    slv(1 downto 0));

end entity Ad9249;

architecture top of Ad9249 is

   signal clk : sl;

begin

   CLK_BUFG : IBUFGDS
      port map (
         I  => clkP,
         IB => clkN,
         O  => clk);



   U_Ad9249Group_0 : entity work.Ad9249Group
      generic map (
         TPD_G            => TPD_G,
         CLK_PERIOD_G     => CLK_PERIOD_G,
         DIVCLK_DIVIDE_G  => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_G  => CLKFBOUT_MULT_G,
         CLK_DCO_DIVIDE_G => CLK_DCO_DIVIDE_G,
         CLK_FCO_DIVIDE_G => CLK_FCO_DIVIDE_G)
      port map (
         clk  => clk,                   -- [in]
         vin  => vin(7 downto 0),       -- [in]
         dP   => dP(7 downto 0),        -- [out]
         dN   => dN(7 downto 0),        -- [out]
         dcoP => dcoP(0),               -- [out]
         dcoN => dcoN(0),               -- [out]
         fcoP => fcoP(0),               -- [out]
         fcoN => fcoN(0),               -- [out]
         sclk => sclk,                  -- [in]
         sdio => sdio,                  -- [inout]
         csb  => csb(0));               -- [in]

   U_Ad9249Group_1 : entity work.Ad9249Group
      generic map (
         TPD_G            => TPD_G,
         CLK_PERIOD_G     => CLK_PERIOD_G,
         DIVCLK_DIVIDE_G  => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_G  => CLKFBOUT_MULT_G,
         CLK_DCO_DIVIDE_G => CLK_DCO_DIVIDE_G,
         CLK_FCO_DIVIDE_G => CLK_FCO_DIVIDE_G)
      port map (
         clk  => clk,                   -- [in]
         vin  => vin(15 downto 8),      -- [in]
         dP   => dP(15 downto 8),       -- [out]
         dN   => dN(15 downto 8),       -- [out]
         dcoP => dcoP(1),               -- [out]
         dcoN => dcoN(1),               -- [out]
         fcoP => fcoP(1),               -- [out]
         fcoN => fcoN(1),               -- [out]
         sclk => sclk,                  -- [in]
         sdio => sdio,                  -- [inout]
         csb  => csb(1));               -- [in]


end architecture top;
