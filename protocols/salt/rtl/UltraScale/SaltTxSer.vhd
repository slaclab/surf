-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for SelectioSer
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

library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity SaltTxSer is
   generic (
      TPD_G        : time   := 1 ns;
      SIM_DEVICE_G : string := "ULTRASCALE");
   port (
      -- SELECTIO Ports
      txP    : out sl;
      txN    : out sl;
      -- Clock and Reset Interface
      clkx4  : in  sl;
      clkx1  : in  sl;
      rstx1  : in  sl;
      -- Output
      dataIn : in  slv(7 downto 0));
end SaltTxSer;

architecture mapping of SaltTxSer is

   signal tx : sl;

begin

   U_OSERDESE3 : OSERDESE3
      generic map (
         DATA_WIDTH => 8,
         SIM_DEVICE => SIM_DEVICE_G)
      port map (
         CLK    => clkx4,
         CLKDIV => clkx1,
         RST    => rstx1,
         T      => '0',
         D      => dataIn,
         OQ     => tx,
         T_OUT  => open);

   U_OBUFDS : OBUFDS
      port map (
         I  => tx,
         O  => txP,
         OB => txN);

end mapping;
