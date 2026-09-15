-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened cocotb adapter for the Ad9249 pin-level model.
--
-- Each normalData slot supplies an offset-binary code or, when selected by
-- INPUT_MILLIVOLTS_G, signed differential millivolts. The adapter converts
-- that stimulus to real volts and exposes SPI and differential serialized
-- pins without adding state or changing the device's conversion latency.
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

entity Ad9249SimWrapper is
   generic (
      INPUT_MILLIVOLTS_G    : boolean := false;
      CLK_PERIOD_G          : time    := 24 ns;
      DATA_PHASE_PS_G       : natural := 0;
      FCO_PHASE_PS_G        : natural := 0;
      DATA_LANE0_SKEW_PS_G  : natural := 0;
      FCO_LANE0_SKEW_PS_G   : natural := 0;
      JITTER_PS_G           : natural := 0;
      TIMING_BIAS_PS_G      : natural := 0);
   port (
      clkP       : in  sl;
      clkN       : in  sl;
      normalData : in  slv(255 downto 0);
      dP         : out slv(15 downto 0);
      dN         : out slv(15 downto 0);
      dcoP       : out slv(1 downto 0);
      dcoN       : out slv(1 downto 0);
      fcoP       : out slv(1 downto 0);
      fcoN       : out slv(1 downto 0);
      sclk       : in  sl;
      sdioDrive  : in  sl;
      sdioEnable : in  sl;
      sdioRead   : out sl;
      csb        : in  slv(1 downto 0));
end entity Ad9249SimWrapper;

architecture rtl of Ad9249SimWrapper is

   signal vin  : RealArray(15 downto 0);
   signal sdio : sl;

begin

   -- Default stimulus is an offset-binary code, independent of output coding.
   -- Analog regressions instead supply signed millivolts in each 16-bit slot.
   GEN_INPUT : for i in 15 downto 0 generate
      inputVoltage : process (normalData) is
      begin
         if (INPUT_MILLIVOLTS_G) then
            vin(i) <= real(to_integer(signed(normalData((16*i)+15 downto 16*i))))/1000.0;
         else
            vin(i) <= real(to_integer(unsigned(normalData((16*i)+13 downto 16*i))))*
                      (2.0/16384.0) - 1.0;
         end if;
      end process inputVoltage;
   end generate GEN_INPUT;

   sdio     <= sdioDrive when sdioEnable = '1' else 'Z';
   sdioRead <= to_x01z(sdio);

   U_DUT : entity surf.Ad9249Sim
      generic map (
         CLK_PERIOD_G  => CLK_PERIOD_G,
         DATA_PHASE_G  => DATA_PHASE_PS_G*1 ps,
         FCO_PHASE_G   => FCO_PHASE_PS_G*1 ps,
         DATA_SKEW_G   => (0 => DATA_LANE0_SKEW_PS_G*1 ps, others => 0 ns),
         FCO_SKEW_G    => (0 => FCO_LANE0_SKEW_PS_G*1 ps, others => 0 ns),
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
