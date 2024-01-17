-------------------------------------------------------------------------------
-- Title      : PGPv2b: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv2b GTY Ultrascale Core Module
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
use surf.Pgp2fcPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp2fcGtyUltra is
   generic (
      TPD_G             : time                 := 1 ns;
      SIMULATION_G      : boolean              := false;
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      FC_WORDS_G        : integer range 1 to 8 := 1;
      TX_POLARITY_G     : sl                   := '0';
      RX_POLARITY_G     : sl                   := '0';
      AXI_CLK_FREQ_G    : real                 := 125.0e6;
      AXI_BASE_ADDR_G   : slv(31 downto 0)     := (others => '0');
      TX_ENABLE_G       : boolean              := true;
      RX_ENABLE_G       : boolean              := true;
      PAYLOAD_CNT_TOP_G : integer              := 7;  -- Top bit for payload counter
      VC_INTERLEAVE_G   : integer              := 0;  -- Interleave Frames
      NUM_VC_EN_G       : integer range 1 to 4 := 4);
   port (
      -- GT Clocking
      stableClk        : in  sl;                      -- GT needs a stable clock to "boot up"
      stableRst        : in  sl;
      gtRefClk         : in  sl;
      gtFabricRefClk   : in  sl;
      gtUserRefClk     : in  sl;
      rxRecClk         : out sl;
      -- Gt Serial IO
      pgpGtTxP         : out sl;
      pgpGtTxN         : out sl;
      pgpGtRxP         : in  sl;
      pgpGtRxN         : in  sl;
      -- Tx Clocking
      pgpTxReset       : in  sl;
      pgpTxResetDone   : out sl;
      pgpTxOutClk      : out sl;                      -- recovered clock
      pgpTxClk         : in  sl;
      pgpTxMmcmLocked  : in  sl;
      -- Rx clocking
      pgpRxReset       : in  sl;
      pgpRxResetDone   : out sl;
      pgpRxOutClk      : out sl;                      -- recovered clock
      pgpRxClk         : in  sl;
      pgpRxMmcmLocked  : in  sl;
      -- Non VC Rx Signals
      pgpRxIn          : in  Pgp2fcRxInType;
      pgpRxOut         : out Pgp2fcRxOutType;
      -- Non VC Tx Signals
      pgpTxIn          : in  Pgp2fcTxInType;
      pgpTxOut         : out Pgp2fcTxOutType;
      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpTxMasters     : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpRxMasters     : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : out AxiStreamMasterType;
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0);
      -- AXI-Lite DRP interface
      axilClk          : in  sl                               := '0';
      axilRst          : in  sl                               := '0';
      axilReadMaster   : in  AxiLiteReadMasterType            := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType           := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave   : out AxiLiteWriteSlaveType);
end Pgp2fcGtyUltra;

architecture mapping of Pgp2fcGtyUltra is

   signal resetGtSync : sl;
   signal gtHardReset : sl;

   -- PgpRx Signals
   signal resetRxSync   : sl;
   signal gtRxUserReset : sl;
   signal phyRxLaneIn   : Pgp2fcRxPhyLaneInType;
   signal phyRxReady    : sl;
   signal phyRxInit     : sl;

   -- PgpTx Signals
   signal gtTxUserReset : sl;
   signal phyTxLaneOut  : Pgp2fcTxPhyLaneOutType;
   signal phyTxReady    : sl;

   signal phyRxInitSync : sl;

begin

   pgpTxResetDone <= phyTxReady;
   pgpRxResetDone <= phyRxReady;

   U_RstSync_1 : entity surf.PwrUpRst
      generic map (
         TPD_G      => TPD_G,
         DURATION_G => ite(SIMULATION_G, 12500, 125000000)) -- 100us in sim; 1s in silicon
      port map (
         arst   => pgpTxIn.resetGt,     -- [in]
         clk    => stableClk,           -- [in]
         rstOut => resetGtSync);        -- [out]

   gtHardReset <= resetGtSync or stableRst;

   U_RstSync_4 : entity surf.SynchronizerOneShot
      generic map (
         TPD_G         => TPD_G,
         PULSE_WIDTH_G => ite(SIMULATION_G, 12500, 125000000)) -- 100us in sim; 1s in silicon
      port map (
         clk     => stableClk,          -- [in]
         dataIn  => phyRxInit,          -- [in]
         dataOut => phyRxInitSync);     -- [out]

   -- Sync pgpRxIn.rxReset to stableClk and tie to gtRxUserReset
   U_RstSync_2 : entity surf.PwrUpRst
      generic map (
         TPD_G      => TPD_G,
         DURATION_G => ite(SIMULATION_G, 12500, 125000000)) -- 100us in sim; 1s in silicon
      port map (
         arst   => pgpRxIn.resetRx,     -- [in]
         clk    => stableClk,           -- [in]
         rstOut => resetRxSync);        -- [out]

   gtRxUserReset <= phyRxInitSync or resetRxSync;

   U_RstSync_3 : entity surf.PwrUpRst
      generic map (
         TPD_G      => TPD_G,
         DURATION_G => ite(SIMULATION_G, 12500, 125000000)) -- 100us in sim; 1s in silicon
      port map (
         arst   => pgpTxIn.resetTx,     -- [in]
         clk    => stableClk,           -- [in]
         rstOut => gtTxUserReset);      -- [out]

   U_Pgp2fcLane : entity surf.Pgp2fcLane
      generic map (
         FC_WORDS_G        => FC_WORDS_G,
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G       => NUM_VC_EN_G,
         TX_ENABLE_G       => TX_ENABLE_G,
         RX_ENABLE_G       => RX_ENABLE_G)
      port map (
         pgpTxClk         => pgpTxClk,
         pgpTxClkRst      => pgpTxReset,
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         phyTxLaneOut     => phyTxLaneOut,
         phyTxReady       => phyTxReady,
         pgpRxClk         => pgpRxClk,
         pgpRxClkRst      => pgpRxReset,
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => pgpRxMasterMuxed,
         pgpRxCtrl        => pgpRxCtrl,
         phyRxLaneIn      => phyRxLaneIn,
         phyRxReady       => phyRxReady,
         phyRxInit        => phyRxInit);

   --------------------------
   -- Wrapper for GTY IP core
   --------------------------
   PgpGtyCoreWrapper_1 : entity surf.Pgp2fcGtyCoreWrapper
      generic map (
         TPD_G           => TPD_G,
         AXI_CLK_FREQ_G  => AXI_CLK_FREQ_G,
         AXI_BASE_ADDR_G => AXI_BASE_ADDR_G)
      port map (
         stableClk       => stableClk,
         stableRst       => gtHardReset,
         gtRefClk        => gtRefClk,
         gtFabricRefClk  => gtFabricRefClk,
         gtUserRefClk    => gtUserRefClk,
         gtRxP           => pgpGtRxP,
         gtRxN           => pgpGtRxN,
         gtTxP           => pgpGtTxP,
         gtTxN           => pgpGtTxN,
         rxReset         => gtRxUserReset,
         rxUsrClkActive  => pgpRxMmcmLocked,
         rxResetDone     => phyRxReady,
         rxUsrClk        => pgpRxClk,
         rxData          => phyRxLaneIn.data,
         rxDataK         => phyRxLaneIn.dataK,
         rxDispErr       => phyRxLaneIn.dispErr,
         rxDecErr        => phyRxLaneIn.decErr,
         rxPolarity      => RX_POLARITY_G,
         rxOutClk        => pgpRxOutClk,
         rxRecClk        => rxRecClk,
         txReset         => gtTxUserReset,
         txUsrClk        => pgpTxClk,
         txUsrClkActive  => pgpTxMmcmLocked,
         txResetDone     => phyTxReady,
         txData          => phyTxLaneOut.data,
         txDataK         => phyTxLaneOut.dataK,
         txPolarity      => TX_POLARITY_G,
         txOutClk        => pgpTxOutClk,
         loopback        => pgpRxIn.loopback,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end mapping;
