-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTX7 IP Core Wrapper
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

entity Pgp3Gtx7IpWrapper is
   generic (
      TPD_G         : time    := 1 ns;
      EN_DRP_G      : boolean := true;
      RATE_G        : string  := "10.3125Gbps";  -- or "6.25Gbps" or "3.125Gbps"
      TX_POLARITY_G : sl      := '0';
      RX_POLARITY_G : sl      := '0');
   port (
      stableClk       : in  sl;
      stableRst       : in  sl;
      -- QPLL Interface
      qpllLock        : in  sl;
      qpllclk         : in  sl;
      qpllrefclk      : in  sl;
      qpllRefClkLost  : in  sl;
      qpllRst         : out sl;
      -- TX PLL Interface
      gtTxOutClk      : out sl;
      gtTxPllRst      : out sl;
      txPllClk        : in  slv(1 downto 0);
      txPllRst        : in  slv(1 downto 0);
      gtTxPllLock     : in  sl;
      -- GTH FPGA IO
      gtRxP           : in  sl;
      gtRxN           : in  sl;
      gtTxP           : out sl;
      gtTxN           : out sl;
      -- Rx ports
      rxReset         : in  sl;
      rxResetDone     : out sl;
      rxUsrClk        : out sl;
      rxUsrClk2       : out sl;
      rxUsrClkRst     : out sl;
      rxData          : out slv(63 downto 0);
      rxDataValid     : out sl;
      rxHeader        : out slv(1 downto 0);
      rxHeaderValid   : out sl;
      rxGearboxSlip   : in  sl;
      -- Tx Ports
      txReset         : in  sl;
      txResetDone     : out sl;
      txUsrClk        : out sl;
      txUsrClk2       : out sl;
      txUsrClkRst     : out sl;
      txDataRdy       : out sl;
      txData          : in  slv(63 downto 0);
      txHeader        : in  slv(1 downto 0);
      txStart         : in  sl;
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
end entity Pgp3Gtx7IpWrapper;

architecture mapping of Pgp3Gtx7IpWrapper is

   component Pgp3Gtx7Ip10G
      port (
         SYSCLK_IN                   : in  std_logic;
         SOFT_RESET_TX_IN            : in  std_logic;
         SOFT_RESET_RX_IN            : in  std_logic;
         DONT_RESET_ON_DATA_ERROR_IN : in  std_logic;
         GT0_TX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_RX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_DATA_VALID_IN           : in  std_logic;
         GT0_TX_MMCM_LOCK_IN         : in  std_logic;
         GT0_TX_MMCM_RESET_OUT       : out std_logic;
         GT0_RX_MMCM_LOCK_IN         : in  std_logic;
         GT0_RX_MMCM_RESET_OUT       : out std_logic;
         --_________________________________________________________________________
         --GT0  (X0Y0)
         --____________________________CHANNEL PORTS________________________________
         ---------------------------- Channel - DRP Ports  --------------------------
         gt0_drpaddr_in              : in  std_logic_vector(8 downto 0);
         gt0_drpclk_in               : in  std_logic;
         gt0_drpdi_in                : in  std_logic_vector(15 downto 0);
         gt0_drpdo_out               : out std_logic_vector(15 downto 0);
         gt0_drpen_in                : in  std_logic;
         gt0_drprdy_out              : out std_logic;
         gt0_drpwe_in                : in  std_logic;
         --------------------------- Digital Monitor Ports --------------------------
         gt0_dmonitorout_out         : out std_logic_vector(7 downto 0);
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
         gt0_rxusrclk_in             : in  std_logic;
         gt0_rxusrclk2_in            : in  std_logic;
         ------------------ Receive Ports - FPGA RX interface Ports -----------------
         gt0_rxdata_out              : out std_logic_vector(63 downto 0);
         --------------------------- Receive Ports - RX AFE -------------------------
         gt0_gtxrxp_in               : in  std_logic;
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         gt0_gtxrxn_in               : in  std_logic;
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         gt0_rxbufreset_in           : in  std_logic;
         --------------------- Receive Ports - RX Equalizer Ports -------------------
         gt0_rxdfelpmreset_in        : in  std_logic;
         gt0_rxmonitorout_out        : out std_logic_vector(6 downto 0);
         gt0_rxmonitorsel_in         : in  std_logic_vector(1 downto 0);
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
         gt0_txusrclk_in             : in  std_logic;
         gt0_txusrclk2_in            : in  std_logic;
         --------------- Transmit Ports - TX Configurable Driver Ports --------------
         gt0_txdiffctrl_in           : in  std_logic_vector(3 downto 0);
         ------------------ Transmit Ports - TX Data Path interface -----------------
         gt0_txdata_in               : in  std_logic_vector(63 downto 0);
         ---------------- Transmit Ports - TX Driver and OOB signaling --------------
         gt0_gtxtxn_out              : out std_logic;
         gt0_gtxtxp_out              : out std_logic;
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         gt0_txoutclk_out            : out std_logic;
         gt0_txoutclkfabric_out      : out std_logic;
         gt0_txoutclkpcs_out         : out std_logic;
         --------------------- Transmit Ports - TX Gearbox Ports --------------------
         gt0_txgearboxready_out      : out std_logic;
         gt0_txheader_in             : in  std_logic_vector(1 downto 0);
         gt0_txstartseq_in           : in  std_logic;
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         gt0_txpcsreset_in           : in  std_logic;
         gt0_txpmareset_in           : in  std_logic;
         gt0_txresetdone_out         : out std_logic;
         ----------------- Transmit Ports - TX Polarity Control Ports ---------------
         gt0_txpolarity_in           : in  std_logic;
         --____________________________COMMON PORTS________________________________
         GT0_QPLLLOCK_IN             : in  std_logic;
         GT0_QPLLREFCLKLOST_IN       : in  std_logic;
         GT0_QPLLRESET_OUT           : out std_logic;
         GT0_QPLLOUTCLK_IN           : in  std_logic;
         GT0_QPLLOUTREFCLK_IN        : in  std_logic
         );
   end component;

   component Pgp3Gtx7Ip6G
      port (
         SYSCLK_IN                   : in  std_logic;
         SOFT_RESET_TX_IN            : in  std_logic;
         SOFT_RESET_RX_IN            : in  std_logic;
         DONT_RESET_ON_DATA_ERROR_IN : in  std_logic;
         GT0_TX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_RX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_DATA_VALID_IN           : in  std_logic;
         GT0_TX_MMCM_LOCK_IN         : in  std_logic;
         GT0_TX_MMCM_RESET_OUT       : out std_logic;
         GT0_RX_MMCM_LOCK_IN         : in  std_logic;
         GT0_RX_MMCM_RESET_OUT       : out std_logic;
         --_________________________________________________________________________
         --GT0  (X0Y0)
         --____________________________CHANNEL PORTS________________________________
         ---------------------------- Channel - DRP Ports  --------------------------
         gt0_drpaddr_in              : in  std_logic_vector(8 downto 0);
         gt0_drpclk_in               : in  std_logic;
         gt0_drpdi_in                : in  std_logic_vector(15 downto 0);
         gt0_drpdo_out               : out std_logic_vector(15 downto 0);
         gt0_drpen_in                : in  std_logic;
         gt0_drprdy_out              : out std_logic;
         gt0_drpwe_in                : in  std_logic;
         --------------------------- Digital Monitor Ports --------------------------
         gt0_dmonitorout_out         : out std_logic_vector(7 downto 0);
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
         gt0_rxusrclk_in             : in  std_logic;
         gt0_rxusrclk2_in            : in  std_logic;
         ------------------ Receive Ports - FPGA RX interface Ports -----------------
         gt0_rxdata_out              : out std_logic_vector(63 downto 0);
         --------------------------- Receive Ports - RX AFE -------------------------
         gt0_gtxrxp_in               : in  std_logic;
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         gt0_gtxrxn_in               : in  std_logic;
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         gt0_rxbufreset_in           : in  std_logic;
         --------------------- Receive Ports - RX Equalizer Ports -------------------
         gt0_rxdfelpmreset_in        : in  std_logic;
         gt0_rxmonitorout_out        : out std_logic_vector(6 downto 0);
         gt0_rxmonitorsel_in         : in  std_logic_vector(1 downto 0);
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
         gt0_txusrclk_in             : in  std_logic;
         gt0_txusrclk2_in            : in  std_logic;
         --------------- Transmit Ports - TX Configurable Driver Ports --------------
         gt0_txdiffctrl_in           : in  std_logic_vector(3 downto 0);
         ------------------ Transmit Ports - TX Data Path interface -----------------
         gt0_txdata_in               : in  std_logic_vector(63 downto 0);
         ---------------- Transmit Ports - TX Driver and OOB signaling --------------
         gt0_gtxtxn_out              : out std_logic;
         gt0_gtxtxp_out              : out std_logic;
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         gt0_txoutclk_out            : out std_logic;
         gt0_txoutclkfabric_out      : out std_logic;
         gt0_txoutclkpcs_out         : out std_logic;
         --------------------- Transmit Ports - TX Gearbox Ports --------------------
         gt0_txgearboxready_out      : out std_logic;
         gt0_txheader_in             : in  std_logic_vector(1 downto 0);
         gt0_txstartseq_in           : in  std_logic;
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         gt0_txpcsreset_in           : in  std_logic;
         gt0_txpmareset_in           : in  std_logic;
         gt0_txresetdone_out         : out std_logic;
         ----------------- Transmit Ports - TX Polarity Control Ports ---------------
         gt0_txpolarity_in           : in  std_logic;
         --____________________________COMMON PORTS________________________________
         GT0_QPLLLOCK_IN             : in  std_logic;
         GT0_QPLLREFCLKLOST_IN       : in  std_logic;
         GT0_QPLLRESET_OUT           : out std_logic;
         GT0_QPLLOUTCLK_IN           : in  std_logic;
         GT0_QPLLOUTREFCLK_IN        : in  std_logic
         );
   end component;

   component Pgp3Gtx7Ip3G
      port (
         SYSCLK_IN                   : in  std_logic;
         SOFT_RESET_TX_IN            : in  std_logic;
         SOFT_RESET_RX_IN            : in  std_logic;
         DONT_RESET_ON_DATA_ERROR_IN : in  std_logic;
         GT0_TX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_RX_FSM_RESET_DONE_OUT   : out std_logic;
         GT0_DATA_VALID_IN           : in  std_logic;
         GT0_TX_MMCM_LOCK_IN         : in  std_logic;
         GT0_TX_MMCM_RESET_OUT       : out std_logic;
         GT0_RX_MMCM_LOCK_IN         : in  std_logic;
         GT0_RX_MMCM_RESET_OUT       : out std_logic;
         --_________________________________________________________________________
         --GT0  (X0Y0)
         --____________________________CHANNEL PORTS________________________________
         ---------------------------- Channel - DRP Ports  --------------------------
         gt0_drpaddr_in              : in  std_logic_vector(8 downto 0);
         gt0_drpclk_in               : in  std_logic;
         gt0_drpdi_in                : in  std_logic_vector(15 downto 0);
         gt0_drpdo_out               : out std_logic_vector(15 downto 0);
         gt0_drpen_in                : in  std_logic;
         gt0_drprdy_out              : out std_logic;
         gt0_drpwe_in                : in  std_logic;
         --------------------------- Digital Monitor Ports --------------------------
         gt0_dmonitorout_out         : out std_logic_vector(7 downto 0);
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
         gt0_rxusrclk_in             : in  std_logic;
         gt0_rxusrclk2_in            : in  std_logic;
         ------------------ Receive Ports - FPGA RX interface Ports -----------------
         gt0_rxdata_out              : out std_logic_vector(63 downto 0);
         --------------------------- Receive Ports - RX AFE -------------------------
         gt0_gtxrxp_in               : in  std_logic;
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         gt0_gtxrxn_in               : in  std_logic;
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         gt0_rxbufreset_in           : in  std_logic;
         --------------------- Receive Ports - RX Equalizer Ports -------------------
         gt0_rxdfelpmreset_in        : in  std_logic;
         gt0_rxmonitorout_out        : out std_logic_vector(6 downto 0);
         gt0_rxmonitorsel_in         : in  std_logic_vector(1 downto 0);
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
         gt0_txusrclk_in             : in  std_logic;
         gt0_txusrclk2_in            : in  std_logic;
         --------------- Transmit Ports - TX Configurable Driver Ports --------------
         gt0_txdiffctrl_in           : in  std_logic_vector(3 downto 0);
         ------------------ Transmit Ports - TX Data Path interface -----------------
         gt0_txdata_in               : in  std_logic_vector(63 downto 0);
         ---------------- Transmit Ports - TX Driver and OOB signaling --------------
         gt0_gtxtxn_out              : out std_logic;
         gt0_gtxtxp_out              : out std_logic;
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         gt0_txoutclk_out            : out std_logic;
         gt0_txoutclkfabric_out      : out std_logic;
         gt0_txoutclkpcs_out         : out std_logic;
         --------------------- Transmit Ports - TX Gearbox Ports --------------------
         gt0_txgearboxready_out      : out std_logic;
         gt0_txheader_in             : in  std_logic_vector(1 downto 0);
         gt0_txstartseq_in           : in  std_logic;
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         gt0_txpcsreset_in           : in  std_logic;
         gt0_txpmareset_in           : in  std_logic;
         gt0_txresetdone_out         : out std_logic;
         ----------------- Transmit Ports - TX Polarity Control Ports ---------------
         gt0_txpolarity_in           : in  std_logic;
         --____________________________COMMON PORTS________________________________
         GT0_QPLLLOCK_IN             : in  std_logic;
         GT0_QPLLREFCLKLOST_IN       : in  std_logic;
         GT0_QPLLRESET_OUT           : out std_logic;
         GT0_QPLLOUTCLK_IN           : in  std_logic;
         GT0_QPLLOUTREFCLK_IN        : in  std_logic
         );
   end component;

   signal gtRxOutClk   : sl;
   signal gtRxPllRst   : sl;
   signal gtRxPllLock  : sl;
   signal rxPllClk     : slv(1 downto 0);
   signal rxPllRst     : slv(1 downto 0);
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

   signal txGearBoxReady    : sl := '0';
   signal txGearBoxReadyDly : sl := '0';

begin

   rxUsrClk  <= rxUsrClkInt;
   rxUsrClk2 <= rxUsrClk2Int;

   txUsrClk  <= txUsrClkInt;
   txUsrClk2 <= txUsrClk2Int;

   U_RX_PLL : entity surf.ClockManager7
      generic map(
         TPD_G            => TPD_G,
         TYPE_G           => "PLL",
         BANDWIDTH_G      => "OPTIMIZED",
         INPUT_BUFG_G     => true,
         FB_BUFG_G        => false,
         NUM_CLOCKS_G     => 2,
         CLKIN_PERIOD_G   => ite((RATE_G = "10.3125Gbps"), 3.103, ite((RATE_G = "6.25Gbps"), 5.12, 10.24)),
         DIVCLK_DIVIDE_G  => 1,
         CLKFBOUT_MULT_G  => ite((RATE_G = "10.3125Gbps"), 3, ite((RATE_G = "6.25Gbps"), 5, 10)),
         CLKOUT0_DIVIDE_G => ite((RATE_G = "10.3125Gbps"), 3, ite((RATE_G = "6.25Gbps"), 5, 10)),
         CLKOUT1_DIVIDE_G => ite((RATE_G = "10.3125Gbps"), 6, ite((RATE_G = "6.25Gbps"), 10, 20)))
      port map(
         clkIn  => gtRxOutClk,
         rstIn  => gtRxPllRst,
         clkOut => rxPllClk,
         rstOut => rxPllRst,
         locked => gtRxPllLock);

   rxUsrClkInt  <= rxPllClk(0);
   rxUsrClk2Int <= rxPllClk(1);
   rxUsrClkRst  <= rxPllRst(1);

   txUsrClkInt  <= txPllClk(0);
   txUsrClk2Int <= txPllClk(1);
   txUsrClkRst  <= txPllRst(1);

   txDataRdy <= txGearBoxReady or txGearBoxReadyDly;
   process(txUsrClk2Int)
   begin
      if rising_edge(txUsrClk2Int) then
         txGearBoxReadyDly <= txGearBoxReady after TPD_G;
      end if;
   end process;

   GEN_10G : if (RATE_G = "10.3125Gbps") generate
      U_Pgp3Gtx7Ip10G : Pgp3Gtx7Ip10G
         port map (
            SYSCLK_IN                   => stableClk,
            SOFT_RESET_TX_IN            => txReset,
            SOFT_RESET_RX_IN            => rxReset,
            DONT_RESET_ON_DATA_ERROR_IN => '0',
            GT0_TX_FSM_RESET_DONE_OUT   => txResetDone,
            GT0_RX_FSM_RESET_DONE_OUT   => rxResetDone,
            GT0_DATA_VALID_IN           => '1',
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
            gt0_rxusrclk_in             => rxUsrClkInt,  -- 322.26 MHz (3.103 ns period)
            gt0_rxusrclk2_in            => rxUsrClk2Int,  -- 161.13 MHz (6.206 ns period)
            ------------------ Receive Ports - FPGA RX interface Ports -----------------
            gt0_rxdata_out              => rxData,
            --------------------------- Receive Ports - RX AFE -------------------------
            gt0_gtxrxp_in               => gtRxP,
            ------------------------ Receive Ports - RX AFE Ports ----------------------
            gt0_gtxrxn_in               => gtRxN,
            ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
            gt0_rxbufreset_in           => '0',
            --------------------- Receive Ports - RX Equalizer Ports -------------------
            gt0_rxdfelpmreset_in        => '0',
            gt0_rxmonitorout_out        => open,
            gt0_rxmonitorsel_in         => "00",
            --------------- Receive Ports - RX Fabric Output Control Ports -------------
            gt0_rxoutclk_out            => gtRxOutClk,  -- 322.26 MHz (3.103 ns period)
            gt0_rxoutclkfabric_out      => open,  -- 156.25 MHz (6.400 ns period)
            ---------------------- Receive Ports - RX Gearbox Ports --------------------
            gt0_rxdatavalid_out         => rxDataValid,
            gt0_rxheader_out            => rxHeader,
            gt0_rxheadervalid_out       => rxHeaderValid,
            --------------------- Receive Ports - RX Gearbox Ports  --------------------
            gt0_rxgearboxslip_in        => rxGearboxSlip,
            ------------- Receive Ports - RX Initialization and Reset Ports ------------
            gt0_gtrxreset_in            => '0',
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
            gt0_txusrclk_in             => txUsrClkInt,  -- 322.26 MHz (3.103 ns period)
            gt0_txusrclk2_in            => txUsrClk2Int,  -- 161.13 MHz (6.206 ns period)
            --------------- Transmit Ports - TX Configurable Driver Ports --------------
            gt0_txdiffctrl_in           => txDiffCtrl(4 downto 1),
            ------------------ Transmit Ports - TX Data Path interface -----------------
            gt0_txdata_in               => txData,
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gtxtxn_out              => gtTxN,
            gt0_gtxtxp_out              => gtTxP,
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclk_out            => gtTxOutClk,  -- 322.27 MHz (3.103 ns period)
            gt0_txoutclkfabric_out      => open,  -- 156.25 MHz (6.206 ns period)
            gt0_txoutclkpcs_out         => open,
            --------------------- Transmit Ports - TX Gearbox Ports --------------------
            gt0_txgearboxready_out      => txGearBoxReady,
            gt0_txheader_in             => txHeader,
            gt0_txstartseq_in           => txStart,
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txpcsreset_in           => '0',
            gt0_txpmareset_in           => '0',
            gt0_txresetdone_out         => open,
            ----------------- Transmit Ports - TX Polarity Control Ports ---------------
            gt0_txpolarity_in           => TX_POLARITY_G,
            --____________________________COMMON PORTS________________________________
            GT0_QPLLLOCK_IN             => qpllLock,
            GT0_QPLLREFCLKLOST_IN       => qpllRefClkLost,
            GT0_QPLLRESET_OUT           => qpllRst,
            GT0_QPLLOUTCLK_IN           => qpllclk,
            GT0_QPLLOUTREFCLK_IN        => qpllrefclk);
   end generate;

   GEN_6G : if (RATE_G = "6.25Gbps") generate
      U_Pgp3Gtx7Ip6G : Pgp3Gtx7Ip6G
         port map (
            SYSCLK_IN                   => stableClk,
            SOFT_RESET_TX_IN            => txReset,
            SOFT_RESET_RX_IN            => rxReset,
            DONT_RESET_ON_DATA_ERROR_IN => '0',
            GT0_TX_FSM_RESET_DONE_OUT   => txResetDone,
            GT0_RX_FSM_RESET_DONE_OUT   => rxResetDone,
            GT0_DATA_VALID_IN           => '1',
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
            gt0_rxdata_out              => rxData,
            --------------------------- Receive Ports - RX AFE -------------------------
            gt0_gtxrxp_in               => gtRxP,
            ------------------------ Receive Ports - RX AFE Ports ----------------------
            gt0_gtxrxn_in               => gtRxN,
            ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
            gt0_rxbufreset_in           => '0',
            --------------------- Receive Ports - RX Equalizer Ports -------------------
            gt0_rxdfelpmreset_in        => '0',
            gt0_rxmonitorout_out        => open,
            gt0_rxmonitorsel_in         => "00",
            --------------- Receive Ports - RX Fabric Output Control Ports -------------
            gt0_rxoutclk_out            => gtRxOutClk,  -- 195.31 MHz (5.12 ns period)
            gt0_rxoutclkfabric_out      => open,  -- 156.25 MHz (6.400 ns period)
            ---------------------- Receive Ports - RX Gearbox Ports --------------------
            gt0_rxdatavalid_out         => rxDataValid,
            gt0_rxheader_out            => rxHeader,
            gt0_rxheadervalid_out       => rxHeaderValid,
            --------------------- Receive Ports - RX Gearbox Ports  --------------------
            gt0_rxgearboxslip_in        => rxGearboxSlip,
            ------------- Receive Ports - RX Initialization and Reset Ports ------------
            gt0_gtrxreset_in            => '0',
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
            gt0_txdata_in               => txData,
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gtxtxn_out              => gtTxN,
            gt0_gtxtxp_out              => gtTxP,
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclk_out            => gtTxOutClk,  -- 322.27 MHz (5.12 ns period)
            gt0_txoutclkfabric_out      => open,  -- 156.25 MHz (6.4 ns period)
            gt0_txoutclkpcs_out         => open,
            --------------------- Transmit Ports - TX Gearbox Ports --------------------
            gt0_txgearboxready_out      => txGearBoxReady,
            gt0_txheader_in             => txHeader,
            gt0_txstartseq_in           => txStart,
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txpcsreset_in           => '0',
            gt0_txpmareset_in           => '0',
            gt0_txresetdone_out         => open,
            ----------------- Transmit Ports - TX Polarity Control Ports ---------------
            gt0_txpolarity_in           => TX_POLARITY_G,
            --____________________________COMMON PORTS________________________________
            GT0_QPLLLOCK_IN             => qpllLock,
            GT0_QPLLREFCLKLOST_IN       => qpllRefClkLost,
            GT0_QPLLRESET_OUT           => qpllRst,
            GT0_QPLLOUTCLK_IN           => qpllclk,
            GT0_QPLLOUTREFCLK_IN        => qpllrefclk);
   end generate;

   GEN_3G : if (RATE_G = "3.125Gbps") generate
      U_Pgp3Gtx7Ip3G : Pgp3Gtx7Ip3G
         port map (
            SYSCLK_IN                   => stableClk,
            SOFT_RESET_TX_IN            => txReset,
            SOFT_RESET_RX_IN            => rxReset,
            DONT_RESET_ON_DATA_ERROR_IN => '0',
            GT0_TX_FSM_RESET_DONE_OUT   => txResetDone,
            GT0_RX_FSM_RESET_DONE_OUT   => rxResetDone,
            GT0_DATA_VALID_IN           => '1',
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
            gt0_rxdata_out              => rxData,
            --------------------------- Receive Ports - RX AFE -------------------------
            gt0_gtxrxp_in               => gtRxP,
            ------------------------ Receive Ports - RX AFE Ports ----------------------
            gt0_gtxrxn_in               => gtRxN,
            ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
            gt0_rxbufreset_in           => '0',
            --------------------- Receive Ports - RX Equalizer Ports -------------------
            gt0_rxdfelpmreset_in        => '0',
            gt0_rxmonitorout_out        => open,
            gt0_rxmonitorsel_in         => "00",
            --------------- Receive Ports - RX Fabric Output Control Ports -------------
            gt0_rxoutclk_out            => gtRxOutClk,  -- 195.31 MHz (5.12 ns period)
            gt0_rxoutclkfabric_out      => open,  -- 156.25 MHz (6.400 ns period)
            ---------------------- Receive Ports - RX Gearbox Ports --------------------
            gt0_rxdatavalid_out         => rxDataValid,
            gt0_rxheader_out            => rxHeader,
            gt0_rxheadervalid_out       => rxHeaderValid,
            --------------------- Receive Ports - RX Gearbox Ports  --------------------
            gt0_rxgearboxslip_in        => rxGearboxSlip,
            ------------- Receive Ports - RX Initialization and Reset Ports ------------
            gt0_gtrxreset_in            => '0',
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
            gt0_txdata_in               => txData,
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gtxtxn_out              => gtTxN,
            gt0_gtxtxp_out              => gtTxP,
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclk_out            => gtTxOutClk,  -- 322.27 MHz (5.12 ns period)
            gt0_txoutclkfabric_out      => open,  -- 156.25 MHz (6.4 ns period)
            gt0_txoutclkpcs_out         => open,
            --------------------- Transmit Ports - TX Gearbox Ports --------------------
            gt0_txgearboxready_out      => txGearBoxReady,
            gt0_txheader_in             => txHeader,
            gt0_txstartseq_in           => txStart,
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txpcsreset_in           => '0',
            gt0_txpmareset_in           => '0',
            gt0_txresetdone_out         => open,
            ----------------- Transmit Ports - TX Polarity Control Ports ---------------
            gt0_txpolarity_in           => TX_POLARITY_G,
            --____________________________COMMON PORTS________________________________
            GT0_QPLLLOCK_IN             => qpllLock,
            GT0_QPLLREFCLKLOST_IN       => qpllRefClkLost,
            GT0_QPLLRESET_OUT           => qpllRst,
            GT0_QPLLOUTCLK_IN           => qpllclk,
            GT0_QPLLOUTREFCLK_IN        => qpllrefclk);
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

end architecture mapping;
