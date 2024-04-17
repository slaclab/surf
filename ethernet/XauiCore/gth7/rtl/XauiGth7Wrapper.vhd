-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Gth7 Wrapper for 10 GigE XAUI
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

entity XauiGth7Wrapper is
   generic (
      TPD_G           : time                := 1 ns;
      JUMBO_G         : boolean             := true;
      PAUSE_EN_G      : boolean             := true;
      -- QUAD PLL Configurations
      USE_GTREFCLK_G  : boolean             := false;  --  FALSE: gtClkP/N,  TRUE: gtRefClk
      REFCLK_DIV2_G   : boolean             := false;  --  FALSE: gtClkP/N = 156.25 MHz,  TRUE: gtClkP/N = 312.5 MHz
      -- AXI-Lite Configurations
      EN_AXI_REG_G    : boolean             := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G   : AxiStreamConfigType := EMAC_AXIS_CONFIG_C);
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
      phyClk             : out sl;
      phyRst             : out sl;
      phyReady           : out sl;
      -- MGT Clock Port (156.25 MHz or 312.5 MHz)
      gtRefClk           : in  sl                     := '0';  -- 156.25 MHz only
      gtClkP             : in  sl                     := '1';
      gtClkN             : in  sl                     := '0';
      -- MGT Ports
      gtTxP              : out slv(3 downto 0);
      gtTxN              : out slv(3 downto 0);
      gtRxP              : in  slv(3 downto 0);
      gtRxN              : in  slv(3 downto 0));
end XauiGth7Wrapper;

architecture mapping of XauiGth7Wrapper is

   signal phyClock     : sl;
   signal refClockDiv2 : sl;
   signal refClock     : sl;
   signal refClk       : sl;

begin

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => refClockDiv2,
         O     => refClock);

   refClk <= gtRefClk when (USE_GTREFCLK_G) else refClockDiv2 when(REFCLK_DIV2_G) else refClock;

   ----------------------
   -- 10 GigE XAUI Module
   ----------------------
   XauiGth7_Inst : entity surf.XauiGth7
      generic map (
         TPD_G           => TPD_G,
         JUMBO_G         => JUMBO_G,
         PAUSE_EN_G      => PAUSE_EN_G,
         -- AXI-Lite Configurations
         EN_AXI_REG_G    => EN_AXI_REG_G,
         -- AXI Streaming Configurations
         AXIS_CONFIG_G   => AXIS_CONFIG_G)
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
         extRst             => extRst,
         phyClk             => phyClk,
         phyRst             => phyRst,
         phyReady           => phyReady,
         -- MGT Ports
         gtRefClk           => refClk,
         gtTxP              => gtTxP,
         gtTxN              => gtTxN,
         gtRxP              => gtRxP,
         gtRxN              => gtRxN);

end mapping;
