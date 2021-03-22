-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: sfixed delay module, wraps SlvFixedDelay from surf base library
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

entity sfixedDelay is
   generic (
      TPD_G          : time      := 1 ns;
      XIL_DEVICE_G   : string    := "ULTRASCALE_PLUS";
      DELAY_STYLE_G  : string    := "srl_reg"; -- "reg", "srl", "srl_reg", "reg_srl", "reg_srl_reg" or "block"
      DELAY_G        : integer   := 256);
   port (
      clk      : in  sl;
      din      : in  sfixed;
      dout     : out sfixed);
end entity sfixedDelay;


architecture rtl of sfixedDelay is

   signal slvDelayIn  : slv(din'length - 1 downto 0);
   signal slvDelayOut : slv(din'length - 1 downto 0);

begin

   slvDelayIn <= to_slv(din);
   dout       <= to_sfixed(slvDelayOut, dout);

   U_SLV_DELAY : entity surf.SlvFixedDelay
      generic map (
         TPD_G   => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G,
         DELAY_STYLE_G => DELAY_STYLE_G,
         DELAY_G       => DELAY_G,
         WIDTH_G       => din'length)
      port map (
         clk  => clk,
         din  => slvDelayIn,
         dout => slvDelayOut);

end rtl;
