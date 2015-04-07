-------------------------------------------------------------------------------
-- Title      : Core Block level
-- Project    : XAUI
-------------------------------------------------------------------------------
-- File       : XauiGtx7Core_block.vhd
-------------------------------------------------------------------------------
-- Description: This file is a wrapper for the XAUI core. It contains the XAUI
-- core, the transceivers and some transceiver logic.
-------------------------------------------------------------------------------
--
-- (c) Copyright 2002 - 2014 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity XauiGtx7Core_block is
    port (
      dclk                     : in  std_logic;
      reset                    : in  std_logic;
      clk156_out               : out  std_logic;
      clk156_lock              : out std_logic;
      refclk                   : in  std_logic;
      xgmii_txd                : in  std_logic_vector(63 downto 0);
      xgmii_txc                : in  std_logic_vector(7 downto 0);
      xgmii_rxd                : out std_logic_vector(63 downto 0);
      xgmii_rxc                : out std_logic_vector(7 downto 0);
      xaui_tx_l0_p             : out std_logic;
      xaui_tx_l0_n             : out std_logic;
      xaui_tx_l1_p             : out std_logic;
      xaui_tx_l1_n             : out std_logic;
      xaui_tx_l2_p             : out std_logic;
      xaui_tx_l2_n             : out std_logic;
      xaui_tx_l3_p             : out std_logic;
      xaui_tx_l3_n             : out std_logic;
      xaui_rx_l0_p             : in  std_logic;
      xaui_rx_l0_n             : in  std_logic;
      xaui_rx_l1_p             : in  std_logic;
      xaui_rx_l1_n             : in  std_logic;
      xaui_rx_l2_p             : in  std_logic;
      xaui_rx_l2_n             : in  std_logic;
      xaui_rx_l3_p             : in  std_logic;
      xaui_rx_l3_n             : in  std_logic;
      signal_detect            : in  std_logic_vector(3 downto 0);
      debug                    : out std_logic_vector(5 downto 0); -- Debug vector
   -- GT Control Ports
   -- DRP
      gt0_drpaddr              : in  std_logic_vector(8 downto 0);
      gt0_drpen                : in  std_logic;
      gt0_drpdi                : in  std_logic_vector(15 downto 0);
      gt0_drpdo                : out std_logic_vector(15 downto 0);
      gt0_drprdy               : out std_logic;
      gt0_drpwe                : in  std_logic;
   -- TX Reset and Initialisation
      gt0_txpmareset_in        : in std_logic;
      gt0_txpcsreset_in        : in std_logic;
      gt0_txresetdone_out      : out std_logic;
   -- RX Reset and Initialisation
      gt0_rxpmareset_in        : in std_logic;
      gt0_rxpcsreset_in        : in std_logic;
      gt0_rxresetdone_out      : out std_logic;
   -- Clocking
      gt0_rxbufstatus_out      : out std_logic_vector(2 downto 0);
      gt0_txphaligndone_out    : out std_logic;
      gt0_txphinitdone_out     : out std_logic;
      gt0_txdlysresetdone_out  : out std_logic;
      gt_qplllock_out                : out std_logic;
   -- Signal Integrity adn Functionality
   -- Eye Scan
      gt0_eyescantrigger_in    : in  std_logic;
      gt0_eyescanreset_in      : in  std_logic;
      gt0_eyescandataerror_out : out std_logic;
      gt0_rxrate_in            : in  std_logic_vector(2 downto 0);
   -- Loopback
      gt0_loopback_in          : in  std_logic_vector(2 downto 0);
   -- Polarity
      gt0_rxpolarity_in        : in  std_logic;
      gt0_txpolarity_in        : in  std_logic;
   -- RX Decision Feedback Equalizer(DFE)
      gt0_rxlpmen_in           : in  std_logic;
      gt0_rxdfelpmreset_in     : in  std_logic;
      gt0_rxmonitorsel_in      : in  std_logic_vector(1 downto 0);
      gt0_rxmonitorout_out     : out std_logic_vector(6 downto 0);
   -- TX Driver
      gt0_txpostcursor_in      : in std_logic_vector(4 downto 0);
      gt0_txprecursor_in       : in std_logic_vector(4 downto 0);
      gt0_txdiffctrl_in        : in std_logic_vector(3 downto 0);
   -- PRBS
      gt0_rxprbscntreset_in    : in  std_logic;
      gt0_rxprbserr_out        : out std_logic;
      gt0_rxprbssel_in         : in std_logic_vector(2 downto 0);
      gt0_txprbssel_in         : in std_logic_vector(2 downto 0);
      gt0_txprbsforceerr_in    : in std_logic;

      gt0_rxcdrhold_in         : in std_logic;

      gt0_dmonitorout_out      : out  std_logic_vector(7 downto 0);

   -- Status
      gt0_rxdisperr_out        : out std_logic_vector(1 downto 0);
      gt0_rxnotintable_out     : out std_logic_vector(1 downto 0);
      gt0_rxcommadet_out       : out std_logic;
   -- DRP
      gt1_drpaddr              : in  std_logic_vector(8 downto 0);
      gt1_drpen                : in  std_logic;
      gt1_drpdi                : in  std_logic_vector(15 downto 0);
      gt1_drpdo                : out std_logic_vector(15 downto 0);
      gt1_drprdy               : out std_logic;
      gt1_drpwe                : in  std_logic;
   -- TX Reset and Initialisation
      gt1_txpmareset_in        : in std_logic;
      gt1_txpcsreset_in        : in std_logic;
      gt1_txresetdone_out      : out std_logic;
   -- RX Reset and Initialisation
      gt1_rxpmareset_in        : in std_logic;
      gt1_rxpcsreset_in        : in std_logic;
      gt1_rxresetdone_out      : out std_logic;
   -- Clocking
      gt1_rxbufstatus_out      : out std_logic_vector(2 downto 0);
      gt1_txphaligndone_out    : out std_logic;
      gt1_txphinitdone_out     : out std_logic;
      gt1_txdlysresetdone_out  : out std_logic;
   -- Signal Integrity adn Functionality
   -- Eye Scan
      gt1_eyescantrigger_in    : in  std_logic;
      gt1_eyescanreset_in      : in  std_logic;
      gt1_eyescandataerror_out : out std_logic;
      gt1_rxrate_in            : in  std_logic_vector(2 downto 0);
   -- Loopback
      gt1_loopback_in          : in  std_logic_vector(2 downto 0);
   -- Polarity
      gt1_rxpolarity_in        : in  std_logic;
      gt1_txpolarity_in        : in  std_logic;
   -- RX Decision Feedback Equalizer(DFE)
      gt1_rxlpmen_in           : in  std_logic;
      gt1_rxdfelpmreset_in     : in  std_logic;
      gt1_rxmonitorsel_in      : in  std_logic_vector(1 downto 0);
      gt1_rxmonitorout_out     : out std_logic_vector(6 downto 0);
   -- TX Driver
      gt1_txpostcursor_in      : in std_logic_vector(4 downto 0);
      gt1_txprecursor_in       : in std_logic_vector(4 downto 0);
      gt1_txdiffctrl_in        : in std_logic_vector(3 downto 0);
   -- PRBS
      gt1_rxprbscntreset_in    : in  std_logic;
      gt1_rxprbserr_out        : out std_logic;
      gt1_rxprbssel_in         : in std_logic_vector(2 downto 0);
      gt1_txprbssel_in         : in std_logic_vector(2 downto 0);
      gt1_txprbsforceerr_in    : in std_logic;

      gt1_rxcdrhold_in         : in std_logic;

      gt1_dmonitorout_out      : out  std_logic_vector(7 downto 0);

   -- Status
      gt1_rxdisperr_out        : out std_logic_vector(1 downto 0);
      gt1_rxnotintable_out     : out std_logic_vector(1 downto 0);
      gt1_rxcommadet_out       : out std_logic;
   -- DRP
      gt2_drpaddr              : in  std_logic_vector(8 downto 0);
      gt2_drpen                : in  std_logic;
      gt2_drpdi                : in  std_logic_vector(15 downto 0);
      gt2_drpdo                : out std_logic_vector(15 downto 0);
      gt2_drprdy               : out std_logic;
      gt2_drpwe                : in  std_logic;
   -- TX Reset and Initialisation
      gt2_txpmareset_in        : in std_logic;
      gt2_txpcsreset_in        : in std_logic;
      gt2_txresetdone_out      : out std_logic;
   -- RX Reset and Initialisation
      gt2_rxpmareset_in        : in std_logic;
      gt2_rxpcsreset_in        : in std_logic;
      gt2_rxresetdone_out      : out std_logic;
   -- Clocking
      gt2_rxbufstatus_out      : out std_logic_vector(2 downto 0);
      gt2_txphaligndone_out    : out std_logic;
      gt2_txphinitdone_out     : out std_logic;
      gt2_txdlysresetdone_out  : out std_logic;
   -- Signal Integrity adn Functionality
   -- Eye Scan
      gt2_eyescantrigger_in    : in  std_logic;
      gt2_eyescanreset_in      : in  std_logic;
      gt2_eyescandataerror_out : out std_logic;
      gt2_rxrate_in            : in  std_logic_vector(2 downto 0);
   -- Loopback
      gt2_loopback_in          : in  std_logic_vector(2 downto 0);
   -- Polarity
      gt2_rxpolarity_in        : in  std_logic;
      gt2_txpolarity_in        : in  std_logic;
   -- RX Decision Feedback Equalizer(DFE)
      gt2_rxlpmen_in           : in  std_logic;
      gt2_rxdfelpmreset_in     : in  std_logic;
      gt2_rxmonitorsel_in      : in  std_logic_vector(1 downto 0);
      gt2_rxmonitorout_out     : out std_logic_vector(6 downto 0);
   -- TX Driver
      gt2_txpostcursor_in      : in std_logic_vector(4 downto 0);
      gt2_txprecursor_in       : in std_logic_vector(4 downto 0);
      gt2_txdiffctrl_in        : in std_logic_vector(3 downto 0);
   -- PRBS
      gt2_rxprbscntreset_in    : in  std_logic;
      gt2_rxprbserr_out        : out std_logic;
      gt2_rxprbssel_in         : in std_logic_vector(2 downto 0);
      gt2_txprbssel_in         : in std_logic_vector(2 downto 0);
      gt2_txprbsforceerr_in    : in std_logic;

      gt2_rxcdrhold_in         : in std_logic;

      gt2_dmonitorout_out      : out  std_logic_vector(7 downto 0);

   -- Status
      gt2_rxdisperr_out        : out std_logic_vector(1 downto 0);
      gt2_rxnotintable_out     : out std_logic_vector(1 downto 0);
      gt2_rxcommadet_out       : out std_logic;
   -- DRP
      gt3_drpaddr              : in  std_logic_vector(8 downto 0);
      gt3_drpen                : in  std_logic;
      gt3_drpdi                : in  std_logic_vector(15 downto 0);
      gt3_drpdo                : out std_logic_vector(15 downto 0);
      gt3_drprdy               : out std_logic;
      gt3_drpwe                : in  std_logic;
   -- TX Reset and Initialisation
      gt3_txpmareset_in        : in std_logic;
      gt3_txpcsreset_in        : in std_logic;
      gt3_txresetdone_out      : out std_logic;
   -- RX Reset and Initialisation
      gt3_rxpmareset_in        : in std_logic;
      gt3_rxpcsreset_in        : in std_logic;
      gt3_rxresetdone_out      : out std_logic;
   -- Clocking
      gt3_rxbufstatus_out      : out std_logic_vector(2 downto 0);
      gt3_txphaligndone_out    : out std_logic;
      gt3_txphinitdone_out     : out std_logic;
      gt3_txdlysresetdone_out  : out std_logic;
   -- Signal Integrity adn Functionality
   -- Eye Scan
      gt3_eyescantrigger_in    : in  std_logic;
      gt3_eyescanreset_in      : in  std_logic;
      gt3_eyescandataerror_out : out std_logic;
      gt3_rxrate_in            : in  std_logic_vector(2 downto 0);
   -- Loopback
      gt3_loopback_in          : in  std_logic_vector(2 downto 0);
   -- Polarity
      gt3_rxpolarity_in        : in  std_logic;
      gt3_txpolarity_in        : in  std_logic;
   -- RX Decision Feedback Equalizer(DFE)
      gt3_rxlpmen_in           : in  std_logic;
      gt3_rxdfelpmreset_in     : in  std_logic;
      gt3_rxmonitorsel_in      : in  std_logic_vector(1 downto 0);
      gt3_rxmonitorout_out     : out std_logic_vector(6 downto 0);
   -- TX Driver
      gt3_txpostcursor_in      : in std_logic_vector(4 downto 0);
      gt3_txprecursor_in       : in std_logic_vector(4 downto 0);
      gt3_txdiffctrl_in        : in std_logic_vector(3 downto 0);
   -- PRBS
      gt3_rxprbscntreset_in    : in  std_logic;
      gt3_rxprbserr_out        : out std_logic;
      gt3_rxprbssel_in         : in std_logic_vector(2 downto 0);
      gt3_txprbssel_in         : in std_logic_vector(2 downto 0);
      gt3_txprbsforceerr_in    : in std_logic;

      gt3_rxcdrhold_in         : in std_logic;

      gt3_dmonitorout_out      : out  std_logic_vector(7 downto 0);

   -- Status
      gt3_rxdisperr_out        : out std_logic_vector(1 downto 0);
      gt3_rxnotintable_out     : out std_logic_vector(1 downto 0);
      gt3_rxcommadet_out       : out std_logic;
      configuration_vector     : in  std_logic_vector(6 downto 0);
      status_vector            : out std_logic_vector(7 downto 0)
);
end XauiGtx7Core_block;

library ieee;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library xaui_v12_1;
use xaui_v12_1.all;

architecture wrapper of XauiGtx7Core_block is

  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of wrapper : architecture is "yes";

----------------------------------------------------------------------------
-- Component Declaration for the XAUI core.
----------------------------------------------------------------------------

   component xaui_v12_1_top
      generic (
        c_family : string      := "virtex7";
        c_has_mdio : boolean   := true;
        c_is_dxaui : boolean   := false
      );
      port (
        reset                  : in  std_logic;

        xgmii_txd              : in  std_logic_vector(63 downto 0);
        xgmii_txc              : in  std_logic_vector(7 downto 0);
        xgmii_rxd              : out std_logic_vector(63 downto 0);
        xgmii_rxc              : out std_logic_vector(7 downto 0);
        usrclk                 : in  std_logic;
        mgt_txdata             : out std_logic_vector(63 downto 0);
        mgt_txcharisk          : out std_logic_vector(7 downto 0);
        mgt_rxdata             : in  std_logic_vector(63 downto 0);
        mgt_rxcharisk          : in  std_logic_vector(7 downto 0);
        mgt_codevalid          : in  std_logic_vector(7 downto 0);
        mgt_codecomma          : in  std_logic_vector(7 downto 0);
        mgt_enable_align       : out std_logic_vector(3 downto 0);
        mgt_enchansync         : out std_logic;
        mgt_rxlock             : in  std_logic_vector(3 downto 0);
        mgt_loopback           : out std_logic;
        mgt_powerdown          : out std_logic;
        mgt_tx_reset           : in  std_logic_vector(3 downto 0);
        mgt_rx_reset           : in  std_logic_vector(3 downto 0);

        soft_reset             : out std_logic;

        signal_detect          : in  std_logic_vector(3 downto 0);
        align_status           : out std_logic;
        sync_status            : out std_logic_vector(3 downto 0);

        mdc                    : in  std_logic;
        mdio_in                : in  std_logic;
        mdio_out               : out std_logic;
        mdio_tri               : out std_logic;
        prtad                  : in  std_logic_vector(4 downto 0);
        type_sel               : in  std_logic_vector(1 downto 0);

        configuration_vector   : in  std_logic_vector(6 downto 0);
        status_vector          : out std_logic_vector(7 downto 0));

  end component;

  --------------------------------------------------------------------------
  -- Component declaration for the GTX transceiver container
  --------------------------------------------------------------------------

  component XauiGtx7Core_gt_wrapper is
  generic
  (
      -- Simulation attributes
      WRAPPER_SIM_GTRESET_SPEEDUP    : string    := "FALSE" -- Set to 1 to speed up sim reset
  );
  port
  (
    --_________________________________________________________________________
    --_________________________________________________________________________
    --GT0  (X0Y4)
    --____________________________CHANNEL PORTS________________________________
    ---------------------------- Channel - DRP Ports  --------------------------
    gt0_drpaddr_in                          : in   std_logic_vector(8 downto 0);
    gt0_drpclk_in                           : in   std_logic;
    gt0_drpdi_in                            : in   std_logic_vector(15 downto 0);
    gt0_drpdo_out                           : out  std_logic_vector(15 downto 0);
    gt0_drpen_in                            : in   std_logic;
    gt0_drprdy_out                          : out  std_logic;
    gt0_drpwe_in                            : in   std_logic;
    ------------------------- Digital Monitor Ports --------------------------
    gt0_dmonitorout_out                     : out  std_logic_vector(7 downto 0);
    ------------------------------- Loopback Ports -----------------------------
    gt0_loopback_in                         : in   std_logic_vector(2 downto 0);
    ------------------------------ Power-Down Ports ----------------------------
    gt0_rxpd_in                             : in   std_logic_vector(1 downto 0);
    gt0_txpd_in                             : in   std_logic_vector(1 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    gt0_rxuserrdy_in                        : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    gt0_eyescandataerror_out                : out  std_logic;
    gt0_eyescanreset_in                     : in   std_logic;
    gt0_eyescantrigger_in                   : in   std_logic;
    gt0_rxrate_in                           : in   std_logic_vector(2 downto 0);
    gt0_rxratedone_out                      : out  std_logic;
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt0_rxcdrhold_in                        : in   std_logic;
    gt0_rxcdrlock_out                       : out  std_logic;
    ------------------- Receive Ports - Clock Correction Ports -----------------
    gt0_rxclkcorcnt_out                     : out  std_logic_vector(1 downto 0);
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt0_rxusrclk_in                         : in   std_logic;
    gt0_rxusrclk2_in                        : in   std_logic;
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt0_rxdata_out                          : out  std_logic_vector(15 downto 0);
    ------------------- Receive Ports - Pattern Checker Ports ------------------
    gt0_rxprbserr_out                       : out  std_logic;
    gt0_rxprbssel_in                        : in   std_logic_vector(2 downto 0);
    ------------------- Receive Ports - Pattern Checker ports ------------------
    gt0_rxprbscntreset_in                   : in   std_logic;
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt0_rxdisperr_out                       : out  std_logic_vector(1 downto 0);
    gt0_rxnotintable_out                    : out  std_logic_vector(1 downto 0);
    --------------------------- Receive Ports - RX AFE -------------------------
    gt0_GTXrxp_in                           : in   std_logic;
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt0_GTXrxn_in                           : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt0_rxbufreset_in                       : in   std_logic;
    gt0_rxbufstatus_out                     : out  std_logic_vector(2 downto 0);
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt0_rxbyteisaligned_out                 : out  std_logic;
    gt0_rxbyterealign_out                   : out  std_logic;
    gt0_rxcommadet_out                      : out  std_logic;
    gt0_rxmcommaalignen_in                  : in   std_logic;
    gt0_rxpcommaalignen_in                  : in   std_logic;
    ------------------ Receive Ports - RX Channel Bonding Ports ----------------
    gt0_rxchanbondseq_out                   : out  std_logic;
    gt0_rxchbonden_in                       : in   std_logic;
    gt0_rxchbondlevel_in                    : in   std_logic_vector(2 downto 0);
    gt0_rxchbondmaster_in                   : in   std_logic;
    gt0_rxchbondo_out                       : out  std_logic_vector(4 downto 0);
    gt0_rxchbondslave_in                    : in   std_logic;
    ----------------- Receive Ports - RX Channel Bonding Ports  ----------------
    gt0_rxchanisaligned_out                 : out  std_logic;
    gt0_rxchanrealign_out                   : out  std_logic;
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt0_rxdfeagchold_in                     : in   std_logic;
    gt0_rxdfelfhold_in                      : in   std_logic;
    gt0_rxdfelpmreset_in                    : in   std_logic;
    gt0_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
    gt0_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt0_rxoutclk_out                        : out  std_logic;
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt0_gtrxreset_in                        : in   std_logic;
    gt0_rxpcsreset_in                       : in   std_logic;
    gt0_rxpmareset_in                       : in   std_logic;
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt0_rxlpmen_in                          : in   std_logic;
    ----------------- Polarity Control Ports ----------------
    gt0_rxpolarity_in                       : in   std_logic;
    gt0_txpolarity_in                       : in   std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt0_rxchariscomma_out                   : out  std_logic_vector(1 downto 0);
    gt0_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
    ------------------ Receive Ports - Rx Channel Bonding Ports ----------------
    gt0_rxchbondi_in                        : in   std_logic_vector(4 downto 0);
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt0_rxresetdone_out                     : out  std_logic;
    ------------------------ TX Configurable Driver Ports ----------------------
    gt0_txpostcursor_in                     : in   std_logic_vector(4 downto 0);
    gt0_txprecursor_in                      : in   std_logic_vector(4 downto 0);
    --------------------- TX Initialization and Reset Ports --------------------
    gt0_gttxreset_in                        : in   std_logic;
    gt0_txuserrdy_in                        : in   std_logic;
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt0_txusrclk_in                         : in   std_logic;
    gt0_txusrclk2_in                        : in   std_logic;
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt0_txelecidle_in                       : in   std_logic;
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt0_txprbsforceerr_in                   : in   std_logic;
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt0_txdlyen_in                          : in   std_logic;
    gt0_txdlysreset_in                      : in   std_logic;
    gt0_txdlysresetdone_out                 : out  std_logic;
    gt0_txphalign_in                        : in   std_logic;
    gt0_txphaligndone_out                   : out  std_logic;
    gt0_txphalignen_in                      : in   std_logic;
    gt0_txphdlyreset_in                     : in   std_logic;
    gt0_txphinit_in                         : in   std_logic;
    gt0_txphinitdone_out                    : out  std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt0_txdata_in                           : in   std_logic_vector(15 downto 0);
    gt0_txdiffctrl_in                       : in   std_logic_vector(3 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt0_GTXtxn_out                          : out  std_logic;
    gt0_GTXtxp_out                          : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt0_txoutclk_out                        : out  std_logic;
    gt0_txoutclkfabric_out                  : out  std_logic;
    gt0_txoutclkpcs_out                     : out  std_logic;
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt0_txcharisk_in                        : in   std_logic_vector(1 downto 0);
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt0_txpcsreset_in                       : in   std_logic;
    gt0_txpmareset_in                       : in   std_logic;
    gt0_txresetdone_out                     : out  std_logic;
    ------------------ Transmit Ports - pattern Generator Ports ----------------
    gt0_txprbssel_in                        : in   std_logic_vector(2 downto 0);

    --GT1  (X0Y5)
    --____________________________CHANNEL PORTS________________________________
    ---------------------------- Channel - DRP Ports  --------------------------
    gt1_drpaddr_in                          : in   std_logic_vector(8 downto 0);
    gt1_drpclk_in                           : in   std_logic;
    gt1_drpdi_in                            : in   std_logic_vector(15 downto 0);
    gt1_drpdo_out                           : out  std_logic_vector(15 downto 0);
    gt1_drpen_in                            : in   std_logic;
    gt1_drprdy_out                          : out  std_logic;
    gt1_drpwe_in                            : in   std_logic;
    gt1_dmonitorout_out                     : out  std_logic_vector(7 downto 0);
    ------------------------------- Loopback Ports -----------------------------
    gt1_loopback_in                         : in   std_logic_vector(2 downto 0);
    ------------------------------ Power-Down Ports ----------------------------
    gt1_rxpd_in                             : in   std_logic_vector(1 downto 0);
    gt1_txpd_in                             : in   std_logic_vector(1 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    gt1_rxuserrdy_in                        : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    gt1_eyescandataerror_out                : out  std_logic;
    gt1_eyescanreset_in                     : in   std_logic;
    gt1_eyescantrigger_in                   : in   std_logic;
    gt1_rxrate_in                           : in   std_logic_vector(2 downto 0);
    gt1_rxratedone_out                      : out  std_logic;
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt1_rxcdrhold_in                        : in   std_logic;
    gt1_rxcdrlock_out                       : out  std_logic;
    ------------------- Receive Ports - Clock Correction Ports -----------------
    gt1_rxclkcorcnt_out                     : out  std_logic_vector(1 downto 0);
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt1_rxusrclk_in                         : in   std_logic;
    gt1_rxusrclk2_in                        : in   std_logic;
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt1_rxdata_out                          : out  std_logic_vector(15 downto 0);
    ------------------- Receive Ports - Pattern Checker Ports ------------------
    gt1_rxprbserr_out                       : out  std_logic;
    gt1_rxprbssel_in                        : in   std_logic_vector(2 downto 0);
    ------------------- Receive Ports - Pattern Checker ports ------------------
    gt1_rxprbscntreset_in                   : in   std_logic;
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt1_rxdisperr_out                       : out  std_logic_vector(1 downto 0);
    gt1_rxnotintable_out                    : out  std_logic_vector(1 downto 0);
    --------------------------- Receive Ports - RX AFE -------------------------
    gt1_GTXrxp_in                           : in   std_logic;
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt1_GTXrxn_in                           : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt1_rxbufreset_in                       : in   std_logic;
    gt1_rxbufstatus_out                     : out  std_logic_vector(2 downto 0);
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt1_rxbyteisaligned_out                 : out  std_logic;
    gt1_rxbyterealign_out                   : out  std_logic;
    gt1_rxcommadet_out                      : out  std_logic;
    gt1_rxmcommaalignen_in                  : in   std_logic;
    gt1_rxpcommaalignen_in                  : in   std_logic;
    ------------------ Receive Ports - RX Channel Bonding Ports ----------------
    gt1_rxchanbondseq_out                   : out  std_logic;
    gt1_rxchbonden_in                       : in   std_logic;
    gt1_rxchbondlevel_in                    : in   std_logic_vector(2 downto 0);
    gt1_rxchbondmaster_in                   : in   std_logic;
    gt1_rxchbondo_out                       : out  std_logic_vector(4 downto 0);
    gt1_rxchbondslave_in                    : in   std_logic;
    ----------------- Receive Ports - RX Channel Bonding Ports  ----------------
    gt1_rxchanisaligned_out                 : out  std_logic;
    gt1_rxchanrealign_out                   : out  std_logic;
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt1_rxdfeagchold_in                     : in   std_logic;
    gt1_rxdfelfhold_in                      : in   std_logic;
    gt1_rxdfelpmreset_in                    : in   std_logic;
    gt1_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
    gt1_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt1_rxoutclk_out                        : out  std_logic;
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt1_gtrxreset_in                        : in   std_logic;
    gt1_rxpcsreset_in                       : in   std_logic;
    gt1_rxpmareset_in                       : in   std_logic;
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt1_rxlpmen_in                          : in   std_logic;
    ----------------- Polarity Control Ports ----------------
    gt1_rxpolarity_in                       : in   std_logic;
    gt1_txpolarity_in                       : in   std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt1_rxchariscomma_out                   : out  std_logic_vector(1 downto 0);
    gt1_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
    ------------------ Receive Ports - Rx Channel Bonding Ports ----------------
    gt1_rxchbondi_in                        : in   std_logic_vector(4 downto 0);
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt1_rxresetdone_out                     : out  std_logic;
    ------------------------ TX Configurable Driver Ports ----------------------
    gt1_txpostcursor_in                     : in   std_logic_vector(4 downto 0);
    gt1_txprecursor_in                      : in   std_logic_vector(4 downto 0);
    --------------------- TX Initialization and Reset Ports --------------------
    gt1_gttxreset_in                        : in   std_logic;
    gt1_txuserrdy_in                        : in   std_logic;
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt1_txusrclk_in                         : in   std_logic;
    gt1_txusrclk2_in                        : in   std_logic;
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt1_txelecidle_in                       : in   std_logic;
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt1_txprbsforceerr_in                   : in   std_logic;
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt1_txdlyen_in                          : in   std_logic;
    gt1_txdlysreset_in                      : in   std_logic;
    gt1_txdlysresetdone_out                 : out  std_logic;
    gt1_txphalign_in                        : in   std_logic;
    gt1_txphaligndone_out                   : out  std_logic;
    gt1_txphalignen_in                      : in   std_logic;
    gt1_txphdlyreset_in                     : in   std_logic;
    gt1_txphinit_in                         : in   std_logic;
    gt1_txphinitdone_out                    : out  std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt1_txdata_in                           : in   std_logic_vector(15 downto 0);
    gt1_txdiffctrl_in                       : in   std_logic_vector(3 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt1_GTXtxn_out                          : out  std_logic;
    gt1_GTXtxp_out                          : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt1_txoutclk_out                        : out  std_logic;
    gt1_txoutclkfabric_out                  : out  std_logic;
    gt1_txoutclkpcs_out                     : out  std_logic;
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt1_txcharisk_in                        : in   std_logic_vector(1 downto 0);
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt1_txpcsreset_in                       : in   std_logic;
    gt1_txpmareset_in                       : in   std_logic;
    gt1_txresetdone_out                     : out  std_logic;
    ------------------ Transmit Ports - pattern Generator Ports ----------------
    gt1_txprbssel_in                        : in   std_logic_vector(2 downto 0);
    --GT2  (X0Y6)
    --____________________________CHANNEL PORTS________________________________
    ---------------------------- Channel - DRP Ports  --------------------------
    gt2_drpaddr_in                          : in   std_logic_vector(8 downto 0);
    gt2_drpclk_in                           : in   std_logic;
    gt2_drpdi_in                            : in   std_logic_vector(15 downto 0);
    gt2_drpdo_out                           : out  std_logic_vector(15 downto 0);
    gt2_drpen_in                            : in   std_logic;
    gt2_drprdy_out                          : out  std_logic;
    gt2_drpwe_in                            : in   std_logic;
    gt2_dmonitorout_out                     : out  std_logic_vector(7 downto 0);
    ------------------------------- Loopback Ports -----------------------------
    gt2_loopback_in                         : in   std_logic_vector(2 downto 0);
    ------------------------------ Power-Down Ports ----------------------------
    gt2_rxpd_in                             : in   std_logic_vector(1 downto 0);
    gt2_txpd_in                             : in   std_logic_vector(1 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    gt2_rxuserrdy_in                        : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    gt2_eyescandataerror_out                : out  std_logic;
    gt2_eyescanreset_in                     : in   std_logic;
    gt2_eyescantrigger_in                   : in   std_logic;
    gt2_rxrate_in                           : in   std_logic_vector(2 downto 0);
    gt2_rxratedone_out                      : out  std_logic;
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt2_rxcdrhold_in                        : in   std_logic;
    gt2_rxcdrlock_out                       : out  std_logic;
    ------------------- Receive Ports - Clock Correction Ports -----------------
    gt2_rxclkcorcnt_out                     : out  std_logic_vector(1 downto 0);
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt2_rxusrclk_in                         : in   std_logic;
    gt2_rxusrclk2_in                        : in   std_logic;
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt2_rxdata_out                          : out  std_logic_vector(15 downto 0);
    ------------------- Receive Ports - Pattern Checker Ports ------------------
    gt2_rxprbserr_out                       : out  std_logic;
    gt2_rxprbssel_in                        : in   std_logic_vector(2 downto 0);
    ------------------- Receive Ports - Pattern Checker ports ------------------
    gt2_rxprbscntreset_in                   : in   std_logic;
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt2_rxdisperr_out                       : out  std_logic_vector(1 downto 0);
    gt2_rxnotintable_out                    : out  std_logic_vector(1 downto 0);
    --------------------------- Receive Ports - RX AFE -------------------------
    gt2_GTXrxp_in                           : in   std_logic;
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt2_GTXrxn_in                           : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt2_rxbufreset_in                       : in   std_logic;
    gt2_rxbufstatus_out                     : out  std_logic_vector(2 downto 0);
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt2_rxbyteisaligned_out                 : out  std_logic;
    gt2_rxbyterealign_out                   : out  std_logic;
    gt2_rxcommadet_out                      : out  std_logic;
    gt2_rxmcommaalignen_in                  : in   std_logic;
    gt2_rxpcommaalignen_in                  : in   std_logic;
    ------------------ Receive Ports - RX Channel Bonding Ports ----------------
    gt2_rxchanbondseq_out                   : out  std_logic;
    gt2_rxchbonden_in                       : in   std_logic;
    gt2_rxchbondlevel_in                    : in   std_logic_vector(2 downto 0);
    gt2_rxchbondmaster_in                   : in   std_logic;
    gt2_rxchbondo_out                       : out  std_logic_vector(4 downto 0);
    gt2_rxchbondslave_in                    : in   std_logic;
    ----------------- Receive Ports - RX Channel Bonding Ports  ----------------
    gt2_rxchanisaligned_out                 : out  std_logic;
    gt2_rxchanrealign_out                   : out  std_logic;
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt2_rxdfeagchold_in                     : in   std_logic;
    gt2_rxdfelfhold_in                      : in   std_logic;
    gt2_rxdfelpmreset_in                    : in   std_logic;
    gt2_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
    gt2_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt2_rxoutclk_out                        : out  std_logic;
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt2_gtrxreset_in                        : in   std_logic;
    gt2_rxpcsreset_in                       : in   std_logic;
    gt2_rxpmareset_in                       : in   std_logic;
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt2_rxlpmen_in                          : in   std_logic;
    ----------------- Polarity Control Ports ----------------
    gt2_rxpolarity_in                       : in   std_logic;
    gt2_txpolarity_in                       : in   std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt2_rxchariscomma_out                   : out  std_logic_vector(1 downto 0);
    gt2_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
    ------------------ Receive Ports - Rx Channel Bonding Ports ----------------
    gt2_rxchbondi_in                        : in   std_logic_vector(4 downto 0);
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt2_rxresetdone_out                     : out  std_logic;
    ------------------------ TX Configurable Driver Ports ----------------------
    gt2_txpostcursor_in                     : in   std_logic_vector(4 downto 0);
    gt2_txprecursor_in                      : in   std_logic_vector(4 downto 0);
    --------------------- TX Initialization and Reset Ports --------------------
    gt2_gttxreset_in                        : in   std_logic;
    gt2_txuserrdy_in                        : in   std_logic;
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt2_txusrclk_in                         : in   std_logic;
    gt2_txusrclk2_in                        : in   std_logic;
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt2_txelecidle_in                       : in   std_logic;
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt2_txprbsforceerr_in                   : in   std_logic;
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt2_txdlyen_in                          : in   std_logic;
    gt2_txdlysreset_in                      : in   std_logic;
    gt2_txdlysresetdone_out                 : out  std_logic;
    gt2_txphalign_in                        : in   std_logic;
    gt2_txphaligndone_out                   : out  std_logic;
    gt2_txphalignen_in                      : in   std_logic;
    gt2_txphdlyreset_in                     : in   std_logic;
    gt2_txphinit_in                         : in   std_logic;
    gt2_txphinitdone_out                    : out  std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt2_txdata_in                           : in   std_logic_vector(15 downto 0);
    gt2_txdiffctrl_in                       : in   std_logic_vector(3 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt2_GTXtxn_out                          : out  std_logic;
    gt2_GTXtxp_out                          : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt2_txoutclk_out                        : out  std_logic;
    gt2_txoutclkfabric_out                  : out  std_logic;
    gt2_txoutclkpcs_out                     : out  std_logic;
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt2_txcharisk_in                        : in   std_logic_vector(1 downto 0);
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt2_txpcsreset_in                       : in   std_logic;
    gt2_txpmareset_in                       : in   std_logic;
    gt2_txresetdone_out                     : out  std_logic;
    ------------------ Transmit Ports - pattern Generator Ports ----------------
    gt2_txprbssel_in                        : in   std_logic_vector(2 downto 0);
    --GT3  (X0Y7)
    --____________________________CHANNEL PORTS________________________________
    ---------------------------- Channel - DRP Ports  --------------------------
    gt3_drpaddr_in                          : in   std_logic_vector(8 downto 0);
    gt3_drpclk_in                           : in   std_logic;
    gt3_drpdi_in                            : in   std_logic_vector(15 downto 0);
    gt3_drpdo_out                           : out  std_logic_vector(15 downto 0);
    gt3_drpen_in                            : in   std_logic;
    gt3_drprdy_out                          : out  std_logic;
    gt3_drpwe_in                            : in   std_logic;
    gt3_dmonitorout_out                     : out  std_logic_vector(7 downto 0);
    ------------------------------- Loopback Ports -----------------------------
    gt3_loopback_in                         : in   std_logic_vector(2 downto 0);
    ------------------------------ Power-Down Ports ----------------------------
    gt3_rxpd_in                             : in   std_logic_vector(1 downto 0);
    gt3_txpd_in                             : in   std_logic_vector(1 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    gt3_rxuserrdy_in                        : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    gt3_eyescandataerror_out                : out  std_logic;
    gt3_eyescanreset_in                     : in   std_logic;
    gt3_eyescantrigger_in                   : in   std_logic;
    gt3_rxrate_in                           : in   std_logic_vector(2 downto 0);
    gt3_rxratedone_out                      : out  std_logic;
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt3_rxcdrhold_in                        : in   std_logic;
    gt3_rxcdrlock_out                       : out  std_logic;
    ------------------- Receive Ports - Clock Correction Ports -----------------
    gt3_rxclkcorcnt_out                     : out  std_logic_vector(1 downto 0);
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt3_rxusrclk_in                         : in   std_logic;
    gt3_rxusrclk2_in                        : in   std_logic;
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt3_rxdata_out                          : out  std_logic_vector(15 downto 0);
    ------------------- Receive Ports - Pattern Checker Ports ------------------
    gt3_rxprbserr_out                       : out  std_logic;
    gt3_rxprbssel_in                        : in   std_logic_vector(2 downto 0);
    ------------------- Receive Ports - Pattern Checker ports ------------------
    gt3_rxprbscntreset_in                   : in   std_logic;
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt3_rxdisperr_out                       : out  std_logic_vector(1 downto 0);
    gt3_rxnotintable_out                    : out  std_logic_vector(1 downto 0);
    --------------------------- Receive Ports - RX AFE -------------------------
    gt3_GTXrxp_in                           : in   std_logic;
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt3_GTXrxn_in                           : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt3_rxbufreset_in                       : in   std_logic;
    gt3_rxbufstatus_out                     : out  std_logic_vector(2 downto 0);
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt3_rxbyteisaligned_out                 : out  std_logic;
    gt3_rxbyterealign_out                   : out  std_logic;
    gt3_rxcommadet_out                      : out  std_logic;
    gt3_rxmcommaalignen_in                  : in   std_logic;
    gt3_rxpcommaalignen_in                  : in   std_logic;
    ------------------ Receive Ports - RX Channel Bonding Ports ----------------
    gt3_rxchanbondseq_out                   : out  std_logic;
    gt3_rxchbonden_in                       : in   std_logic;
    gt3_rxchbondlevel_in                    : in   std_logic_vector(2 downto 0);
    gt3_rxchbondmaster_in                   : in   std_logic;
    gt3_rxchbondo_out                       : out  std_logic_vector(4 downto 0);
    gt3_rxchbondslave_in                    : in   std_logic;
    ----------------- Receive Ports - RX Channel Bonding Ports  ----------------
    gt3_rxchanisaligned_out                 : out  std_logic;
    gt3_rxchanrealign_out                   : out  std_logic;
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt3_rxdfeagchold_in                     : in   std_logic;
    gt3_rxdfelfhold_in                      : in   std_logic;
    gt3_rxdfelpmreset_in                    : in   std_logic;
    gt3_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
    gt3_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt3_rxoutclk_out                        : out  std_logic;
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt3_gtrxreset_in                        : in   std_logic;
    gt3_rxpcsreset_in                       : in   std_logic;
    gt3_rxpmareset_in                       : in   std_logic;
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt3_rxlpmen_in                          : in   std_logic;
    ----------------- Polarity Control Ports ----------------
    gt3_rxpolarity_in                       : in   std_logic;
    gt3_txpolarity_in                       : in   std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt3_rxchariscomma_out                   : out  std_logic_vector(1 downto 0);
    gt3_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
    ------------------ Receive Ports - Rx Channel Bonding Ports ----------------
    gt3_rxchbondi_in                        : in   std_logic_vector(4 downto 0);
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt3_rxresetdone_out                     : out  std_logic;
    ------------------------ TX Configurable Driver Ports ----------------------
    gt3_txpostcursor_in                     : in   std_logic_vector(4 downto 0);
    gt3_txprecursor_in                      : in   std_logic_vector(4 downto 0);
    --------------------- TX Initialization and Reset Ports --------------------
    gt3_gttxreset_in                        : in   std_logic;
    gt3_txuserrdy_in                        : in   std_logic;
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt3_txusrclk_in                         : in   std_logic;
    gt3_txusrclk2_in                        : in   std_logic;
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt3_txelecidle_in                       : in   std_logic;
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt3_txprbsforceerr_in                   : in   std_logic;
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt3_txdlyen_in                          : in   std_logic;
    gt3_txdlysreset_in                      : in   std_logic;
    gt3_txdlysresetdone_out                 : out  std_logic;
    gt3_txphalign_in                        : in   std_logic;
    gt3_txphaligndone_out                   : out  std_logic;
    gt3_txphalignen_in                      : in   std_logic;
    gt3_txphdlyreset_in                     : in   std_logic;
    gt3_txphinit_in                         : in   std_logic;
    gt3_txphinitdone_out                    : out  std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt3_txdata_in                           : in   std_logic_vector(15 downto 0);
    gt3_txdiffctrl_in                       : in   std_logic_vector(3 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt3_GTXtxn_out                          : out  std_logic;
    gt3_GTXtxp_out                          : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt3_txoutclk_out                        : out  std_logic;
    gt3_txoutclkfabric_out                  : out  std_logic;
    gt3_txoutclkpcs_out                     : out  std_logic;
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt3_txcharisk_in                        : in   std_logic_vector(1 downto 0);
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt3_txpcsreset_in                       : in   std_logic;
    gt3_txpmareset_in                       : in   std_logic;
    gt3_txresetdone_out                     : out  std_logic;
    ------------------ Transmit Ports - pattern Generator Ports ----------------
    gt3_txprbssel_in                        : in   std_logic_vector(2 downto 0);
    --____________________________COMMON PORTS________________________________
    ----------------- Common Block - GTPE2_COMMON Clocking Ports ---------------
    gt0_gtrefclk0_common_in                 : in   std_logic;
    ------------------------- Common Block - QPLL Ports ------------------------
    gt0_qplllock_out                        : out  std_logic;
    gt0_qplllockdetclk_in                   : in   std_logic;
    gt0_qpllrefclklost_out                  : out  std_logic;
    gt0_qpllreset_in                        : in   std_logic
  );
  end component;

  component XauiGtx7Core_cl_clocking
  port (
    txoutclk                 : in std_logic;
    clk156                   : out std_logic
    );
  end component;

  component XauiGtx7Core_cl_resets
  port (
    reset                    : in  std_logic;
    clk156                   : in  std_logic;
    txlock                   : in  std_logic;
    reset156                 : out std_logic
    );
  end component;

  component XauiGtx7Core_gt_wrapper_tx_sync_manual
  Generic(
    NUMBER_OF_LANES          : integer range 1 to 32:= 4;  -- Number of lanes that are controlled using this FSM.
    MASTER_LANE_ID           : integer range 0 to 31:= 0   -- Number of the lane which is considered the master in manual phase-alignment
  );

  Port (
    STABLE_CLOCK             : in  std_logic;              --Stable Clock, either a stable clock from the PCB
                                                           --or reference-clock present at startup.
    RESET_PHALIGNMENT        : in  std_logic;
    RUN_PHALIGNMENT          : in  std_logic;
    PHASE_ALIGNMENT_DONE     : out std_logic := '0';       -- Manual phase-alignment performed sucessfully
    TXDLYSRESET              : out std_logic_vector(NUMBER_OF_LANES-1 downto 0) := (others=> '0');
    TXDLYSRESETDONE          : in  std_logic_vector(NUMBER_OF_LANES-1 downto 0);
    TXPHINIT                 : out std_logic_vector(NUMBER_OF_LANES-1 downto 0) := (others=> '0');
    TXPHINITDONE             : in  std_logic_vector(NUMBER_OF_LANES-1 downto 0);
    TXPHALIGN                : out std_logic_vector(NUMBER_OF_LANES-1 downto 0) := (others=> '0');
    TXPHALIGNDONE            : in  std_logic_vector(NUMBER_OF_LANES-1 downto 0);
    TXDLYEN                  : out std_logic_vector(NUMBER_OF_LANES-1 downto 0) := (others=> '0')
  );
  end component;

  component XauiGtx7Core_reset_counter
    port
    (
      clk                    : in  std_logic;
      done                   : out std_logic;
      initial_reset          : out std_logic
    );
  end component;

  component XauiGtx7Core_ff_synchronizer
    generic
    (
      C_NUM_SYNC_REGS  : integer := 3
    );
    port
    (
      clk                    : in  std_logic;
      data_in                : in std_logic;
      data_out               : out std_logic
    );
  end component;

  component XauiGtx7Core_pulse_stretcher
    generic
    (
      C_NUM_SYNC_REGS  : integer := 3
    );
    port
    (
      clk                    : in  std_logic;
      data_in                : in std_logic;
      data_out               : out std_logic
    );
  end component;

  constant SYNC_COUNT_LENGTH                 : integer := 16;
  constant RESET_COUNT_LENGTH                : integer := 32;
  constant CHBOND_COUNT_LENGTH               : integer := 16;

----------------------------------------------------------------------------
-- Signal declarations.
---------------------------------------------------------------------------
  signal uclk_signal_detect                  : std_logic_vector(3 downto 0);
  signal core_mgt_rx_reset                   : std_logic_vector(3 downto 0);
  signal mgt_txdata                          : std_logic_vector(63 downto 0);
  signal mgt_txcharisk                       : std_logic_vector(7 downto 0);
  signal mgt_rxdata                          : std_logic_vector(63 downto 0);
  signal mgt_rxcharisk                       : std_logic_vector(7 downto 0);
  signal mgt_enable_align                    : std_logic_vector(3 downto 0);
  signal uclk_mgt_enchansync                 : std_logic;
  signal uclk_mgt_enchansync_reg             : std_logic;
  signal mgt_rxdisperr                       : std_logic_vector(7 downto 0);
  signal mgt_rxnotintable                    : std_logic_vector(7 downto 0);
  signal uclk_mgt_rx_reset                   : std_logic;
  signal uclk_mgt_tx_reset                   : std_logic;
  signal mgt_codevalid                       : std_logic_vector(7 downto 0);
  signal mgt_rxchariscomma                   : std_logic_vector(7 downto 0);
  signal mgt_rxdata_reg                      : std_logic_vector(63 downto 0);
  signal mgt_rxcharisk_reg                   : std_logic_vector(7 downto 0);

  signal mgt_rxnotintable_reg                : std_logic_vector(7 downto 0);
  signal mgt_rxdisperr_reg                   : std_logic_vector(7 downto 0);
  signal mgt_codecomma_reg                   : std_logic_vector(7 downto 0);
  signal uclk_mgt_rxbuf_reset                : std_logic_vector(3 downto 0) := "0000";
  signal mgt_tx_fault                        : std_logic_vector(3 downto 0);

  signal uclk_mgt_loopback                   : std_logic;
  signal uclk_mgt_loopback_reg               : std_logic;
  signal uclk_loopback_reset                 : std_logic;
  signal uclk_loopback_int                   : std_logic_vector(2 downto 0);

  signal uclk_mgt_powerdown                  : std_logic;
  signal uclk_mgt_powerdown_r                : std_logic;
  signal uclk_mgt_powerdown_r2               : std_logic_vector(1 downto 0);
  signal uclk_mgt_powerdown_falling          : std_logic;

  signal mgt_plllocked                       : std_logic;
  signal uclk_txlock                         : std_logic;
  signal uclk_rxlock                         : std_logic_vector(3 downto 0);

  signal uclk_mgt_rxbuferr                   : std_logic_vector(3 downto 0);
  signal uclk_mgt_rxbufstatus                : std_logic_vector(11 downto 0);
  signal uclk_mgt_rxbufstatus_reg            : std_logic_vector(11 downto 0);
  signal uclk_mgt_txresetdone_reg            : std_logic_vector(3 downto 0);
  signal uclk_cbm_rx_reset                   : std_logic;
  signal mgt_txuserrdy                       : std_logic;
  signal mgt_rxuserrdy                       : std_logic;

  signal gt0_txoutclk_i                      : std_logic;

  -- GT Control
  signal gt0_loopback                        : std_logic_vector(2 downto 0);
  signal uclk_gt0_rxresetdone                : std_logic;
  signal uclk_gt0_txresetdone                : std_logic;
  -- Debug Wires

  -- TX Reset and Initialisation
  signal gt0_gttxreset                       : std_logic;
  signal gt0_txpmareset                      : std_logic;
  signal gt0_txpcsreset                      : std_logic;
  signal gt0_txuserrdy                       : std_logic;
  -- RX Reset and Initialisation
  signal gt0_gtrxreset                       : std_logic;
  signal gt0_rxpmareset                      : std_logic;
  signal gt0_rxpcsreset                      : std_logic;
  signal gt0_rxbufreset                      : std_logic;
  signal gt0_rxuserrdy                       : std_logic;

  signal gt0_rxchanbondseq                   : std_logic;
  signal gt0_rxchanisaligned                 : std_logic;
  signal gt0_rxchanrealign                   : std_logic;
  signal gt0_rxclkcorcnt                     : std_logic_vector(1 downto 0);
  signal gt0_rxbyteisaligned                 : std_logic;
  signal gt0_rxbyterealign                   : std_logic;
  signal gt0_rxcommadet                      : std_logic;
  signal gt0_rxprbserr                       : std_logic;
  -------------------------- Channel Bonding Wires ---------------------------
  signal gt0_rxchbondo_i                     : std_logic_vector(4 downto 0);
  signal gt1_loopback                        : std_logic_vector(2 downto 0);
  signal uclk_gt1_rxresetdone                : std_logic;
  signal uclk_gt1_txresetdone                : std_logic;
  -- Debug Wires

  -- TX Reset and Initialisation
  signal gt1_gttxreset                       : std_logic;
  signal gt1_txpmareset                      : std_logic;
  signal gt1_txpcsreset                      : std_logic;
  signal gt1_txuserrdy                       : std_logic;
  -- RX Reset and Initialisation
  signal gt1_gtrxreset                       : std_logic;
  signal gt1_rxpmareset                      : std_logic;
  signal gt1_rxpcsreset                      : std_logic;
  signal gt1_rxbufreset                      : std_logic;
  signal gt1_rxuserrdy                       : std_logic;

  signal gt1_rxchanbondseq                   : std_logic;
  signal gt1_rxchanisaligned                 : std_logic;
  signal gt1_rxchanrealign                   : std_logic;
  signal gt1_rxclkcorcnt                     : std_logic_vector(1 downto 0);
  signal gt1_rxbyteisaligned                 : std_logic;
  signal gt1_rxbyterealign                   : std_logic;
  signal gt1_rxcommadet                      : std_logic;
  signal gt1_rxprbserr                       : std_logic;
  -------------------------- Channel Bonding Wires ---------------------------
  signal gt1_rxchbondo_i                     : std_logic_vector(4 downto 0);
  signal gt2_loopback                        : std_logic_vector(2 downto 0);
  signal uclk_gt2_rxresetdone                : std_logic;
  signal uclk_gt2_txresetdone                : std_logic;
  -- Debug Wires

  -- TX Reset and Initialisation
  signal gt2_gttxreset                       : std_logic;
  signal gt2_txpmareset                      : std_logic;
  signal gt2_txpcsreset                      : std_logic;
  signal gt2_txuserrdy                       : std_logic;
  -- RX Reset and Initialisation
  signal gt2_gtrxreset                       : std_logic;
  signal gt2_rxpmareset                      : std_logic;
  signal gt2_rxpcsreset                      : std_logic;
  signal gt2_rxbufreset                      : std_logic;
  signal gt2_rxuserrdy                       : std_logic;

  signal gt2_rxchanbondseq                   : std_logic;
  signal gt2_rxchanisaligned                 : std_logic;
  signal gt2_rxchanrealign                   : std_logic;
  signal gt2_rxclkcorcnt                     : std_logic_vector(1 downto 0);
  signal gt2_rxbyteisaligned                 : std_logic;
  signal gt2_rxbyterealign                   : std_logic;
  signal gt2_rxcommadet                      : std_logic;
  signal gt2_rxprbserr                       : std_logic;
  -------------------------- Channel Bonding Wires ---------------------------
  signal gt2_rxchbondo_i                     : std_logic_vector(4 downto 0);
  signal gt3_loopback                        : std_logic_vector(2 downto 0);
  signal uclk_gt3_rxresetdone                : std_logic;
  signal uclk_gt3_txresetdone                : std_logic;
  -- Debug Wires

  -- TX Reset and Initialisation
  signal gt3_gttxreset                       : std_logic;
  signal gt3_txpmareset                      : std_logic;
  signal gt3_txpcsreset                      : std_logic;
  signal gt3_txuserrdy                       : std_logic;
  -- RX Reset and Initialisation
  signal gt3_gtrxreset                       : std_logic;
  signal gt3_rxpmareset                      : std_logic;
  signal gt3_rxpcsreset                      : std_logic;
  signal gt3_rxbufreset                      : std_logic;
  signal gt3_rxuserrdy                       : std_logic;

  signal gt3_rxchanbondseq                   : std_logic;
  signal gt3_rxchanisaligned                 : std_logic;
  signal gt3_rxchanrealign                   : std_logic;
  signal gt3_rxclkcorcnt                     : std_logic_vector(1 downto 0);
  signal gt3_rxbyteisaligned                 : std_logic;
  signal gt3_rxbyterealign                   : std_logic;
  signal gt3_rxcommadet                      : std_logic;
  signal gt3_rxprbserr                       : std_logic;
  -------------------------- Channel Bonding Wires ---------------------------
  signal gt3_rxchbondo_i                     : std_logic_vector(4 downto 0);

  signal uclk_sync_status                    : std_logic_vector(3 downto 0);
  signal uclk_align_status                   : std_logic;

  signal gt_txdlysreset                      : std_logic_vector(3 downto 0);
  signal gt_txphaligndone                    : std_logic_vector(3 downto 0);
  signal gt_txdlysresetdone                  : std_logic_vector(3 downto 0);

  signal gt_txphinit                         : std_logic_vector(3 downto 0);
  signal gt_txphinitdone                     : std_logic_vector(3 downto 0);
  signal gt_txphalign                        : std_logic_vector(3 downto 0);
  signal gt_txdlyen                          : std_logic_vector(3 downto 0);
  signal uclk_txsync_start_phase_align       : std_logic;

  signal uclk_phase_align_complete           : std_logic;

  signal uclk_chbond_counter                 : unsigned(CHBOND_COUNT_LENGTH -1 downto 0) := (others => '0');
  signal uclk_sync_counter                   : unsigned(SYNC_COUNT_LENGTH - 1 downto 0)  := (others => '0');
  signal dclk_reset_count_done               : std_logic := '0';
  signal uclk_reset_count_done               : std_logic := '0';
  signal dclk_initial_reset                  : std_logic := '0';
  signal dclk_pll_reset                      : std_logic;

  signal reset156                            : std_logic;
  signal dclk_reset                          : std_logic;
  signal clk156                              : std_logic;

  signal rxprbs_in_use                       : std_logic := '0';

----------------------------------------------------------------------------
-- Function declarations.
---------------------------------------------------------------------------
function IsBufError (bufStatus:std_logic_vector(2 downto 0)) return std_logic is
  variable result : std_logic;
begin
  if bufStatus = "101" or bufStatus = "110" then
    result := '1';
  else
    result := '0';
  end if;
  return result;
end;

begin

----------------------------------------------------------------------------
-- Logic description.
---------------------------------------------------------------------------

  -- Assign output port from interal signals
  debug <= uclk_align_status & uclk_sync_status & uclk_phase_align_complete;
  clk156_out <= clk156;

  xaui_cl_clocking_i : XauiGtx7Core_cl_clocking
    port map(
      txoutclk             => gt0_txoutclk_i,
      clk156               => clk156
    );

  xaui_cl_resets_i : XauiGtx7Core_cl_resets
    port map(
      reset                => reset,
      clk156               => clk156,
      txlock               => uclk_txlock,
      reset156             => reset156
    );

  -- Synchronize the reset signal to dclk
  reset_sync_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
      clk                  => dclk,
      data_in              => reset,
      data_out             => dclk_reset
    );

  -- Synchronize signal_detect to clk156
  signal_detect_0_sync_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
     clk                   => clk156,
     data_in               => signal_detect(0),
     data_out              => uclk_signal_detect(0)
    );
  signal_detect_1_sync_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
     clk                   => clk156,
     data_in               => signal_detect(1),
     data_out              => uclk_signal_detect(1)
    );
  signal_detect_2_sync_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
     clk                   => clk156,
     data_in               => signal_detect(2),
     data_out              => uclk_signal_detect(2)
    );
  signal_detect_3_sync_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
     clk                   => clk156,
     data_in               => signal_detect(3),
     data_out              => uclk_signal_detect(3)
    );

  XauiGtx7Core_core : xaui_v12_1_top
    generic map(
      c_family             => "kintex7",
      c_has_mdio           => false,
      c_is_dxaui           => false
    )
    port map (
      reset                => reset156,

      xgmii_txd            => xgmii_txd,
      xgmii_txc            => xgmii_txc,
      xgmii_rxd            => xgmii_rxd,
      xgmii_rxc            => xgmii_rxc,
      usrclk               => clk156,
      mgt_txdata           => mgt_txdata,
      mgt_txcharisk        => mgt_txcharisk,
      mgt_rxdata           => mgt_rxdata_reg,
      mgt_rxcharisk        => mgt_rxcharisk_reg,
      mgt_codevalid        => mgt_codevalid,
      mgt_codecomma        => mgt_codecomma_reg,
      mgt_enable_align     => mgt_enable_align,
      mgt_enchansync       => uclk_mgt_enchansync,
      mgt_rxlock           => uclk_rxlock,
      mgt_loopback         => uclk_mgt_loopback,
      mgt_powerdown        => uclk_mgt_powerdown,
      mgt_tx_reset         => mgt_tx_fault,
      mgt_rx_reset         => core_mgt_rx_reset,

      signal_detect        => uclk_signal_detect,
      align_status         => uclk_align_status,
      sync_status          => uclk_sync_status,

      soft_reset           => open,
      mdc                  => '0',
      mdio_in              => '0',
      mdio_out             => open,
      mdio_tri             => open,
      prtad                => (others => '0'),
      type_sel             => (others => '0'),

      configuration_vector => configuration_vector,
      status_vector        => status_vector );

  -- Detect a falling edge in loopback and issues a reset so that GTs lose sync and alignment.
  p_loopback_reset : process (clk156)
  begin
    if rising_edge(clk156) then
      uclk_mgt_loopback_reg <= uclk_mgt_loopback;
      if uclk_mgt_loopback_reg = '1' and uclk_mgt_loopback = '0' then
        uclk_loopback_reset <= '1';
      else
        uclk_loopback_reset <= '0';
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------
   -- Transceiver instances
   gt_wrapper_i : XauiGtx7Core_gt_wrapper
    generic map (
      WRAPPER_SIM_GTRESET_SPEEDUP => "TRUE"
    )
    port map (
    ---------------------------- Channel - DRP Ports  --------------------------
    gt0_drpaddr_in                          => gt0_drpaddr,
    gt0_drpclk_in                           => dclk,
    gt0_drpdi_in                            => gt0_drpdi,
    gt0_drpdo_out                           => gt0_drpdo,
    gt0_drpen_in                            => gt0_drpen,
    gt0_drprdy_out                          => gt0_drprdy,
    gt0_drpwe_in                            => gt0_drpwe,
    ------------------------- Digital Monitor Ports --------------------------
    gt0_dmonitorout_out                     => gt0_dmonitorout_out,
    ------------------------------- Loopback Ports -----------------------------
    gt0_loopback_in                         => gt0_loopback,
    ------------------------------ Power-Down Ports ----------------------------
    gt0_rxpd_in                             => uclk_mgt_powerdown_r2,
    gt0_txpd_in                             => uclk_mgt_powerdown_r2,
    --------------------- RX Initialization and Reset Ports --------------------
    gt0_rxuserrdy_in                        => gt0_rxuserrdy,
    -------------------------- RX Margin Analysis Ports ------------------------
    gt0_eyescandataerror_out                => gt0_eyescandataerror_out,
    gt0_eyescanreset_in                     => gt0_eyescanreset_in,
    gt0_eyescantrigger_in                   => gt0_eyescantrigger_in,
    gt0_rxrate_in                           => gt0_rxrate_in,
    gt0_rxratedone_out                      => open,
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt0_rxcdrhold_in                        => gt0_rxcdrhold_in,
    gt0_rxcdrlock_out                       => open,
    ------------------- Receive Ports - Clock Correction Ports -----------------
    gt0_rxclkcorcnt_out                     => gt0_rxclkcorcnt,
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt0_rxusrclk_in                         => clk156,
    gt0_rxusrclk2_in                        => clk156,
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt0_rxdata_out                          => mgt_rxdata(15 downto 0),
    ------------------- Receive Ports - Pattern Checker Ports ------------------
    gt0_rxprbserr_out                       => gt0_rxprbserr,
    gt0_rxprbssel_in                        => gt0_rxprbssel_in,
    ------------------- Receive Ports - Pattern Checker ports ------------------
    gt0_rxprbscntreset_in                   => gt0_rxprbscntreset_in,
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt0_rxdisperr_out                       => mgt_rxdisperr(1 downto 0),
    gt0_rxnotintable_out                    => mgt_rxnotintable(1 downto 0),
    --------------------------- Receive Ports - RX AFE -------------------------
    gt0_GTXrxp_in                 => xaui_rx_l0_p,
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt0_GTXrxn_in                 => xaui_rx_l0_n,
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt0_rxbufreset_in                       => gt0_rxbufreset,
    gt0_rxbufstatus_out                     => uclk_mgt_rxbufstatus(2 downto 0),
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt0_rxbyteisaligned_out                 => gt0_rxbyteisaligned,
    gt0_rxbyterealign_out                   => gt0_rxbyterealign,
    gt0_rxcommadet_out                      => gt0_rxcommadet,
    gt0_rxmcommaalignen_in                  => mgt_enable_align(0),
    gt0_rxpcommaalignen_in                  => mgt_enable_align(0),
    ------------------ Receive Ports - RX Channel Bonding Ports ----------------
    gt0_rxchanbondseq_out                   => gt0_rxchanbondseq,
    gt0_rxchbonden_in                       => uclk_mgt_enchansync_reg,
    gt0_rxchbondlevel_in                    => "000",
    gt0_rxchbondmaster_in                   => '0',
    gt0_rxchbondo_out                       => gt0_rxchbondo_i,
    gt0_rxchbondslave_in                    => '1',
    gt0_rxchbondi_in                        => gt1_rxchbondo_i,
    gt0_rxchanisaligned_out                 => gt0_rxchanisaligned,
    gt0_rxchanrealign_out                   => gt0_rxchanrealign,
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt0_rxdfeagchold_in                     => '0',
    gt0_rxdfelfhold_in                      => '0',
    gt0_rxdfelpmreset_in                    => gt0_rxdfelpmreset_in,
    gt0_rxmonitorout_out                    => gt0_rxmonitorout_out,
    gt0_rxmonitorsel_in                     => gt0_rxmonitorsel_in,
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt0_rxoutclk_out                        => open,
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt0_gtrxreset_in                        => gt0_gtrxreset,
    gt0_rxpcsreset_in                       => gt0_rxpcsreset,
    gt0_rxpmareset_in                       => gt0_rxpmareset,
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt0_rxlpmen_in                          => gt0_rxlpmen_in,
    ----------------- Polarity Control Ports ----------------
    gt0_rxpolarity_in                       => gt0_rxpolarity_in,
    gt0_txpolarity_in                       => gt0_txpolarity_in,
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt0_rxchariscomma_out                   => mgt_rxchariscomma(1 downto 0),
    gt0_rxcharisk_out                       => mgt_rxcharisk(1 downto 0),
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt0_rxresetdone_out                     => uclk_gt0_rxresetdone,
    ------------------------ TX Configurable Driver Ports ----------------------
    gt0_txpostcursor_in                     => gt0_txpostcursor_in,
    gt0_txprecursor_in                      => gt0_txprecursor_in,
    --------------------- TX Initialization and Reset Ports --------------------
    gt0_gttxreset_in                        => gt0_gttxreset,
    gt0_txuserrdy_in                        => gt0_txuserrdy,
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt0_txusrclk_in                         => clk156,
    gt0_txusrclk2_in                        => clk156,
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt0_txelecidle_in                       => uclk_mgt_powerdown_r,
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt0_txprbsforceerr_in                   => gt0_txprbsforceerr_in,
    gt0_txprbssel_in                        => gt0_txprbssel_in,
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt0_txdlyen_in                          => gt_txdlyen(0),
    gt0_txdlysreset_in                      => gt_txdlysreset(0),
    gt0_txdlysresetdone_out                 => gt_txdlysresetdone(0),
    gt0_txphalign_in                        => gt_txphalign(0),
    gt0_txphaligndone_out                   => gt_txphaligndone(0),
    gt0_txphalignen_in                      => '1',
    gt0_txphdlyreset_in                     => '0',
    gt0_txphinit_in                         => gt_txphinit(0),
    gt0_txphinitdone_out                    => gt_txphinitdone(0),
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt0_txdata_in                           => mgt_txdata(15 downto 0),
    gt0_txdiffctrl_in                       => gt0_txdiffctrl_in,
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt0_GTXtxn_out                => xaui_tx_l0_n,
    gt0_GTXtxp_out                => xaui_tx_l0_p,
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt0_txoutclk_out                        => gt0_txoutclk_i,
    gt0_txoutclkfabric_out                  => open,
    gt0_txoutclkpcs_out                     => open,
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt0_txcharisk_in                        => mgt_txcharisk(1 downto 0),
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt0_txpcsreset_in                       => gt0_txpcsreset,
    gt0_txpmareset_in                       => gt0_txpmareset,
    gt0_txresetdone_out                     => uclk_gt0_txresetdone,
    --GT1  (X0Y5)
    --____________________________CHANNEL PORTS________________________________
    ---------------------------- Channel - DRP Ports  --------------------------
    gt1_drpaddr_in                          => gt1_drpaddr,
    gt1_drpclk_in                           => dclk,
    gt1_drpdi_in                            => gt1_drpdi,
    gt1_drpdo_out                           => gt1_drpdo,
    gt1_drpen_in                            => gt1_drpen,
    gt1_drprdy_out                          => gt1_drprdy,
    gt1_drpwe_in                            => gt1_drpwe,
    ------------------------- Digital Monitor Ports --------------------------
    gt1_dmonitorout_out                     => gt1_dmonitorout_out,
    ------------------------------- Loopback Ports -----------------------------
    gt1_loopback_in                         => gt1_loopback,
    ------------------------------ Power-Down Ports ----------------------------
    gt1_rxpd_in                             => uclk_mgt_powerdown_r2,
    gt1_txpd_in                             => uclk_mgt_powerdown_r2,
    --------------------- RX Initialization and Reset Ports --------------------
    gt1_rxuserrdy_in                        => gt1_rxuserrdy,
    -------------------------- RX Margin Analysis Ports ------------------------
    gt1_eyescandataerror_out                => gt1_eyescandataerror_out,
    gt1_eyescanreset_in                     => gt1_eyescanreset_in,
    gt1_eyescantrigger_in                   => gt1_eyescantrigger_in,
    gt1_rxrate_in                           => gt1_rxrate_in,
    gt1_rxratedone_out                      => open,
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt1_rxcdrhold_in                        => gt1_rxcdrhold_in,
    gt1_rxcdrlock_out                       => open,
    ------------------- Receive Ports - Clock Correction Ports -----------------
    gt1_rxclkcorcnt_out                     => gt1_rxclkcorcnt,
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt1_rxusrclk_in                         => clk156,
    gt1_rxusrclk2_in                        => clk156,
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt1_rxdata_out                          => mgt_rxdata(31 downto 16),
    ------------------- Receive Ports - Pattern Checker Ports ------------------
    gt1_rxprbserr_out                       => gt1_rxprbserr,
    gt1_rxprbssel_in                        => gt1_rxprbssel_in,
    ------------------- Receive Ports - Pattern Checker ports ------------------
    gt1_rxprbscntreset_in                   => gt1_rxprbscntreset_in,
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt1_rxdisperr_out                       => mgt_rxdisperr(3 downto 2),
    gt1_rxnotintable_out                    => mgt_rxnotintable(3 downto 2),
    --------------------------- Receive Ports - RX AFE -------------------------
    gt1_GTXrxp_in                 => xaui_rx_l1_p,
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt1_GTXrxn_in                 => xaui_rx_l1_n,
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt1_rxbufreset_in                       => gt1_rxbufreset,
    gt1_rxbufstatus_out                     => uclk_mgt_rxbufstatus(5 downto 3),
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt1_rxbyteisaligned_out                 => gt1_rxbyteisaligned,
    gt1_rxbyterealign_out                   => gt1_rxbyterealign,
    gt1_rxcommadet_out                      => gt1_rxcommadet,
    gt1_rxmcommaalignen_in                  => mgt_enable_align(1),
    gt1_rxpcommaalignen_in                  => mgt_enable_align(1),
    ------------------ Receive Ports - RX Channel Bonding Ports ----------------
    gt1_rxchanbondseq_out                   => gt1_rxchanbondseq,
    gt1_rxchbonden_in                       => uclk_mgt_enchansync_reg,
    gt1_rxchbondlevel_in                    => "001",
    gt1_rxchbondmaster_in                   => '0',
    gt1_rxchbondo_out                       => gt1_rxchbondo_i,
    gt1_rxchbondslave_in                    => '1',
    gt1_rxchbondi_in                        => gt2_rxchbondo_i,
    gt1_rxchanisaligned_out                 => gt1_rxchanisaligned,
    gt1_rxchanrealign_out                   => gt1_rxchanrealign,
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt1_rxdfeagchold_in                     => '0',
    gt1_rxdfelfhold_in                      => '0',
    gt1_rxdfelpmreset_in                    => gt1_rxdfelpmreset_in,
    gt1_rxmonitorout_out                    => gt1_rxmonitorout_out,
    gt1_rxmonitorsel_in                     => gt1_rxmonitorsel_in,
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt1_rxoutclk_out                        => open,
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt1_gtrxreset_in                        => gt1_gtrxreset,
    gt1_rxpcsreset_in                       => gt1_rxpcsreset,
    gt1_rxpmareset_in                       => gt1_rxpmareset,
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt1_rxlpmen_in                          => gt1_rxlpmen_in,
    ----------------- Polarity Control Ports ----------------
    gt1_rxpolarity_in                       => gt1_rxpolarity_in,
    gt1_txpolarity_in                       => gt1_txpolarity_in,
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt1_rxchariscomma_out                   => mgt_rxchariscomma(3 downto 2),
    gt1_rxcharisk_out                       => mgt_rxcharisk(3 downto 2),
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt1_rxresetdone_out                     => uclk_gt1_rxresetdone,
    ------------------------ TX Configurable Driver Ports ----------------------
    gt1_txpostcursor_in                     => gt1_txpostcursor_in,
    gt1_txprecursor_in                      => gt1_txprecursor_in,
    --------------------- TX Initialization and Reset Ports --------------------
    gt1_gttxreset_in                        => gt1_gttxreset,
    gt1_txuserrdy_in                        => gt1_txuserrdy,
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt1_txusrclk_in                         => clk156,
    gt1_txusrclk2_in                        => clk156,
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt1_txelecidle_in                       => uclk_mgt_powerdown_r,
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt1_txprbsforceerr_in                   => gt1_txprbsforceerr_in,
    gt1_txprbssel_in                        => gt1_txprbssel_in,
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt1_txdlyen_in                          => gt_txdlyen(1),
    gt1_txdlysreset_in                      => gt_txdlysreset(1),
    gt1_txdlysresetdone_out                 => gt_txdlysresetdone(1),
    gt1_txphalign_in                        => gt_txphalign(1),
    gt1_txphaligndone_out                   => gt_txphaligndone(1),
    gt1_txphalignen_in                      => '1',
    gt1_txphdlyreset_in                     => '0',
    gt1_txphinit_in                         => gt_txphinit(1),
    gt1_txphinitdone_out                    => gt_txphinitdone(1),
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt1_txdata_in                           => mgt_txdata(31 downto 16),
    gt1_txdiffctrl_in                       => gt1_txdiffctrl_in,
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt1_GTXtxn_out                => xaui_tx_l1_n,
    gt1_GTXtxp_out                => xaui_tx_l1_p,
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt1_txoutclk_out                        => open,
    gt1_txoutclkfabric_out                  => open,
    gt1_txoutclkpcs_out                     => open,
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt1_txcharisk_in                        => mgt_txcharisk(3 downto 2),
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt1_txpcsreset_in                       => gt1_txpcsreset,
    gt1_txpmareset_in                       => gt1_txpmareset,
    gt1_txresetdone_out                     => uclk_gt1_txresetdone,
    --GT2  (X0Y6)
    --____________________________CHANNEL PORTS________________________________

    ---------------------------- Channel - DRP Ports  --------------------------
    gt2_drpaddr_in                          => gt2_drpaddr,
    gt2_drpclk_in                           => dclk,
    gt2_drpdi_in                            => gt2_drpdi,
    gt2_drpdo_out                           => gt2_drpdo,
    gt2_drpen_in                            => gt2_drpen,
    gt2_drprdy_out                          => gt2_drprdy,
    gt2_drpwe_in                            => gt2_drpwe,
    ------------------------- Digital Monitor Ports --------------------------
    gt2_dmonitorout_out                     => gt2_dmonitorout_out,
    ------------------------------- Loopback Ports -----------------------------
    gt2_loopback_in                         => gt2_loopback,
    ------------------------------ Power-Down Ports ----------------------------
    gt2_rxpd_in                             => uclk_mgt_powerdown_r2,
    gt2_txpd_in                             => uclk_mgt_powerdown_r2,
    --------------------- RX Initialization and Reset Ports --------------------
    gt2_rxuserrdy_in                        => gt2_rxuserrdy,
    -------------------------- RX Margin Analysis Ports ------------------------
    gt2_eyescandataerror_out                => gt2_eyescandataerror_out,
    gt2_eyescanreset_in                     => gt2_eyescanreset_in,
    gt2_eyescantrigger_in                   => gt2_eyescantrigger_in,
    gt2_rxrate_in                           => gt2_rxrate_in,
    gt2_rxratedone_out                      => open,
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt2_rxcdrhold_in                        => gt2_rxcdrhold_in,
    gt2_rxcdrlock_out                       => open,
    ------------------- Receive Ports - Clock Correction Ports -----------------
    gt2_rxclkcorcnt_out                     => gt2_rxclkcorcnt,
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt2_rxusrclk_in                         => clk156,
    gt2_rxusrclk2_in                        => clk156,
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt2_rxdata_out                          => mgt_rxdata(47 downto 32),
    ------------------- Receive Ports - Pattern Checker Ports ------------------
    gt2_rxprbserr_out                       => gt2_rxprbserr,
    gt2_rxprbssel_in                        => gt2_rxprbssel_in,
    ------------------- Receive Ports - Pattern Checker ports ------------------
    gt2_rxprbscntreset_in                   => gt2_rxprbscntreset_in,
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt2_rxdisperr_out                       => mgt_rxdisperr(5 downto 4),
    gt2_rxnotintable_out                    => mgt_rxnotintable(5 downto 4),
    --------------------------- Receive Ports - RX AFE -------------------------
    gt2_GTXrxp_in                 => xaui_rx_l2_p,
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt2_GTXrxn_in                 => xaui_rx_l2_n,
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt2_rxbufreset_in                       => gt2_rxbufreset,
    gt2_rxbufstatus_out                     => uclk_mgt_rxbufstatus(8 downto 6),
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt2_rxbyteisaligned_out                 => gt2_rxbyteisaligned,
    gt2_rxbyterealign_out                   => gt2_rxbyterealign,
    gt2_rxcommadet_out                      => gt2_rxcommadet,
    gt2_rxmcommaalignen_in                  => mgt_enable_align(2),
    gt2_rxpcommaalignen_in                  => mgt_enable_align(2),
    ------------------ Receive Ports - RX Channel Bonding Ports ----------------
    gt2_rxchanbondseq_out                   => gt2_rxchanbondseq,
    gt2_rxchbonden_in                       => uclk_mgt_enchansync_reg,
    gt2_rxchbondlevel_in                    => "010",
    gt2_rxchbondmaster_in                   => '1',
    gt2_rxchbondo_out                       => gt2_rxchbondo_i,
    gt2_rxchbondslave_in                    => '0',
    gt2_rxchbondi_in                        => (others => '0'),
    gt2_rxchanisaligned_out                 => gt2_rxchanisaligned,
    gt2_rxchanrealign_out                   => gt2_rxchanrealign,
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt2_rxdfeagchold_in                     => '0',
    gt2_rxdfelfhold_in                      => '0',
    gt2_rxdfelpmreset_in                    => gt2_rxdfelpmreset_in,
    gt2_rxmonitorout_out                    => gt2_rxmonitorout_out,
    gt2_rxmonitorsel_in                     => gt2_rxmonitorsel_in,
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt2_rxoutclk_out                        => open,
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt2_gtrxreset_in                        => gt2_gtrxreset,
    gt2_rxpcsreset_in                       => gt2_rxpcsreset,
    gt2_rxpmareset_in                       => gt2_rxpmareset,
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt2_rxlpmen_in                          => gt2_rxlpmen_in,
    ----------------- Polarity Control Ports ----------------
    gt2_rxpolarity_in                       => gt2_rxpolarity_in,
    gt2_txpolarity_in                       => gt2_txpolarity_in,
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt2_rxchariscomma_out                   => mgt_rxchariscomma(5 downto 4),
    gt2_rxcharisk_out                       => mgt_rxcharisk(5 downto 4),
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt2_rxresetdone_out                     => uclk_gt2_rxresetdone,
    ------------------------ TX Configurable Driver Ports ----------------------
    gt2_txpostcursor_in                     => gt2_txpostcursor_in,
    gt2_txprecursor_in                      => gt2_txprecursor_in,
    --------------------- TX Initialization and Reset Ports --------------------
    gt2_gttxreset_in                        => gt2_gttxreset,
    gt2_txuserrdy_in                        => gt2_txuserrdy,
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt2_txusrclk_in                         => clk156,
    gt2_txusrclk2_in                        => clk156,
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt2_txelecidle_in                       => uclk_mgt_powerdown_r,
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt2_txprbsforceerr_in                   => gt2_txprbsforceerr_in,
    gt2_txprbssel_in                        => gt2_txprbssel_in,
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt2_txdlyen_in                          => gt_txdlyen(2),
    gt2_txdlysreset_in                      => gt_txdlysreset(2),
    gt2_txdlysresetdone_out                 => gt_txdlysresetdone(2),
    gt2_txphalign_in                        => gt_txphalign(2),
    gt2_txphaligndone_out                   => gt_txphaligndone(2),
    gt2_txphalignen_in                      => '1',
    gt2_txphdlyreset_in                     => '0',
    gt2_txphinit_in                         => gt_txphinit(2),
    gt2_txphinitdone_out                    => gt_txphinitdone(2),
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt2_txdata_in                           => mgt_txdata(47 downto 32),
    gt2_txdiffctrl_in                       => gt2_txdiffctrl_in,
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt2_GTXtxn_out                => xaui_tx_l2_n,
    gt2_GTXtxp_out                => xaui_tx_l2_p,
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt2_txoutclk_out                        => open,
    gt2_txoutclkfabric_out                  => open,
    gt2_txoutclkpcs_out                     => open,
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt2_txcharisk_in                        => mgt_txcharisk(5 downto 4),
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt2_txpcsreset_in                       => gt2_txpcsreset,
    gt2_txpmareset_in                       => gt2_txpmareset,
    gt2_txresetdone_out                     => uclk_gt2_txresetdone,
    --GT3  (X0Y7)
    --____________________________CHANNEL PORTS________________________________

    ---------------------------- Channel - DRP Ports  --------------------------
    gt3_drpaddr_in                          => gt3_drpaddr,
    gt3_drpclk_in                           => dclk,
    gt3_drpdi_in                            => gt3_drpdi,
    gt3_drpdo_out                           => gt3_drpdo,
    gt3_drpen_in                            => gt3_drpen,
    gt3_drprdy_out                          => gt3_drprdy,
    gt3_drpwe_in                            => gt3_drpwe,
    ------------------------- Digital Monitor Ports --------------------------
    gt3_dmonitorout_out                     => gt3_dmonitorout_out,
    ------------------------------- Loopback Ports -----------------------------
    gt3_loopback_in                         => gt3_loopback,
    ------------------------------ Power-Down Ports ----------------------------
    gt3_rxpd_in                             => uclk_mgt_powerdown_r2,
    gt3_txpd_in                             => uclk_mgt_powerdown_r2,
    --------------------- RX Initialization and Reset Ports --------------------
    gt3_rxuserrdy_in                        => gt3_rxuserrdy,
    -------------------------- RX Margin Analysis Ports ------------------------
    gt3_eyescandataerror_out                => gt3_eyescandataerror_out,
    gt3_eyescanreset_in                     => gt3_eyescanreset_in,
    gt3_eyescantrigger_in                   => gt3_eyescantrigger_in,
    gt3_rxrate_in                           => gt3_rxrate_in,
    gt3_rxratedone_out                      => open,
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt3_rxcdrhold_in                        => gt3_rxcdrhold_in,
    gt3_rxcdrlock_out                       => open,
    ------------------- Receive Ports - Clock Correction Ports -----------------
    gt3_rxclkcorcnt_out                     => gt3_rxclkcorcnt,
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt3_rxusrclk_in                         => clk156,
    gt3_rxusrclk2_in                        => clk156,
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt3_rxdata_out                          => mgt_rxdata(63 downto 48),
    ------------------- Receive Ports - Pattern Checker Ports ------------------
    gt3_rxprbserr_out                       => gt3_rxprbserr,
    gt3_rxprbssel_in                        => gt3_rxprbssel_in,
    ------------------- Receive Ports - Pattern Checker ports ------------------
    gt3_rxprbscntreset_in                   => gt3_rxprbscntreset_in,
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt3_rxdisperr_out                       => mgt_rxdisperr(7 downto 6),
    gt3_rxnotintable_out                    => mgt_rxnotintable(7 downto 6),
    --------------------------- Receive Ports - RX AFE -------------------------
    gt3_GTXrxp_in                 => xaui_rx_l3_p,
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt3_GTXrxn_in                 => xaui_rx_l3_n,
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt3_rxbufreset_in                       => gt3_rxbufreset,
    gt3_rxbufstatus_out                     => uclk_mgt_rxbufstatus(11 downto 9),
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt3_rxbyteisaligned_out                 => gt3_rxbyteisaligned,
    gt3_rxbyterealign_out                   => gt3_rxbyterealign,
    gt3_rxcommadet_out                      => gt3_rxcommadet,
    gt3_rxmcommaalignen_in                  => mgt_enable_align(3),
    gt3_rxpcommaalignen_in                  => mgt_enable_align(3),
    ------------------ Receive Ports - RX Channel Bonding Ports ----------------
    gt3_rxchanbondseq_out                   => gt3_rxchanbondseq,
    gt3_rxchbonden_in                       => uclk_mgt_enchansync_reg,
    gt3_rxchbondlevel_in                    => "001",
    gt3_rxchbondmaster_in                   => '0',
    gt3_rxchbondo_out                       => gt3_rxchbondo_i,
    gt3_rxchbondslave_in                    => '1',
    gt3_rxchbondi_in                        => gt2_rxchbondo_i,
    gt3_rxchanisaligned_out                 => gt3_rxchanisaligned,
    gt3_rxchanrealign_out                   => gt3_rxchanrealign,
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt3_rxdfeagchold_in                     => '0',
    gt3_rxdfelfhold_in                      => '0',
    gt3_rxdfelpmreset_in                    => gt3_rxdfelpmreset_in,
    gt3_rxmonitorout_out                    => gt3_rxmonitorout_out,
    gt3_rxmonitorsel_in                     => gt3_rxmonitorsel_in,
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt3_rxoutclk_out                        => open,
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt3_gtrxreset_in                        => gt3_gtrxreset,
    gt3_rxpcsreset_in                       => gt3_rxpcsreset,
    gt3_rxpmareset_in                       => gt3_rxpmareset,
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt3_rxlpmen_in                          => gt3_rxlpmen_in,
    ----------------- Polarity Control Ports ----------------
    gt3_rxpolarity_in                       => gt3_rxpolarity_in,
    gt3_txpolarity_in                       => gt3_txpolarity_in,
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt3_rxchariscomma_out                   => mgt_rxchariscomma(7 downto 6),
    gt3_rxcharisk_out                       => mgt_rxcharisk(7 downto 6),
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt3_rxresetdone_out                     => uclk_gt3_rxresetdone,
    ------------------------ TX Configurable Driver Ports ----------------------
    gt3_txpostcursor_in                     => gt3_txpostcursor_in,
    gt3_txprecursor_in                      => gt3_txprecursor_in,
    --------------------- TX Initialization and Reset Ports --------------------
    gt3_gttxreset_in                        => gt3_gttxreset,
    gt3_txuserrdy_in                        => gt3_txuserrdy,
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt3_txusrclk_in                         => clk156,
    gt3_txusrclk2_in                        => clk156,
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt3_txelecidle_in                       => uclk_mgt_powerdown_r,
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt3_txprbsforceerr_in                   => gt3_txprbsforceerr_in,
    gt3_txprbssel_in                        => gt3_txprbssel_in,
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt3_txdlyen_in                          => gt_txdlyen(3),
    gt3_txdlysreset_in                      => gt_txdlysreset(3),
    gt3_txdlysresetdone_out                 => gt_txdlysresetdone(3),
    gt3_txphalign_in                        => gt_txphalign(3),
    gt3_txphaligndone_out                   => gt_txphaligndone(3),
    gt3_txphalignen_in                      => '1',
    gt3_txphdlyreset_in                     => '0',
    gt3_txphinit_in                         => gt_txphinit(3),
    gt3_txphinitdone_out                    => gt_txphinitdone(3),
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt3_txdata_in                           => mgt_txdata(63 downto 48),
    gt3_txdiffctrl_in                       => gt3_txdiffctrl_in,
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt3_GTXtxn_out                => xaui_tx_l3_n,
    gt3_GTXtxp_out                => xaui_tx_l3_p,
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt3_txoutclk_out                        => open,
    gt3_txoutclkfabric_out                  => open,
    gt3_txoutclkpcs_out                     => open,
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt3_txcharisk_in                        => mgt_txcharisk(7 downto 6),
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt3_txpcsreset_in                       => gt3_txpcsreset,
    gt3_txpmareset_in                       => gt3_txpmareset,
    gt3_txresetdone_out                     => uclk_gt3_txresetdone,
    --____________________________COMMON PORTS________________________________
    ---------------------- Common Block  - Ref Clock Ports ---------------------
    gt0_gtrefclk0_common_in                 => refclk,
    ------------------------- Common Block - QPLL Ports ------------------------
    gt0_qplllock_out                        => mgt_plllocked,
    gt0_qplllockdetclk_in                   => dclk,
    gt0_qpllrefclklost_out                  => open,
    gt0_qpllreset_in                        => dclk_pll_reset
    );

  mgt_codevalid    <= not (mgt_rxnotintable_reg or mgt_rxdisperr_reg);

  -- The Actual GT Loopback is can be set by the external gt_control port
  -- logical OR this. The user should not drive both the XAUI Loopback
  -- and gt_control ports simultaneously
  uclk_loopback_int     <= "010" when uclk_mgt_loopback_reg = '1' else "000";

  gt0_loopback         <= uclk_loopback_int or gt0_loopback_in;
  gt0_rxresetdone_out  <= uclk_gt0_rxresetdone;
  gt0_txresetdone_out  <= uclk_gt0_txresetdone;
  gt0_rxdisperr_out    <= mgt_rxdisperr(1 downto 0);
  gt0_rxnotintable_out <= mgt_rxnotintable(1 downto 0);
  gt0_rxcommadet_out   <= gt0_rxcommadet;
  gt0_rxprbserr_out    <= gt0_rxprbserr;
  gt0_rxbufstatus_out  <= uclk_mgt_rxbufstatus(2 downto 0);

  gt0_txphaligndone_out   <= gt_txphaligndone(0);
  gt0_txphinitdone_out    <= gt_txphinitdone(0);
  gt0_txdlysresetdone_out <= gt_txdlysresetdone(0);


  gt0_gttxreset  <= uclk_mgt_tx_reset;
  gt0_txpmareset <= gt0_txpmareset_in;
  gt0_txpcsreset <= gt0_txpcsreset_in;
  gt0_txuserrdy  <= mgt_txuserrdy;

  gt0_gtrxreset  <= uclk_mgt_rx_reset;
  gt0_rxbufreset <= uclk_mgt_rxbuf_reset(0);

  -- Synchronize the rxpmareset signal
  rxpmareset_sync0_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
      clk      => dclk,
      data_in  => gt0_rxpmareset_in,
      data_out => gt0_rxpmareset
    );

  gt0_rxpcsreset <= gt0_rxpcsreset_in;
  gt0_rxuserrdy  <= mgt_rxuserrdy;
  gt1_loopback         <= uclk_loopback_int or gt1_loopback_in;
  gt1_rxresetdone_out  <= uclk_gt1_rxresetdone;
  gt1_txresetdone_out  <= uclk_gt1_txresetdone;
  gt1_rxdisperr_out    <= mgt_rxdisperr(3 downto 2);
  gt1_rxnotintable_out <= mgt_rxnotintable(3 downto 2);
  gt1_rxcommadet_out   <= gt1_rxcommadet;
  gt1_rxprbserr_out    <= gt1_rxprbserr;
  gt1_rxbufstatus_out  <= uclk_mgt_rxbufstatus(5 downto 3);

  gt1_txphaligndone_out   <= gt_txphaligndone(1);
  gt1_txphinitdone_out    <= gt_txphinitdone(1);
  gt1_txdlysresetdone_out <= gt_txdlysresetdone(1);


  gt1_gttxreset  <= uclk_mgt_tx_reset;
  gt1_txpmareset <= gt1_txpmareset_in;
  gt1_txpcsreset <= gt1_txpcsreset_in;
  gt1_txuserrdy  <= mgt_txuserrdy;

  gt1_gtrxreset  <= uclk_mgt_rx_reset;
  gt1_rxbufreset <= uclk_mgt_rxbuf_reset(1);

  -- Synchronize the rxpmareset signal
  rxpmareset_sync1_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
      clk      => dclk,
      data_in  => gt1_rxpmareset_in,
      data_out => gt1_rxpmareset
    );

  gt1_rxpcsreset <= gt1_rxpcsreset_in;
  gt1_rxuserrdy  <= mgt_rxuserrdy;
  gt2_loopback         <= uclk_loopback_int or gt2_loopback_in;
  gt2_rxresetdone_out  <= uclk_gt2_rxresetdone;
  gt2_txresetdone_out  <= uclk_gt2_txresetdone;
  gt2_rxdisperr_out    <= mgt_rxdisperr(5 downto 4);
  gt2_rxnotintable_out <= mgt_rxnotintable(5 downto 4);
  gt2_rxcommadet_out   <= gt2_rxcommadet;
  gt2_rxprbserr_out    <= gt2_rxprbserr;
  gt2_rxbufstatus_out  <= uclk_mgt_rxbufstatus(8 downto 6);

  gt2_txphaligndone_out   <= gt_txphaligndone(2);
  gt2_txphinitdone_out    <= gt_txphinitdone(2);
  gt2_txdlysresetdone_out <= gt_txdlysresetdone(2);


  gt2_gttxreset  <= uclk_mgt_tx_reset;
  gt2_txpmareset <= gt2_txpmareset_in;
  gt2_txpcsreset <= gt2_txpcsreset_in;
  gt2_txuserrdy  <= mgt_txuserrdy;

  gt2_gtrxreset  <= uclk_mgt_rx_reset;
  gt2_rxbufreset <= uclk_mgt_rxbuf_reset(2);

  -- Synchronize the rxpmareset signal
  rxpmareset_sync2_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
      clk      => dclk,
      data_in  => gt2_rxpmareset_in,
      data_out => gt2_rxpmareset
    );

  gt2_rxpcsreset <= gt2_rxpcsreset_in;
  gt2_rxuserrdy  <= mgt_rxuserrdy;
  gt3_loopback         <= uclk_loopback_int or gt3_loopback_in;
  gt3_rxresetdone_out  <= uclk_gt3_rxresetdone;
  gt3_txresetdone_out  <= uclk_gt3_txresetdone;
  gt3_rxdisperr_out    <= mgt_rxdisperr(7 downto 6);
  gt3_rxnotintable_out <= mgt_rxnotintable(7 downto 6);
  gt3_rxcommadet_out   <= gt3_rxcommadet;
  gt3_rxprbserr_out    <= gt3_rxprbserr;
  gt3_rxbufstatus_out  <= uclk_mgt_rxbufstatus(11 downto 9);

  gt3_txphaligndone_out   <= gt_txphaligndone(3);
  gt3_txphinitdone_out    <= gt_txphinitdone(3);
  gt3_txdlysresetdone_out <= gt_txdlysresetdone(3);


  gt3_gttxreset  <= uclk_mgt_tx_reset;
  gt3_txpmareset <= gt3_txpmareset_in;
  gt3_txpcsreset <= gt3_txpcsreset_in;
  gt3_txuserrdy  <= mgt_txuserrdy;

  gt3_gtrxreset  <= uclk_mgt_rx_reset;
  gt3_rxbufreset <= uclk_mgt_rxbuf_reset(3);

  -- Synchronize the rxpmareset signal
  rxpmareset_sync3_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
      clk      => dclk,
      data_in  => gt3_rxpmareset_in,
      data_out => gt3_rxpmareset
    );

  gt3_rxpcsreset <= gt3_rxpcsreset_in;
  gt3_rxuserrdy  <= mgt_rxuserrdy;

  gt_qplllock_out               <= mgt_plllocked;

  -- Synchronize the PLL Locked signal
  plllocked_sync_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
      clk      => clk156,
      data_in  => mgt_plllocked,
      data_out => uclk_txlock
    );

  clk156_lock     <= uclk_txlock;
  uclk_rxlock     <= uclk_txlock & uclk_txlock & uclk_txlock & uclk_txlock;
  -- reset logic

  mgt_txuserrdy    <= uclk_txlock;
  mgt_rxuserrdy    <= uclk_txlock;

  -- Synchronize the dclk_reset_count_done signal to clk156
  reset_count_done_sync_i : XauiGtx7Core_ff_synchronizer
    generic map (
      C_NUM_SYNC_REGS => 3)
    port map (
      clk      => clk156,
      data_in  => dclk_reset_count_done,
      data_out => uclk_reset_count_done
    );


  process(clk156) begin
    if rising_edge(clk156) then
      core_mgt_rx_reset(0) <= not uclk_gt0_rxresetdone;
      core_mgt_rx_reset(1) <= not uclk_gt1_rxresetdone;
      core_mgt_rx_reset(2) <= not uclk_gt2_rxresetdone;
      core_mgt_rx_reset(3) <= not uclk_gt3_rxresetdone;
    end if;
  end process;

  -- Detect falling edge of mgt_powerdown
  p_powerdown_r : process(clk156)
  begin
    if rising_edge(clk156) then
      uclk_mgt_powerdown_r <= uclk_mgt_powerdown;
    end if;
  end process;

  uclk_mgt_powerdown_r2 <= (uclk_mgt_powerdown_r & uclk_mgt_powerdown_r);

  p_powerdown_falling : process(clk156, reset156)
  begin
    if (reset156 = '1') then
        uclk_mgt_powerdown_falling <= '0';
    elsif rising_edge(clk156) then
      if uclk_mgt_powerdown_r = '1' and uclk_mgt_powerdown = '0' then
        uclk_mgt_powerdown_falling <= '1';
      else
        uclk_mgt_powerdown_falling <= '0';
      end if;
    end if;
  end process;

  RXBUFERR_P: process (uclk_mgt_rxbufstatus_reg)
  begin
    for i in 0 to 3 loop
      uclk_mgt_rxbuferr(i) <= IsBufError(uclk_mgt_rxbufstatus_reg(i*3+2 downto i*3));
    end loop;
  end process;

  -- reset logic
  reset_counter_i : XauiGtx7Core_reset_counter
  port map (
    clk           => dclk,
    done          => dclk_reset_count_done,
    initial_reset => dclk_initial_reset);

  -- Detect when the Rx PRBS is in use.  When it is, auto-generated periodic uclk_sync_counter resets will be inhibited
  process (clk156) begin
    if rising_edge(clk156) then
      if (gt0_rxprbssel_in  /= "000" or gt1_rxprbssel_in  /= "000" or gt2_rxprbssel_in  /= "000" or gt3_rxprbssel_in  /= "000") then
        rxprbs_in_use <= '1';
      else
        rxprbs_in_use <= '0';
      end if;
    end if;
  end process;

  -- sync timeout counter. GT requires a reset if the far end powers down.
  process (clk156) begin
    if rising_edge(clk156) then
      if (uclk_sync_counter(SYNC_COUNT_LENGTH - 1) = '1' or uclk_mgt_powerdown = '1' or rxprbs_in_use = '1') then
        uclk_sync_counter <= (others => '0');
      elsif (uclk_sync_status /= "1111") then
        uclk_sync_counter <= uclk_sync_counter + 1;
      else
        uclk_sync_counter <= (others => '0');
      end if;
    end if;
  end process;

  mgt_tx_fault   <= "1111" when uclk_phase_align_complete = '0' else "0000";
  dclk_pll_reset <= (dclk_reset and dclk_reset_count_done) or dclk_initial_reset;

  process (clk156)
  begin
    if rising_edge(clk156) then
      uclk_mgt_rx_reset <= (uclk_cbm_rx_reset or reset156 or (not uclk_txlock) or uclk_mgt_powerdown_falling or uclk_sync_counter(SYNC_COUNT_LENGTH - 1) or uclk_loopback_reset) and uclk_reset_count_done;
      uclk_mgt_tx_reset <= (reset156 or (not uclk_txlock) or uclk_mgt_powerdown_falling) and uclk_reset_count_done;
    end if;
  end process;

  -- reset the rx side when the buffer overflows / underflows or fails to achieve alignment after a certain time
  process (clk156)
  begin
    if rising_edge(clk156) then
      if uclk_mgt_rxbuferr /= "0000" or (uclk_chbond_counter(CHBOND_COUNT_LENGTH-1) = '1') then
        uclk_mgt_rxbuf_reset <= "1111";
      else
        uclk_mgt_rxbuf_reset <= "0000";
      end if;
    end if;
  end process;

  p_mgt_reg : process(clk156)
  begin
    if rising_edge(clk156) then
        mgt_rxdata_reg             <= mgt_rxdata;
        mgt_rxcharisk_reg          <= mgt_rxcharisk;
        mgt_rxnotintable_reg       <= mgt_rxnotintable;
        mgt_rxdisperr_reg          <= mgt_rxdisperr;
        mgt_codecomma_reg          <= mgt_rxchariscomma;
        uclk_mgt_enchansync_reg    <= uclk_mgt_enchansync;
        uclk_mgt_rxbufstatus_reg   <= uclk_mgt_rxbufstatus;
        uclk_mgt_txresetdone_reg   <= uclk_gt0_txresetdone & uclk_gt1_txresetdone & uclk_gt2_txresetdone & uclk_gt3_txresetdone;
    end if;
  end process p_mgt_reg;

  -- chbond counter. Resets the GT RX Buffers if the core fails to align due
  -- to extra skew introduced by the buffers.
  process (clk156) begin
    if rising_edge(clk156) then
      if ((uclk_chbond_counter(CHBOND_COUNT_LENGTH-1) = '1') or (uclk_align_status = '1')) then
        uclk_chbond_counter <= (others => '0');
      elsif (uclk_sync_status = "1111") then
        uclk_chbond_counter <= uclk_chbond_counter + 1;
      else
        uclk_chbond_counter <= (others => '0');
      end if;
    end if;
  end process;

  uclk_cbm_rx_reset <= uclk_chbond_counter(CHBOND_COUNT_LENGTH-1);

    --------------------------- TX Buffer Bypass Logic --------------------
    -- The TX SYNC Module drives the ports needed to Bypass the TX Buffer.

  process (clk156) begin
    if (rising_edge(clk156)) then
      if (uclk_reset_count_done = '1') then
        if (uclk_mgt_txresetdone_reg = "1111") then
          uclk_txsync_start_phase_align <= '1';
        else
          uclk_txsync_start_phase_align <= '0';
        end if;
      end if;
    end if;
  end process;

  txsync_i : XauiGtx7Core_gt_wrapper_tx_sync_manual
  generic map
  ( NUMBER_OF_LANES      => 4,
    MASTER_LANE_ID       => 0
  )
  port map
  (
    STABLE_CLOCK         => clk156,
    RESET_PHALIGNMENT    => uclk_mgt_tx_reset,
    RUN_PHALIGNMENT      => uclk_txsync_start_phase_align,
    PHASE_ALIGNMENT_DONE => uclk_phase_align_complete,
    TXDLYSRESET          => gt_txdlysreset,
    TXDLYSRESETDONE      => gt_txdlysresetdone,
    TXPHINIT             => gt_txphinit,
    TXPHINITDONE         => gt_txphinitdone,
    TXPHALIGN            => gt_txphalign,
    TXPHALIGNDONE        => gt_txphaligndone,
    TXDLYEN              => gt_txdlyen
  );


end wrapper;
