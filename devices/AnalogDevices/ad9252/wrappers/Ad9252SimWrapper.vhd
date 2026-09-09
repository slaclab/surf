-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened cocotb wrapper for surf.Ad9252Sim
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

entity Ad9252SimWrapper is
   generic (
      CLK_PERIOD_G         : time    := 24 ns;
      DATA_PHASE_PS_G      : natural := 0;
      FCO_PHASE_PS_G       : natural := 0;
      DATA_LANE0_SKEW_PS_G : natural := 0;
      FCO_SKEW_PS_G        : natural := 0;
      JITTER_PS_G          : natural := 0;
      TIMING_BIAS_PS_G     : natural := 0);
   port (
      clkP       : in  sl;
      clkN       : in  sl;
      normalData : in  slv(127 downto 0);
      dP         : out slv(7 downto 0);
      dN         : out slv(7 downto 0);
      dcoP       : out sl;
      dcoN       : out sl;
      fcoP       : out sl;
      fcoN       : out sl;
      sclk       : in  sl;
      sdioDrive  : in  sl;
      sdioEnable : in  sl;
      sdioRead   : out sl;
      csb        : in  sl);
end entity Ad9252SimWrapper;

architecture rtl of Ad9252SimWrapper is

   signal vin  : RealArray(7 downto 0);
   signal sdio : sl;

begin

   GEN_INPUT : for i in 7 downto 0 generate
      vin(i) <= real(to_integer(unsigned(normalData((16*i)+13 downto 16*i))))*(2.0/16384.0);
   end generate GEN_INPUT;

   sdio     <= sdioDrive when sdioEnable = '1' else 'Z';
   sdioRead <= sdio;

   U_DUT : entity surf.Ad9252Sim
      generic map (
         CLK_PERIOD_G  => CLK_PERIOD_G,
         DATA_PHASE_G  => DATA_PHASE_PS_G*1 ps,
         FCO_PHASE_G   => FCO_PHASE_PS_G*1 ps,
         DATA_SKEW_G   => (0 => DATA_LANE0_SKEW_PS_G*1 ps, others => 0 ns),
         FCO_SKEW_G    => FCO_SKEW_PS_G*1 ps,
         JITTER_G      => JITTER_PS_G*1 ps,
         TIMING_BIAS_G => TIMING_BIAS_PS_G*1 ps)
      port map (
         clkP => clkP, -- [in]
         clkN => clkN, -- [in]
         vin  => vin, -- [in]
         dP   => dP, -- [out]
         dN   => dN, -- [out]
         dcoP => dcoP, -- [out]
         dcoN => dcoN, -- [out]
         fcoP => fcoP, -- [out]
         fcoN => fcoN, -- [out]
         sclk => sclk, -- [in]
         sdio => sdio, -- [inout]
         csb  => csb); -- [in]

end architecture rtl;
