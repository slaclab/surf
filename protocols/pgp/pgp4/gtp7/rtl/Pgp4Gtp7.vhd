-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv4 GTP7 Core Module
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.Pgp4Pkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp4Gtp7 is
   generic (
      TPD_G                       : time                  := 1 ns;
      RATE_G                      : string                := "6.25Gbps";  -- or "3.125Gbps"
      CLKIN_PERIOD_G              : real;
      BANDWIDTH_G                 : string;
      CLKFBOUT_MULT_G             : positive;
      CLKOUT0_DIVIDE_G            : positive;
      CLKOUT1_DIVIDE_G            : positive;
      CLKOUT2_DIVIDE_G            : positive;
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PGP_RX_ENABLE_G             : boolean               := true;
      RX_ALIGN_SLIP_WAIT_G        : integer               := 32;
      PGP_TX_ENABLE_G             : boolean               := true;
      NUM_VC_G                    : integer range 1 to 16 := 4;
      TX_CELL_WORDS_MAX_G         : integer               := PGP4_DEFAULT_TX_CELL_WORDS_MAX_C;  -- Number of 64-bit words per cell
      TX_MUX_MODE_G               : string                := "INDEXED";  -- Or "ROUTED"
      TX_MUX_TDEST_ROUTES_G       : Slv8Array             := (0      => "--------");  -- Only used in ROUTED mode
      TX_MUX_TDEST_LOW_G          : integer range 0 to 7  := 0;
      TX_MUX_ILEAVE_EN_G          : boolean               := true;
      TX_MUX_ILEAVE_ON_NOTVALID_G : boolean               := true;
      EN_DRP_G                    : boolean               := false;
      EN_PGP_MON_G                : boolean               := false;
      WRITE_EN_G                  : boolean               := true;  -- Set to false when on remote end of a link
      TX_POLARITY_G               : sl                    := '0';
      RX_POLARITY_G               : sl                    := '0';
      STATUS_CNT_WIDTH_G          : natural range 1 to 32 := 16;
      ERROR_CNT_WIDTH_G           : natural range 1 to 32 := 8;
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
      pgpRxIn         : in  Pgp4RxInType := PGP4_RX_IN_INIT_C;
      pgpRxOut        : out Pgp4RxOutType;
      -- Non VC Tx Signals
      pgpTxIn         : in  Pgp4TxInType := PGP4_TX_IN_INIT_C;
      pgpTxOut        : out Pgp4TxOutType;
      -- Frame Transmit Interface
      pgpTxMasters    : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface
      pgpRxMasters    : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl       : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end Pgp4Gtp7;

architecture rtl of Pgp4Gtp7 is

   -- Clocks and Resets
   signal phyRxClk : sl := '0';
   signal phyRxRst : sl := '1';
   signal phyTxClk : sl := '0';
   signal phyTxRst : sl := '1';

   -- PgpRx Signals
   signal phyRxInit   : sl               := '0';
   signal phyRxActive : sl               := '0';
   signal phyRxValid  : sl               := '0';
   signal phyRxHeader : slv(1 downto 0)  := (others => '0');
   signal phyRxData   : slv(63 downto 0) := (others => '0');
   signal phyRxSlip   : sl               := '0';
   signal locRxOut    : Pgp4RxOutType;

   -- PgpTx Signals
   signal phyTxActive  : sl               := '0';
   signal phyTxHeader  : slv(1 downto 0)  := (others => '0');
   signal phyTxData    : slv(63 downto 0) := (others => '0');
   signal phyTxValid   : sl               := '0';
   signal phyTxDataRdy : sl               := '0';

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

   signal loopback     : slv(2 downto 0) := (others => '0');
   signal txDiffCtrl   : slv(4 downto 0);
   signal txPreCursor  : slv(4 downto 0);
   signal txPostCursor : slv(4 downto 0);

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of phyRxClk     : signal is "TRUE";
   -- attribute dont_touch of phyRxRst     : signal is "TRUE";
   -- attribute dont_touch of phyTxClk     : signal is "TRUE";
   -- attribute dont_touch of phyTxRst     : signal is "TRUE";
   -- attribute dont_touch of phyRxInit    : signal is "TRUE";
   -- attribute dont_touch of phyRxActive  : signal is "TRUE";
   -- attribute dont_touch of phyRxValid   : signal is "TRUE";
   -- attribute dont_touch of phyRxHeader  : signal is "TRUE";
   -- attribute dont_touch of phyRxData    : signal is "TRUE";
   -- attribute dont_touch of phyRxSlip    : signal is "TRUE";
   -- attribute dont_touch of phyTxActive  : signal is "TRUE";
   -- attribute dont_touch of phyTxHeader  : signal is "TRUE";
   -- attribute dont_touch of phyTxData    : signal is "TRUE";
   -- attribute dont_touch of phyTxValid   : signal is "TRUE";
   -- attribute dont_touch of phyTxDataRdy : signal is "TRUE";

begin

   assert ((RATE_G = "3.125Gbps") or (RATE_G = "6.25Gbps"))
      report "RATE_G: Must be either 3.125Gbps, 6.25Gbps"
      severity error;

   pgpClk    <= phyTxClk;
   pgpClkRst <= phyTxRst;
   pgpRxOut  <= locRxOut;

   GEN_XBAR : if (EN_DRP_G and EN_PGP_MON_G) generate
      U_XBAR : entity surf.AxiLiteCrossbar
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

   U_Pgp4Core : entity surf.Pgp4Core
      generic map (
         TPD_G                       => TPD_G,
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
         WRITE_EN_G                  => WRITE_EN_G,
         STATUS_CNT_WIDTH_G          => STATUS_CNT_WIDTH_G,
         ERROR_CNT_WIDTH_G           => ERROR_CNT_WIDTH_G,
         AXIL_CLK_FREQ_G             => AXIL_CLK_FREQ_G)
      port map (
         -- Tx User interface
         pgpTxClk        => phyTxClk,                            -- [in]
         pgpTxRst        => phyTxRst,                            -- [in]
         pgpTxIn         => pgpTxIn,                             -- [in]
         pgpTxOut        => pgpTxOut,                            -- [out]
         pgpTxMasters    => pgpTxMasters,                        -- [in]
         pgpTxSlaves     => pgpTxSlaves,                         -- [out]
         -- Tx PHY interface
         phyTxActive     => phyTxActive,                         -- [in]
         phyTxHeader     => phyTxHeader,                         -- [out]
         phyTxData       => phyTxData,                           -- [out]
         phyTxValid      => phyTxValid,                          -- [out]
         phyTxReady      => phyTxDataRdy,                        -- [in]
         -- Rx User interface
         pgpRxClk        => phyTxClk,                            -- [in]
         pgpRxRst        => phyTxRst,                            -- [in]
         pgpRxIn         => pgpRxIn,                             -- [in]
         pgpRxOut        => locRxOut,                            -- [out]
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
         phyRxStartSeq   => '0',                                 -- [in]
         phyRxSlip       => phyRxSlip,                           -- [out]
         -- Debug Interface
         loopback        => loopback,                            -- [out]
         txDiffCtrl      => txDiffCtrl,                          -- [out]
         txPreCursor     => txPreCursor,                         -- [out]
         txPostCursor    => txPostCursor,                        -- [out]
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
   U_Pgp3Gtp7IpWrapper : entity surf.Pgp3Gtp7IpWrapper -- Same IP core for both PGPv3 and PGPv4
      generic map (
         TPD_G            => TPD_G,
         CLKIN_PERIOD_G   => CLKIN_PERIOD_G,
         BANDWIDTH_G      => BANDWIDTH_G,
         CLKFBOUT_MULT_G  => CLKFBOUT_MULT_G,
         CLKOUT0_DIVIDE_G => CLKOUT0_DIVIDE_G,
         CLKOUT1_DIVIDE_G => CLKOUT1_DIVIDE_G,
         CLKOUT2_DIVIDE_G => CLKOUT2_DIVIDE_G,
         TX_POLARITY_G    => TX_POLARITY_G,
         RX_POLARITY_G    => RX_POLARITY_G,
         EN_DRP_G         => EN_DRP_G,
         RATE_G           => RATE_G)
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
         rxUsrClk        => phyRxClk,
         rxUsrClkRst     => phyRxRst,
         rxReset         => phyRxInit,
         rxResetDone     => phyRxActive,
         rxValid         => phyRxValid,
         rxHeader        => phyRxHeader,
         rxData          => phyRxData,
         rxSlip          => phyRxSlip,
         rxAligned       => locRxOut.gearboxAligned,
         -- Tx Ports
         txUsrClk        => phyTxClk,
         txUsrClkRst     => phyTxRst,
         txReset         => stableRst,
         txResetDone     => phyTxActive,
         txHeader        => phyTxHeader,
         txData          => phyTxData,
         txValid         => phyTxValid,
         txReady         => phyTxDataRdy,
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

end rtl;
