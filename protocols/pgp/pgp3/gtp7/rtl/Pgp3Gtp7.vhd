-------------------------------------------------------------------------------
-- File       : Pgp3Gtp7.vhd
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

entity Pgp3Gtp7 is
   generic (
      TPD_G                       : time                  := 1 ns;
      RATE_G                      : string                := "6.25Gbps";  -- or "3.125Gbps"
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PGP_RX_ENABLE_G             : boolean               := true;
      RX_ALIGN_GOOD_COUNT_G       : integer               := 128;
      RX_ALIGN_BAD_COUNT_G        : integer               := 16;
      RX_ALIGN_SLIP_WAIT_G        : integer               := 32;
      PGP_TX_ENABLE_G             : boolean               := true;
      NUM_VC_G                    : integer range 1 to 16 := 4;
      TX_CELL_WORDS_MAX_G         : integer               := PGP3_DEFAULT_TX_CELL_WORDS_MAX_C;  -- Number of 64-bit words per cell
      TX_SKP_INTERVAL_G           : integer               := 5000;
      TX_SKP_BURST_SIZE_G         : integer               := 8;
      TX_MUX_MODE_G               : string                := "INDEXED";  -- Or "ROUTED"
      TX_MUX_TDEST_ROUTES_G       : Slv8Array             := (0      => "--------");  -- Only used in ROUTED mode
      TX_MUX_TDEST_LOW_G          : integer range 0 to 7  := 0;
      TX_MUX_ILEAVE_EN_G          : boolean               := true;
      TX_MUX_ILEAVE_ON_NOTVALID_G : boolean               := true;
      EN_DRP_G                    : boolean               := true;
      EN_PGP_MON_G                : boolean               := true;
      TX_POLARITY_G               : sl                    := '0';
      RX_POLARITY_G               : sl                    := '0';
      AXIL_BASE_ADDR_G            : slv(31 downto 0)      := (others => '0');
      AXIL_CLK_FREQ_G             : real                  := 156.25E+6);
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- QPLL Interface
      qPllOutClk      : in  slv(1 downto 0);
      qPllOutRefClk   : in  slv(1 downto 0);
      qPllLock        : in  slv(1 downto 0);
      qPllRefClkLost  : in  slv(1 downto 0);
      qpllRst         : out slv(1 downto 0);
      -- TX PLL Interface
      gtTxOutClk      : out sl;
      gtTxPllRst      : out sl;
      txPllClk        : in  slv(2 downto 0);
      txPllRst        : in  slv(2 downto 0);
      gtTxPllLock     : in  sl;
      -- Gt Serial IO
      pgpGtTxP        : out sl;
      pgpGtTxN        : out sl;
      pgpGtRxP        : in  sl;
      pgpGtRxN        : in  sl;
      -- Clocking
      pgpClk          : out sl;
      pgpClkRst       : out sl;
      -- Non VC Rx Signals
      pgpRxIn         : in  Pgp3RxInType;
      pgpRxOut        : out Pgp3RxOutType;
      -- Non VC Tx Signals
      pgpTxIn         : in  Pgp3TxInType;
      pgpTxOut        : out Pgp3TxOutType;
      -- Frame Transmit Interface
      pgpTxMasters    : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface
      pgpRxMasters    : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl       : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      -- Debug Interface 
      txPreCursor     : in  slv(4 downto 0)        := "00111";
      txPostCursor    : in  slv(4 downto 0)        := "00111";
      txDiffCtrl      : in  slv(3 downto 0)        := "1111";
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end Pgp3Gtp7;

architecture rtl of Pgp3Gtp7 is

   -- Clocks and Resets
   signal phyRxClkSlow : sl;
   signal phyRxRstSlow : sl;
   signal phyRxClkFast : sl;
   signal phyRxRstFast : sl;
   signal phyTxClkSlow : sl;
   signal phyTxRstSlow : sl;
   signal phyTxClkFast : sl;
   signal phyTxRstFast : sl;

   -- PgpRx Signals
   signal phyRxInit   : sl;
   signal phyRxActive : sl;
   signal phyRxValid  : sl;
   signal phyRxHeader : slv(1 downto 0);
   signal phyRxData   : slv(63 downto 0);
   signal phyRxSlip   : sl;
   signal slipOneShot : sl;
   signal rxFifoValid : sl;
   signal rxFifoReady : sl;
   signal rxFifoData  : slv(65 downto 0);
   signal rxData      : slv(31 downto 0);

   -- PgpTx Signals
   signal phyTxActive  : sl;
   signal phyTxHeader  : slv(1 downto 0);
   signal phyTxData    : slv(63 downto 0);
   signal phyTxStart   : sl;
   signal phyTxDataRdy : sl;
   signal txFifoValid  : sl;
   signal txFifoReady  : sl;
   signal txFifoRead   : sl;
   signal txFifoData   : slv(65 downto 0);
   signal txData       : slv(31 downto 0);


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

   assert ((RATE_G = "3.125Gbps") or (RATE_G = "6.25Gbps"))
      report "RATE_G: Must be either 3.125Gbps, 6.25Gbps"
      severity error;

   pgpClk    <= phyTxClkSlow;
   pgpClkRst <= phyTxRstSlow;

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

   U_Pgp3Core : entity work.Pgp3Core
      generic map (
         TPD_G                       => TPD_G,
         NUM_VC_G                    => NUM_VC_G,
         PGP_RX_ENABLE_G             => PGP_RX_ENABLE_G,
         RX_ALIGN_GOOD_COUNT_G       => RX_ALIGN_GOOD_COUNT_G,
         RX_ALIGN_BAD_COUNT_G        => RX_ALIGN_BAD_COUNT_G,
         RX_ALIGN_SLIP_WAIT_G        => RX_ALIGN_SLIP_WAIT_G,
         PGP_TX_ENABLE_G             => PGP_TX_ENABLE_G,
         TX_CELL_WORDS_MAX_G         => TX_CELL_WORDS_MAX_G,
         TX_SKP_INTERVAL_G           => TX_SKP_INTERVAL_G,
         TX_SKP_BURST_SIZE_G         => TX_SKP_BURST_SIZE_G,
         TX_MUX_MODE_G               => TX_MUX_MODE_G,
         TX_MUX_TDEST_ROUTES_G       => TX_MUX_TDEST_ROUTES_G,
         TX_MUX_TDEST_LOW_G          => TX_MUX_TDEST_LOW_G,
         TX_MUX_ILEAVE_EN_G          => TX_MUX_ILEAVE_EN_G,
         TX_MUX_ILEAVE_ON_NOTVALID_G => TX_MUX_ILEAVE_ON_NOTVALID_G,
         EN_PGP_MON_G                => EN_PGP_MON_G,
         AXIL_CLK_FREQ_G             => AXIL_CLK_FREQ_G)
      port map (
         -- Tx User interface
         pgpTxClk        => phyTxClkSlow,                        -- [in]
         pgpTxRst        => phyTxRstSlow,                        -- [in]
         pgpTxIn         => pgpTxIn,                             -- [in]
         pgpTxOut        => pgpTxOut,                            -- [out]
         pgpTxMasters    => pgpTxMasters,                        -- [in]
         pgpTxSlaves     => pgpTxSlaves,                         -- [out]
         -- Tx PHY interface
         phyTxActive     => phyTxActive,                         -- [in]
         phyTxHeader     => phyTxHeader,                         -- [out]
         phyTxData       => phyTxData,                           -- [out]
         phyTxStart      => phyTxStart,                          -- [out]
         phyTxReady      => phyTxDataRdy,                        -- [in]
         -- Rx User interface
         pgpRxClk        => phyTxClkSlow,                        -- [in]
         pgpRxRst        => phyTxRstSlow,                        -- [in]
         pgpRxIn         => pgpRxIn,                             -- [in]
         pgpRxOut        => pgpRxOut,                            -- [out]
         pgpRxMasters    => pgpRxMasters,                        -- [out]
         pgpRxCtrl       => pgpRxCtrl,                           -- [in]
         -- Rx PHY interface
         phyRxClk        => phyRxClkSlow,                        -- [in]
         phyRxRst        => phyRxRstSlow,                        -- [in]
         phyRxInit       => phyRxInit,                           -- [out]
         phyRxActive     => phyRxActive,                         -- [in]
         phyRxValid      => phyRxValid,                          -- [in]
         phyRxHeader     => phyRxHeader,                         -- [in]
         phyRxData       => phyRxData,                           -- [in]
         phyRxStartSeq   => '0',                                 -- [in]
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

   ----------
   -- TX SYNC
   ----------
   U_TxSync : entity work.FifoAsync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '0',
         BRAM_EN_G      => false,
         FWFT_EN_G      => true,
         DATA_WIDTH_G   => 66,
         ADDR_WIDTH_G   => 4,
         INIT_G         => (PGP3_K_HEADER_C & x"9999_9999_9999_9999"))  -- PGP3_IDLE_C
      port map (
         -- Asynchronous Reset
         rst               => phyTxActive,
         -- Write Ports (wr_clk domain)
         wr_clk            => phyTxClkSlow,
         wr_en             => phyTxStart,
         almost_full       => phyTxDataRdy,
         din(65 downto 64) => phyTxHeader,
         din(63 downto 0)  => phyTxData,
         -- Read Ports (rd_clk domain)
         rd_clk            => phyTxClkFast,
         valid             => txFifoValid,
         rd_en             => txFifoRead,
         dout              => txFifoData);

   -------------
   -- TX Gearbox
   -------------
   U_TxGearbox : entity work.Gearbox
      generic map (
         TPD_G          => TPD_G,
         INPUT_WIDTH_G  => 66,
         OUTPUT_WIDTH_G => 32)
      port map (
         -- Clock and Reset
         clk     => phyTxClkFast,
         rst     => phyTxRstFast,
         -- Input side data and flow control
         dataIn  => txFifoData,
         validIn => txFifoValid,
         readyIn => txFifoRead,
         -- Output side data and flow control
         dataOut => txData);

   --------------------------
   -- Wrapper for GTH IP core
   --------------------------
   U_Pgp3Gtp7IpWrapper : entity work.Pgp3Gtp7IpWrapper
      generic map (
         TPD_G         => TPD_G,
         TX_POLARITY_G => TX_POLARITY_G,
         RX_POLARITY_G => RX_POLARITY_G,
         EN_DRP_G      => EN_DRP_G,
         RATE_G        => RATE_G)
      port map (
         stableClk       => stableClk,
         stableRst       => stableRst,
         -- QPLL Interface
         qPllOutClk      => qPllOutClk,
         qPllOutRefClk   => qPllOutRefClk,
         qPllLock        => qPllLock,
         qpllRefClkLost  => qpllRefClkLost,
         qpllRst         => qpllRst,
         -- TX PLL Interface
         gtTxOutClk      => gtTxOutClk,
         gtTxPllRst      => gtTxPllRst,
         txPllClk        => txPllClk,
         txPllRst        => txPllRst,
         gtTxPllLock     => gtTxPllLock,
         -- GTH FPGA IO
         gtRxP           => pgpGtRxP,
         gtRxN           => pgpGtRxN,
         gtTxP           => pgpGtTxP,
         gtTxN           => pgpGtTxN,
         -- Rx ports
         rxReset         => phyRxInit,
         rxResetDone     => phyRxActive,
         rxUsrClk0       => phyRxClkSlow,
         rxUsrClk0Rst    => phyRxRstSlow,
         rxUsrClk2       => phyRxClkFast,
         rxUsrClk2Rst    => phyRxRstFast,
         rxData          => rxData,
         -- Tx Ports
         txReset         => '0',
         txResetDone     => phyTxActive,
         txUsrClk0       => phyTxClkSlow,
         txUsrClk0Rst    => phyTxRstSlow,
         txUsrClk2       => phyTxClkFast,
         txUsrClk2Rst    => phyTxRstFast,
         txData          => txData,
         -- Debug Interface 
         loopback        => loopback,
         txPreCursor     => txPreCursor,
         txPostCursor    => txPostCursor,
         txDiffCtrl      => txDiffCtrl,
         -- AXI-Lite DRP Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(DRP_AXIL_INDEX_C),
         axilReadSlave   => axilReadSlaves(DRP_AXIL_INDEX_C),
         axilWriteMaster => axilWriteMasters(DRP_AXIL_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(DRP_AXIL_INDEX_C));

   -------------
   -- RX Gearbox
   -------------
   U_RxGearbox : entity work.Gearbox
      generic map (
         TPD_G          => TPD_G,
         INPUT_WIDTH_G  => 32,
         OUTPUT_WIDTH_G => 66)
      port map (
         -- Clock and Reset
         clk      => phyRxClkFast,
         rst      => phyRxRstFast,
         -- Input side data and flow control
         dataIn   => rxData,
         validIn  => phyRxActive,
         -- sequencing and slip
         slip     => slipOneShot,
         -- Output side data and flow control
         dataOut  => rxFifoData,
         validOut => rxFifoValid,
         readyOut => rxFifoReady);

   ----------
   -- RX SYNC
   ----------
   U_RxSync : entity work.FifoAsync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '0',
         BRAM_EN_G      => false,
         FWFT_EN_G      => true,
         DATA_WIDTH_G   => 66,
         ADDR_WIDTH_G   => 4,
         INIT_G         => (PGP3_K_HEADER_C & x"9999_9999_9999_9999"))  -- PGP3_IDLE_C   
      port map (
         -- Asynchronous Reset
         rst                => phyRxActive,
         -- Write Ports (wr_clk domain)
         wr_clk             => phyRxClkFast,
         wr_en              => rxFifoValid,
         din                => rxFifoData,
         almost_full        => rxFifoReady,
         -- Read Ports (rd_clk domain)
         rd_clk             => phyRxClkSlow,
         valid              => phyRxValid,
         rd_en              => '1',
         dout(65 downto 64) => phyRxHeader,
         dout(63 downto 0)  => phyRxData);

   U_phyRxSlip : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => phyRxClkFast,
         dataIn  => phyRxSlip,
         dataOut => slipOneShot);

end rtl;
