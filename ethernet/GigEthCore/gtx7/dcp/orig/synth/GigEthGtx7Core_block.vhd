
--------------------------------------------------------------------------------
-- File       : GigEthGtx7Core_block.vhd
-- Author     : Xilinx Inc.
--------------------------------------------------------------------------------
-- (c) Copyright 2009 Xilinx, Inc. All rights reserved.
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
--
--
--------------------------------------------------------------------------------
-- Description: This Core Block Level wrapper connects the core to a
--              Series-7 Transceiver.
--
--
--   ------------------------------------------------------------
--   |                      Core Block wrapper                  |
--   |                                                          |
--   |        ------------------          -----------------     |
--   |        |      Core      |          | Transceiver   |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
-- ---------->| GMII           |--------->|           TXP |-------->
--   |        | Tx             |          |           TXN |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        | GMII           |          |           RXP |     |
-- <----------| Rx             |<---------|           RXN |<--------
--   |        |                |          |               |     |
--   |        ------------------          -----------------     |
--   |                                                          |
--   ------------------------------------------------------------
--
--


library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gig_ethernet_pcs_pma_v15_1_0;
use gig_ethernet_pcs_pma_v15_1_0.all;
--------------------------------------------------------------------------------
-- The entity declaration for the Core Block wrapper.
--------------------------------------------------------------------------------

entity GigEthGtx7Core_block is

      port(
      -- Transceiver Interface
      ---------------------

 
      gtrefclk             : in std_logic;                  
      gtrefclk_bufg        : in std_logic; 
      txp                  : out std_logic;                    -- Differential +ve of serial transmission from PMA to PMD.
      txn                  : out std_logic;                    -- Differential -ve of serial transmission from PMA to PMD.
      rxp                  : in std_logic;                     -- Differential +ve for serial reception from PMD to PMA.
      rxn                  : in std_logic;                     -- Differential -ve for serial reception from PMD to PMA.

      txoutclk             : out std_logic;                    
      rxoutclk             : out std_logic;                    
      resetdone            : out std_logic;                    -- The GT transceiver has completed its reset cycle
      cplllock             : out std_logic;                    -- The GT transceiver has completed its reset cycle
      mmcm_reset           : out std_logic;
      mmcm_locked          : in std_logic;                     -- Locked indication from MMCM
      userclk              : in std_logic;                   
      userclk2             : in std_logic;                   
      rxuserclk              : in std_logic;                 
      rxuserclk2             : in std_logic;                 
      independent_clock_bufg : in std_logic;                 
      pma_reset              : in std_logic;                   -- transceiver PMA reset signal
 
      -- GMII Interface
      -----------------
      gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
      gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
      gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.

      -- Management: Alternative to MDIO Interface
      --------------------------------------------

      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.


      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
      
      
      signal_detect        : in std_logic;                      -- Input from PMD to indicate presence of optical input.

    gt0_qplloutclk_in                          : in   std_logic;
    gt0_qplloutrefclk_in                       : in   std_logic
      );
end GigEthGtx7Core_block;


architecture block_level of GigEthGtx7Core_block is

   attribute DowngradeIPIdentifiedWarnings: string;
   attribute DowngradeIPIdentifiedWarnings of block_level : architecture is "yes";


   -----------------------------------------------------------------------------
   -- Component Declaration for the Transceiver wrapper
   -----------------------------------------------------------------------------

   component GigEthGtx7Core_transceiver
  generic
(
    EXAMPLE_SIMULATION                      : integer   := 0          -- Set to 1 for simulation
);
   port (

      encommaalign        : in    std_logic;
      powerdown           : in    std_logic;
      usrclk              : in    std_logic;
      usrclk2             : in    std_logic;
      rxusrclk              : in    std_logic;
      rxusrclk2             : in    std_logic;
      independent_clock   : in    std_logic;
      data_valid          : in    std_logic;
      txreset             : in    std_logic;
      txdata              : in    std_logic_vector (7 downto 0);
      txchardispmode      : in    std_logic;
      txchardispval       : in    std_logic;
      txcharisk           : in    std_logic;
      rxreset             : in    std_logic;
      rxchariscomma       : out   std_logic;
      rxcharisk           : out   std_logic;
      rxclkcorcnt         : out   std_logic_vector (2 downto 0);
      rxdata              : out   std_logic_vector (7 downto 0);
      rxdisperr           : out   std_logic;
      rxnotintable        : out   std_logic;
      rxrundisp           : out   std_logic;
      rxbuferr            : out   std_logic;
      txbuferr            : out   std_logic;
      plllkdet            : out   std_logic;
      mmcm_reset          : out std_logic;
      txoutclk            : out   std_logic;
      rxoutclk            : out   std_logic;
      txn                 : out   std_logic;
      txp                 : out   std_logic;
      rxn                 : in    std_logic;
      rxp                 : in    std_logic;
      gtrefclk            : in    std_logic;
      gtrefclk_bufg       : in    std_logic;
      pmareset            : in    std_logic;
      mmcm_locked         : in    std_logic;

        gt0_drpaddr_in            : in  std_logic_vector(8 downto 0);
        gt0_drpclk_in             : in  std_logic;
        gt0_drpdi_in              : in  std_logic_vector(15 downto 0);
        gt0_drpdo_out             : out std_logic_vector(15 downto 0);
        gt0_drpen_in              : in  std_logic;
        gt0_drprdy_out            : out std_logic;
        gt0_drpwe_in              : in  std_logic;
        gt0_txpmareset_in         : in  std_logic;
        gt0_txpcsreset_in         : in  std_logic;
        gt0_rxpmareset_in         : in  std_logic;
        gt0_rxpcsreset_in         : in  std_logic;
        gt0_rxbufreset_in         : in  std_logic;
        gt0_rxbufstatus_out       : out std_logic_vector(2 downto 0);
        gt0_txbufstatus_out       : out std_logic_vector(1 downto 0);
        gt0_rxbyteisaligned_out   : out std_logic;
        gt0_rxbyterealign_out     : out std_logic;
        gt0_rxdfeagcovrden_in     : in  std_logic;
        gt0_rxmonitorout_out      : out std_logic_vector(6 downto 0);
        gt0_rxmonitorsel_in       : in  std_logic_vector(1 downto 0);
        gt0_rxcommadet_out        : out std_logic;
        gt0_txpolarity_in         : in  std_logic;
        gt0_txdiffctrl_in         : in  std_logic_vector(3 downto 0);
        gt0_txinhibit_in          : in  std_logic;
        gt0_txpostcursor_in       : in  std_logic_vector(4 downto 0);
        gt0_txprecursor_in        : in  std_logic_vector(4 downto 0);
        gt0_rxpolarity_in         : in  std_logic;
        gt0_rxdfelpmreset_in      : in  std_logic;
        gt0_rxlpmen_in            : in  std_logic;
        gt0_txprbssel_in          : in  std_logic_vector(2 downto 0);
        gt0_txprbsforceerr_in     : in  std_logic;
        gt0_rxprbscntreset_in     : in  std_logic;
        gt0_rxprbserr_out         : out std_logic;
        gt0_rxprbssel_in          : in  std_logic_vector(2 downto 0);
        gt0_loopback_in           : in  std_logic_vector(2 downto 0);
        gt0_txresetdone_out       : out std_logic;
        gt0_rxresetdone_out       : out std_logic;
        gt0_eyescanreset_in       : in  std_logic;
        gt0_eyescandataerror_out  : out std_logic;
        gt0_eyescantrigger_in     : in  std_logic;
        gt0_rxcdrhold_in          : in  std_logic;
        gt0_dmonitorout_out       : out std_logic_vector(7 downto 0);        
      resetdone           : out   std_logic;
     
    gt0_qplloutclk                          : in   std_logic;
    gt0_qplloutrefclk                       : in   std_logic
   );
   end component;



   -----------------------------------------------------------------------------
   -- Component Declaration for the 1000BASE-X PCS/PMA sublayer core.
   -----------------------------------------------------------------------------
   component gig_ethernet_pcs_pma_v15_1_0
      generic (
         C_ELABORATION_TRANSIENT_DIR : string := "";
         C_COMPONENT_NAME            : string := "";
         C_FAMILY                    : string := "virtex2";
         C_IS_SGMII                  : boolean := false;
         C_USE_TRANSCEIVER           : boolean := true;
         C_HAS_TEMAC                 : boolean := true;
         C_USE_TBI                   : boolean := false;
         C_USE_LVDS                  : boolean := false;
         C_HAS_AN                    : boolean := true;
         C_HAS_MDIO                  : boolean := true;
         C_SGMII_PHY_MODE            : boolean := false;
         C_DYNAMIC_SWITCHING         : boolean := false;
         C_SGMII_FABRIC_BUFFER       : boolean := false;
         C_1588                      : integer := 0;
         B_SHIFTER_ADDR              : std_logic_vector(7 downto 0) := x"4E";
         RX_GT_NOMINAL_LATENCY       : std_logic_vector(15 downto 0) := "0000000011001000";
         GT_RX_BYTE_WIDTH            : integer := 1
      );
      port(
      -- Core <=> Transceiver Interface
      ------------------------------

      mgt_rx_reset         : out std_logic;                    -- Transceiver connection: reset for the receiver half of the Transceiver
      mgt_tx_reset         : out std_logic;                    -- Transceiver connection: reset for the transmitter half of the Transceiver
      userclk              : in std_logic;                     -- Routed to TXUSERCLK and RXUSERCLK of Transceiver.
      userclk2             : in std_logic;                     -- Routed to TXUSERCLK2 and RXUSERCLK2 of Transceiver.
      dcm_locked           : in std_logic;                     -- LOCKED signal from DCM.

      rxbufstatus          : in std_logic_vector (1 downto 0); -- Transceiver connection: Elastic Buffer Status.
      rxchariscomma        : in std_logic_vector (0 downto 0); -- Transceiver connection: Comma detected in RXDATA.
      rxcharisk            : in std_logic_vector (0 downto 0); -- Transceiver connection: K character received (or extra data bit) in RXDATA.
      rxclkcorcnt          : in std_logic_vector (2 downto 0); -- Transceiver connection: Indicates clock correction.
      rxdata               : in std_logic_vector (7 downto 0); -- Transceiver connection: Data after 8B/10B decoding.
      rxdisperr            : in std_logic_vector (0 downto 0); -- Transceiver connection: Disparity-error in RXDATA.
      rxnotintable         : in std_logic_vector (0 downto 0); -- Transceiver connection: Non-existent 8B/10 code indicated.
      rxrundisp            : in std_logic_vector (0 downto 0); -- Transceiver connection: Running Disparity of RXDATA (or extra data bit).
      txbuferr             : in std_logic;                     -- Transceiver connection: TX Buffer error (overflow or underflow).

      powerdown            : out std_logic;                    -- Transceiver connection: Powerdown the Transceiver
      txchardispmode       : out std_logic;                    -- Transceiver connection: Set running disparity for current byte.
      txchardispval        : out std_logic;                    -- Transceiver connection: Set running disparity value.
      txcharisk            : out std_logic;                    -- Transceiver connection: K character transmitted in TXDATA.
      txdata               : out std_logic_vector(7 downto 0); -- Transceiver connection: Data for 8B/10B encoding.
      enablealign          : out std_logic;                    -- Allow the transceivers to serially realign to a comma character.

      -- GMII Interface
      -----------------

      gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
      gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
      gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.

      -- Management: Alternative to MDIO Interface
      --------------------------------------------

      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.

      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
      signal_detect        : in std_logic;                      -- Input from PMD to indicate presence of optical input.
      reset_done           : in std_logic 

      );

   end component;

   component GigEthGtx7Core_sync_block
   generic (
     INITIALISE : bit_vector(1 downto 0) := "00"
   );
   port  (
             clk           : in  std_logic;
             data_in       : in  std_logic;
             data_out      : out std_logic
          );
   end component;
  ------------------------------------------------------------------------------
  -- internal signals used in this block level wrapper.
  ------------------------------------------------------------------------------

  -- Core <=> Transceiver interconnect
  signal mgt_rx_reset      : std_logic;                        -- Reset for the receiver half of the Transceiver
  signal mgt_tx_reset      : std_logic;                        -- Reset for the transmitter half of the Transceiver
  signal rxbufstatus       : std_logic_vector (1 downto 0);    -- Elastic Buffer Status (bit 1 asserted indicates overflow or underflow).

  signal rxchariscomma     : std_logic_vector (0 downto 0);    -- Comma detected in RXDATA.
  signal rxcharisk         : std_logic_vector (0 downto 0);    -- K character received (or extra data bit) in RXDATA.
  signal rxclkcorcnt       : std_logic_vector (2 downto 0);    -- Indicates clock correction.
  signal rxdata            : std_logic_vector (7 downto 0);    -- Data after 8B/10B decoding.
  signal rxdisperr         : std_logic_vector (0 downto 0);    -- Disparity-error in RXDATA.
  signal rxnotintable      : std_logic_vector (0 downto 0);    -- Non-existent 8B/10 code indicated.
  signal rxrundisp         : std_logic_vector (0 downto 0);    -- Running Disparity after current byte, becomes 9th data bit when RXNOTINTABLE='1'.
  signal txbuferr          : std_logic;                        -- TX Buffer error (overflow or underflow).
  signal powerdown         : std_logic;                        -- Powerdown the Transceiver
  signal txchardispmode    : std_logic;                        -- Set running disparity for current byte.
  signal txchardispval     : std_logic;                        -- Set running disparity value.
  signal txcharisk         : std_logic;                        -- K character transmitted in TXDATA.
  signal txdata            : std_logic_vector(7 downto 0);     -- Data for 8B/10B encoding.
  signal enablealign       : std_logic;                        -- Allow the transceivers to serially realign to a comma character.
  signal status_vector_i   : std_logic_vector(15 downto 0);    -- Internal status vector signal.

constant EXAMPLE_SIMULATION    : integer := 0 ;

  signal phyaddress : std_logic_vector(4 downto 0);


signal gt0_txresetdone_out_i : std_logic;
signal gt0_rxresetdone_out_i : std_logic;
signal resetdone_i : std_logic;
signal tx_reset_done_i : std_logic;
signal rx_reset_done_i : std_logic;
signal reset_done_i : std_logic;
signal mdio_o_int : std_logic;
signal mdio_t_int : std_logic;

begin



phyaddress <= std_logic_vector(to_unsigned(1, phyaddress'length));

  ------------------------------------------------------------------------------
  -- Instantiate the core
  ------------------------------------------------------------------------------

  GigEthGtx7Core_core : gig_ethernet_pcs_pma_v15_1_0
    generic map (
      C_ELABORATION_TRANSIENT_DIR => "BlankString",
      C_COMPONENT_NAME            => "GigEthGtx7Core",
      C_FAMILY                    => "kintex7",
      C_IS_SGMII                  => false,
      C_USE_TRANSCEIVER           => true,
      C_HAS_TEMAC                 => true,
      C_USE_TBI                   => false,
      C_USE_LVDS                  => false,
      C_HAS_AN                    => false,
      C_HAS_MDIO                  => false,
      C_SGMII_PHY_MODE            => false,
      C_DYNAMIC_SWITCHING         => false,
      C_SGMII_FABRIC_BUFFER       => true,
      C_1588                      => 0,
      B_SHIFTER_ADDR              => x"4E",
      RX_GT_NOMINAL_LATENCY       => "0000000011001000",
      GT_RX_BYTE_WIDTH            => 1
    )
    port map (
      mgt_rx_reset         => mgt_rx_reset,
      mgt_tx_reset         => mgt_tx_reset,
      userclk              => userclk2,
      userclk2             => userclk2,
      dcm_locked           => mmcm_locked,
      rxbufstatus          => rxbufstatus,
      rxchariscomma        => rxchariscomma,
      rxcharisk            => rxcharisk,
      rxclkcorcnt          => rxclkcorcnt,
      rxdata               => rxdata,
      rxdisperr            => rxdisperr,
      rxnotintable         => rxnotintable,
      rxrundisp            => rxrundisp,
      txbuferr             => txbuferr,
      powerdown            => powerdown,
      txchardispmode       => txchardispmode,
      txchardispval        => txchardispval,
      txcharisk            => txcharisk,
      txdata               => txdata,
      enablealign          => enablealign,
      gmii_txd             => gmii_txd,
      gmii_tx_en           => gmii_tx_en,
      gmii_tx_er           => gmii_tx_er,
      gmii_rxd             => gmii_rxd,
      gmii_rx_dv           => gmii_rx_dv,
      gmii_rx_er           => gmii_rx_er,
      gmii_isolate         => gmii_isolate,
      configuration_vector => configuration_vector,
      status_vector        => status_vector_i,
      reset                => reset,
      signal_detect        => signal_detect,
      reset_done           => reset_done_i

   );

  status_vector <= status_vector_i;

  ------------------------------------------------------------------------------
  -- Component Instantiation for the Series-7 Transceiver wrapper
  ------------------------------------------------------------------------------

   transceiver_inst : GigEthGtx7Core_transceiver
   generic map
    (
        EXAMPLE_SIMULATION            => EXAMPLE_SIMULATION
    )    
   
   port map (

      encommaalign                 => enablealign,
      powerdown                    => powerdown,
      usrclk                       => userclk,
      usrclk2                      => userclk2,
      rxusrclk                     => rxuserclk,
      rxusrclk2                    => rxuserclk2,
      independent_clock            => independent_clock_bufg,
      data_valid                   => status_vector_i(1),
      txreset                      => mgt_tx_reset,
      txchardispmode               => txchardispmode,
      txchardispval                => txchardispval,
      txcharisk                    => txcharisk,
      txdata                       => txdata,
      rxreset                      => mgt_rx_reset,
      rxchariscomma                => rxchariscomma(0),
      rxcharisk                    => rxcharisk(0),
      rxclkcorcnt                  => rxclkcorcnt,
      rxdata                       => rxdata,
      rxdisperr                    => rxdisperr(0),
      rxnotintable                 => rxnotintable(0),
      rxrundisp                    => rxrundisp(0),
      rxbuferr                     => rxbufstatus(1),
      txbuferr                     => txbuferr,
      plllkdet                     => cplllock,
      mmcm_reset                   => mmcm_reset,
      txoutclk                     => txoutclk,
      rxoutclk                     => rxoutclk,
      txn                          => txn,
      txp                          => txp,
      rxn                          => rxn,
      rxp                          => rxp,

      gtrefclk                     => gtrefclk,
      gtrefclk_bufg                => gtrefclk_bufg,
      pmareset                     => pma_reset,
      mmcm_locked                  => mmcm_locked,
      gt0_txpmareset_in         => '0',
      gt0_txpcsreset_in         => '0',
      gt0_rxpmareset_in         => '0',
      gt0_rxpcsreset_in         => '0',
      gt0_rxbufreset_in         => '0',
      gt0_rxbufstatus_out       => open,
      gt0_txbufstatus_out       => open,
      gt0_drpaddr_in            => (others=>'0'),
      
      gt0_drpclk_in                => gtrefclk_bufg,

      gt0_drpdi_in              => (others=>'0'),
      gt0_drpdo_out             => open,
      gt0_drpen_in              => '0',
      gt0_drprdy_out            => open,
      gt0_drpwe_in              => '0',
      gt0_rxbyteisaligned_out   => open,
      gt0_rxbyterealign_out     => open,
      gt0_rxdfeagcovrden_in     => '0',
      gt0_rxmonitorout_out      => open,
      gt0_rxmonitorsel_in       => (others=>'0'),
      gt0_rxcommadet_out        => open,
      gt0_txpolarity_in         => '0',
      gt0_txdiffctrl_in         => "1000",
      
      gt0_txinhibit_in          => '0',
      gt0_txpostcursor_in       => (others=>'0'),
      gt0_txprecursor_in        => (others=>'0'),
      gt0_rxpolarity_in         => '0',
      gt0_rxdfelpmreset_in      => '0',
      gt0_rxlpmen_in            => '1',
      gt0_txprbssel_in          => (others=>'0'),
      gt0_txprbsforceerr_in     => '0',
      gt0_rxprbscntreset_in     => '0',
      gt0_rxprbserr_out         => open,
      gt0_rxprbssel_in          => (others=>'0'),
      gt0_loopback_in           => (others=>'0'),
      gt0_txresetdone_out       => gt0_txresetdone_out_i,
      gt0_rxresetdone_out       => gt0_rxresetdone_out_i,
      gt0_eyescanreset_in       => '0',
      gt0_eyescandataerror_out  => open,
      gt0_eyescantrigger_in     => '0',
      gt0_rxcdrhold_in          => '0',
      gt0_dmonitorout_out       => open ,       
      
      resetdone                 => open,
     gt0_qplloutclk             => gt0_qplloutclk_in,
     gt0_qplloutrefclk          => gt0_qplloutrefclk_in
   );

   sync_block_tx_reset_done : GigEthGtx7Core_sync_block
   port map
        (
           clk             => userclk2 ,
           data_in         => gt0_txresetdone_out_i,
           data_out        => tx_reset_done_i
        );
   sync_block_rx_reset_done : GigEthGtx7Core_sync_block
   port map
        (
           clk             => userclk2 ,
           data_in         => gt0_rxresetdone_out_i,
           data_out        => rx_reset_done_i
        );   
 reset_done_i <= tx_reset_done_i and rx_reset_done_i;

 resetdone  <= reset_done_i;




   -- Unused
  rxbufstatus(0)           <= '0';

end block_level;

