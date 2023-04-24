-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv4 Core "Lite"
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
use surf.Pgp4Pkg.all;

entity Pgp4CoreLite is
   generic (
      TPD_G                : time                  := 1 ns;
      RST_ASYNC_G          : boolean               := false;
      NUM_VC_G             : integer range 1 to 16 := 4;
      PGP_RX_ENABLE_G      : boolean               := true;
      PGP_TX_ENABLE_G      : boolean               := true;
      RX_ALIGN_SLIP_WAIT_G : integer               := 32;
      SKIP_EN_G            : boolean               := false;  -- FALSE: No skips (assumes clock source synchronous system)
      FLOW_CTRL_EN_G       : boolean               := true;
      EN_PGP_MON_G         : boolean               := false;
      WRITE_EN_G           : boolean               := false;  -- Set to false when on remote end of a link
      STATUS_CNT_WIDTH_G   : natural range 1 to 32 := 16;
      ERROR_CNT_WIDTH_G    : natural range 1 to 32 := 8;
      AXIL_CLK_FREQ_G      : real                  := 125.0E+6);
   port (
      -- Tx User interface
      pgpTxClk     : in  sl;
      pgpTxRst     : in  sl;
      pgpTxActive  : in  sl                                       := '1';
      pgpTxIn      : in  Pgp4TxInType                             := PGP4_TX_IN_INIT_C;
      pgpTxOut     : out Pgp4TxOutType;
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_SLAVE_FORCE_C);

      -- Tx PHY interface
      phyTxActive : in  sl               := '0';
      phyTxReady  : in  sl;
      phyTxValid  : out sl               := '0';
      phyTxStart  : out sl               := '0';
      phyTxData   : out slv(63 downto 0) := (others => '0');
      phyTxHeader : out slv(1 downto 0)  := (others => '0');

      -- Rx User interface
      pgpRxClk     : in  sl;
      pgpRxRst     : in  sl;
      pgpRxIn      : in  Pgp4RxInType                              := PGP4_RX_IN_INIT_C;
      pgpRxOut     : out Pgp4RxOutType;
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpRxCtrl    : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

      -- Rx PHY interface
      phyRxClk      : in  sl;
      phyRxRst      : in  sl;
      phyRxInit     : out sl := '0';
      phyRxActive   : in  sl;
      phyRxValid    : in  sl;
      phyRxHeader   : in  slv(1 downto 0);
      phyRxData     : in  slv(63 downto 0);
      phyRxStartSeq : in  sl;
      phyRxSlip     : out sl := '0';

      -- Debug Interface
      loopback     : out slv(2 downto 0);
      txDiffCtrl   : out slv(4 downto 0);
      txPreCursor  : out slv(4 downto 0);
      txPostCursor : out slv(4 downto 0);

      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end entity Pgp4CoreLite;

architecture rtl of Pgp4CoreLite is

   signal locRxLinkReady : sl                                      := '0';
   signal remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);
   signal remRxLinkReady : sl                                      := '0';

   signal pgpTxInInt  : Pgp4TxInType  := PGP4_TX_IN_INIT_C;
   signal pgpTxOutInt : Pgp4TxOutType := PGP4_TX_OUT_INIT_C;
   signal pgpRxInInt  : Pgp4RxInType  := PGP4_RX_IN_INIT_C;
   signal pgpRxOutInt : Pgp4RxOutType := PGP4_RX_OUT_INIT_C;

begin

   pgpRxOut <= pgpRxOutInt;
   pgpTxOut <= pgpTxOutInt;

   GEN_TX : if (PGP_TX_ENABLE_G) generate
      U_Pgp4Tx_1 : entity surf.Pgp4TxLite
         generic map (
            TPD_G          => TPD_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            NUM_VC_G       => NUM_VC_G,
            SKIP_EN_G      => SKIP_EN_G,
            FLOW_CTRL_EN_G => FLOW_CTRL_EN_G)
         port map (
            pgpTxClk       => pgpTxClk,        -- [in]
            pgpTxRst       => pgpTxRst,        -- [in]
            pgpTxIn        => pgpTxInInt,      -- [in]
            pgpTxOut       => pgpTxOutInt,     -- [out]
            pgpTxActive    => pgpTxActive,     -- [in]
            pgpTxMasters   => pgpTxMasters,    -- [in]
            pgpTxSlaves    => pgpTxSlaves,     -- [out]
            locRxFifoCtrl  => pgpRxCtrl,       -- [in]
            locRxLinkReady => locRxLinkReady,  -- [in]
            remRxFifoCtrl  => remRxFifoCtrl,   -- [in]
            remRxLinkReady => remRxLinkReady,  -- [in]
            phyTxActive    => phyTxActive,     --[in]
            phyTxReady     => phyTxReady,      -- [in]
            phyTxValid     => phyTxValid,      -- [out]
            phyTxStart     => phyTxStart,      -- [out]
            phyTxData      => phyTxData,       -- [out]
            phyTxHeader    => phyTxHeader);    -- [out]
   end generate GEN_TX;

   GEN_RX : if (PGP_RX_ENABLE_G) generate
      U_Pgp4Rx_1 : entity surf.Pgp4Rx
         generic map (
            TPD_G             => TPD_G,
            RST_ASYNC_G       => RST_ASYNC_G,
            NUM_VC_G          => NUM_VC_G,
            SKIP_EN_G         => SKIP_EN_G,
            LITE_EN_G         => true, -- TRUE = Pgp4RxLite
            ALIGN_SLIP_WAIT_G => RX_ALIGN_SLIP_WAIT_G)
         port map (
            pgpRxClk       => pgpRxClk,        -- [in]
            pgpRxRst       => pgpRxRst,        -- [in]
            pgpRxIn        => pgpRxInInt,      -- [in]
            pgpRxOut       => pgpRxOutInt,     -- [out]
            pgpRxMasters   => pgpRxMasters,    -- [out]
            pgpRxCtrl      => pgpRxCtrl,       -- [in]
            remRxFifoCtrl  => remRxFifoCtrl,   -- [out]
            remRxLinkReady => remRxLinkReady,  -- [out]
            locRxLinkReady => locRxLinkReady,  -- [out]
            phyRxClk       => phyRxClk,        -- [in]
            phyRxRst       => phyRxRst,        -- [in]
            phyRxInit      => phyRxInit,       -- [out]
            phyRxActive    => phyRxActive,     -- [in]
            phyRxValid     => phyRxValid,      -- [in]
            phyRxHeader    => phyRxHeader,     -- [in]
            phyRxData      => phyRxData,       -- [in]
            phyRxStartSeq  => phyRxStartSeq,   -- [in]
            phyRxSlip      => phyRxSlip);      -- [out]
   end generate GEN_RX;

   GEN_PGP_MON : if (EN_PGP_MON_G) generate
      U_Pgp4AxiL : entity surf.Pgp4AxiL
         generic map (
            TPD_G              => TPD_G,
            RST_ASYNC_G        => RST_ASYNC_G,
            COMMON_TX_CLK_G    => false,
            COMMON_RX_CLK_G    => false,
            WRITE_EN_G         => WRITE_EN_G,
            NUM_VC_G           => NUM_VC_G,
            STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
            ERROR_CNT_WIDTH_G  => ERROR_CNT_WIDTH_G,
            AXIL_CLK_FREQ_G    => AXIL_CLK_FREQ_G)
         port map (
            pgpTxClk        => pgpTxClk,         -- [in]
            pgpTxRst        => pgpTxRst,         -- [in]
            pgpTxIn         => pgpTxInInt,       -- [out]
            pgpTxOut        => pgpTxOutInt,      -- [in]
            locTxIn         => pgpTxIn,          -- [in]
            pgpRxClk        => pgpRxClk,         -- [in]
            pgpRxRst        => pgpRxRst,         -- [in]
            pgpRxIn         => pgpRxInInt,       -- [out]
            pgpRxOut        => pgpRxOutInt,      -- [in]
            locRxIn         => pgpRxIn,          -- [in]
            txDiffCtrl      => txDiffCtrl,       -- [out]
            txPreCursor     => txPreCursor,      -- [out]
            txPostCursor    => txPostCursor,     -- [out]
            axilClk         => axilClk,          -- [in]
            axilRst         => axilRst,          -- [in]
            axilReadMaster  => axilReadMaster,   -- [in]
            axilReadSlave   => axilReadSlave,    -- [out]
            axilWriteMaster => axilWriteMaster,  -- [in]
            axilWriteSlave  => axilWriteSlave);  -- [out]
   end generate GEN_PGP_MON;

   NO_PGP_MON : if (not EN_PGP_MON_G) generate
      pgpTxInInt   <= pgpTxIn;
      pgpRxInInt   <= pgpRxIn;
      txDiffCtrl   <= (others => '1');
      txPreCursor  <= "00111";
      txPostCursor <= "00111";
   end generate NO_PGP_MON;

   loopback <= pgpRxInInt.loopback;

end rtl;
