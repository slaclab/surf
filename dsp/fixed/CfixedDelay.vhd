-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
--- Description: cfixed delay module, wraps SlvFixedDelay from surf base library
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
use ieee.fixed_pkg.all;

library surf;
use surf.StdRtlPkg.all;
use surf.ComplexFixedPkg.all;

entity cfixedDelay is
   generic (
      TPD_G          : time      := 1 ns;
      XIL_DEVICE_G   : string    := "ULTRASCALE_PLUS";
      USER_WIDTH_G   : integer   := 0;
      DELAY_STYLE_G  : string    := "srl_reg"; -- "reg", "srl", "srl_reg", "reg_srl", "reg_srl_reg" or "block"
      DELAY_G        : integer   := 256);
   port (
      clk      : in  sl;
      validIn  : in  sl := '0';
      userIn   : in  slv(USER_WIDTH_G-1 downto 0) := (others => '0');
      din      : in  cfixed;
      validOut : out sl;
      userOut  : out slv(USER_WIDTH_G-1 downto 0);
      dout     : out cfixed);
end entity cfixedDelay;


architecture rtl of cfixedDelay is

   constant SLV_LEN_C : integer := din.re'length + din.im'length + 1 + USER_WIDTH_G;

   signal slvDelayIn  : slv(SLV_LEN_C-1 downto 0);
   signal slvDelayOut : slv(SLV_LEN_C-1 downto 0);

begin

   slvDelayIn(slvDelayIn'high)                                            <= validIn;
   slvDelayIn(slvDelayIn'high - 1 downto slvDelayIn'high - USER_WIDTH_G)  <= userIn;
   slvDelayIn(slvDelayIn'high - USER_WIDTH_G - 1 downto 0)                <= to_slv(din);

   validOut <= slvDelayOut(slvDelayOut'high);
   userOut  <= slvDelayOut(slvDelayIn'high - 1 downto slvDelayIn'high - USER_WIDTH_G);
   dout     <= to_cfixed(slvDelayOut(slvDelayIn'high - USER_WIDTH_G - 1 downto 0), dout);

   U_SLV_DELAY : entity surf.SlvFixedDelay
      generic map (
         TPD_G         => TPD_G,
         XIL_DEVICE_G  => XIL_DEVICE_G,
         DELAY_STYLE_G => DELAY_STYLE_G,
         DELAY_G       => DELAY_G,
         WIDTH_G       => slvDelayIn'length)
      port map (
         clk  => clk,
         din  => slvDelayIn,
         dout => slvDelayOut);

end rtl;
