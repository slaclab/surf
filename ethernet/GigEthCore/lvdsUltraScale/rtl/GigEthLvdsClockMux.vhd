-------------------------------------------------------------------------------
-- File       : GigEthLvdsUltraScaleWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for SGMII/LVDS Ethernet
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

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity GigEthLvdsClockMux is
   port (
      clk125p0   : in  sl;
      clk12p50   : in  sl;
      clk1p250   : in  sl;
      sel12p50   : in  sl;
      sel1p250   : in  sl;
      O          : out sl
   );
end entity GigEthLvdsClockMux;

architecture GigEthLvdsClockMuxImpl of GigEthLvdsClockMux is
   signal bufCasc : sl;
begin

      U_BUFGMUX_100_1K : BUFGMUX_CTRL
            port map (
               I0 => clk125p0,
               I1 => clk12p50,
               S  => sel12p50,
               O  => bufCasc
            );

      U_BUFGMUX_10 : BUFGMUX_CTRL
            port map (
               I0 => bufCasc,
               I1 => clk1p250,
               S  => sel1p250,
               O  => O
            );
end architecture GigEthLvdsClockMuxImpl;
