--------------------------------------------------------------------------------
-- File       : SaltUltraScaleCore_block.vhd
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
 
--------------------------------------------------------------------------------
-- Description: This Core Block Level wrapper connects the core to a LVDS 
--              transceiver implementation
--
--              The SGMII adaptation module is provided to convert
--              between 1Gbps and 10/100 Mbps rates.  This is connected
--              to the MAC side of the core to provide a GMII style
--              interface.  When the core is running at 1Gbps speeds,
--              the GMII (8-bitdata pathway) is used at a clock
--              frequency of 125MHz.  When the core is running at
--              100Mbps, a clock frequency of 12.5MHz is used.  When
--              running at 100Mbps speeds, a clock frequency of 1.25MHz
--              is used.
--
--    ----------------------------------------------------------------
--    |                   Core Block Level Wrapper                   |
--    |                                                              |
--    |                                                              |
--    |                  --------------          --------------      |
--    |                  |    Core    |          |    LVDS    |      |
--    |                  |            |          | transceiver|      |
--    |    ---------     |            |          |            |      |
--    |    |       |     |            |          |            |      |
--    |    | SGMII |     |            |          |            |      |
--  ------>| Adapt |---->| GMII       |--------->|        TXP |-------->
--    |    | Module|     | Tx         |          |        TXN |      |
--    |    |       |     |            |          |            |      |
--    |    |       |     |            |  trans-  |            |      |
--    |    |       |     |            | ceiver   |            |      |
--    |    |       |     |            |    I/F   |            |      |
--    |    |       |     |            |          |            |      |
--    |    |       |     | GMII       |          |        RXP |      |
--  <------|       |<----| Rx         |<---------|        RXN |<--------
--    |    |       |     |            |          |            |      |
--    |    ---------     --------------          --------------      |
--    |                                                              |
--    ----------------------------------------------------------------


library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
USE IEEE.std_logic_unsigned.ALL;
USE IEEE.std_logic_arith.ALL;
use ieee.numeric_std.all; 


library gig_ethernet_pcs_pma_v15_1_0;
use gig_ethernet_pcs_pma_v15_1_0.all;

--------------------------------------------------------------------------------
-- The entity declaration for the Core Block wrapper.
--------------------------------------------------------------------------------


entity SaltUltraScaleCore_block is
      port (
      -- LVDS transceiver Interface
      -----------------------------


      txp      : out std_logic;                  -- Differential +ve of serial transmission from PMA to PMD.
      txn      : out std_logic;                  -- Differential -ve of serial transmission from PMA to PMD.
      rxp      : in std_logic;                   -- Differential +ve for serial reception from PMD to PMA.
      rxn      : in std_logic;                   -- Differential -ve for serial reception from PMD to PMA.


      clk125m     : in std_logic;
      mmcm_locked  : in std_logic;
      
      sgmii_clk_r   : out std_logic;           -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
      sgmii_clk_f   : out std_logic;           -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
      sgmii_clk_en: out std_logic;             -- Clock enable for client MAC
      idelay_rdy_in : in std_logic;
      clk625 : in std_logic;
      clk312 : in std_logic;
      ----------------
      -- Speed Control
      ----------------
      speed_is_10_100      : in std_logic;                     -- Core should operate at either 10Mbps or 100Mbps speeds
      speed_is_100         : in std_logic;                     -- Core should operate at 100Mbps speed
      -- GMII Interface
      -----------------
      gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
      gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
      gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.

      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
      signal_detect        : in std_logic                      -- Input from PMD to indicate presence of optical input.

);
end SaltUltraScaleCore_block;

architecture block_level of SaltUltraScaleCore_block is

   attribute DowngradeIPIdentifiedWarnings: string;
   attribute DowngradeIPIdentifiedWarnings of block_level : architecture is "yes";
   -----------------------------------------------------------------------------
   -- Component Declaration for the LVDS transceiver module
   -----------------------------------------------------------------------------
    component SaltUltraScaleCore_lvds_transceiver_ser8
   port (
    -- Transceiver Transmitter Interface (synchronous to clk125m)
    txchardispmode         : in std_logic;
    txchardispval          : in std_logic;
    txcharisk              : in std_logic;
    txdata                 : in std_logic_vector(7 downto 0);
    txbuferr               : out std_logic;

    -- Transceiver Receiver Interface (synchronous to clk125m)
    rxchariscomma          : out std_logic;
    rxcharisk              : out std_logic;
    rxdata                 : out std_logic_vector(7 downto 0);
    rxdisperr              : out std_logic;
    rxnotintable           : out std_logic;
    rxrundisp              : out std_logic;
    rxbuferr               : out std_logic;

    clk125                 : in std_logic;
    soft_tx_reset          : in std_logic;
    soft_rx_reset          : in std_logic;
    reset                  : in std_logic; -- CLK125
    clk625                 : in std_logic;
    idelay_rdy             : in  std_logic;
    clk312                 : in std_logic;
    

-- Serial input wire and output wire differential pairs
    pin_sgmii_txn          : out std_logic;
    pin_sgmii_txp          : out std_logic;
    pin_sgmii_rxn          : in std_logic;
    pin_sgmii_rxp          : in std_logic
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
         C_SGMII_FABRIC_BUFFER       : boolean := false
      );
      port(
      -- Core <=> Transceiver Interface
      ---------------------------------

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

      -- Management: MDIO Interface
      -----------------------------


      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.


      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
      signal_detect        : in std_logic;                      -- Input from PMD to indicate presence of optical input.
      reset_done           : in std_logic
      );

   end component;



   -----------------------------------------------------------------------------
   -- Component Declaration for the SGMII adaptation module
   -----------------------------------------------------------------------------
   component SaltUltraScaleCore_sgmii_adapt
      port(

      -- Asynchronous Reset
      reset                : in std_logic;                     -- Asynchronous reset for entire core.

      -- Clock derivation
      -------------------

      clk125m              : in std_logic;                     -- Reference 125MHz clock (as routed to TXUSERCLK2 and RXUSERCLK2 of Transceiver).
      sgmii_clk_r          : out std_logic;                    -- Clock to client MAC (125MHz, 12.5MHz or 1.25MHz) (to rising edge DDR).
      sgmii_clk_f          : out std_logic;                    -- Clock to client MAC (125MHz, 12.5MHz or 1.25MHz) (to falling edge DDR).

      sgmii_clk_en         : out std_logic;                    -- Clock enable to client MAC (125MHz, 12.5MHz or 1.25MHz).

      -- GMII Tx
      ----------
      gmii_txd_in          : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en_in        : in std_logic;                     -- Transmit data valid signal from client MAC.
      gmii_tx_er_in        : in std_logic;                     -- Transmit error signal from client MAC.
      gmii_rxd_out         : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv_out       : out std_logic;                    -- Received data valid signal to client MAC.
      gmii_rx_er_out       : out std_logic;                    -- Received error signal to client MAC.

      -- GMII Rx
      ----------
      gmii_rxd_in          : in std_logic_vector(7 downto 0);  -- Received Data to client MAC.
      gmii_rx_dv_in        : in std_logic;                     -- Received data valid signal to client MAC.
      gmii_rx_er_in        : in std_logic;                     -- Received error signal to client MAC.
      gmii_txd_out         : out std_logic_vector(7 downto 0); -- Transmit data from client MAC.
      gmii_tx_en_out       : out std_logic;                    -- Transmit data valid signal from client MAC.
      gmii_tx_er_out       : out std_logic;                    -- Transmit error signal from client MAC.

      -- Speed Control
      ----------------
      speed_is_10_100      : in std_logic;                     -- Core should operate at either 10Mbps or 100Mbps speeds
      speed_is_100         : in std_logic                      -- Core should operate at 100Mbps speed

      );
   end component;
   component SaltUltraScaleCore_sync_block
   generic (
     INITIALISE : bit_vector(1 downto 0) := "00"
   );
   port  (
             clk           : in  std_logic;
             data_in       : in  std_logic;
             data_out      : out std_logic
          );
   end component;
   component SaltUltraScaleCore_reset_wtd_timer
   generic (
     WAIT_TIME  : std_logic_vector(23 downto 0) := x"8F0D18"
   );   
   port (
       clk         : in  std_logic;
       data_valid  : in  std_logic;
       reset       : out std_logic
   );
   end component;
   -----------------------------------------------------------------------------
   -- Internal signals used in this block level wrapper.
   -----------------------------------------------------------------------------

   -- GMII signals routed between core and SGMII Adaptation Module
    signal gmii_txd_int               : std_logic_vector(7 downto 0);             -- Internal gmii_txd signal (between core and SGMII adaptation module).
    signal gmii_tx_en_int             : std_logic;                                -- Internal gmii_tx_en signal (between core and SGMII adaptation module).
    signal gmii_tx_er_int             : std_logic;                                -- Internal gmii_tx_er signal (between core and SGMII adaptation module).
    signal gmii_rxd_int              : std_logic_vector(7 downto 0);             -- Internal gmii_rxd signal (between core and SGMII adaptation module).
    signal gmii_rx_dv_int             : std_logic;                                -- Internal gmii_rx_dv signal (between core and SGMII adaptation module).
    signal gmii_rx_er_int             : std_logic;                                -- Internal gmii_rx_er signal (between core and SGMII adaptation module).
    signal lvds_phy_ready             : std_logic; 
    signal rxbufstatus                : std_logic_vector(1 downto 0);             -- Elastic Buffer Status (bit 1 asserted indicates  overflow or underflow).
    
   signal rxchariscomma     : std_logic_vector (0 downto 0);    -- Comma detected in RXDATA.
   signal rxcharisk         : std_logic_vector (0 downto 0);    -- K character received (or extra data bit) in RXDATA.
   signal rxclkcorcnt       : std_logic_vector (2 downto 0);    -- Indicates clock correction.
   signal rxdata            : std_logic_vector (7 downto 0);    -- Data after 8B/10B decoding.
   signal rxdisperr         : std_logic_vector (0 downto 0);    -- Disparity-error in RXDATA.
   signal rxnotintable      : std_logic_vector (0 downto 0);    -- Non-existent 8B/10 code indicated.
   signal rxrundisp         : std_logic_vector (0 downto 0);    -- Running Disparity after current byte, becomes 9th data bit when RXNOTINTABLE='1'.

   signal txbuferr                   : std_logic;                                -- TX Buffer error (overflow or underflow).
   signal txchardispmode             : std_logic;                                -- Set running disparity for current byte.
   signal txchardispval              : std_logic;                                -- Set running disparity value.
   signal txcharisk                  : std_logic;                                -- K character transmitted in TXDATA.
   signal txdata                     : std_logic_vector(7 downto 0);             -- Data for 8B/10B encoding.
   signal enablealign                : std_logic;                                -- Allow the transceivers to serially realign to a comma character.
   signal lvds_phy_rdy_sig_det       : std_logic;
   signal mgt_tx_reset               : std_logic;
   signal mgt_rx_reset               : std_logic;
   signal mmcm_locked_sync_125 : std_logic;
   signal eye_mon_wait_time : std_logic_vector(11 downto 0);

   signal status_vector_int : std_logic_vector(15 downto 0);

   signal mdio_o_int : std_logic;
   signal mdio_t_int : std_logic;

  signal phyaddress       : std_logic_vector(4 downto 0);
  signal wtd_reset        : std_logic;
  signal rx_reset         : std_logic;

constant EXAMPLE_SIMULATION    : integer := 0 ;

signal sgmii_clk_r_i :std_logic;
begin
   reset_wtd_timer : SaltUltraScaleCore_reset_wtd_timer
   generic map (
     WAIT_TIME  => x"596825"
   )   
   port map
          (
             clk             =>  clk125m,
             data_valid      =>  status_vector_int(1),
             reset           =>  wtd_reset
          );
  
rx_reset   <= wtd_reset or mgt_rx_reset;
phyaddress <= std_logic_vector(to_unsigned(1, phyaddress'length));

sgmii_clk_r <= sgmii_clk_r_i;


  -- Eye Monitor Wait timer value is set to 12'03F for reducing simulation
  -- time. The value is 12'FFF for normal runs
  ---------------------------------------------------------------------------
  eye_mon_wait_time <= "111111111111" when (EXAMPLE_SIMULATION = 0) else  "000000111111";


   sync_block_mmcm_locked : SaltUltraScaleCore_sync_block
   port map
        (
           clk             => clk125m ,
           data_in         => mmcm_locked ,
           data_out        => mmcm_locked_sync_125
        );



  status_vector <= status_vector_int;
  


  sgmii_logic : SaltUltraScaleCore_sgmii_adapt
  port map (

     reset                => mgt_tx_reset,
     clk125m              => clk125m,
     sgmii_clk_r          => sgmii_clk_r_i,
     sgmii_clk_f          => sgmii_clk_f,
     sgmii_clk_en         => sgmii_clk_en,
     gmii_txd_in          => gmii_txd,
     gmii_tx_en_in        => gmii_tx_en,
     gmii_tx_er_in        => gmii_tx_er,
     gmii_rxd_in          => gmii_rxd_int,
     gmii_rx_dv_in        => gmii_rx_dv_int,
     gmii_rx_er_in        => gmii_rx_er_int,
     gmii_txd_out         => gmii_txd_int,
     gmii_tx_en_out       => gmii_tx_en_int,
     gmii_tx_er_out       => gmii_tx_er_int,
     gmii_rxd_out         => gmii_rxd,
     gmii_rx_dv_out       => gmii_rx_dv,
     gmii_rx_er_out       => gmii_rx_er,
     speed_is_10_100      => speed_is_10_100,
     speed_is_100         => speed_is_100
     );


   -----------------------------------------------------------------------------
   -- Instantiate the core
   -----------------------------------------------------------------------------

  SaltUltraScaleCore_core : gig_ethernet_pcs_pma_v15_1_0
    generic map (
      C_ELABORATION_TRANSIENT_DIR => "BlankString",
      C_COMPONENT_NAME            => "SaltUltraScaleCore",
      C_FAMILY                    => "kintexu",
      C_IS_SGMII                  => true,
      C_USE_TRANSCEIVER           => false,
      C_HAS_TEMAC                 => true,
      C_USE_TBI                   => false,
      C_USE_LVDS                  => true,
      C_HAS_AN                    => false,
      C_HAS_MDIO                  => false,
      C_SGMII_PHY_MODE            => false,
      C_DYNAMIC_SWITCHING         => false,
      C_SGMII_FABRIC_BUFFER       => true
    )
    port map (
      mgt_rx_reset         => mgt_rx_reset,
      mgt_tx_reset         => mgt_tx_reset,
      userclk              => clk125m,
      userclk2             => clk125m,
      dcm_locked           => mmcm_locked_sync_125,
      rxbufstatus          => "00",
      rxchariscomma        => rxchariscomma,
      rxcharisk            => rxcharisk,
      rxclkcorcnt          => rxclkcorcnt,
      rxdata               => rxdata,
      rxdisperr            => rxdisperr,
      rxnotintable         => rxnotintable,
      rxrundisp            => rxrundisp,
      txbuferr             => txbuferr,
      powerdown            => open,
      txchardispmode       => txchardispmode,
      txchardispval        => txchardispval,
      txcharisk            => txcharisk,
      txdata               => txdata,
      enablealign          => enablealign,
      
      gmii_txd             => gmii_txd_int,
      gmii_tx_en           => gmii_tx_en_int,
      gmii_tx_er           => gmii_tx_er_int,
      gmii_rxd             => gmii_rxd_int,
      gmii_rx_dv           => gmii_rx_dv_int,
      gmii_rx_er           => gmii_rx_er_int,
      gmii_isolate         => gmii_isolate,
      
      configuration_vector => configuration_vector,
      status_vector        => status_vector_int,

      reset                => reset,
      signal_detect        => lvds_phy_rdy_sig_det,
      reset_done           => '1'

   );

   -----------------------------------------------------------------------------
   --  Component Instantiation for the LVDS Transceiver
   -----------------------------------------------------------------------------

     lvds_transceiver_mw : SaltUltraScaleCore_lvds_transceiver_ser8
   port map (
      txchardispmode   =>     txchardispmode,
      txchardispval    =>     txchardispval,
      txcharisk        =>     txcharisk,
      txdata           =>     txdata,
      txbuferr         =>     txbuferr,
      rxchariscomma    =>     rxchariscomma(0),
      rxcharisk        =>     rxcharisk(0),
      rxdata           =>     rxdata,
      rxdisperr        =>     rxdisperr(0),
      rxnotintable     =>     rxnotintable(0),
      rxrundisp        =>     rxrundisp(0),
      idelay_rdy       =>     idelay_rdy_in,
      clk625           =>     clk625, 
      clk312           =>     clk312, 
      clk125           =>     clk125m, 
      pin_sgmii_txn    =>     txn, 
      pin_sgmii_txp    =>     txp,
      pin_sgmii_rxn    =>     rxn,
      pin_sgmii_rxp    =>     rxp,
      rxbuferr         =>     open,
      soft_tx_reset    =>     mgt_tx_reset,
      soft_rx_reset    =>     rx_reset,
      reset            =>     reset
   );


  -- Unused
   rxbufstatus(0) <= '0';
  lvds_phy_rdy_sig_det <= signal_detect ;
  rxclkcorcnt          <= "000";


end block_level;
