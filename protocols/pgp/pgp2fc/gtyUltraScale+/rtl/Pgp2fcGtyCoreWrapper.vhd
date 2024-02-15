-------------------------------------------------------------------------------
-- Title      : PGPv2b: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv2b GTY Ultrascale IP Core Wrapper
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp2fcGtyCoreWrapper is
   generic (
      TPD_G               : time    := 1 ns;
      SEL_FABRIC_REFCLK_G : boolean := false;
      USE_ALIGN_CHECK_G   : boolean := true;
      AXI_CLK_FREQ_G      : real             := 125.0e6;
      AXI_BASE_ADDR_G     : slv(31 downto 0) := (others => '0'));
   port (
      stableClk      : in  sl;
      stableRst      : in  sl;

      -- GTY FPGA IO
      gtRefClk       : in  sl;
      gtFabricRefClk : in  sl;
      gtUserRefClk   : in  sl;
      gtRxP          : in  sl;
      gtRxN          : in  sl;
      gtTxP          : out sl;
      gtTxN          : out sl;

      -- Rx ports
      rxReset        : in  sl;
      rxUsrClkActive : in  sl;
      rxResetDone    : out sl;
      rxUsrClk       : in  sl;
      rxData         : out slv(15 downto 0);
      rxDataK        : out slv(1 downto 0);
      rxDispErr      : out slv(1 downto 0);
      rxDecErr       : out slv(1 downto 0);
      rxPolarity     : in  sl;
      rxOutClk       : out sl;
      rxRecClk       : out sl; -- raw recovered clock

      -- Tx Ports
      txReset        : in  sl;
      txUsrClk       : in  sl;
      txUsrClkActive : in  sl;
      txResetDone    : out sl;
      txData         : in  slv(15 downto 0);
      txDataK        : in  slv(1 downto 0);
      txPolarity     : in  sl;
      txOutClk       : out sl;
      loopback       : in  slv(2 downto 0);

      -- AXI-Lite DRP interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end entity Pgp2fcGtyCoreWrapper;

architecture mapping of Pgp2fcGtyCoreWrapper is

   component Pgp2fcGtyCore
      port (
         gtwiz_userclk_tx_reset_in          : in  std_logic_vector (0 downto 0);
         gtwiz_userclk_tx_active_in         : in  std_logic_vector (0 downto 0);
         gtwiz_userclk_rx_active_in         : in  std_logic_vector (0 downto 0);
         gtwiz_buffbypass_tx_reset_in       : in  std_logic_vector (0 downto 0);
         gtwiz_buffbypass_tx_start_user_in  : in  std_logic_vector (0 downto 0);
         gtwiz_buffbypass_tx_done_out       : out std_logic_vector (0 downto 0);
         gtwiz_buffbypass_tx_error_out      : out std_logic_vector (0 downto 0);
         gtwiz_buffbypass_rx_reset_in       : in  std_logic_vector (0 downto 0);
         gtwiz_buffbypass_rx_start_user_in  : in  std_logic_vector (0 downto 0);
         gtwiz_buffbypass_rx_done_out       : out std_logic_vector (0 downto 0);
         gtwiz_buffbypass_rx_error_out      : out std_logic_vector (0 downto 0);
         gtwiz_reset_clk_freerun_in         : in  std_logic_vector (0 downto 0);
         gtwiz_reset_all_in                 : in  std_logic_vector (0 downto 0);
         gtwiz_reset_tx_pll_and_datapath_in : in  std_logic_vector (0 downto 0);
         gtwiz_reset_tx_datapath_in         : in  std_logic_vector (0 downto 0);
         gtwiz_reset_rx_pll_and_datapath_in : in  std_logic_vector (0 downto 0);
         gtwiz_reset_rx_datapath_in         : in  std_logic_vector (0 downto 0);
         gtwiz_reset_rx_cdr_stable_out      : out std_logic_vector (0 downto 0);
         gtwiz_reset_tx_done_out            : out std_logic_vector (0 downto 0);
         gtwiz_reset_rx_done_out            : out std_logic_vector (0 downto 0);
         gtwiz_userdata_tx_in               : in  std_logic_vector (15 downto 0);
         gtwiz_userdata_rx_out              : out std_logic_vector (15 downto 0);
         cpllrefclksel_in                   : in  std_logic_vector (2 downto 0);
         cplllockdetclk_in                  : in  std_logic_vector (0 downto 0);
         cplllocken_in                      : in  std_logic_vector (0 downto 0);
         drpaddr_in                         : in  std_logic_vector (9 downto 0);
         drpclk_in                          : in  std_logic_vector (0 downto 0);
         drpdi_in                           : in  std_logic_vector (15 downto 0);
         drpen_in                           : in  std_logic_vector (0 downto 0);
         drpwe_in                           : in  std_logic_vector (0 downto 0);
         gtgrefclk_in                       : in  std_logic_vector (0 downto 0);
         gtrefclk0_in                       : in  std_logic_vector (0 downto 0);
         gtyrxn_in                          : in  std_logic_vector (0 downto 0);
         gtyrxp_in                          : in  std_logic_vector (0 downto 0);
         loopback_in                        : in  std_logic_vector (2 downto 0);
         rx8b10ben_in                       : in  std_logic_vector (0 downto 0);
         rxcdrreset_in                      : in  std_logic_vector (0 downto 0);
         rxcommadeten_in                    : in  std_logic_vector (0 downto 0);
         rxmcommaalignen_in                 : in  std_logic_vector (0 downto 0);
         rxpcommaalignen_in                 : in  std_logic_vector (0 downto 0);
         rxpcsreset_in                      : in  std_logic_vector (0 downto 0);
         rxpmareset_in                      : in  std_logic_vector (0 downto 0);
         rxpolarity_in                      : in  std_logic_vector (0 downto 0);
         rxusrclk_in                        : in  std_logic_vector (0 downto 0);
         rxusrclk2_in                       : in  std_logic_vector (0 downto 0);
         tx8b10ben_in                       : in  std_logic_vector (0 downto 0);
         txctrl0_in                         : in  std_logic_vector (15 downto 0);
         txctrl1_in                         : in  std_logic_vector (15 downto 0);
         txctrl2_in                         : in  std_logic_vector (7 downto 0);
         txpcsreset_in                      : in  std_logic_vector (0 downto 0);
         txpmareset_in                      : in  std_logic_vector (0 downto 0);
         txpolarity_in                      : in  std_logic_vector (0 downto 0);
         txusrclk_in                        : in  std_logic_vector (0 downto 0);
         txusrclk2_in                       : in  std_logic_vector (0 downto 0);
         cpllfbclklost_out                  : out std_logic_vector (0 downto 0);
         cplllock_out                       : out std_logic_vector (0 downto 0);
         cpllrefclklost_out                 : out std_logic_vector (0 downto 0);
         drpdo_out                          : out std_logic_vector (15 downto 0);
         drprdy_out                         : out std_logic_vector (0 downto 0);
         gtpowergood_out                    : out std_logic_vector (0 downto 0);
         gtytxn_out                         : out std_logic_vector (0 downto 0);
         gtytxp_out                         : out std_logic_vector (0 downto 0);
         rxbyteisaligned_out                : out std_logic_vector (0 downto 0);
         rxbyterealign_out                  : out std_logic_vector (0 downto 0);
         rxcommadet_out                     : out std_logic_vector (0 downto 0);
         rxctrl0_out                        : out std_logic_vector (15 downto 0);
         rxctrl1_out                        : out std_logic_vector (15 downto 0);
         rxctrl2_out                        : out std_logic_vector (7 downto 0);
         rxctrl3_out                        : out std_logic_vector (7 downto 0);
         rxdlysresetdone_out                : out std_logic_vector (0 downto 0);
         rxoutclk_out                       : out std_logic_vector (0 downto 0);
         rxrecclkout_out                    : out std_logic_vector (0 downto 0);
         rxphaligndone_out                  : out std_logic_vector (0 downto 0);
         rxpmaresetdone_out                 : out std_logic_vector (0 downto 0);
         rxresetdone_out                    : out std_logic_vector (0 downto 0);
         rxsyncdone_out                     : out std_logic_vector (0 downto 0);
         txoutclk_out                       : out std_logic_vector (0 downto 0);
         txpmaresetdone_out                 : out std_logic_vector (0 downto 0);
         txresetdone_out                    : out std_logic_vector (0 downto 0));
   end component;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) := (
      0               => (
         baseAddr     => (AXI_BASE_ADDR_G),
         addrBits     => 12,
         connectivity => x"FFFF"),
      1               => (
         baseAddr     => (AXI_BASE_ADDR_G+x"1000"),
         addrBits     => 12,
         connectivity => x"FFFF"));

   signal axilWriteMasters  : AxiLiteWriteMasterArray(1 downto 0);
   signal axilWriteSlaves   : AxiLiteWriteSlaveArray(1 downto 0);
   signal axilReadMasters   : AxiLiteReadMasterArray(1 downto 0);
   signal axilReadSlaves    : AxiLiteReadSlaveArray(1 downto 0);

   signal mAxilWriteMaster  : AxiLiteWriteMasterType;
   signal mAxilWriteSlave   : AxiLiteWriteSlaveType;
   signal mAxilReadMaster   : AxiLiteReadMasterType;
   signal mAxilReadSlave    : AxiLiteReadSlaveType;

   signal drpAddr           : slv(9 downto 0) := (others => '0');
   signal drpDi             : slv(15 downto 0) := (others => '0');
   signal drpDo             : slv(15 downto 0) := (others => '0');
   signal drpEn             : sl := '0';
   signal drpWe             : sl := '0';
   signal drpRdy            : sl := '0';
   signal dummy0_6          : slv(5 downto 0) := (others => '0');
   signal dummy1_14         : slv(13 downto 0) := (others => '0');
   signal dummy2_14         : slv(13 downto 0) := (others => '0');
   signal dummy3_6          : slv(5 downto 0) := (others => '0');
   signal dummy4_1          : sl := '0';
   signal dummy5_1          : sl := '0';
   signal txctrl2           : slv(7 downto 0) := (others => '0');

   signal cPllRefClkSel     : slv(2 downto 0) := (others => '0');
   signal cPllFbClkLost     : sl := '0';
   signal cPllLock          : sl := '0';
   signal cPllRefClkLost    : sl := '0';
   signal rxCdrReset        : sl := '0';
   signal rxPcsReset        : sl := '0';
   signal rxPmaReset        : sl := '0';
   signal txPcsReset        : sl := '0';
   signal txPmaReset        : sl := '0';
   signal rxPmaResetDone    : sl := '0';
   signal txPmaResetDone    : sl := '0';
   signal rxByteIsAligned   : sl := '0';
   signal rxByteReAlign     : sl := '0';
   signal rxCommaDet        : sl := '0';
   signal txUsrActive       : sl := '0';
   signal rxUsrActive       : sl := '0';
   signal rxMcommaAlignEn   : sl := '1';
   signal rxPcommaAlignEn   : sl := '1';
   signal buffBypassTxReset : sl := '0';
   signal buffBypassTxStart : sl := '0';
   signal buffBypassTxDone  : sl := '0';
   signal buffBypassTxError : sl := '0';
   signal buffBypassRxReset : sl := '0';
   signal buffBypassRxStart : sl := '0';
   signal buffBypassRxDone  : sl := '0';
   signal buffBypassRxError : sl := '0';
   signal rxDlysResetDone   : sl := '0';
   signal rxPhyAlignDone    : sl := '0';
   signal rxSyncDone        : sl := '0';
   signal txResetGt         : sl := '0';
   signal rxResetGt         : sl := '0';
   signal rxResetAlignCheck : sl := '0';
   signal rstSyncRxIn       : sl := '0';
   signal rxStatusLocked    : sl := '0';
   signal rxOutClkGt        : sl := '0';
   signal txOutClkGt        : sl := '0';
   signal rxOutClkB         : sl := '0';
   signal txOutClkB         : sl := '0';

begin

   -- Has to be generated from aurora core in order to work properly.
   -- Also, look out for the K-character 8b/10b alignment parameters;
   -- sometimes the core resets these to the default value (K28.5).
   -- The 8b/10b decoder aligns automatically for K28.1 (PGP2FC).
   -- The core features a GTGrefclk port, that should be connected
   -- to a fabric-generated clock (idea stolen from LCLS-II timing repo).
   -- This will only work if the fabric clock is 185.714MHz, and if
   -- the associated generic is set to true.
   U_Pgp2fcGtyCore : Pgp2fcGtyCore
      port map (
         gtwiz_userclk_tx_active_in(0)         => txUsrActive,
         gtwiz_userclk_rx_active_in(0)         => rxUsrActive,
         gtwiz_reset_clk_freerun_in(0)         => stableClk,
         gtwiz_reset_all_in(0)                 => stableRst,
         gtwiz_buffbypass_tx_reset_in(0)       => buffBypassTxReset,
         gtwiz_buffbypass_tx_start_user_in(0)  => buffBypassTxStart,
         gtwiz_buffbypass_tx_done_out(0)       => buffBypassTxDone,
         gtwiz_buffbypass_tx_error_out(0)      => buffBypassTxError,
         gtwiz_buffbypass_rx_reset_in(0)       => buffBypassRxReset,
         gtwiz_buffbypass_rx_start_user_in(0)  => buffBypassRxStart,
         gtwiz_buffbypass_rx_done_out(0)       => buffBypassRxDone,
         gtwiz_buffbypass_rx_error_out(0)      => buffBypassRxError,
         gtwiz_userclk_tx_reset_in(0)          => buffBypassTxReset,
         gtwiz_reset_tx_pll_and_datapath_in(0) => '0',
         gtwiz_reset_tx_datapath_in(0)         => txReset,
         gtwiz_reset_rx_pll_and_datapath_in(0) => '0',
         gtwiz_reset_rx_datapath_in(0)         => rxResetGt,
         gtwiz_reset_rx_cdr_stable_out         => open,
         gtwiz_reset_tx_done_out               => open,
         gtwiz_reset_rx_done_out               => open,
         gtwiz_userdata_tx_in                  => txData,
         gtwiz_userdata_rx_out                 => rxData,
         cpllrefclksel_in                      => cPllRefClkSel,
         cplllockdetclk_in(0)                  => stableClk,
         cplllocken_in(0)                      => '1',
         cpllfbclklost_out(0)                  => cPllFbClkLost,
         cplllock_out(0)                       => cPllLock,
         cpllrefclklost_out(0)                 => cPllRefClkLost,
         drpclk_in(0)                          => stableClk,
         drpaddr_in                            => drpAddr,
         drpdi_in                              => drpDi,
         drpen_in(0)                           => drpEn,
         drpwe_in(0)                           => drpWe,
         drpdo_out                             => drpDo,
         drprdy_out(0)                         => drpRdy,
         gtyrxn_in(0)                          => gtRxN,
         gtyrxp_in(0)                          => gtRxP,
         gtgrefclk_in(0)                       => gtFabricRefClk,
         gtrefclk0_in(0)                       => gtRefClk,
         loopback_in                           => loopback,
         rx8b10ben_in(0)                       => '1',
         rxcdrreset_in(0)                      => rxCdrReset,
         rxcommadeten_in(0)                    => '1',
         rxmcommaalignen_in(0)                 => rxMcommaAlignEn,
         rxpcommaalignen_in(0)                 => rxPcommaAlignEn,
         rxpcsreset_in(0)                      => rxPcsReset,
         rxpmareset_in(0)                      => rxPmaReset,
         txpcsreset_in(0)                      => txPcsReset,
         txpmareset_in(0)                      => txPmaReset,
         rxpolarity_in(0)                      => rxPolarity,
         rxusrclk_in(0)                        => rxUsrClk,
         rxusrclk2_in(0)                       => rxUsrClk,
         tx8b10ben_in(0)                       => '1',
         txctrl0_in                            => X"0000",
         txctrl1_in                            => X"0000",
         txctrl2_in                            => txctrl2,
         txpolarity_in(0)                      => txPolarity,
         txusrclk_in(0)                        => txUsrClk,
         txusrclk2_in(0)                       => txUsrClk,
         gtytxn_out(0)                         => gtTxN,
         gtytxp_out(0)                         => gtTxP,
         rxbyteisaligned_out(0)                => rxByteIsAligned,
         rxbyterealign_out(0)                  => rxByteReAlign,
         rxcommadet_out(0)                     => rxCommaDet,
         rxctrl0_out(1 downto 0)               => rxDataK,
         rxctrl0_out(15 downto 2)              => dummy1_14,
         rxctrl1_out(1 downto 0)               => rxDispErr,
         rxctrl1_out(15 downto 2)              => dummy2_14,
         rxctrl2_out                           => open,
         rxctrl3_out(1 downto 0)               => rxDecErr,
         rxctrl3_out(7 downto 2)               => dummy0_6,
         rxdlysresetdone_out(0)                => rxDlysResetDone,
         rxphaligndone_out(0)                  => rxPhyAlignDone,
         rxoutclk_out(0)                       => rxOutClkGt,
         rxrecclkout_out(0)                    => rxRecClk,
         txoutclk_out(0)                       => txOutClkGt, -- unused
         rxpmaresetdone_out(0)                 => rxPmaResetDone,
         rxresetdone_out(0)                    => rxResetDone,
         rxsyncdone_out(0)                     => rxSyncDone,
         txpmaresetdone_out(0)                 => txPmaResetDone,
         txresetdone_out(0)                    => txResetDone);

      TIMING_RECCLK_BUFG_GT : BUFG_GT
         port map (
            I       => rxOutClkGt,
            CE      => '1',
            CEMASK  => '1',
            CLR     => '0',
            CLRMASK => '1',
            DIV     => "000",
            O       => rxOutClkB);

      -- if one does not use the userRefClk for the txOutClk, placement errors occur
      txOutClkB <= gtUserRefClk;

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => 2,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteMasters(1) => mAxilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiWriteSlaves(1)  => mAxilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadMasters(1)  => mAxilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         sAxiReadSlaves(1)   => mAxilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_AlignCheck : entity surf.GtRxAlignCheck
      generic map (
         TPD_G          => TPD_G,
         GT_TYPE_G      => "GTYE4",
         AXI_CLK_FREQ_G => AXI_CLK_FREQ_G,
         DRP_ADDR_G     => AXI_CROSSBAR_MASTERS_CONFIG_C(1).baseAddr)
      port map (
         -- Clock Monitoring
         txClk            => txUsrClk,
         rxClk            => rxUsrClk,
         refClk           => gtUserRefClk,
         -- GTH Status/Control Interface
         resetIn          => rxReset,
         resetDone        => buffBypassRxDone,
         resetErr         => buffBypassRxError,
         resetOut         => rxResetAlignCheck,
         locked           => rxStatusLocked,
         -- Clock and Reset
         axilClk          => axilClk,
         axilRst          => axilRst,
         -- Slave AXI-Lite Interface
         mAxilReadMaster  => mAxilReadMaster,
         mAxilReadSlave   => mAxilReadSlave,
         mAxilWriteMaster => mAxilWriteMaster,
         mAxilWriteSlave  => mAxilWriteSlave,
         -- Slave AXI-Lite Interface
         sAxilReadMaster  => axilReadMasters(0),
         sAxilReadSlave   => axilReadSlaves(0),
         sAxilWriteMaster => axilWriteMasters(0),
         sAxilWriteSlave  => axilWriteSlaves(0));

   U_AxiLiteToDrp_1 : entity surf.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => false,
         EN_ARBITRATION_G => false,
         ADDR_WIDTH_G     => 10,
         DATA_WIDTH_G     => 16)
      port map (
         axilClk         => axilClk,             -- [in]
         axilRst         => axilRst,             -- [in]
         axilReadMaster  => axilReadMasters(1),  -- [in]
         axilReadSlave   => axilReadSlaves(1),   -- [out]
         axilWriteMaster => axilWriteMasters(1), -- [in]
         axilWriteSlave  => axilWriteSlaves(1),  -- [out]
         drpClk          => stableClk,           -- [in]
         drpRst          => stableRst,           -- [in]
         drpReq          => open,                -- [out]
         drpRdy          => drpRdy,              -- [in]
         drpEn           => drpEn,               -- [out]
         drpWe           => drpWe,               -- [out]
         drpUsrRst       => open,                -- [out]
         drpAddr         => drpAddr,             -- [out]
         drpDi           => drpDi,               -- [out]
         drpDo           => drpDo);              -- [in]

   txctrl2           <= "000000" & txDataK;
   txUsrActive       <= txUsrClkActive and txPmaResetDone;
   rxUsrActive       <= rxUsrClkActive and rxPmaResetDone;

   cPllRefClkSel     <= ite(SEL_FABRIC_REFCLK_G, "111", "001");

   rstSyncRxIn       <= ite(USE_ALIGN_CHECK_G, rxResetAlignCheck, rxReset);
   rxResetGt         <= ite(USE_ALIGN_CHECK_G, rxResetAlignCheck, rxReset);

   txOutClk          <= txOutClkB;
   rxOutClk          <= rxOutClkB;

   U_RstSyncTx : entity surf.RstSync
      generic map (TPD_G => TPD_G)
      port map (clk      => gtUserRefClk,
                asyncRst => txReset,
                syncRst  => buffBypassTxReset);

   U_RstSyncRx : entity surf.RstSync
      generic map (TPD_G => TPD_G)
      port map (clk      => gtUserRefClk,
                asyncRst => rstSyncRxIn,
                syncRst  => buffBypassRxReset);

end architecture mapping;
