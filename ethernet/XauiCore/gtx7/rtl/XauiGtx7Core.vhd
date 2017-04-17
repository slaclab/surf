-------------------------------------------------------------------------------
-- File       : XauiGtx7Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-12
-- Last update: 2016-02-19
-------------------------------------------------------------------------------
-- Description: 10 GigE XAUI for Gtx7
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

entity XauiGtx7Core is
    port (
      dclk                     : in  std_logic;
      reset                    : in  std_logic;
      clk156_out               : out std_logic;
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
      configuration_vector     : in  std_logic_vector(6 downto 0);
      status_vector            : out std_logic_vector(7 downto 0)
);
end XauiGtx7Core;

library xaui_v12_1;
use xaui_v12_1.all;

architecture wrapper of XauiGtx7Core is

  component XauiGtx7Core_block is
    port (
      dclk                     : in  std_logic;
      reset                    : in  std_logic;
      clk156_out               : out std_logic;
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
  end component;

  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF wrapper : ARCHITECTURE IS "XauiGtx7Core,xaui_v12_1,{x_ipProduct=Vivado 2014.4.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=xaui,x_ipVersion=12.1,x_ipCoreRevision=4,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,c_family=kintex7,c_component_name=XauiGtx7Core,c_is_dxaui=false,c_has_mdio=false,c_sub_core_name=XauiGtx7Core_gt,c_gt_dmonitorout_width=8,c_gt_txdiffctrl_width=16}";
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF wrapper: ARCHITECTURE IS "xaui_v12_1,Vivado 2014.4.1";

begin

  U0 : XauiGtx7Core_block
    port map(
      dclk                     => dclk,
      reset                    => reset,
      clk156_out               => clk156_out,
      clk156_lock              => clk156_lock,
      refclk                   => refclk,
      xgmii_txd                => xgmii_txd,
      xgmii_txc                => xgmii_txc,
      xgmii_rxd                => xgmii_rxd,
      xgmii_rxc                => xgmii_rxc,
      xaui_tx_l0_p             => xaui_tx_l0_p,
      xaui_tx_l0_n             => xaui_tx_l0_n,
      xaui_tx_l1_p             => xaui_tx_l1_p,
      xaui_tx_l1_n             => xaui_tx_l1_n,
      xaui_tx_l2_p             => xaui_tx_l2_p,
      xaui_tx_l2_n             => xaui_tx_l2_n,
      xaui_tx_l3_p             => xaui_tx_l3_p,
      xaui_tx_l3_n             => xaui_tx_l3_n,
      xaui_rx_l0_p             => xaui_rx_l0_p,
      xaui_rx_l0_n             => xaui_rx_l0_n,
      xaui_rx_l1_p             => xaui_rx_l1_p,
      xaui_rx_l1_n             => xaui_rx_l1_n,
      xaui_rx_l2_p             => xaui_rx_l2_p,
      xaui_rx_l2_n             => xaui_rx_l2_n,
      xaui_rx_l3_p             => xaui_rx_l3_p,
      xaui_rx_l3_n             => xaui_rx_l3_n,
      signal_detect            => signal_detect,
      debug                    => debug,
   -- DRP
      gt0_drpaddr              => (others => '0'),
      gt0_drpen                => '0',
      gt0_drpdi                => (others => '0'),
      gt0_drpdo                => open,
      gt0_drprdy               => open,
      gt0_drpwe                => '0',
   -- TX Reset and Initialisation
      gt0_txpmareset_in        => '0',
      gt0_txpcsreset_in        => '0',
      gt0_txresetdone_out      => open,
   -- RX Reset and Initialisation
      gt0_rxpmareset_in        => '0',
      gt0_rxpcsreset_in        => '0',
      gt0_rxresetdone_out      => open,
   -- Clocking
      gt0_rxbufstatus_out      => open,
      gt0_txphaligndone_out    => open,
      gt0_txphinitdone_out     => open,
      gt0_txdlysresetdone_out  => open,
      gt_qplllock_out                => open,
   -- Signal Integrity adn Functionality
   -- Eye Scan
      gt0_eyescantrigger_in    => '0',
      gt0_eyescanreset_in      => '0',
      gt0_eyescandataerror_out => open,
      gt0_rxrate_in            => "000",
   -- Loopback
      gt0_loopback_in          => "000",
   -- Polarity
      gt0_rxpolarity_in        => '0',
      gt0_txpolarity_in        => '0',
   -- RX Decision Feedback Equalizer(DFE)
      gt0_rxlpmen_in           => '0',
      gt0_rxdfelpmreset_in     => '0',
      gt0_rxmonitorsel_in      => "00",
      gt0_rxmonitorout_out     => open,
   -- TX Driver
      gt0_txdiffctrl_in        => "1000",
      gt0_txpostcursor_in      => "00000",
      gt0_txprecursor_in       => "00000",
   -- PRBS - GT
      gt0_rxprbscntreset_in    => '0',
      gt0_rxprbserr_out        => open,
      gt0_rxprbssel_in         => "000",
      gt0_txprbssel_in         => "000",
      gt0_txprbsforceerr_in    => '0',

      gt0_rxcdrhold_in         => '0',

      gt0_dmonitorout_out      => open,

   -- Status
      gt0_rxdisperr_out        => open,
      gt0_rxnotintable_out     => open,
      gt0_rxcommadet_out       => open,
   -- DRP
      gt1_drpaddr              => (others => '0'),
      gt1_drpen                => '0',
      gt1_drpdi                => (others => '0'),
      gt1_drpdo                => open,
      gt1_drprdy               => open,
      gt1_drpwe                => '0',
   -- TX Reset and Initialisation
      gt1_txpmareset_in        => '0',
      gt1_txpcsreset_in        => '0',
      gt1_txresetdone_out      => open,
   -- RX Reset and Initialisation
      gt1_rxpmareset_in        => '0',
      gt1_rxpcsreset_in        => '0',
      gt1_rxresetdone_out      => open,
   -- Clocking
      gt1_rxbufstatus_out      => open,
      gt1_txphaligndone_out    => open,
      gt1_txphinitdone_out     => open,
      gt1_txdlysresetdone_out  => open,
   -- Signal Integrity adn Functionality
   -- Eye Scan
      gt1_eyescantrigger_in    => '0',
      gt1_eyescanreset_in      => '0',
      gt1_eyescandataerror_out => open,
      gt1_rxrate_in            => "000",
   -- Loopback
      gt1_loopback_in          => "000",
   -- Polarity
      gt1_rxpolarity_in        => '0',
      gt1_txpolarity_in        => '0',
   -- RX Decision Feedback Equalizer(DFE)
      gt1_rxlpmen_in           => '0',
      gt1_rxdfelpmreset_in     => '0',
      gt1_rxmonitorsel_in      => "00",
      gt1_rxmonitorout_out     => open,
   -- TX Driver
      gt1_txdiffctrl_in        => "1000",
      gt1_txpostcursor_in      => "00000",
      gt1_txprecursor_in       => "00000",
   -- PRBS - GT
      gt1_rxprbscntreset_in    => '0',
      gt1_rxprbserr_out        => open,
      gt1_rxprbssel_in         => "000",
      gt1_txprbssel_in         => "000",
      gt1_txprbsforceerr_in    => '0',

      gt1_rxcdrhold_in         => '0',

      gt1_dmonitorout_out      => open,

   -- Status
      gt1_rxdisperr_out        => open,
      gt1_rxnotintable_out     => open,
      gt1_rxcommadet_out       => open,
   -- DRP
      gt2_drpaddr              => (others => '0'),
      gt2_drpen                => '0',
      gt2_drpdi                => (others => '0'),
      gt2_drpdo                => open,
      gt2_drprdy               => open,
      gt2_drpwe                => '0',
   -- TX Reset and Initialisation
      gt2_txpmareset_in        => '0',
      gt2_txpcsreset_in        => '0',
      gt2_txresetdone_out      => open,
   -- RX Reset and Initialisation
      gt2_rxpmareset_in        => '0',
      gt2_rxpcsreset_in        => '0',
      gt2_rxresetdone_out      => open,
   -- Clocking
      gt2_rxbufstatus_out      => open,
      gt2_txphaligndone_out    => open,
      gt2_txphinitdone_out     => open,
      gt2_txdlysresetdone_out  => open,
   -- Signal Integrity adn Functionality
   -- Eye Scan
      gt2_eyescantrigger_in    => '0',
      gt2_eyescanreset_in      => '0',
      gt2_eyescandataerror_out => open,
      gt2_rxrate_in            => "000",
   -- Loopback
      gt2_loopback_in          => "000",
   -- Polarity
      gt2_rxpolarity_in        => '0',
      gt2_txpolarity_in        => '0',
   -- RX Decision Feedback Equalizer(DFE)
      gt2_rxlpmen_in           => '0',
      gt2_rxdfelpmreset_in     => '0',
      gt2_rxmonitorsel_in      => "00",
      gt2_rxmonitorout_out     => open,
   -- TX Driver
      gt2_txdiffctrl_in        => "1000",
      gt2_txpostcursor_in      => "00000",
      gt2_txprecursor_in       => "00000",
   -- PRBS - GT
      gt2_rxprbscntreset_in    => '0',
      gt2_rxprbserr_out        => open,
      gt2_rxprbssel_in         => "000",
      gt2_txprbssel_in         => "000",
      gt2_txprbsforceerr_in    => '0',

      gt2_rxcdrhold_in         => '0',

      gt2_dmonitorout_out      => open,

   -- Status
      gt2_rxdisperr_out        => open,
      gt2_rxnotintable_out     => open,
      gt2_rxcommadet_out       => open,
   -- DRP
      gt3_drpaddr              => (others => '0'),
      gt3_drpen                => '0',
      gt3_drpdi                => (others => '0'),
      gt3_drpdo                => open,
      gt3_drprdy               => open,
      gt3_drpwe                => '0',
   -- TX Reset and Initialisation
      gt3_txpmareset_in        => '0',
      gt3_txpcsreset_in        => '0',
      gt3_txresetdone_out      => open,
   -- RX Reset and Initialisation
      gt3_rxpmareset_in        => '0',
      gt3_rxpcsreset_in        => '0',
      gt3_rxresetdone_out      => open,
   -- Clocking
      gt3_rxbufstatus_out      => open,
      gt3_txphaligndone_out    => open,
      gt3_txphinitdone_out     => open,
      gt3_txdlysresetdone_out  => open,
   -- Signal Integrity adn Functionality
   -- Eye Scan
      gt3_eyescantrigger_in    => '0',
      gt3_eyescanreset_in      => '0',
      gt3_eyescandataerror_out => open,
      gt3_rxrate_in            => "000",
   -- Loopback
      gt3_loopback_in          => "000",
   -- Polarity
      gt3_rxpolarity_in        => '0',
      gt3_txpolarity_in        => '0',
   -- RX Decision Feedback Equalizer(DFE)
      gt3_rxlpmen_in           => '0',
      gt3_rxdfelpmreset_in     => '0',
      gt3_rxmonitorsel_in      => "00",
      gt3_rxmonitorout_out     => open,
   -- TX Driver
      gt3_txdiffctrl_in        => "1000",
      gt3_txpostcursor_in      => "00000",
      gt3_txprecursor_in       => "00000",
   -- PRBS - GT
      gt3_rxprbscntreset_in    => '0',
      gt3_rxprbserr_out        => open,
      gt3_rxprbssel_in         => "000",
      gt3_txprbssel_in         => "000",
      gt3_txprbsforceerr_in    => '0',

      gt3_rxcdrhold_in         => '0',

      gt3_dmonitorout_out      => open,

   -- Status
      gt3_rxdisperr_out        => open,
      gt3_rxnotintable_out     => open,
      gt3_rxcommadet_out       => open,
      configuration_vector     => configuration_vector,
      status_vector            => status_vector
);

end wrapper;
