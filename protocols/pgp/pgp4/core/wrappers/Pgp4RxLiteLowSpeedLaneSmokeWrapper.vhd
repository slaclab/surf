-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing smoke wrapper for surf.Pgp4RxLiteLowSpeedLane
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

entity Pgp4RxLiteLowSpeedLaneSmokeWrapper is
   port (
      clk       : in sl;
      rst       : in sl;
      deserData : in slv(7 downto 0));
end entity Pgp4RxLiteLowSpeedLaneSmokeWrapper;

architecture rtl of Pgp4RxLiteLowSpeedLaneSmokeWrapper is

begin

   U_DUT : entity surf.Pgp4RxLiteLowSpeedLane
      generic map (
         SIMULATION_G       => true,
         STATUS_CNT_WIDTH_G => 8,
         ERROR_CNT_WIDTH_G  => 4,
         AXIL_CLK_FREQ_G    => 100.0E+6)
      port map (
         deserClk        => clk,
         deserRst        => rst,
         deserData       => deserData,
         dlyLoad         => open,
         dlyCfg          => open,
         enUsrDlyCfg     => '1',
         usrDlyCfg       => (others => '0'),
         minEyeWidth     => x"01",
         lockingCntCfg   => x"00_0004",
         bypFirstBerDet  => '1',
         polarity        => '0',
         bitOrder        => (others => '0'),
         errorDet        => open,
         bitSlip         => open,
         eyeWidth        => open,
         locked          => open,
         pgpRxMaster     => open,
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

end architecture rtl;
