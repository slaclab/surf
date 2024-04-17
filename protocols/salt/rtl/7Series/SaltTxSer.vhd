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
      SIM_DEVICE_G : string := "7SERIES");
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

   U_OSERDESE2 : OSERDESE2
      generic map (
         DATA_RATE_OQ   => "DDR",
         DATA_RATE_TQ   => "SDR",
         DATA_WIDTH     => 8,
         INIT_OQ        => '0',
         INIT_TQ        => '0',
         SERDES_MODE    => "MASTER",
         SRVAL_OQ       => '0',
         SRVAL_TQ       => '0',
         TBYTE_CTL      => "FALSE",
         TBYTE_SRC      => "FALSE",
         TRISTATE_WIDTH => 1)
      port map (
         OFB       => open,
         OQ        => tx,
         SHIFTOUT1 => open,
         SHIFTOUT2 => open,
         TBYTEOUT  => open,
         TFB       => open,
         TQ        => open,
         CLK       => clkx4,
         CLKDIV    => clkx1,
         D1        => dataIn(0),
         D2        => dataIn(1),
         D3        => dataIn(2),
         D4        => dataIn(3),
         D5        => dataIn(4),
         D6        => dataIn(5),
         D7        => dataIn(6),
         D8        => dataIn(7),
         OCE       => '1',
         RST       => rstx1,
         SHIFTIN1  => '0',
         SHIFTIN2  => '0',
         T1        => '0',
         T2        => '0',
         T3        => '0',
         T4        => '0',
         TBYTEIN   => '0',
         TCE       => '0');

   U_OBUFDS : OBUFDS
      port map (
         I  => tx,
         O  => txP,
         OB => txN);

end mapping;
