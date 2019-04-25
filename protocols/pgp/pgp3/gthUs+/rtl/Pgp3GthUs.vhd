-------------------------------------------------------------------------------
-- File       : Pgp3GthUs.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.Pgp3Pkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp3GthUs is
   generic (
      TPD_G                       : time                  := 1 ns;
      RATE_G                      : string                := "10.3125Gbps";  -- or "6.25Gbps" or "3.125Gbps"     
      SYNTH_MODE_G                : string                := "inferred";
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PGP_RX_ENABLE_G             : boolean               := true;
      RX_ALIGN_SLIP_WAIT_G        : integer               := 32;
      PGP_TX_ENABLE_G             : boolean               := true;
      NUM_VC_G                    : integer range 1 to 16 := 4;
      TX_CELL_WORDS_MAX_G         : integer               := PGP3_DEFAULT_TX_CELL_WORDS_MAX_C;  -- Number of 64-bit words per cell
      TX_MUX_MODE_G               : string                := "INDEXED";  -- Or "ROUTED"
      TX_MUX_TDEST_ROUTES_G       : Slv8Array             := (0      => "--------");  -- Only used in ROUTED mode
      TX_MUX_TDEST_LOW_G          : integer range 0 to 7  := 0;
      TX_MUX_ILEAVE_EN_G          : boolean               := true;
      TX_MUX_ILEAVE_ON_NOTVALID_G : boolean               := true;
      EN_DRP_G                    : boolean               := false;
      EN_PGP_MON_G                : boolean               := false;
      TX_POLARITY_G               : sl                    := '0';
      RX_POLARITY_G               : sl                    := '0';
      AXIL_BASE_ADDR_G            : slv(31 downto 0)      := (others => '0');
      AXIL_CLK_FREQ_G             : real                  := 125.0E+6);
   port (
      -- Stable Clock and Reset
      stableClk    : in  sl;            -- GT needs a stable clock to "boot up"
      stableRst    : in  sl;
      -- QPLL Interface
      qpllLock     : in  slv(1 downto 0);
      qpllclk      : in  slv(1 downto 0);
      qpllrefclk   : in  slv(1 downto 0);
      qpllRst      : out slv(1 downto 0);
      -- Gt Serial IO
      pgpGtTxP     : out sl;
      pgpGtTxN     : out sl;
      pgpGtRxP     : in  sl;
      pgpGtRxN     : in  sl;
      -- Clocking
      pgpClk       : out sl;
      pgpClkRst    : out sl;
      -- Non VC Rx Signals
      pgpRxIn      : in  Pgp3RxInType;
      pgpRxOut     : out Pgp3RxOutType;
      -- Non VC Tx Signals
      pgpTxIn      : in  Pgp3TxInType;
      pgpTxOut     : out Pgp3TxOutType;
      -- Frame Transmit Interface
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl    : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end Pgp3GthUs;

architecture rtl of Pgp3GthUs is

   -- clocks
   signal pgpRxClkInt : sl;
   signal pgpRxRstInt : sl;
   signal pgpTxClkInt : sl;
   signal pgpTxRstInt : sl;

   -- PgpRx Signals
--   signal gtRxUserReset : sl;
   signal phyRxClk      : sl;
   signal phyRxRst      : sl;
   signal phyRxInit     : sl;
   signal phyRxActive   : sl;
   signal phyRxValid    : sl;
   signal phyRxHeader   : slv(1 downto 0);
   signal phyRxData     : slv(63 downto 0);
   signal phyRxStartSeq : sl;
   signal phyRxSlip     : sl;


   -- PgpTx Signals
--   signal gtTxUserReset : sl;
   signal phyTxActive   : sl;
   signal phyTxStart    : sl;
   signal phyTxData     : slv(63 downto 0);
   signal phyTxHeader   : slv(1 downto 0);

   constant NUM_AXIL_MASTERS_C : integer := 2;
   constant PGP_AXIL_INDEX_C   : integer := 0;
   constant DRP_AXIL_INDEX_C   : integer := 1;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := (
      PGP_AXIL_INDEX_C => (
         baseAddr      => AXIL_BASE_ADDR_G,
         addrBits      => 12,
         connectivity  => X"FFFF"),
      DRP_AXIL_INDEX_C => (
         baseAddr      => AXIL_BASE_ADDR_G + X"1000",
         addrBits      => 11,
         connectivity  => X"FFFF"));

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)   := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);

   signal loopback : slv(2 downto 0);

begin

   assert ((RATE_G = "3.125Gbps") or (RATE_G = "6.25Gbps") or (RATE_G = "10.3125Gbps"))
      report "RATE_G: Must be either 3.125Gbps or 6.25Gbps or 10.3125Gbps"
      severity error;

   pgpClk    <= pgpTxClkInt;
   pgpClkRst <= pgpTxRstInt;

   --gtRxUserReset <= phyRxInit or pgpRxIn.resetRx;
   --gtTxUserReset <= pgpTxRst;

   GEN_XBAR : if (EN_DRP_G and EN_PGP_MON_G) generate
      U_XBAR : entity work.AxiLiteCrossbar
         generic map (
            TPD_G              => TPD_G,
            NUM_SLAVE_SLOTS_G  => 1,
            NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
            MASTERS_CONFIG_G   => XBAR_CONFIG_C)
         port map (
            axiClk              => axilClk,
            axiClkRst           => axilRst,
            sAxiWriteMasters(0) => axilWriteMaster,
            sAxiWriteSlaves(0)  => axilWriteSlave,
            sAxiReadMasters(0)  => axilReadMaster,
            sAxiReadSlaves(0)   => axilReadSlave,
            mAxiWriteMasters    => axilWriteMasters,
            mAxiWriteSlaves     => axilWriteSlaves,
            mAxiReadMasters     => axilReadMasters,
            mAxiReadSlaves      => axilReadSlaves);
   end generate GEN_XBAR;

   -- If DRP or PGP_MON not enabled, no crossbar needed
   -- If neither enabled, default values will auto-terminate the bus   
   GEN_DRP_ONLY : if (EN_DRP_G and not EN_PGP_MON_G) generate
      axilWriteSlave                     <= axilWriteSlaves(DRP_AXIL_INDEX_C);
      axilWriteMasters(DRP_AXIL_INDEX_C) <= axilWriteMaster;
      axilReadSlave                      <= axilReadSlaves(DRP_AXIL_INDEX_C);
      axilReadMasters(DRP_AXIL_INDEX_C)  <= axilReadMaster;
   end generate GEN_DRP_ONLY;

   GEN_PGP_MON_ONLY : if (EN_PGP_MON_G and not EN_DRP_G) generate
      axilWriteSlave                     <= axilWriteSlaves(PGP_AXIL_INDEX_C);
      axilWriteMasters(PGP_AXIL_INDEX_C) <= axilWriteMaster;
      axilReadSlave                      <= axilReadSlaves(PGP_AXIL_INDEX_C);
      axilReadMasters(PGP_AXIL_INDEX_C)  <= axilReadMaster;
   end generate GEN_PGP_MON_ONLY;


   U_Pgp3Core_1 : entity work.Pgp3Core
      generic map (
         TPD_G                       => TPD_G,
         SYNTH_MODE_G                => SYNTH_MODE_G,
         NUM_VC_G                    => NUM_VC_G,
         PGP_RX_ENABLE_G             => PGP_RX_ENABLE_G,
         RX_ALIGN_SLIP_WAIT_G        => RX_ALIGN_SLIP_WAIT_G,
         PGP_TX_ENABLE_G             => PGP_TX_ENABLE_G,
         TX_CELL_WORDS_MAX_G         => TX_CELL_WORDS_MAX_G,
         TX_MUX_MODE_G               => TX_MUX_MODE_G,
         TX_MUX_TDEST_ROUTES_G       => TX_MUX_TDEST_ROUTES_G,
         TX_MUX_TDEST_LOW_G          => TX_MUX_TDEST_LOW_G,
         TX_MUX_ILEAVE_EN_G          => TX_MUX_ILEAVE_EN_G,
         TX_MUX_ILEAVE_ON_NOTVALID_G => TX_MUX_ILEAVE_ON_NOTVALID_G,
         EN_PGP_MON_G                => EN_PGP_MON_G,
         AXIL_CLK_FREQ_G             => AXIL_CLK_FREQ_G)
      port map (
         -- Tx User interface
         pgpTxClk        => pgpTxClkInt,                         -- [in]
         pgpTxRst        => pgpTxRstInt,                         -- [in]
         pgpTxIn         => pgpTxIn,                             -- [in]
         pgpTxOut        => pgpTxOut,                            -- [out]
         pgpTxMasters    => pgpTxMasters,                        -- [in]
         pgpTxSlaves     => pgpTxSlaves,                         -- [out]
         -- Tx PHY interface
         phyTxActive     => phyTxActive,                         -- [in]
         phyTxReady      => '1',                                 -- [in]
         phyTxStart      => phyTxStart,                          -- [out]
         phyTxData       => phyTxData,                           -- [out]
         phyTxHeader     => phyTxHeader,                         -- [out]
         -- Rx User interface
         pgpRxClk        => pgpTxClkInt,                         -- [in]
         pgpRxRst        => pgpTxRstInt,                         -- [in]
         pgpRxIn         => pgpRxIn,                             -- [in]
         pgpRxOut        => pgpRxOut,                            -- [out]
         pgpRxMasters    => pgpRxMasters,                        -- [out]
         pgpRxCtrl       => pgpRxCtrl,                           -- [in]
         -- Rx PHY interface
         phyRxClk        => phyRxClk,                            -- [in]
         phyRxRst        => phyRxRst,                            -- [in]
         phyRxInit       => phyRxInit,                           -- [out]
         phyRxActive     => phyRxActive,                         -- [in]
         phyRxValid      => phyRxValid,                          -- [in]
         phyRxHeader     => phyRxHeader,                         -- [in]
         phyRxData       => phyRxData,                           -- [in]
         phyRxStartSeq   => phyRxStartSeq,                       -- [in]
         phyRxSlip       => phyRxSlip,                           -- [out]
         -- Debug Interface
         loopback        => loopback,                            -- [out]
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => axilClk,                             -- [in]
         axilRst         => axilRst,                             -- [in]
         axilReadMaster  => axilReadMasters(PGP_AXIL_INDEX_C),   -- [in]
         axilReadSlave   => axilReadSlaves(PGP_AXIL_INDEX_C),    -- [out]
         axilWriteMaster => axilWriteMasters(PGP_AXIL_INDEX_C),  -- [in]
         axilWriteSlave  => axilWriteSlaves(PGP_AXIL_INDEX_C));  -- [out]

   --------------------------
   -- Wrapper for GTH IP core
   --------------------------
   U_Pgp3GthUsIpWrapper_1 : entity work.Pgp3GthUsIpWrapper
      generic map (
         TPD_G         => TPD_G,
         TX_POLARITY_G => TX_POLARITY_G,
         RX_POLARITY_G => RX_POLARITY_G,
         RATE_G        => RATE_G,
         EN_DRP_G      => EN_DRP_G)
      port map (
         stableClk       => stableClk,                           -- [in]
         stableRst       => stableRst,                           -- [in]
         qpllLock        => qpllLock,                            -- [in]
         qpllclk         => qpllclk,                             -- [in]
         qpllrefclk      => qpllrefclk,                          -- [in]
         qpllRst         => qpllRst,                             -- [out]
         gtRxP           => pgpGtRxP,                            -- [in]
         gtRxN           => pgpGtRxN,                            -- [in]
         gtTxP           => pgpGtTxP,                            -- [out]
         gtTxN           => pgpGtTxN,                            -- [out]
         rxReset         => phyRxInit,                           -- [in]
         rxUsrClkActive  => open,                                -- [out]
         rxResetDone     => phyRxActive,                         -- [out]
         rxUsrClk        => open,                                -- [out]
         rxUsrClk2       => phyRxClk,                            -- [out]
         rxUsrClkRst     => phyRxRst,                            -- [out]
         rxData          => phyRxData,                           -- [out]
         rxDataValid     => phyRxValid,                          -- [out]
         rxHeader        => phyRxHeader,                         -- [out]
         rxHeaderValid   => open,                                -- [out]
         rxStartOfSeq    => phyRxStartSeq,                       -- [out]
         rxGearboxSlip   => phyRxSlip,                           -- [in]
         rxOutClk        => open,                                -- [out]
         txReset         => '0',                                 -- [in]
         txUsrClkActive  => open,                                -- [out]
         txResetDone     => phyTxActive,                         -- [out]
         txUsrClk        => open,                                -- [out]
         txUsrClk2       => pgpTxClkInt,                         -- [out]
         txUsrClkRst     => pgpTxRstInt,                         -- [out]
         txData          => phyTxData,                           -- [in]
         txHeader        => phyTxHeader,                         -- [in]
         txOutClk        => open,                                -- [out]
         loopback        => loopback,                            -- [in]
         axilClk         => axilClk,                             -- [in]
         axilRst         => axilRst,                             -- [in]
         axilReadMaster  => axilReadMasters(DRP_AXIL_INDEX_C),   -- [in]
         axilReadSlave   => axilReadSlaves(DRP_AXIL_INDEX_C),    -- [out]
         axilWriteMaster => axilWriteMasters(DRP_AXIL_INDEX_C),  -- [in]
         axilWriteSlave  => axilWriteSlaves(DRP_AXIL_INDEX_C));  -- [out]


end rtl;
