-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: GTH Ultra Scale Wrapper for 10 GigE XAUI
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.EthMacPkg.all;
use surf.XauiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XauiGthUltraScaleWrapper is
   generic (
      TPD_G             : time                := 1 ns;
      JUMBO_G           : boolean             := true;
      PAUSE_EN_G        : boolean             := true;
      EN_WDT_G          : boolean             := false;
      EXT_REF_G         : boolean             := false;
      STABLE_CLK_FREQ_G : real                := 156.25E+6;  -- Support 156.25MHz or 312.5MHz
      -- AXI-Lite Configurations
      EN_AXI_REG_G      : boolean             := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G     : AxiStreamConfigType := EMAC_AXIS_CONFIG_C);
   port (
      -- Local Configurations
      localMac           : in  slv(47 downto 0)       := MAC_ADDR_INIT_C;
      -- Streaming DMA Interface
      dmaClk             : in  sl;
      dmaRst             : in  sl;
      dmaIbMaster        : out AxiStreamMasterType;
      dmaIbSlave         : in  AxiStreamSlaveType;
      dmaObMaster        : in  AxiStreamMasterType;
      dmaObSlave         : out AxiStreamSlaveType;
      -- Slave AXI-Lite Interface
      axiLiteClk         : in  sl                     := '0';
      axiLiteRst         : in  sl                     := '0';
      axiLiteReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiLiteReadSlave   : out AxiLiteReadSlaveType;
      axiLiteWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiLiteWriteSlave  : out AxiLiteWriteSlaveType;
      -- Misc. Signals
      extRst             : in  sl                     := '0';
      stableClk          : in  sl                     := '0';
      phyClk             : out sl;
      phyRst             : out sl;
      phyReady           : out sl;
      -- Transceiver Debug Interface
      gtTxPreCursor      : in  slv(19 downto 0)       := (others => '0');
      gtTxPostCursor     : in  slv(19 downto 0)       := (others => '0');
      gtTxDiffCtrl       : in  slv(15 downto 0)       := x"CCCC";
      gtRxPolarity       : in  slv(3 downto 0)        := x"0";
      gtTxPolarity       : in  slv(3 downto 0)        := x"0";
      -- MGT Clock Port (156.25MHz or 312.5MHz)
      gtRefClk           : in  sl                     := '0';
      gtClkP             : in  sl                     := '0';
      gtClkN             : in  sl                     := '1';
      -- MGT Ports
      gtTxP              : out slv(3 downto 0);
      gtTxN              : out slv(3 downto 0);
      gtRxP              : in  slv(3 downto 0);
      gtRxN              : in  slv(3 downto 0));
end XauiGthUltraScaleWrapper;

architecture mapping of XauiGthUltraScaleWrapper is

   signal refClk   : sl;
   signal refClock : sl;
   signal linkUp   : sl;
   signal wdtRst   : sl;
   signal wdtReset : sl;
   signal extReset : sl;

begin

   phyReady <= linkUp;

   IBUFDS_GTE3_Inst : IBUFDS_GTE3
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => open,
         O     => refClk);

   refClock <= gtRefClk when(EXT_REF_G) else refClk;

   GEN_WDT : if (EN_WDT_G = true) generate

      -----------------------
      -- 10 Second LinkUp WDT
      -----------------------
      U_Rst : entity surf.PwrUpRst
         generic map(
            TPD_G      => TPD_G,
            DURATION_G => getTimeRatio(STABLE_CLK_FREQ_G, 1.0))  -- 1 s reset
         port map (
            arst   => wdtReset,
            clk    => stableClk,
            rstOut => extReset);

      U_WTD : entity surf.WatchDogRst
         generic map(
            TPD_G      => TPD_G,
            DURATION_G => getTimeRatio(STABLE_CLK_FREQ_G, 0.1))  -- 10 s timeout
         port map (
            clk    => stableClk,
            monIn  => linkUp,
            rstOut => wdtRst);

      wdtReset <= wdtRst or extRst;

   end generate;

   BYPASS_WDT : if (EN_WDT_G = false) generate

      extReset <= extRst;

   end generate;

   ----------------------
   -- 10 GigE XAUI Module
   ----------------------
   XauiGthUltraScale_Inst : entity surf.XauiGthUltraScale
      generic map (
         TPD_G         => TPD_G,
         JUMBO_G       => JUMBO_G,
         PAUSE_EN_G    => PAUSE_EN_G,
         -- AXI-Lite Configurations
         EN_AXI_REG_G  => EN_AXI_REG_G,
         -- AXI Streaming Configurations
         AXIS_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Local Configurations
         localMac           => localMac,
         -- Clocks and resets
         dmaClk             => dmaClk,
         dmaRst             => dmaRst,
         dmaIbMaster        => dmaIbMaster,
         dmaIbSlave         => dmaIbSlave,
         dmaObMaster        => dmaObMaster,
         dmaObSlave         => dmaObSlave,
         -- Slave AXI-Lite Interface
         axiLiteClk         => axiLiteClk,
         axiLiteRst         => axiLiteRst,
         axiLiteReadMaster  => axiLiteReadMaster,
         axiLiteReadSlave   => axiLiteReadSlave,
         axiLiteWriteMaster => axiLiteWriteMaster,
         axiLiteWriteSlave  => axiLiteWriteSlave,
         -- Misc. Signals
         extRst             => extReset,
         phyClk             => phyClk,
         phyRst             => phyRst,
         phyReady           => linkUp,
         -- Transceiver Debug Interface
         gtTxPreCursor      => gtTxPreCursor,
         gtTxPostCursor     => gtTxPostCursor,
         gtTxDiffCtrl       => gtTxDiffCtrl,
         gtRxPolarity       => gtRxPolarity,
         gtTxPolarity       => gtTxPolarity,
         -- MGT Ports
         refClk             => refClock,
         gtTxP              => gtTxP,
         gtTxN              => gtTxN,
         gtRxP              => gtRxP,
         gtRxN              => gtRxN);

end mapping;
