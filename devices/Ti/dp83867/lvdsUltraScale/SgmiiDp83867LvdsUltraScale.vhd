-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for TI DP83867DP83867 PHY  + GigEthLvdsUltraScaleWrapper
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.EthMacPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity SgmiiDp83867LvdsUltraScale is
   generic (
      TPD_G             : time                  := 1 ns;
      STABLE_CLK_FREQ_G : real                  := 156.25E+6;
      PAUSE_EN_G        : boolean               := true;
      JUMBO_G           : boolean               := true;
      EN_AXIL_REG_G     : boolean               := false;
      PHY_G             : natural range 0 to 15 := 3;
      AXIS_CONFIG_G     : AxiStreamConfigType   := EMAC_AXIS_CONFIG_C);
   port (
      -- clock and reset
      extRst          : in    sl;                -- active high
      stableClk       : in    sl;                -- Stable clock reference
      phyClk          : out   sl;
      phyRst          : out   sl;
      -- Local Configurations/status
      localMac        : in    slv(47 downto 0);  --  big-Endian configuration
      phyReady        : out   sl;
      linkUp          : out   sl;
      speed10         : out   sl;
      speed100        : out   sl;
      speed1000       : out   sl;
      -- Interface to Ethernet Media Access Controller (MAC)
      macClk          : in    sl;
      macRst          : in    sl;
      obMacMaster     : out   AxiStreamMasterType;
      obMacSlave      : in    AxiStreamSlaveType;
      ibMacMaster     : in    AxiStreamMasterType;
      ibMacSlave      : out   AxiStreamSlaveType;
      -- Slave AXI-Lite Interface
      axilClk         : in    sl                     := '0';
      axilRst         : in    sl                     := '0';
      axilReadMaster  : in    AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      -- ETH external PHY Ports
      phyClkP         : in    sl;                -- 625.0 MHz
      phyClkN         : in    sl;
      phyMdc          : out   sl;
      phyMdio         : inout sl;
      phyRstN         : out   sl;                -- active low
      phyIrqN         : in    sl;                -- active low
      -- LVDS SGMII Ports
      sgmiiRxP        : in    sl;
      sgmiiRxN        : in    sl;
      sgmiiTxP        : out   sl;
      sgmiiTxN        : out   sl);
end entity SgmiiDp83867LvdsUltraScale;

architecture mapping of SgmiiDp83867LvdsUltraScale is

   signal phyInitRst : sl;
   signal phyIrq     : sl;
   signal phyTri     : sl;
   signal phyMdi     : sl;
   signal phyMdiSync : sl;
   signal phyMdo     : sl := '1';

   signal extPhyRstN : sl := '0';

   signal sp10_100 : sl := '0';
   signal sp100    : sl := '0';
   signal initDone : sl := '0';

begin

   speed10   <= sp10_100 and not sp100;
   speed100  <= sp10_100 and not sp100;
   speed1000 <= not sp10_100 and not sp100;

   -- Tri-state driver for phyMdio
   U_phyMdio : IOBUF
      port map (
         I  => phyMdo,                  -- 1-bit input: Buffer input
         O  => phyMdi,                  -- 1-bit output: Buffer output
         IO => phyMdio,                 -- 1-bit inout: Buffer inout
         T  => phyTri);                 -- 1-bit input: 3-state enable input

   -- Reset line of the external phy
   phyRstN <= extPhyRstN;

   U_SyncIrq : entity surf.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '0',
         INIT_G         => "11")
      port map (
         clk     => stableClk,
         dataIn  => phyIrqN,
         dataOut => phyIrq);

   U_SyncMdi : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => stableClk,
         dataIn  => phyMdi,
         dataOut => phyMdiSync);

   --------------------------------------------------------------------------
   -- We must hold reset for >10ms and then wait >5ms until we may talk
   -- to it (we actually wait also >10ms) which is indicated by 'phyInitRst'
   --------------------------------------------------------------------------
   U_PwrUpRst0 : entity surf.PwrUpRst
      generic map(
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '0',
         DURATION_G     => getTimeRatio(STABLE_CLK_FREQ_G, 2.0))  -- 500 ms reset
      port map (
         arst   => extRst,
         clk    => stableClk,
         rstOut => extPhyRstN);

   U_PwrUpRst1 : entity surf.PwrUpRst
      generic map(
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1',
         DURATION_G     => getTimeRatio(STABLE_CLK_FREQ_G, 2.0))  -- 500 ms reset
      port map (
         arst   => extPhyRstN,
         clk    => stableClk,
         rstOut => phyInitRst);

   U_PhyCtrl : entity surf.SgmiiDp83867Mdio
      generic map (
         TPD_G => TPD_G,
         PHY_G => PHY_G,
         DIV_G => getTimeRatio(STABLE_CLK_FREQ_G, 2*1.0E+6))  -- phyMdc = 1.0 MHz
      port map (
         clk             => stableClk,
         rst             => phyInitRst,
         initDone        => initDone,
         speed_is_10_100 => sp10_100,
         speed_is_100    => sp100,
         linkIsUp        => linkUp,
         mdi             => phyMdiSync,
         mdc             => phyMdc,
         mdTri           => phyTri,
         mdo             => phyMdo,
         linkIrq         => phyIrq);

   U_1GigE : entity surf.GigEthLvdsUltraScale
      generic map (
         TPD_G         => TPD_G,
         PAUSE_EN_G    => PAUSE_EN_G,
         JUMBO_G       => JUMBO_G,
         EN_AXIL_REG_G => EN_AXIL_REG_G,
         AXIS_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Local Configurations
         localMac        => localMac,
         -- Streaming DMA Interface
         dmaClk          => macClk,
         dmaRst          => macRst,
         dmaIbMaster     => obMacMaster,
         dmaIbSlave      => obMacSlave,
         dmaObMaster     => ibMacMaster,
         dmaObSlave      => ibMacSlave,
         -- Slave AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- Speed selection
         speed_is_10_100 => sp10_100,
         speed_is_100    => sp100,
         -- PHY + MAC signals
         extRst          => phyInitRst,
         ethClk          => phyClk,
         ethRst          => phyRst,
         phyReady        => phyReady,
         -- SGMII / LVDS Ports
         sgmiiClkP       => phyClkP,    -- 625 MHz
         sgmiiClkN       => phyClkN,    -- 625 MHz
         sgmiiTxP        => sgmiiTxP,
         sgmiiTxN        => sgmiiTxN,
         sgmiiRxP        => sgmiiRxP,
         sgmiiRxN        => sgmiiRxN);

end mapping;
