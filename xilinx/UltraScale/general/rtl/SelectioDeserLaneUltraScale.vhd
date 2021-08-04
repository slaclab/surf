-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for SelectioDeser
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

entity SelectioDeserLaneUltraScale is
   generic (
      TPD_G        : time   := 1 ns;
      SIM_DEVICE_G : string := "ULTRASCALE");
   port (
      -- SELECTIO Ports
      rxP     : in  sl;
      rxN     : in  sl;
      -- Clock and Reset Interface
      clkx4   : in  sl;
      clkx1   : in  sl;
      rstx1   : in  sl;
      -- Delay Configuration
      dlyLoad : in  sl;
      dlyCfg  : in  slv(8 downto 0);
      -- Output
      dataOut : out slv(7 downto 0));
end SelectioDeserLaneUltraScale;

architecture mapping of SelectioDeserLaneUltraScale is

   signal rx     : sl;
   signal rxDly  : sl;
   signal clkx4L : sl;

begin

   U_IBUFDS : IBUFDS
      port map (
         I  => rxP,
         IB => rxN,
         O  => rx);

   U_DELAY : entity surf.Idelaye3Wrapper
      generic map (
         DELAY_FORMAT     => "COUNT",
         SIM_DEVICE       => SIM_DEVICE_G,
         DELAY_VALUE      => 0,
         REFCLK_FREQUENCY => 300.0,     -- IDELAYCTRL not used in COUNT mode
         UPDATE_MODE      => "ASYNC",
         CASCADE          => "NONE",
         DELAY_SRC        => "IDATAIN",
         DELAY_TYPE       => "VAR_LOAD")
      port map(
         DATAIN      => '0',
         IDATAIN     => rx,
         DATAOUT     => rxDly,
         CLK         => clkx1,
         RST         => rstx1,
         CE          => '0',
         INC         => '0',
         LOAD        => dlyLoad,
         EN_VTC      => '0',
         CASC_IN     => '0',
         CASC_RETURN => '0',
         CNTVALUEIN  => dlyCfg);

   U_ISERDES : ISERDESE3
      generic map (
         DATA_WIDTH     => 8,
         FIFO_ENABLE    => "FALSE",
         FIFO_SYNC_MODE => "FALSE",
         SIM_DEVICE     => SIM_DEVICE_G)
      port map (
         D           => rxDly,
         Q           => dataOut,
         CLK         => clkx4,
         CLK_B       => clkx4L,
         CLKDIV      => clkx1,
         RST         => rstx1,
         FIFO_RD_CLK => '0',
         FIFO_RD_EN  => '0',
         FIFO_EMPTY  => open);

   clkx4L <= not(clkx4);

end mapping;
