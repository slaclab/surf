-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 Core
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
use surf.Pgp3Pkg.all;

entity Pgp3Core is

   generic (
      TPD_G                       : time                  := 1 ns;
      NUM_VC_G                    : integer range 1 to 16 := 4;
      PGP_RX_ENABLE_G             : boolean               := true;
      RX_ALIGN_SLIP_WAIT_G        : integer               := 32;
      PGP_TX_ENABLE_G             : boolean               := true;
      TX_CELL_WORDS_MAX_G         : integer               := PGP3_DEFAULT_TX_CELL_WORDS_MAX_C;  -- Number of 64-bit words per cell
      TX_MUX_MODE_G               : string                := "INDEXED";  -- Or "ROUTED"
      TX_MUX_TDEST_ROUTES_G       : Slv8Array             := (0 => "--------");  -- Only used in ROUTED mode
      TX_MUX_TDEST_LOW_G          : integer range 0 to 7  := 0;
      TX_MUX_ILEAVE_EN_G          : boolean               := true;
      TX_MUX_ILEAVE_ON_NOTVALID_G : boolean               := true;
      EN_PGP_MON_G                : boolean               := true;
      STATUS_CNT_WIDTH_G          : natural range 1 to 32 := 16;
      ERROR_CNT_WIDTH_G           : natural range 1 to 32 := 8;
      AXIL_CLK_FREQ_G             : real                  := 125.0E+6);
   port (
      -- Tx User interface
      pgpTxClk     : in  sl;
      pgpTxRst     : in  sl;
      pgpTxIn      : in  Pgp3TxInType := PGP3_TX_IN_INIT_C;
      pgpTxOut     : out Pgp3TxOutType;
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);

      -- Tx PHY interface
      phyTxActive   : in  sl;
      phyTxReady    : in  sl;
      phyTxValid    : out sl;
      phyTxStart    : out sl;
      phyTxData     : out slv(63 downto 0);
      phyTxHeader   : out slv(1 downto 0);

      -- Rx User interface
      pgpRxClk     : in  sl;
      pgpRxRst     : in  sl;
      pgpRxIn      : in  Pgp3RxInType := PGP3_RX_IN_INIT_C;
      pgpRxOut     : out Pgp3RxOutType;
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl    : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

      -- Rx PHY interface
      phyRxClk      : in  sl;
      phyRxRst      : in  sl;
      phyRxInit     : out sl;
      phyRxActive   : in  sl;
      phyRxValid    : in  sl;
      phyRxHeader   : in  slv(1 downto 0);
      phyRxData     : in  slv(63 downto 0);
      phyRxStartSeq : in  sl;
      phyRxSlip     : out sl;

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
end entity Pgp3Core;

architecture rtl of Pgp3Core is

   signal locRxLinkReady : sl;
   signal remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
   signal remRxLinkReady : sl;

   signal pgpTxInInt  : Pgp3TxInType;
   signal pgpTxOutInt : Pgp3TxOutType;
   signal pgpRxInInt  : Pgp3RxInType;
   signal pgpRxOutInt : Pgp3RxOutType;

begin

   pgpRxOut <= pgpRxOutInt;
   pgpTxOut <= pgpTxOutInt;

   U_Pgp3Tx_1 : entity surf.Pgp3Tx
      generic map (
         TPD_G                    => TPD_G,
         NUM_VC_G                 => NUM_VC_G,
         CELL_WORDS_MAX_G         => TX_CELL_WORDS_MAX_G,
         MUX_MODE_G               => TX_MUX_MODE_G,
         MUX_TDEST_ROUTES_G       => TX_MUX_TDEST_ROUTES_G,
         MUX_TDEST_LOW_G          => TX_MUX_TDEST_LOW_G,
         MUX_ILEAVE_EN_G          => TX_MUX_ILEAVE_EN_G,
         MUX_ILEAVE_ON_NOTVALID_G => TX_MUX_ILEAVE_ON_NOTVALID_G)
      port map (
         pgpTxClk       => pgpTxClk,        -- [in]
         pgpTxRst       => pgpTxRst,        -- [in]
         pgpTxIn        => pgpTxInInt,      -- [in]
         pgpTxOut       => pgpTxOutInt,     -- [out]
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

   U_Pgp3Rx_1 : entity surf.Pgp3Rx
      generic map (
         TPD_G              => TPD_G,
         NUM_VC_G           => NUM_VC_G,
         ALIGN_SLIP_WAIT_G  => RX_ALIGN_SLIP_WAIT_G)
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

   GEN_PGP_MON : if (EN_PGP_MON_G) generate
      U_Pgp3Axi_1 : entity surf.Pgp3AxiL
         generic map (
            TPD_G              => TPD_G,
            COMMON_TX_CLK_G    => false,
            COMMON_RX_CLK_G    => false,
            WRITE_EN_G         => true,
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
            statusWord      => open,             -- [out]
            statusSend      => open,             -- [out]
            phyRxClk        => phyRxClk,         -- [in]
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

end architecture rtl;
