-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTP7 IP Core Wrapper
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
use surf.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp3Gtp7IpWrapper is
   generic (
      TPD_G            : time    := 1 ns;
      EN_DRP_G         : boolean := true;
      RATE_G           : string  := "6.25Gbps";  -- or "3.125Gbps"
      CLKIN_PERIOD_G   : real;
      BANDWIDTH_G      : string;
      CLKFBOUT_MULT_G  : positive;
      CLKOUT0_DIVIDE_G : positive;
      CLKOUT1_DIVIDE_G : positive;
      CLKOUT2_DIVIDE_G : positive;
      TX_POLARITY_G    : sl      := '0';
      RX_POLARITY_G    : sl      := '0');
   port (
      stableClk       : in  sl;
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
      -- GTH FPGA IO
      gtRxP           : in  sl;
      gtRxN           : in  sl;
      gtTxP           : out sl;
      gtTxN           : out sl;
      -- Rx ports
      rxUsrClk        : out sl;
      rxUsrClkRst     : out sl;
      rxReset         : in  sl;
      rxResetDone     : out sl;
      rxValid         : out sl;
      rxHeader        : out slv(1 downto 0);
      rxData          : out slv(63 downto 0);
      rxSlip          : in  sl;
      rxAligned       : in  sl;
      -- Tx Ports
      txUsrClk        : out sl;
      txUsrClkRst     : out sl;
      txReset         : in  sl;
      txResetDone     : out sl;
      txHeader        : in  slv(1 downto 0);
      txData          : in  slv(63 downto 0);
      txValid         : in  sl;
      txReady         : out sl;
      -- Debug Interface
      loopback        : in  slv(2 downto 0);
      txDiffCtrl      : in  slv(4 downto 0);
      txPreCursor     : in  slv(4 downto 0);
      txPostCursor    : in  slv(4 downto 0);
      -- AXI-Lite DRP Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end entity Pgp3Gtp7IpWrapper;

architecture mapping of Pgp3Gtp7IpWrapper is

   component Pgp3Gtp7Ip6G
      port (
         SYSCLK_IN                   : in  std_logic;
         SOFT_RESET_TX_IN            : in  std_logic;
         SOFT_RESET_RX_IN            : in  std_logic;
         DONT_RESET_ON_DATA_ERROR_IN : in  std_logic;
         GT0_TX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_RX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_DRP_BUSY_OUT            : out std_logic;
         GT0_DATA_VALID_IN           : in  std_logic;
         GT0_TX_MMCM_LOCK_IN         : in  std_logic;
         GT0_TX_MMCM_RESET_OUT       : out std_logic;
         GT0_RX_MMCM_LOCK_IN         : in  std_logic;
         GT0_RX_MMCM_RESET_OUT       : out std_logic;
         --____________________________CHANNEL PORTS________________________________
         ---------------------------- Channel - DRP Ports  --------------------------
         gt0_drpaddr_in              : in  std_logic_vector(8 downto 0);
         gt0_drpclk_in               : in  std_logic;
         gt0_drpdi_in                : in  std_logic_vector(15 downto 0);
         gt0_drpdo_out               : out std_logic_vector(15 downto 0);
         gt0_drpen_in                : in  std_logic;
         gt0_drprdy_out              : out std_logic;
         gt0_drpwe_in                : in  std_logic;
         ------------------------------- Loopback Ports -----------------------------
         gt0_loopback_in             : in  std_logic_vector(2 downto 0);
         --------------------- RX Initialization and Reset Ports --------------------
         gt0_eyescanreset_in         : in  std_logic;
         gt0_rxuserrdy_in            : in  std_logic;
         -------------------------- RX Margin Analysis Ports ------------------------
         gt0_eyescandataerror_out    : out std_logic;
         gt0_eyescantrigger_in       : in  std_logic;
         ------------------------- Receive Ports - CDR Ports ------------------------
         gt0_rxcdrovrden_in          : in  std_logic;
         ------------------ Receive Ports - FPGA RX Interface Ports -----------------
         gt0_rxdata_out              : out std_logic_vector(31 downto 0);
         gt0_rxusrclk_in             : in  std_logic;
         gt0_rxusrclk2_in            : in  std_logic;
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         gt0_gtprxn_in               : in  std_logic;
         gt0_gtprxp_in               : in  std_logic;
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         gt0_rxbufreset_in           : in  std_logic;
         gt0_rxphmonitor_out         : out std_logic_vector(4 downto 0);
         gt0_rxphslipmonitor_out     : out std_logic_vector(4 downto 0);
         ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
         gt0_dmonitorout_out         : out std_logic_vector(14 downto 0);
         -------------------- Receive Ports - RX Equailizer Ports -------------------
         gt0_rxlpmhfhold_in          : in  std_logic;
         gt0_rxlpmhfovrden_in        : in  std_logic;
         gt0_rxlpmlfhold_in          : in  std_logic;
         --------------- Receive Ports - RX Fabric Output Control Ports -------------
         gt0_rxoutclk_out            : out std_logic;
         gt0_rxoutclkfabric_out      : out std_logic;
         ---------------------- Receive Ports - RX Gearbox Ports --------------------
         gt0_rxdatavalid_out         : out std_logic;
         gt0_rxheader_out            : out std_logic_vector(1 downto 0);
         gt0_rxheadervalid_out       : out std_logic;
         --------------------- Receive Ports - RX Gearbox Ports  --------------------
         gt0_rxgearboxslip_in        : in  std_logic;
         ------------- Receive Ports - RX Initialization and Reset Ports ------------
         gt0_gtrxreset_in            : in  std_logic;
         gt0_rxlpmreset_in           : in  std_logic;
         gt0_rxpcsreset_in           : in  std_logic;
         gt0_rxpmareset_in           : in  std_logic;
         ----------------- Receive Ports - RX Polarity Control Ports ----------------
         gt0_rxpolarity_in           : in  std_logic;
         -------------- Receive Ports -RX Initialization and Reset Ports ------------
         gt0_rxresetdone_out         : out std_logic;
         ------------------------ TX Configurable Driver Ports ----------------------
         gt0_txpostcursor_in         : in  std_logic_vector(4 downto 0);
         gt0_txprecursor_in          : in  std_logic_vector(4 downto 0);
         --------------------- TX Initialization and Reset Ports --------------------
         gt0_gttxreset_in            : in  std_logic;
         gt0_txuserrdy_in            : in  std_logic;
         ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
         gt0_txdata_in               : in  std_logic_vector(31 downto 0);
         gt0_txusrclk_in             : in  std_logic;
         gt0_txusrclk2_in            : in  std_logic;
         --------------- Transmit Ports - TX Configurable Driver Ports --------------
         gt0_gtptxn_out              : out std_logic;
         gt0_gtptxp_out              : out std_logic;
         gt0_txdiffctrl_in           : in  std_logic_vector(3 downto 0);
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         gt0_txoutclk_out            : out std_logic;
         gt0_txoutclkfabric_out      : out std_logic;
         gt0_txoutclkpcs_out         : out std_logic;
         --------------------- Transmit Ports - TX Gearbox Ports --------------------
         gt0_txheader_in             : in  std_logic_vector(1 downto 0);
         gt0_txsequence_in           : in  std_logic_vector(6 downto 0);
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         gt0_txpcsreset_in           : in  std_logic;
         gt0_txpmareset_in           : in  std_logic;
         gt0_txresetdone_out         : out std_logic;
         ----------------- Transmit Ports - TX Polarity Control Ports ---------------
         gt0_txpolarity_in           : in  std_logic;
         --____________________________COMMON PORTS________________________________
         GT0_PLL0OUTCLK_IN           : in  std_logic;
         GT0_PLL0OUTREFCLK_IN        : in  std_logic;
         GT0_PLL0RESET_OUT           : out std_logic;
         GT0_PLL0LOCK_IN             : in  std_logic;
         GT0_PLL0REFCLKLOST_IN       : in  std_logic;
         GT0_PLL1OUTCLK_IN           : in  std_logic;
         GT0_PLL1OUTREFCLK_IN        : in  std_logic
         );
   end component;

   component Pgp3Gtp7Ip3G
      port (
         SYSCLK_IN                   : in  std_logic;
         SOFT_RESET_TX_IN            : in  std_logic;
         SOFT_RESET_RX_IN            : in  std_logic;
         DONT_RESET_ON_DATA_ERROR_IN : in  std_logic;
         GT0_TX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_RX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_DRP_BUSY_OUT            : out std_logic;
         GT0_DATA_VALID_IN           : in  std_logic;
         GT0_TX_MMCM_LOCK_IN         : in  std_logic;
         GT0_TX_MMCM_RESET_OUT       : out std_logic;
         GT0_RX_MMCM_LOCK_IN         : in  std_logic;
         GT0_RX_MMCM_RESET_OUT       : out std_logic;
         --____________________________CHANNEL PORTS________________________________
         ---------------------------- Channel - DRP Ports  --------------------------
         gt0_drpaddr_in              : in  std_logic_vector(8 downto 0);
         gt0_drpclk_in               : in  std_logic;
         gt0_drpdi_in                : in  std_logic_vector(15 downto 0);
         gt0_drpdo_out               : out std_logic_vector(15 downto 0);
         gt0_drpen_in                : in  std_logic;
         gt0_drprdy_out              : out std_logic;
         gt0_drpwe_in                : in  std_logic;
         ------------------------------- Loopback Ports -----------------------------
         gt0_loopback_in             : in  std_logic_vector(2 downto 0);
         --------------------- RX Initialization and Reset Ports --------------------
         gt0_eyescanreset_in         : in  std_logic;
         gt0_rxuserrdy_in            : in  std_logic;
         -------------------------- RX Margin Analysis Ports ------------------------
         gt0_eyescandataerror_out    : out std_logic;
         gt0_eyescantrigger_in       : in  std_logic;
         ------------------------- Receive Ports - CDR Ports ------------------------
         gt0_rxcdrovrden_in          : in  std_logic;
         ------------------ Receive Ports - FPGA RX Interface Ports -----------------
         gt0_rxdata_out              : out std_logic_vector(31 downto 0);
         gt0_rxusrclk_in             : in  std_logic;
         gt0_rxusrclk2_in            : in  std_logic;
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         gt0_gtprxn_in               : in  std_logic;
         gt0_gtprxp_in               : in  std_logic;
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         gt0_rxbufreset_in           : in  std_logic;
         gt0_rxphmonitor_out         : out std_logic_vector(4 downto 0);
         gt0_rxphslipmonitor_out     : out std_logic_vector(4 downto 0);
         ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
         gt0_dmonitorout_out         : out std_logic_vector(14 downto 0);
         -------------------- Receive Ports - RX Equailizer Ports -------------------
         gt0_rxlpmhfhold_in          : in  std_logic;
         gt0_rxlpmhfovrden_in        : in  std_logic;
         gt0_rxlpmlfhold_in          : in  std_logic;
         --------------- Receive Ports - RX Fabric Output Control Ports -------------
         gt0_rxoutclk_out            : out std_logic;
         gt0_rxoutclkfabric_out      : out std_logic;
         ---------------------- Receive Ports - RX Gearbox Ports --------------------
         gt0_rxdatavalid_out         : out std_logic;
         gt0_rxheader_out            : out std_logic_vector(1 downto 0);
         gt0_rxheadervalid_out       : out std_logic;
         --------------------- Receive Ports - RX Gearbox Ports  --------------------
         gt0_rxgearboxslip_in        : in  std_logic;
         ------------- Receive Ports - RX Initialization and Reset Ports ------------
         gt0_gtrxreset_in            : in  std_logic;
         gt0_rxlpmreset_in           : in  std_logic;
         gt0_rxpcsreset_in           : in  std_logic;
         gt0_rxpmareset_in           : in  std_logic;
         ----------------- Receive Ports - RX Polarity Control Ports ----------------
         gt0_rxpolarity_in           : in  std_logic;
         -------------- Receive Ports -RX Initialization and Reset Ports ------------
         gt0_rxresetdone_out         : out std_logic;
         ------------------------ TX Configurable Driver Ports ----------------------
         gt0_txpostcursor_in         : in  std_logic_vector(4 downto 0);
         gt0_txprecursor_in          : in  std_logic_vector(4 downto 0);
         --------------------- TX Initialization and Reset Ports --------------------
         gt0_gttxreset_in            : in  std_logic;
         gt0_txuserrdy_in            : in  std_logic;
         ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
         gt0_txdata_in               : in  std_logic_vector(31 downto 0);
         gt0_txusrclk_in             : in  std_logic;
         gt0_txusrclk2_in            : in  std_logic;
         --------------- Transmit Ports - TX Configurable Driver Ports --------------
         gt0_gtptxn_out              : out std_logic;
         gt0_gtptxp_out              : out std_logic;
         gt0_txdiffctrl_in           : in  std_logic_vector(3 downto 0);
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         gt0_txoutclk_out            : out std_logic;
         gt0_txoutclkfabric_out      : out std_logic;
         gt0_txoutclkpcs_out         : out std_logic;
         --------------------- Transmit Ports - TX Gearbox Ports --------------------
         gt0_txheader_in             : in  std_logic_vector(1 downto 0);
         gt0_txsequence_in           : in  std_logic_vector(6 downto 0);
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         gt0_txpcsreset_in           : in  std_logic;
         gt0_txpmareset_in           : in  std_logic;
         gt0_txresetdone_out         : out std_logic;
         ----------------- Transmit Ports - TX Polarity Control Ports ---------------
         gt0_txpolarity_in           : in  std_logic;
         --____________________________COMMON PORTS________________________________
         GT0_PLL0OUTCLK_IN           : in  std_logic;
         GT0_PLL0OUTREFCLK_IN        : in  std_logic;
         GT0_PLL0RESET_OUT           : out std_logic;
         GT0_PLL0LOCK_IN             : in  std_logic;
         GT0_PLL0REFCLKLOST_IN       : in  std_logic;
         GT0_PLL1OUTCLK_IN           : in  std_logic;
         GT0_PLL1OUTREFCLK_IN        : in  std_logic
         );
   end component;

   signal gtRxOutClk     : sl;
   signal gtRxOutClkBufg : sl;
   signal clkFb          : sl;
   signal gtRxPllRst     : sl;
   signal gtRxPllLock    : sl;
   signal rxSlipGearbox  : sl;

   signal pllOut   : slv(2 downto 1);
   signal rxPllClk : slv(2 downto 1);
   signal rxPllRst : slv(2 downto 1);

   signal rxUsrClkInt  : sl;
   signal rxUsrClk2Int : sl;

   signal txUsrClkInt  : sl;
   signal txUsrClk2Int : sl;

   signal drpAddr : slv(8 downto 0)  := (others => '0');
   signal drpDi   : slv(15 downto 0) := (others => '0');
   signal drpDo   : slv(15 downto 0) := (others => '0');
   signal drpEn   : sl               := '0';
   signal drpWe   : sl               := '0';
   signal drpRdy  : sl               := '0';

   signal txHeaderGearbox   : slv(1 downto 0);
   signal txDataGearbox     : slv(31 downto 0);
   signal txSequenceGearbox : slv(6 downto 0);

   signal rxHeaderValidGearbox : sl;
   signal rxHeaderGearbox      : slv(1 downto 0);
   signal rxDataValidGearbox   : sl;
   signal rxDataGearbox        : slv(31 downto 0);

begin

   rxUsrClk    <= txPllClk(0);
   rxUsrClkRst <= txPllRst(0);

   txUsrClk    <= txPllClk(0);
   txUsrClkRst <= txPllRst(0);

   U_Bufg : BUFG
      port map (
         I => gtRxOutClk,
         O => gtRxOutClkBufg);

   U_RX_PLL : PLLE2_ADV
      generic map (
         BANDWIDTH      => BANDWIDTH_G,
         CLKIN1_PERIOD  => CLKIN_PERIOD_G,
         DIVCLK_DIVIDE  => 1,
         CLKFBOUT_MULT  => CLKFBOUT_MULT_G,
         CLKOUT0_DIVIDE => CLKOUT0_DIVIDE_G,
         CLKOUT1_DIVIDE => CLKOUT1_DIVIDE_G,
         CLKOUT2_DIVIDE => CLKOUT2_DIVIDE_G)
      port map (
         DCLK     => axilClk,
         DRDY     => open,
         DEN      => '0',
         DWE      => '0',
         DADDR    => (others => '0'),
         DI       => (others => '0'),
         DO       => open,
         PWRDWN   => '0',
         RST      => gtRxPllRst,
         CLKIN1   => gtRxOutClkBufg,
         CLKIN2   => '0',
         CLKINSEL => '1',
         CLKFBOUT => clkFb,
         CLKFBIN  => clkFb,
         LOCKED   => gtRxPllLock,
         CLKOUT0  => open,
         CLKOUT1  => pllOut(1),
         CLKOUT2  => pllOut(2));

   U_rxPllClk1 : BUFG
      port map (
         I => pllOut(1),
         O => rxPllClk(1));

   U_rxPllClk2 : BUFG
      port map (
         I => pllOut(2),
         O => rxPllClk(2));

   GEN_RST : for i in 2 downto 1 generate
      U_RstSync : entity surf.RstSync
         generic map (
            TPD_G          => TPD_G,
            IN_POLARITY_G  => '0',
            OUT_POLARITY_G => '1')
         port map (
            clk      => rxPllClk(i),
            asyncRst => gtRxPllLock,
            syncRst  => rxPllRst(i));
   end generate;

   rxUsrClkInt  <= rxPllClk(1);
   rxUsrClk2Int <= rxPllClk(2);

   txUsrClkInt  <= txPllClk(1);
   txUsrClk2Int <= txPllClk(2);

   U_TxGearbox : entity surf.Pgp3Gtp7TxGearbox
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Slave Interface
         phyTxClkSlow => txPllClk(0),
         phyTxRstSlow => txPllRst(0),
         phyTxHeader  => txHeader,
         phyTxData    => txData,
         phyTxValid   => txValid,
         phyTxDataRdy => txReady,
         -- Master Interface
         phyTxClkFast => txPllClk(2),
         phyTxRstFast => txPllRst(2),
         txHeader     => txHeaderGearbox,
         txData       => txDataGearbox,
         txSequence   => txSequenceGearbox);

   U_RxGearbox : entity surf.Pgp3Gtp7RxGearbox
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Slave Interface
         phyRxClkFast  => rxPllClk(2),
         phyRxRstFast  => rxPllRst(2),
         rxHeaderValid => rxHeaderValidGearbox,
         rxHeader      => rxHeaderGearbox,
         rxDataValid   => rxDataValidGearbox,
         rxData        => rxDataGearbox,
         -- Master Interface
         phyRxClkSlow  => txPllClk(0),
         phyRxRstSlow  => txPllRst(0),
         phyRxValid    => rxValid,
         phyRxHeader   => rxHeader,
         phyRxData     => rxData);

   U_RxSlip : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => rxUsrClk2Int,
         dataIn  => rxSlip,
         dataOut => rxSlipGearbox);

   GEN_6G : if (RATE_G = "6.25Gbps") generate
      U_Pgp3Gtp7Ip6G : Pgp3Gtp7Ip6G
         port map (
            SYSCLK_IN                   => stableClk,
            SOFT_RESET_TX_IN            => txReset,
            SOFT_RESET_RX_IN            => rxReset,
            DONT_RESET_ON_DATA_ERROR_IN => '0',
            GT0_TX_FSM_RESET_DONE_OUT   => txResetDone,
            GT0_RX_FSM_RESET_DONE_OUT   => rxResetDone,
            GT0_DATA_VALID_IN           => rxAligned,
            GT0_DRP_BUSY_OUT            => open,
            GT0_TX_MMCM_LOCK_IN         => gtTxPllLock,
            GT0_TX_MMCM_RESET_OUT       => gtTxPllRst,
            GT0_RX_MMCM_LOCK_IN         => gtRxPllLock,
            GT0_RX_MMCM_RESET_OUT       => gtRxPllRst,
            --_________________________________________________________________________
            --GT0  (X0Y0)
            --____________________________CHANNEL PORTS________________________________
            ---------------------------- Channel - DRP Ports  --------------------------
            gt0_drpaddr_in              => drpAddr,
            gt0_drpclk_in               => stableClk,
            gt0_drpdi_in                => drpDi,
            gt0_drpdo_out               => drpDo,
            gt0_drpen_in                => drpEn,
            gt0_drprdy_out              => drpRdy,
            gt0_drpwe_in                => drpWe,
            --------------------------- Digital Monitor Ports --------------------------
            gt0_dmonitorout_out         => open,
            ------------------------------- Loopback Ports -----------------------------
            gt0_loopback_in             => loopback,
            --------------------- RX Initialization and Reset Ports --------------------
            gt0_eyescanreset_in         => '0',
            gt0_rxuserrdy_in            => '1',
            -------------------------- RX Margin Analysis Ports ------------------------
            gt0_eyescandataerror_out    => open,
            gt0_eyescantrigger_in       => '0',
            ------------------------- Receive Ports - CDR Ports ------------------------
            gt0_rxcdrovrden_in          => '0',
            ------------------ Receive Ports - FPGA RX Interface Ports -----------------
            gt0_rxusrclk_in             => rxUsrClkInt,  -- 390.62 MHz (2.56 ns period)
            gt0_rxusrclk2_in            => rxUsrClk2Int,  -- 195.31 MHz (5.12 ns period)
            ------------------ Receive Ports - FPGA RX interface Ports -----------------
            gt0_rxdata_out              => rxDataGearbox,
            --------------------------- Receive Ports - RX AFE -------------------------
            gt0_gtprxp_in               => gtRxP,
            ------------------------ Receive Ports - RX AFE Ports ----------------------
            gt0_gtprxn_in               => gtRxN,
            ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
            gt0_rxbufreset_in           => '0',
            gt0_rxphmonitor_out         => open,
            gt0_rxphslipmonitor_out     => open,
            --------------------- Receive Ports - RX Equalizer Ports -------------------
            gt0_rxlpmhfhold_in          => '0',
            gt0_rxlpmhfovrden_in        => '0',
            gt0_rxlpmlfhold_in          => '0',
            --------------- Receive Ports - RX Fabric Output Control Ports -------------
            gt0_rxoutclk_out            => gtRxOutClk,  -- 390.62 MHz (2.56 ns period)
            gt0_rxoutclkfabric_out      => open,  -- 156.25 MHz (6.400 ns period)
            ---------------------- Receive Ports - RX Gearbox Ports --------------------
            gt0_rxdatavalid_out         => rxDataValidGearbox,
            gt0_rxheader_out            => rxHeaderGearbox,
            gt0_rxheadervalid_out       => rxHeaderValidGearbox,
            --------------------- Receive Ports - RX Gearbox Ports  --------------------
            gt0_rxgearboxslip_in        => rxSlipGearbox,
            ------------- Receive Ports - RX Initialization and Reset Ports ------------
            gt0_gtrxreset_in            => '0',
            gt0_rxlpmreset_in           => '0',
            gt0_rxpcsreset_in           => '0',
            gt0_rxpmareset_in           => '0',
            ----------------- Receive Ports - RX Polarity Control Ports ----------------
            gt0_rxpolarity_in           => RX_POLARITY_G,
            -------------- Receive Ports -RX Initialization and Reset Ports ------------
            gt0_rxresetdone_out         => open,
            ------------------------ TX Configurable Driver Ports ----------------------
            gt0_txpostcursor_in         => txPostCursor,
            gt0_txprecursor_in          => txPreCursor,
            --------------------- TX Initialization and Reset Ports --------------------
            gt0_gttxreset_in            => '0',
            gt0_txuserrdy_in            => '1',
            ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
            gt0_txusrclk_in             => txUsrClkInt,  -- 390.62 MHz (2.56 ns period)
            gt0_txusrclk2_in            => txUsrClk2Int,  -- 195.31 MHz (5.12 ns period)
            --------------- Transmit Ports - TX Configurable Driver Ports --------------
            gt0_txdiffctrl_in           => txDiffCtrl(4 downto 1),
            ------------------ Transmit Ports - TX Data Path interface -----------------
            gt0_txdata_in               => txDataGearbox,
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gtptxn_out              => gtTxN,
            gt0_gtptxp_out              => gtTxP,
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclk_out            => gtTxOutClk,  -- 390.62 MHz (2.56 ns period)
            gt0_txoutclkfabric_out      => open,  -- 156.25 MHz (6.4 ns period)
            gt0_txoutclkpcs_out         => open,
            --------------------- Transmit Ports - TX Gearbox Ports --------------------
            gt0_txheader_in             => txHeaderGearbox,
            gt0_txsequence_in           => txSequenceGearbox,
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txpcsreset_in           => '0',
            gt0_txpmareset_in           => '0',
            gt0_txresetdone_out         => open,
            ----------------- Transmit Ports - TX Polarity Control Ports ---------------
            gt0_txpolarity_in           => TX_POLARITY_G,
            --____________________________COMMON PORTS________________________________
            GT0_PLL0OUTCLK_IN           => qPllOutClk(0),
            GT0_PLL0OUTREFCLK_IN        => qPllOutRefClk(0),
            GT0_PLL0RESET_OUT           => qpllRst(0),
            GT0_PLL0LOCK_IN             => qpllLock(0),
            GT0_PLL0REFCLKLOST_IN       => qPllRefClkLost(0),
            GT0_PLL1OUTCLK_IN           => qPllOutClk(1),
            GT0_PLL1OUTREFCLK_IN        => qPllOutRefClk(1));
      qpllRst(1) <= '0';
   end generate;

   GEN_3G : if (RATE_G = "3.125Gbps") generate
      U_Pgp3Gtp7Ip3G : Pgp3Gtp7Ip3G
         port map (
            SYSCLK_IN                   => stableClk,
            SOFT_RESET_TX_IN            => txReset,
            SOFT_RESET_RX_IN            => rxReset,
            DONT_RESET_ON_DATA_ERROR_IN => '0',
            GT0_TX_FSM_RESET_DONE_OUT   => txResetDone,
            GT0_RX_FSM_RESET_DONE_OUT   => rxResetDone,
            GT0_DATA_VALID_IN           => rxAligned,
            GT0_DRP_BUSY_OUT            => open,
            GT0_TX_MMCM_LOCK_IN         => gtTxPllLock,
            GT0_TX_MMCM_RESET_OUT       => gtTxPllRst,
            GT0_RX_MMCM_LOCK_IN         => gtRxPllLock,
            GT0_RX_MMCM_RESET_OUT       => gtRxPllRst,
            --_________________________________________________________________________
            --GT0  (X0Y0)
            --____________________________CHANNEL PORTS________________________________
            ---------------------------- Channel - DRP Ports  --------------------------
            gt0_drpaddr_in              => drpAddr,
            gt0_drpclk_in               => stableClk,
            gt0_drpdi_in                => drpDi,
            gt0_drpdo_out               => drpDo,
            gt0_drpen_in                => drpEn,
            gt0_drprdy_out              => drpRdy,
            gt0_drpwe_in                => drpWe,
            --------------------------- Digital Monitor Ports --------------------------
            gt0_dmonitorout_out         => open,
            ------------------------------- Loopback Ports -----------------------------
            gt0_loopback_in             => loopback,
            --------------------- RX Initialization and Reset Ports --------------------
            gt0_eyescanreset_in         => '0',
            gt0_rxuserrdy_in            => '1',
            -------------------------- RX Margin Analysis Ports ------------------------
            gt0_eyescandataerror_out    => open,
            gt0_eyescantrigger_in       => '0',
            ------------------------- Receive Ports - CDR Ports ------------------------
            gt0_rxcdrovrden_in          => '0',
            ------------------ Receive Ports - FPGA RX Interface Ports -----------------
            gt0_rxusrclk_in             => rxUsrClkInt,  -- 195.31 MHz (5.12 ns period)
            gt0_rxusrclk2_in            => rxUsrClk2Int,  -- 97.655 MHz (10.24 ns period)
            ------------------ Receive Ports - FPGA RX interface Ports -----------------
            gt0_rxdata_out              => rxDataGearbox,
            --------------------------- Receive Ports - RX AFE -------------------------
            gt0_gtprxp_in               => gtRxP,
            ------------------------ Receive Ports - RX AFE Ports ----------------------
            gt0_gtprxn_in               => gtRxN,
            ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
            gt0_rxbufreset_in           => '0',
            gt0_rxphmonitor_out         => open,
            gt0_rxphslipmonitor_out     => open,
            --------------------- Receive Ports - RX Equalizer Ports -------------------
            gt0_rxlpmhfhold_in          => '0',
            gt0_rxlpmhfovrden_in        => '0',
            gt0_rxlpmlfhold_in          => '0',
            --------------- Receive Ports - RX Fabric Output Control Ports -------------
            gt0_rxoutclk_out            => gtRxOutClk,  -- 195.31 MHz (5.12 ns period)
            gt0_rxoutclkfabric_out      => open,  -- 156.25 MHz (6.400 ns period)
            ---------------------- Receive Ports - RX Gearbox Ports --------------------
            gt0_rxdatavalid_out         => rxDataValidGearbox,
            gt0_rxheader_out            => rxHeaderGearbox,
            gt0_rxheadervalid_out       => rxHeaderValidGearbox,
            --------------------- Receive Ports - RX Gearbox Ports  --------------------
            gt0_rxgearboxslip_in        => rxSlipGearbox,
            ------------- Receive Ports - RX Initialization and Reset Ports ------------
            gt0_gtrxreset_in            => '0',
            gt0_rxlpmreset_in           => '0',
            gt0_rxpcsreset_in           => '0',
            gt0_rxpmareset_in           => '0',
            ----------------- Receive Ports - RX Polarity Control Ports ----------------
            gt0_rxpolarity_in           => RX_POLARITY_G,
            -------------- Receive Ports -RX Initialization and Reset Ports ------------
            gt0_rxresetdone_out         => open,
            ------------------------ TX Configurable Driver Ports ----------------------
            gt0_txpostcursor_in         => txPostCursor,
            gt0_txprecursor_in          => txPreCursor,
            --------------------- TX Initialization and Reset Ports --------------------
            gt0_gttxreset_in            => '0',
            gt0_txuserrdy_in            => '1',
            ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
            gt0_txusrclk_in             => txUsrClkInt,  -- 195.31 MHz (5.12 ns period)
            gt0_txusrclk2_in            => txUsrClk2Int,  -- 97.655 MHz (10.24 ns period)
            --------------- Transmit Ports - TX Configurable Driver Ports --------------
            gt0_txdiffctrl_in           => txDiffCtrl(4 downto 1),
            ------------------ Transmit Ports - TX Data Path interface -----------------
            gt0_txdata_in               => txDataGearbox,
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gtptxn_out              => gtTxN,
            gt0_gtptxp_out              => gtTxP,
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclk_out            => gtTxOutClk,  -- 195.31 MHz (5.12 ns period)
            gt0_txoutclkfabric_out      => open,  -- 156.25 MHz (6.4 ns period)
            gt0_txoutclkpcs_out         => open,
            --------------------- Transmit Ports - TX Gearbox Ports --------------------
            gt0_txheader_in             => txHeaderGearbox,
            gt0_txsequence_in           => txSequenceGearbox,
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txpcsreset_in           => '0',
            gt0_txpmareset_in           => '0',
            gt0_txresetdone_out         => open,
            ----------------- Transmit Ports - TX Polarity Control Ports ---------------
            gt0_txpolarity_in           => TX_POLARITY_G,
            --____________________________COMMON PORTS________________________________
            GT0_PLL0OUTCLK_IN           => qPllOutClk(0),
            GT0_PLL0OUTREFCLK_IN        => qPllOutRefClk(0),
            GT0_PLL0RESET_OUT           => qpllRst(0),
            GT0_PLL0LOCK_IN             => qpllLock(0),
            GT0_PLL0REFCLKLOST_IN       => qPllRefClkLost(0),
            GT0_PLL1OUTCLK_IN           => qPllOutClk(1),
            GT0_PLL1OUTREFCLK_IN        => qPllOutRefClk(1));
      qpllRst(1) <= '0';
   end generate;

   GEN_DRP : if (EN_DRP_G) generate
      U_AxiLiteToDrp_1 : entity surf.AxiLiteToDrp
         generic map (
            TPD_G            => TPD_G,
            COMMON_CLK_G     => false,
            EN_ARBITRATION_G => false,
            ADDR_WIDTH_G     => 9,
            DATA_WIDTH_G     => 16)
         port map (
            axilClk         => axilClk,          -- [in]
            axilRst         => axilRst,          -- [in]
            axilReadMaster  => axilReadMaster,   -- [in]
            axilReadSlave   => axilReadSlave,    -- [out]
            axilWriteMaster => axilWriteMaster,  -- [in]
            axilWriteSlave  => axilWriteSlave,   -- [out]
            drpClk          => stableClk,        -- [in]
            drpRst          => stableRst,        -- [in]
            drpReq          => open,             -- [out]
            drpRdy          => drpRdy,           -- [in]
            drpEn           => drpEn,            -- [out]
            drpWe           => drpWe,            -- [out]
            drpUsrRst       => open,             -- [out]
            drpAddr         => drpAddr,          -- [out]
            drpDi           => drpDi,            -- [out]
            drpDo           => drpDo);           -- [in]
   end generate;

end mapping;
