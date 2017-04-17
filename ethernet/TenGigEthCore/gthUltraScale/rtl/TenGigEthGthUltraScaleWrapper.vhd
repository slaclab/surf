-------------------------------------------------------------------------------
-- File       : TenGigEthGthUltraScaleWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2016-09-29
-------------------------------------------------------------------------------
-- Description: GTH Ultra Scale Wrapper for 10GBASE-R Ethernet
-- Note: This module supports up to a MGT QUAD of 10GigE interfaces
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.TenGigEthPkg.all;

entity TenGigEthGthUltraScaleWrapper is
   generic (
      TPD_G             : time                             := 1 ns;
      REF_CLK_FREQ_G    : real                             := 156.25E+6;  -- Support 156.25MHz or 312.5MHz            
      NUM_LANE_G        : natural range 1 to 4             := 1;
      -- QUAD PLL Configurations
      QPLL_REFCLK_SEL_G : slv(2 downto 0)                  := "001";
      -- AXI-Lite Configurations
      EN_AXI_REG_G      : boolean                          := false;
      AXI_ERROR_RESP_G  : slv(1 downto 0)                  := AXI_RESP_SLVERR_C;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G     : AxiStreamConfigArray(3 downto 0) := (others => AXI_STREAM_CONFIG_INIT_C));
   port (
      -- Local Configurations
      localMac            : in  Slv48Array(NUM_LANE_G-1 downto 0)              := (others => MAC_ADDR_INIT_C);
      -- Streaming DMA Interface 
      dmaClk              : in  slv(NUM_LANE_G-1 downto 0);
      dmaRst              : in  slv(NUM_LANE_G-1 downto 0);
      dmaIbMasters        : out AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      dmaIbSlaves         : in  AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
      dmaObMasters        : in  AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      dmaObSlaves         : out AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
      -- Slave AXI-Lite Interface 
      axiLiteClk          : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      axiLiteRst          : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      axiLiteReadMasters  : in  AxiLiteReadMasterArray(NUM_LANE_G-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
      axiLiteReadSlaves   : out AxiLiteReadSlaveArray(NUM_LANE_G-1 downto 0);
      axiLiteWriteMasters : in  AxiLiteWriteMasterArray(NUM_LANE_G-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
      axiLiteWriteSlaves  : out AxiLiteWriteSlaveArray(NUM_LANE_G-1 downto 0);
      -- SFP+ Ports
      sigDet              : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '1');
      txFault             : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      txDisable           : out slv(NUM_LANE_G-1 downto 0);
      -- Misc. Signals
      extRst              : in  sl;
      coreClk             : out sl;
      coreRst             : out sl;
      phyClk              : out slv(NUM_LANE_G-1 downto 0);
      phyRst              : out slv(NUM_LANE_G-1 downto 0);
      phyReady            : out slv(NUM_LANE_G-1 downto 0);
      gtClk               : out sl;
      -- Transceiver Debug Interface
      gtTxPreCursor       : in  slv(4 downto 0)                                := "00000";
      gtTxPostCursor      : in  slv(4 downto 0)                                := "00000";
      gtTxDiffCtrl        : in  slv(3 downto 0)                                := "1110";
      gtRxPolarity        : in  sl                                             := '0';
      gtTxPolarity        : in  sl                                             := '0';
      -- MGT Clock Port (156.25 MHz or 312.5 MHz)
      gtRefClk            : in  sl                                             := '0';
      gtClkP              : in  sl                                             := '1';
      gtClkN              : in  sl                                             := '0';
      -- MGT Ports
      gtTxP               : out slv(NUM_LANE_G-1 downto 0);
      gtTxN               : out slv(NUM_LANE_G-1 downto 0);
      gtRxP               : in  slv(NUM_LANE_G-1 downto 0);
      gtRxN               : in  slv(NUM_LANE_G-1 downto 0));  
end TenGigEthGthUltraScaleWrapper;

architecture mapping of TenGigEthGthUltraScaleWrapper is

   signal qplllock      : sl;
   signal qplloutclk    : sl;
   signal qplloutrefclk : sl;

   signal qpllRst   : slv(NUM_LANE_G-1 downto 0);
   signal qpllReset : sl;

   signal coreClock : sl;
   signal coreReset : sl;

begin

   coreClk <= coreClock;
   coreRst <= coreReset;

   -----------------
   -- Power Up Reset
   -----------------
   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         TPD_G      => TPD_G,
         DURATION_G => 15625000)        -- 100 ms
      port map (
         arst   => extRst,
         clk    => coreClock,
         rstOut => coreReset);   

   ----------------------
   -- Common Clock Module 
   ----------------------
   TenGigEthGthUltraScaleClk_Inst : entity work.TenGigEthGthUltraScaleClk
      generic map (
         TPD_G             => TPD_G,
         REF_CLK_FREQ_G    => REF_CLK_FREQ_G,
         QPLL_REFCLK_SEL_G => QPLL_REFCLK_SEL_G)         
      port map (
         -- MGT Clock Port (156.25 MHz or 312.5 MHz)
         gtRefClk      => gtRefClk,
         gtClkP        => gtClkP,
         gtClkN        => gtClkN,
         coreClk       => coreClock,
         coreRst       => coreReset,
         gtClk         => gtClk,
         -- Quad PLL Ports
         qplllock      => qplllock,
         qplloutclk    => qplloutclk,
         qplloutrefclk => qplloutrefclk,
         qpllRst       => qpllReset);            

   qpllReset <= uOr(qpllRst) and not(qPllLock);

   ----------------
   -- 10GigE Module 
   ----------------
   GEN_LANE :
   for i in 0 to NUM_LANE_G-1 generate
      
      TenGigEthGthUltraScale_Inst : entity work.TenGigEthGthUltraScale
         generic map (
            TPD_G            => TPD_G,
            REF_CLK_FREQ_G   => REF_CLK_FREQ_G,
            -- AXI-Lite Configurations
            EN_AXI_REG_G     => EN_AXI_REG_G,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
            -- AXI Streaming Configurations
            AXIS_CONFIG_G    => AXIS_CONFIG_G(i))       
         port map (
            -- Local Configurations
            localMac           => localMac(i),
            -- Streaming DMA Interface 
            dmaClk             => dmaClk(i),
            dmaRst             => dmaRst(i),
            dmaIbMaster        => dmaIbMasters(i),
            dmaIbSlave         => dmaIbSlaves(i),
            dmaObMaster        => dmaObMasters(i),
            dmaObSlave         => dmaObSlaves(i),
            -- Slave AXI-Lite Interface 
            axiLiteClk         => axiLiteClk(i),
            axiLiteRst         => axiLiteRst(i),
            axiLiteReadMaster  => axiLiteReadMasters(i),
            axiLiteReadSlave   => axiLiteReadSlaves(i),
            axiLiteWriteMaster => axiLiteWriteMasters(i),
            axiLiteWriteSlave  => axiLiteWriteSlaves(i),
            -- SFP+ Ports
            sigDet             => sigDet(i),
            txFault            => txFault(i),
            txDisable          => txDisable(i),
            -- Misc. Signals
            extRst             => coreReset,
            coreClk            => coreClock,
            phyClk             => phyClk(i),
            phyRst             => phyRst(i),
            phyReady           => phyReady(i),
            -- Transceiver Debug Interface
            gtTxPreCursor      => gtTxPreCursor,
            gtTxPostCursor     => gtTxPostCursor,
            gtTxDiffCtrl       => gtTxDiffCtrl,
            gtRxPolarity       => gtRxPolarity,
            gtTxPolarity       => gtTxPolarity,
            -- Quad PLL Ports
            qplllock           => qplllock,
            qplloutclk         => qplloutclk,
            qplloutrefclk      => qplloutrefclk,
            -- MGT Ports
            gtTxP              => gtTxP(i),
            gtTxN              => gtTxN(i),
            gtRxP              => gtRxP(i),
            gtRxN              => gtRxN(i));  

   end generate GEN_LANE;

end mapping;
