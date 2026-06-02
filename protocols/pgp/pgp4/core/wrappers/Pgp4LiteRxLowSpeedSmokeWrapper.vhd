-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing smoke wrapper for surf.Pgp4LiteRxLowSpeed
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity Pgp4LiteRxLowSpeedSmokeWrapper is
   port (
      clk       : in sl;
      rst       : in sl;
      deserData : in slv(7 downto 0));
end entity Pgp4LiteRxLowSpeedSmokeWrapper;

architecture rtl of Pgp4LiteRxLowSpeedSmokeWrapper is

   signal deserDataArray : Slv8Array(0 downto 0);

begin

   deserDataArray(0) <= deserData;

   U_DUT : entity surf.Pgp4LiteRxLowSpeed
      generic map (
         SIMULATION_G       => true,
         DLY_STEP_SIZE_G    => 1,
         NUM_LANE_G         => 1,
         STATUS_CNT_WIDTH_G => 8,
         ERROR_CNT_WIDTH_G  => 4,
         AXIL_CLK_FREQ_G    => 100.0E+6,
         AXIL_BASE_ADDR_G   => x"00000000")
      port map (
         deserClk        => clk,
         deserRst        => rst,
         deserData       => deserDataArray,
         dlyLoad         => open,
         dlyCfg          => open,
         pgpRxMasters    => open,
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

end architecture rtl;
