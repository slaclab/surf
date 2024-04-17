-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for Marvell 88E1111 PHY + GigEthLvdsUltraScaleWrapper
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

entity Sgmii88E1111LvdsUltraScale is
   generic (
      TPD_G             : time                  := 1 ns;
      STABLE_CLK_FREQ_G : real                  := 156.25E+6;
      PAUSE_EN_G        : boolean               := true;
      EN_AXIL_REG_G     : boolean               := false;
      PHY_G             : natural range 0 to 31 := 7;
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
end entity Sgmii88E1111LvdsUltraScale;

architecture mapping of Sgmii88E1111LvdsUltraScale is

   signal phyClock : sl;
   signal phyReset : sl;

   signal phyInitRst : sl;
   signal phyIrq     : sl;
   signal phyMdi     : sl;
   signal phyMdo     : sl := '1';

   signal extPhyRstN  : sl := '0';
   signal extPhyReady : sl := '0';

   signal sp10_100 : sl := '0';
   signal sp100    : sl := '0';
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
   -- to it (we actually wait also >10ms) which is indicated by 'extPhyReady'
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
         OUT_POLARITY_G => '0',
         DURATION_G     => getTimeRatio(STABLE_CLK_FREQ_G, 100.0))  -- 10 ms reset
      port map (
         arst   => extPhyRstN,
         clk    => stableClk,
         rstOut => extPhyReady);

   ----------------------------------------------------------------------
   -- The MDIO controller which talks to the external PHY must be held
   -- in reset until extPhyReady; it works in a different clock domain...
   ----------------------------------------------------------------------
   U_PhyInitRstSync : entity surf.RstSync
      generic map (
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')
      port map (
         clk      => phyClock,
         asyncRst => extPhyReady,
         syncRst  => phyInitRst);

   -----------------------------------------------------------------------
   -- The SaltCore does not support auto-negotiation on the SGMII link
   -- (mac<->phy) - however, the Marvell PHY (by default) assumes it does.
   -- We need to disable auto-negotiation in the PHY on the SGMII side
   -- and handle link changes (aneg still enabled on copper) flagged
   -- by the PHY...
   -----------------------------------------------------------------------
   U_PhyCtrl : entity surf.Sgmii88E1111Mdio
      generic map (
         TPD_G => TPD_G,
         PHY_G => PHY_G,
         DIV_G => 100)
      port map (
         clk             => phyClock,
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
         clk     => phyClock,
         dataIn  => phyMdio,
         dataOut => phyMdi);

   U_SyncIrq : entity surf.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '0',
         INIT_G         => "11")
      port map (
         clk     => phyClock,
         dataIn  => phyIrqN,
         dataOut => phyIrq);

   U_1GigE : entity surf.GigEthLvdsUltraScale
      generic map (
         TPD_G         => TPD_G,
         PAUSE_EN_G    => PAUSE_EN_G,
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
         extRst          => extRst,
         ethClk          => phyClock,
         ethRst          => phyReset,
         phyReady        => phyReady,
         -- SGMII / LVDS Ports
         sgmiiClkP       => phyClkP,    -- 625 MHz
         sgmiiClkN       => phyClkN,    -- 625 MHz
         sgmiiTxP        => sgmiiTxP,
         sgmiiTxN        => sgmiiTxN,
         sgmiiRxP        => sgmiiRxP,
         sgmiiRxN        => sgmiiRxN);

end mapping;
