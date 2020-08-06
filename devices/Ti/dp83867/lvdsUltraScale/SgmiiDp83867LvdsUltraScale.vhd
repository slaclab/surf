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

entity SgmiiDp83867LvdsUltraScale is
   generic (
      TPD_G             : time                  := 1 ns;
      STABLE_CLK_FREQ_G : real                  := 156.25E+6;
      USE_BUFG_DIV_G    : boolean               := true;
      CLKOUT1_PHASE_G   : real                  := 90.0;
      PHY_G             : natural range 0 to 15 := 3;
      AXIS_CONFIG_G     : AxiStreamConfigType   := EMAC_AXIS_CONFIG_C);
   port (
      -- clock and reset
      extRst      : in    sl;                -- active high
      stableClk   : in    sl;                -- Stable clock reference
      phyClk      : out   sl;
      phyRst      : out   sl;
      -- Local Configurations/status
      localMac    : in    slv(47 downto 0);  --  big-Endian configuration
      phyReady    : out   sl;
      linkUp      : out   sl;
      speed10     : out   sl;
      speed100    : out   sl;
      speed1000   : out   sl;
      mmcmLocked  : out   sl;
      -- Interface to Ethernet Media Access Controller (MAC)
      macClk      : in    sl;
      macRst      : in    sl;
      obMacMaster : out   AxiStreamMasterType;
      obMacSlave  : in    AxiStreamSlaveType;
      ibMacMaster : in    AxiStreamMasterType;
      ibMacSlave  : out   AxiStreamSlaveType;
      -- ETH external PHY Ports
      phyClkP     : in    sl;                -- 625.0 MHz
      phyClkN     : in    sl;
      phyMdc      : out   sl;
      phyMdio     : inout sl;
      phyRstN     : out   sl;                -- active low
      phyIrqN     : in    sl;                -- active low
      -- LVDS SGMII Ports
      sgmiiRxP    : in    sl;
      sgmiiRxN    : in    sl;
      sgmiiTxP    : out   sl;
      sgmiiTxN    : out   sl);
end entity SgmiiDp83867LvdsUltraScale;

architecture mapping of SgmiiDp83867LvdsUltraScale is

   signal phyClock : sl;
   signal phyReset : sl;

   signal phyInitRst : sl;
   signal phyIrq     : sl;
   signal phyMdi     : sl;
   signal phyMdo     : sl := '1';

   signal extPhyRstN : sl := '0';

   signal sp10_100 : sl := '0';
   signal sp100    : sl := '0';

   signal sp10_100_sync : sl := '0';
   signal sp100_sync    : sl := '0';

   signal initDone : sl := '0';

begin

   phyClk <= phyClock;
   phyRst <= phyReset;

   speed10   <= sp10_100 and not sp100;
   speed100  <= sp10_100 and not sp100;
   speed1000 <= not sp10_100 and not sp100;

   -- Tri-state driver for phyMdio
   phyMdio <= 'Z' when phyMdo = '1' else '0';

   -- Reset line of the external phy
   phyRstN <= extPhyRstN;

   --------------------------------------------------------------------------
   -- We must hold reset for >10ms and then wait >5ms until we may talk
   -- to it (we actually wait also >10ms) which is indicated by 'phyInitRst'
   --------------------------------------------------------------------------
   U_PwrUpRst0 : entity surf.PwrUpRst
      generic map(
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '0',
         DURATION_G     => getTimeRatio(STABLE_CLK_FREQ_G, 100.0))  -- 10 ms reset
      port map (
         arst   => extRst,
         clk    => stableClk,
         rstOut => extPhyRstN);

   U_PwrUpRst1 : entity surf.PwrUpRst
      generic map(
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1',
         DURATION_G     => getTimeRatio(STABLE_CLK_FREQ_G, 100.0))  -- 10 ms reset
      port map (
         arst   => extPhyRstN,
         clk    => stableClk,
         rstOut => phyInitRst);

   -----------------------------------------------------------------------
   -- The SaltCore does not support auto-negotiation on the SGMII link
   -- (mac<->phy) - however, the DP83867ISRGZ PHY (by default) assumes it does.
   -- We need to disable auto-negotiation in the PHY on the SGMII side
   -- and handle link changes (aneg still enabled on copper) flagged
   -- by the PHY...
   -----------------------------------------------------------------------
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
         mdi             => phyMdi,
         mdc             => phyMdc,
         mdo             => phyMdo,
         linkIrq         => phyIrq);

   ----------------------------------------------------
   -- synchronize MDI and IRQ signals into 'clk' domain
   ----------------------------------------------------
   U_SyncMdi : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => stableClk,
         dataIn  => phyMdio,
         dataOut => phyMdi);

   U_SyncIrq : entity surf.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '0',
         INIT_G         => "11")
      port map (
         clk     => stableClk,
         dataIn  => phyIrqN,
         dataOut => phyIrq);

   U_sync_speed : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map (
         clk        => phyClock,
         dataIn(0)  => sp10_100,
         dataIn(1)  => sp100,
         dataOut(0) => sp10_100_sync,
         dataOut(1) => sp100_sync);

   U_1GigE : entity surf.GigEthLvdsUltraScaleWrapper
      generic map (
         TPD_G           => TPD_G,
         USE_BUFG_DIV_G  => USE_BUFG_DIV_G,
         CLKOUT1_PHASE_G => CLKOUT1_PHASE_G,
         AXIS_CONFIG_G   => (others => AXIS_CONFIG_G))
      port map (
         -- Local Configurations
         localMac(0)        => localMac,
         -- Streaming DMA Interface
         dmaClk(0)          => macClk,
         dmaRst(0)          => macRst,
         dmaIbMasters(0)    => obMacMaster,
         dmaIbSlaves(0)     => obMacSlave,
         dmaObMasters(0)    => ibMacMaster,
         dmaObSlaves(0)     => ibMacSlave,
         -- Misc. Signals
         extRst             => extRst,
         phyClk             => phyClock,
         phyRst             => phyReset,
         mmcmLocked         => mmcmLocked,
         phyReady(0)        => phyReady,
         speed_is_10_100(0) => sp10_100_sync,
         speed_is_100(0)    => sp100_sync,
         -- MGT Clock Port
         sgmiiClkP          => phyClkP,
         sgmiiClkN          => phyClkN,
         -- MGT Ports
         sgmiiTxP(0)        => sgmiiTxP,
         sgmiiTxN(0)        => sgmiiTxN,
         sgmiiRxP(0)        => sgmiiRxP,
         sgmiiRxN(0)        => sgmiiRxN);

end mapping;
