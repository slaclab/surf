--------------------------------------------------------------------------------
-- Title      : Top-level Transceiver GT wrapper for Ethernet
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
--------------------------------------------------------------------------------
-- File       : GigEthGth7Core_transceiver.vhd
-- Author     : Xilinx
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
-- Description:  This is the top-level Transceiver GT wrapper. It
--               instantiates the lower-level wrappers produced by
--               the Series-7 FPGA Transceiver GT Wrapper Wizard.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

library unisim;
use unisim.vcomponents.all;


entity GigEthGth7Core_transceiver is
generic
(
    EXAMPLE_SIMULATION                      : integer   := 0          -- Set to 1 for simulation
);
   port (
      mmcm_reset          : out   std_logic;
      data_valid          : in    std_logic;
      independent_clock   : in    std_logic;
      encommaalign        : in    std_logic;
      powerdown           : in    std_logic;
      usrclk              : in    std_logic;
      usrclk2             : in    std_logic;
      rxusrclk              : in    std_logic;
      rxusrclk2             : in    std_logic;
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
      resetdone           : out   std_logic;
        gt0_rxbyteisaligned_out   : out std_logic;
        gt0_rxbyterealign_out     : out std_logic;
        gt0_rxcommadet_out        : out std_logic;
        gt0_txpolarity_in         : in  std_logic;
        gt0_txdiffctrl_in         : in  std_logic_vector(3 downto 0);
        gt0_txinhibit_in          : in  std_logic;
        gt0_txpostcursor_in       : in  std_logic_vector(4 downto 0);
        gt0_txprecursor_in        : in  std_logic_vector(4 downto 0);
        gt0_rxpolarity_in         : in  std_logic;
        gt0_rxdfelpmreset_in      : in  std_logic;
        gt0_rxdfeagcovrden_in     : in  std_logic;
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
        gt0_rxmonitorout_out      : out std_logic_vector(6 downto 0);
        gt0_rxmonitorsel_in       : in  std_logic_vector(1 downto 0);     
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
        gt0_rxpmaresetdone_out    : out std_logic;
        gt0_rxbufstatus_out       : out std_logic_vector(2 downto 0);
        gt0_txbufstatus_out       : out std_logic_vector(1 downto 0);        
        gt0_dmonitorout_out       : out std_logic_vector(14 downto 0);       
        gt0_qplloutclk            : in   std_logic;
        gt0_qplloutrefclk         : in   std_logic
   );
end GigEthGth7Core_transceiver;


architecture wrapper of GigEthGth7Core_transceiver is

   attribute DowngradeIPIdentifiedWarnings: string;
   attribute DowngradeIPIdentifiedWarnings of wrapper : architecture is "yes";

   component GigEthGth7Core_sync_block
   generic (
     INITIALISE : bit_vector(1 downto 0) := "00"
   );
   port  (
             clk           : in  std_logic;
             data_in       : in  std_logic;
             data_out      : out std_logic
          );
   end component;

   component GigEthGth7Core_reset_wtd_timer
   port (
       clk         : in  std_logic;
       data_valid  : in  std_logic;
       reset       : out std_logic
   );
   end component;
   -----------------------------------------------------------------------------
   -- Component declatarion for the Transceiver GT file
   -- (generated by the GT Wizard)
   -----------------------------------------------------------------------------

  component GigEthGth7Core_GTWIZARD
  generic
(
    EXAMPLE_SIMULATION                      : integer   := 0          -- Set to 1 for simulation
);
  port
  (
    mmcm_reset                              : out   std_logic;
    SYSCLK_IN                               : in   std_logic;
    SOFT_RESET_TX_IN                        : in   std_logic;
    SOFT_RESET_RX_IN                        : in   std_logic;
    DONT_RESET_ON_DATA_ERROR_IN             : in   std_logic;
    GT0_DRP_BUSY_OUT                        : out  std_logic;
    GT0_TX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT0_RX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT0_DATA_VALID_IN                       : in   std_logic;

    --_________________________________________________________________________
    --GT0  (X1Y4)
    --____________________________CHANNEL PORTS________________________________
    --------------------------------- CPLL Ports -------------------------------
    gt0_cpllfbclklost_out                   : out  std_logic;
    gt0_cplllock_out                        : out  std_logic;
    gt0_cplllockdetclk_in                   : in   std_logic;
    gt0_cpllreset_in                        : in   std_logic;
    -------------------------- Channel - Clocking Ports ------------------------
    gt0_gtrefclk0_in                        : in   std_logic;
    gt0_gtrefclk0_bufg_in                   : in   std_logic;
     
    ---------------------------- Channel - DRP Ports  --------------------------
    gt0_drpaddr_in                          : in   std_logic_vector(8 downto 0);
    gt0_drpclk_in                           : in   std_logic;
    gt0_drpdi_in                            : in   std_logic_vector(15 downto 0);
    gt0_drpdo_out                           : out  std_logic_vector(15 downto 0);
    gt0_drpen_in                            : in   std_logic;
    gt0_drprdy_out                          : out  std_logic;
    gt0_drpwe_in                            : in   std_logic;
    ------------------------------- Loopback Ports -----------------------------
    gt0_loopback_in                         : in   std_logic_vector(2 downto 0);
    ------------------------------ Power-Down Ports ----------------------------
    gt0_rxpd_in                             : in   std_logic_vector(1 downto 0);
    gt0_txpd_in                             : in   std_logic_vector(1 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    gt0_eyescanreset_in                     : in   std_logic;
    gt0_rxuserrdy_in                        : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    gt0_eyescandataerror_out                : out  std_logic;
    gt0_eyescantrigger_in                   : in   std_logic;
    ------------------------- Receive Ports - CDR Ports ------------------------
    gt0_rxcdrhold_in                        : in  std_logic;
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
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt0_gthrxn_in                           : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt0_rxbufreset_in                       : in   std_logic;
    gt0_rxbufstatus_out                     : out  std_logic_vector(2 downto 0);
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt0_rxbyteisaligned_out                 : out  std_logic;
    gt0_rxbyterealign_out                   : out  std_logic;
    gt0_rxcommadet_out                      : out  std_logic;
    gt0_rxmcommaalignen_in                  : in   std_logic;
    gt0_rxpcommaalignen_in                  : in   std_logic;
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt0_rxdfeagcovrden_in                   : in   std_logic;
    gt0_rxdfelpmreset_in                    : in   std_logic;
    gt0_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
    gt0_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt0_rxoutclk_out                        : out  std_logic;
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt0_gtrxreset_in                        : in   std_logic;
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
    gt0_rxlpmen_in                          : in   std_logic;
    ----------------- Receive Ports - RX Polarity Control Ports ----------------
    gt0_rxpolarity_in                       : in   std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt0_rxchariscomma_out                   : out  std_logic_vector(1 downto 0);
    gt0_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
    ------------------------ Receive Ports -RX AFE Ports -----------------------
    gt0_gthrxp_in                           : in   std_logic;
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt0_rxresetdone_out                     : out  std_logic;
    ------------------------ TX Configurable Driver Ports ----------------------
    gt0_txpostcursor_in                     : in   std_logic_vector(4 downto 0);
    gt0_txprecursor_in                      : in   std_logic_vector(4 downto 0);
    --------------------- TX Initialization and Reset Ports --------------------
    gt0_gttxreset_in                        : in   std_logic;
    gt0_txuserrdy_in                        : in   std_logic;
    ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
    gt0_txchardispmode_in                   : in   std_logic_vector(1 downto 0);
    gt0_txchardispval_in                    : in   std_logic_vector(1 downto 0);
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt0_txusrclk_in                         : in   std_logic;
    gt0_txusrclk2_in                        : in   std_logic;
    --------------------- Transmit Ports - PCI Express Ports -------------------
    gt0_txelecidle_in                       : in   std_logic;
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
    gt0_txprbsforceerr_in                   : in   std_logic;
    ---------------------- Transmit Ports - TX Buffer Ports --------------------
    gt0_txbufstatus_out                     : out  std_logic_vector(1 downto 0);
    --------------- Transmit Ports - TX Configurable Driver Ports --------------
    gt0_txdiffctrl_in                       : in   std_logic_vector(3 downto 0);
    gt0_txinhibit_in                        : in  std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt0_txdata_in                           : in   std_logic_vector(15 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt0_gthtxn_out                          : out  std_logic;
    gt0_gthtxp_out                          : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt0_txoutclk_out                        : out  std_logic;
    gt0_txoutclkfabric_out                  : out  std_logic;
    gt0_txoutclkpcs_out                     : out  std_logic;
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt0_txresetdone_out                     : out  std_logic;
    ----------------- Transmit Ports - TX Polarity Control Ports ---------------
    gt0_txpolarity_in                       : in   std_logic;
    ------------------ Transmit Ports - pattern Generator Ports ----------------
    gt0_txprbssel_in                        : in   std_logic_vector(2 downto 0);
    ----------- Transmit Transmit Ports - 8b10b Encoder Control Ports ----------
    gt0_txcharisk_in                        : in   std_logic_vector(1 downto 0);
    
    gt0_txpmareset_in         : in  std_logic;
    gt0_txpcsreset_in         : in  std_logic;
    gt0_rxpmareset_in         : in  std_logic;
    gt0_rxpcsreset_in         : in  std_logic;
    gt0_rxpmaresetdone_out    : out std_logic;
    gt0_dmonitorout_out       : out std_logic_vector(14 downto 0);       


    --____________________________COMMON PORTS________________________________
     GT0_QPLLOUTCLK_IN  : in std_logic;
     GT0_QPLLOUTREFCLK_IN : in std_logic
  );
  end component;


   -----------------------------------------------------------------------------
   -- Component declaration for the reset synchroniser
   -----------------------------------------------------------------------------
   component GigEthGth7Core_reset_sync
   port (
      reset_in                   : in  std_logic;
      clk                        : in  std_logic;
      reset_out                  : out std_logic
   );
   end component;


   signal data_valid_reg2        : std_logic;
   signal wtd_rxpcsreset_in      : std_logic;
   signal rxpcsreset_comb        : std_logic;
   -----------------------------------------------------------------------------
   -- Signal declarations
   -----------------------------------------------------------------------------

   signal cplllock               : std_logic;
   signal gt_reset_rx            : std_logic;
   signal gt_reset_tx            : std_logic;
   signal resetdone_tx           : std_logic;
   signal resetdone_rx           : std_logic;
   signal pcsreset               : std_logic;

   signal rxbufstatus            : std_logic_vector(2 downto 0);
   signal txbufstatus            : std_logic_vector(1 downto 0);
   signal rxbufstatus_reg        : std_logic_vector(2 downto 0);
   signal txbufstatus_reg        : std_logic_vector(1 downto 0);
   signal rxclkcorcnt_int        : std_logic_vector(1 downto 0);

    -- signal used to control sampling during bus width conversions
   signal toggle                 : std_logic;

   -- signals reclocked onto the 62.5MHz userclk source of the GT transceiver
   signal encommaalign_int       : std_logic;
   signal txreset_int            : std_logic;
   signal rxreset_int            : std_logic;

   -- Register transmitter signals from the core
   signal txdata_reg            : std_logic_vector (7 downto 0);
   signal txchardispmode_reg    : std_logic;
   signal txchardispval_reg     : std_logic;
   signal txcharisk_reg         : std_logic;

   -- Signals for data bus width doubling on the transmitter path from the core
   -- to the GT transceiver
   signal txdata_double          : std_logic_vector (15 downto 0);
   signal txchardispmode_double  : std_logic_vector (1 downto 0);
   signal txchardispval_double   : std_logic_vector (1 downto 0);
   signal txcharisk_double       : std_logic_vector (1 downto 0);

   -- Double width signals reclocked onto the 62.5MHz userclk source of the GT
   -- transceiver
   signal txdata_int             : std_logic_vector (15 downto 0);
   signal txchardispmode_int     : std_logic_vector (1 downto 0);
   signal txchardispval_int      : std_logic_vector (1 downto 0);
   signal txcharisk_int          : std_logic_vector (1 downto 0);

   -- Double width signals output from the GT transceiver on the 62.5MHz clock
   -- source
   signal rxchariscomma_int      : std_logic_vector (1 downto 0);
   signal rxcharisk_int          : std_logic_vector (1 downto 0);
   signal rxdata_int             : std_logic_vector (15 downto 0);
   signal rxdisperr_int          : std_logic_vector (1 downto 0);
   signal rxnotintable_int       : std_logic_vector (1 downto 0);
   signal rxrundisp_int          : std_logic_vector (1 downto 0);

   -- Double width signals reclocked on the GT's 62.5MHz clock source
   signal rxchariscomma_reg      : std_logic_vector (1 downto 0);
   signal rxcharisk_reg          : std_logic_vector (1 downto 0);
   signal rxdata_reg             : std_logic_vector (15 downto 0);
   signal rxclkcorcnt_reg        : std_logic_vector (1 downto 0);
   signal rxdisperr_reg          : std_logic_vector (1 downto 0);
   signal rxnotintable_reg       : std_logic_vector (1 downto 0);
   signal rxrundisp_reg          : std_logic_vector (1 downto 0);

   -- Double width signals reclocked onto the 125MHz clock source
   signal rxchariscomma_double   : std_logic_vector (1 downto 0);
   signal rxcharisk_double       : std_logic_vector (1 downto 0);
   signal rxdata_double          : std_logic_vector (15 downto 0);
   signal rxclkcorcnt_double     : std_logic_vector (1 downto 0);
   signal rxdisperr_double       : std_logic_vector (1 downto 0);
   signal rxnotintable_double    : std_logic_vector (1 downto 0);
   signal rxrundisp_double       : std_logic_vector (1 downto 0);

   -- Signals for powerdown
   signal txpowerdown_int        : std_logic_vector(1 downto 0);
   signal rxpowerdown_int        : std_logic_vector(1 downto 0);
   signal txpowerdown_reg        : std_logic := '0';
   signal txpowerdown_double     : std_logic := '0';
   signal txpowerdown            : std_logic := '0';
   signal rxpowerdown_reg        : std_logic := '0';
   signal rxpowerdown_double     : std_logic := '0';
   signal rxpowerdown            : std_logic := '0';

   signal gt0_rxprbssel_in_orded   : std_logic;
   signal wtd_rxpcsreset_in_comb   : std_logic;
begin
   sync_block_data_valid : GigEthGth7Core_sync_block
   port map
          (
             clk             =>  independent_clock,
             data_in         =>  data_valid,
             data_out        =>  data_valid_reg2
          );
   reset_wtd_timer : GigEthGth7Core_reset_wtd_timer
   port map
          (
             clk             =>  independent_clock,
             data_valid      =>  data_valid_reg2,
             reset           =>  wtd_rxpcsreset_in
          );

   gt0_rxprbssel_in_orded <= gt0_rxprbssel_in(0) or gt0_rxprbssel_in(1) or gt0_rxprbssel_in(2);
   wtd_rxpcsreset_in_comb <= '0' when gt0_rxprbssel_in_orded = '1' else 
                             wtd_rxpcsreset_in;
   rxpcsreset_comb        <= wtd_rxpcsreset_in_comb or gt0_rxpcsreset_in;
   txpowerdown_int <= txpowerdown & txpowerdown;
   rxpowerdown_int <= rxpowerdown & rxpowerdown;

   -----------------------------------------------------------------------------
   -- The core works from a 125MHz clock source, the GT transceiver fabric
   -- interface works from a 62.5MHz clock source.  The following signals
   -- sourced by the core therefore need to be reclocked onto the 62.5MHz
   -- clock
   -----------------------------------------------------------------------------

   -- Reclock encommaalign
   reclock_encommaalign : GigEthGth7Core_reset_sync
   port map(
      clk       => usrclk,
      reset_in  => encommaalign,
      reset_out => encommaalign_int
   );


   -- Reclock txreset
   reclock_txreset : GigEthGth7Core_reset_sync
   port map(
      clk       => independent_clock,
      reset_in  => txreset,
      reset_out => txreset_int
   );


   -- Reclock rxreset
   reclock_rxreset : GigEthGth7Core_reset_sync
   port map(
      clk       => independent_clock,
      reset_in  => rxreset,
      reset_out => rxreset_int
   );


   -----------------------------------------------------------------------------
   -- toggle signal used to control sampling during bus width conversions
   -----------------------------------------------------------------------------

  process (usrclk2)
  begin
    if usrclk2'event and usrclk2= '1' then
      if txreset = '1' then
        toggle      <= '0';
      else
        toggle      <= not toggle;
      end if;
    end if;
  end process;


   -----------------------------------------------------------------------------
   -- The core works from a 125MHz clock source, the GT transceiver fabric
   -- interface works from a 62.5MHz clock source.  The following signals
   -- sourced by the core therefore need to be converted to double width, then
   -- resampled on the GT's 62.5MHz clock
   -----------------------------------------------------------------------------

  -- Reclock the transmitter signals
  process (usrclk2)
  begin
    if usrclk2'event and usrclk2= '1' then
      if txreset = '1' then
        txdata_reg         <= X"00";
        txchardispmode_reg <= '0';
        txchardispval_reg  <= '0';
        txcharisk_reg      <= '0';
        txpowerdown_reg    <= '0';
      else
        txdata_reg         <= txdata;
        txchardispmode_reg <= txchardispmode;
        txchardispval_reg  <= txchardispval;
        txcharisk_reg      <= txcharisk;
        txpowerdown_reg    <= powerdown;
      end if;
    end if;
  end process;


  -- Double the data width
  process (usrclk2)
  begin
    if usrclk2'event and usrclk2= '1' then
      if txreset = '1' then
        txdata_double                <= X"0000";
        txchardispmode_double        <= "00";
        txchardispval_double         <= "00";
        txcharisk_double             <= "00";
        txpowerdown_double           <= '0';
      else
        if toggle = '0' then
          txdata_double(7 downto 0)  <= txdata_reg;
          txchardispmode_double(0)   <= txchardispmode_reg;
          txchardispval_double(0)    <= txchardispval_reg;
          txcharisk_double(0)        <= txcharisk_reg;
          txdata_double(15 downto 8) <= txdata;
          txchardispmode_double(1)   <= txchardispmode;
          txchardispval_double(1)    <= txchardispval;
          txcharisk_double(1)        <= txcharisk;
        end if;
        txpowerdown_double           <= txpowerdown_reg;
      end if;
    end if;
  end process;


  -- Cross the clock domain.  Both clock domains are frequency related and are
  -- derived from the same MMCM: the Xilinx tools will accont for this
  process (usrclk)
  begin
    if usrclk'event and usrclk= '1' then
      txdata_int         <= txdata_double;
      txchardispmode_int <= txchardispmode_double;
      txchardispval_int  <= txchardispval_double;
      txcharisk_int      <= txcharisk_double;
      txbufstatus_reg    <= txbufstatus;
      txpowerdown        <= txpowerdown_double;
    end if;
  end process;



   -----------------------------------------------------------------------------
   -- The core works from a 125MHz clock source, the GT transceiver fabric
   -- interface works from a 62.5MHz clock source.  The following signals
   -- sourced by the GT transceiver therefore need to converted to half width
   -----------------------------------------------------------------------------

  -- Sample the double width received data from the GT transsciever on the GT's
  -- 62.5MHz clock
  process (usrclk)
  begin
    if usrclk'event and usrclk= '1' then
      rxchariscomma_reg  <= rxchariscomma_int;
      rxcharisk_reg      <= rxcharisk_int;
      rxdata_reg         <= rxdata_int;
      rxclkcorcnt_reg    <= rxclkcorcnt_int;
      rxdisperr_reg      <= rxdisperr_int;
      rxnotintable_reg   <= rxnotintable_int;
      rxrundisp_reg      <= rxrundisp_int;
      rxbufstatus_reg    <= rxbufstatus;
      rxpowerdown        <= rxpowerdown_double;
    end if;
  end process;


  -- Reclock the double width received data from the GT transsciever onto the
  -- 125MHz clock source.   Both clock domains are frequency related and are
  -- derived from the same MMCM: the Xilinx tools will accont for this.

  process (usrclk2)
  begin
    if usrclk2'event and usrclk2= '1' then
      if rxreset = '1' then
        rxchariscomma_double  <= "00";
        rxcharisk_double      <= "00";
        rxdata_double         <= X"0000";
        rxclkcorcnt_double    <= "00";
        rxdisperr_double      <= "00";
        rxnotintable_double   <= "00";
        rxrundisp_double      <= "00";
        rxpowerdown_double    <= '0';
      elsif toggle = '1' then
        rxchariscomma_double  <= rxchariscomma_reg;
        rxcharisk_double      <= rxcharisk_reg;
        rxdata_double         <= rxdata_reg;
        rxclkcorcnt_double    <= rxclkcorcnt_reg;
        rxdisperr_double      <= rxdisperr_reg;
        rxnotintable_double   <= rxnotintable_reg;
        rxrundisp_double      <= rxrundisp_reg;
        rxpowerdown_double    <= rxpowerdown_reg;
      end if;
    end if;
  end process;


  -- Halve the bus width
  process (usrclk2)
  begin
    if usrclk2'event and usrclk2= '1' then
      if rxreset = '1' then
        rxchariscomma    <= '0';
        rxcharisk        <= '0';
        rxdata           <= X"00";
        rxclkcorcnt      <= "000";
        rxdisperr        <= '0';
        rxnotintable     <= '0';
        rxrundisp        <= '0';
        rxpowerdown_reg  <= '0';
      else
        if toggle = '0' then
          rxchariscomma  <= rxchariscomma_double(0);
          rxcharisk      <= rxcharisk_double(0);
          rxdata         <= rxdata_double(7 downto 0);
          rxclkcorcnt <= '0' & rxclkcorcnt_double;
          rxdisperr      <= rxdisperr_double(0);
          rxnotintable   <= rxnotintable_double(0);
          rxrundisp      <= rxrundisp_double(0);
        else
          rxchariscomma  <= rxchariscomma_double(1);
          rxcharisk      <= rxcharisk_double(1);
          rxdata         <= rxdata_double(15 downto 8);
          rxclkcorcnt <= '0' & rxclkcorcnt_double;
          rxdisperr      <= rxdisperr_double(1);
          rxnotintable   <= rxnotintable_double(1);
          rxrundisp      <= rxrundisp_double(1);
        end if;
        rxpowerdown_reg  <= powerdown;
      end if;
    end if;
  end process;

   -----------------------------------------------------------------------------
   -- Instantiate the Series-7 GT transceiver
   -----------------------------------------------------------------------------

   -- Direct from the Transceiver Wizard output
    gtwizard_inst : GigEthGth7Core_GTWIZARD
   generic map
    (
        EXAMPLE_SIMULATION            => EXAMPLE_SIMULATION
    )    
    port map (

        mmcm_reset                      =>      mmcm_reset,
    ------------------------------- Loopback Ports -----------------------------
        gt0_loopback_in                 =>      gt0_loopback_in,
    --------------------- RX Initialization and Reset Ports --------------------
        gt0_eyescanreset_in             =>      gt0_eyescanreset_in,
    -------------------------- RX Margin Analysis Ports ------------------------
        gt0_eyescandataerror_out        =>      gt0_eyescandataerror_out,
        gt0_eyescantrigger_in           =>      gt0_eyescantrigger_in,
    ------------------------- Receive Ports - CDR Ports ------------------------
        gt0_rxcdrhold_in                =>      gt0_rxcdrhold_in,
    ------------------- Receive Ports - Pattern Checker Ports ------------------
        gt0_rxprbserr_out               =>      gt0_rxprbserr_out,
        gt0_rxprbssel_in                =>      gt0_rxprbssel_in,
    ------------------- Receive Ports - Pattern Checker ports ------------------
        gt0_rxprbscntreset_in           =>      gt0_rxprbscntreset_in,
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
        gt0_rxbyteisaligned_out         =>      gt0_rxbyteisaligned_out,
        gt0_rxbyterealign_out           =>      gt0_rxbyterealign_out,
        gt0_rxcommadet_out              =>      gt0_rxcommadet_out,
    --------------------- Receive Ports - RX Equalizer Ports -------------------
        gt0_rxdfeagcovrden_in           =>      gt0_rxdfeagcovrden_in,
        gt0_rxdfelpmreset_in            =>      gt0_rxdfelpmreset_in,
        gt0_rxmonitorout_out            =>      gt0_rxmonitorout_out,
        gt0_rxmonitorsel_in             =>      gt0_rxmonitorsel_in,
    ------------------ Receive Ports - RX Margin Analysis ports ----------------
        gt0_rxlpmen_in                  =>      gt0_rxlpmen_in,
    ----------------- Receive Ports - RX Polarity Control Ports ----------------
        gt0_rxpolarity_in               =>      gt0_rxpolarity_in,
    ------------------------ TX Configurable Driver Ports ----------------------
        gt0_txpostcursor_in             =>      gt0_txpostcursor_in,
        gt0_txprecursor_in              =>      gt0_txprecursor_in,
    ------------------ Transmit Ports - Pattern Generator Ports ----------------
        gt0_txprbsforceerr_in           =>      gt0_txprbsforceerr_in,
    --------------- Transmit Ports - TX Configurable Driver Ports --------------
        gt0_txdiffctrl_in               =>      gt0_txdiffctrl_in,
        gt0_txinhibit_in                =>      gt0_txinhibit_in,
    ----------------- Transmit Ports - TX Polarity Control Ports ---------------
        gt0_txpolarity_in               =>      gt0_txpolarity_in,
    ------------------ Transmit Ports - pattern Generator Ports ----------------
        gt0_txprbssel_in                =>      gt0_txprbssel_in,
        ---------------------------- channel - drp ports  --------------------------
        gt0_drpaddr_in                  =>     gt0_drpaddr_in ,  
        gt0_drpclk_in                   =>     gt0_drpclk_in  ,  
        gt0_drpdi_in                    =>     gt0_drpdi_in   ,  
        gt0_drpdo_out                   =>     gt0_drpdo_out  ,  
        gt0_drpen_in                    =>     gt0_drpen_in   , 
        gt0_drprdy_out                  =>     gt0_drprdy_out , 
        gt0_drpwe_in                    =>     gt0_drpwe_in   , 
        sysclk_in                       =>     independent_clock,
        soft_reset_tx_in                =>     pmareset,
        soft_reset_rx_in                =>     pmareset,
        dont_reset_on_data_error_in     =>     gt0_rxprbssel_in_orded,
        gt0_tx_fsm_reset_done_out       =>     resetdone_tx,
        gt0_rx_fsm_reset_done_out       =>     resetdone_rx,
        gt0_data_valid_in               =>     data_valid_reg2,
    --_________________________________________________________________________
    --_________________________________________________________________________
    --gt0  (x0y4)
    --____________________________channel ports________________________________
    ------------------------- channel - ref clock ports ------------------------
        gt0_gtrefclk0_in                =>      gtrefclk,
        gt0_gtrefclk0_bufg_in           =>      gtrefclk_bufg,
     
    -------------------------------- channel pll -------------------------------
        gt0_cpllfbclklost_out           =>      open,
        gt0_cplllock_out                =>      cplllock,
        gt0_cplllockdetclk_in           =>      independent_clock,
        gt0_cpllreset_in                =>      pmareset,
    ------------------------ loopback and powerdown ports ----------------------
        gt0_rxpd_in                     =>      rxpowerdown_int,
        gt0_txpd_in                     =>      txpowerdown_int,
    ------------------------------- receive ports ------------------------------
        gt0_rxuserrdy_in                =>      mmcm_locked,
    ----------------------- receive ports - 8b10b decoder ----------------------
        gt0_rxchariscomma_out           =>      rxchariscomma_int,
        gt0_rxcharisk_out               =>      rxcharisk_int,
        gt0_rxdisperr_out               =>      rxdisperr_int,
        gt0_rxnotintable_out            =>      rxnotintable_int,
    ------------------- receive ports - clock correction ports -----------------
        gt0_rxclkcorcnt_out             =>      rxclkcorcnt_int,
    --------------- receive ports - comma detection and alignment --------------
        gt0_rxmcommaalignen_in          =>      encommaalign_int,
        gt0_rxpcommaalignen_in          =>      encommaalign_int,
    ------------------- receive ports - rx data path interface -----------------
        gt0_gtrxreset_in                =>      gt_reset_rx,
        gt0_rxdata_out                  =>      rxdata_int,
        gt0_rxoutclk_out                =>      rxoutclk,
        gt0_rxusrclk_in                 =>      rxusrclk,
        gt0_rxusrclk2_in                =>      rxusrclk2,
    ------- receive ports - rx driver,oob signalling,coupling and eq.,cdr ------
        gt0_gthrxn_in                   =>      rxn,
        gt0_gthrxp_in                   =>      rxp,
    -------- receive ports - rx elastic buffer and phase alignment ports -------
        gt0_rxbufreset_in               =>      gt0_rxbufreset_in,
        gt0_rxbufstatus_out             =>      rxbufstatus,
    ------------------------ receive ports - rx pll ports ----------------------
        gt0_rxresetdone_out             =>      open,
    ------------------------------- transmit ports -----------------------------
        gt0_txuserrdy_in                =>      mmcm_locked,
    ---------------- transmit ports - 8b10b encoder control ports --------------
        gt0_txchardispmode_in           =>      txchardispmode_int,
        gt0_txchardispval_in            =>      txchardispval_int,
        gt0_txcharisk_in                =>      txcharisk_int,
    ------------ transmit ports - tx buffer and phase alignment ports ----------
        gt0_txbufstatus_out             =>      txbufstatus,
    ------------------ transmit ports - tx data path interface -----------------
        gt0_gttxreset_in                =>      gt_reset_tx,
        gt0_txdata_in                   =>      txdata_int,
        gt0_txoutclk_out                =>      txoutclk,
        gt0_txoutclkfabric_out          =>      open,
        gt0_txoutclkpcs_out             =>      open,
        gt0_txusrclk_in                 =>      usrclk,
        gt0_txusrclk2_in                =>      usrclk,
    ---------------- transmit ports - tx driver and oob signaling --------------
        gt0_gthtxn_out                  =>      txn,
        gt0_gthtxp_out                  =>      txp,
    ----------------------- transmit ports - tx pll ports ----------------------
        gt0_txresetdone_out             =>      open,
    ----------------- transmit ports - tx ports for pci express ----------------
        gt0_txelecidle_in               =>      txpowerdown,
    ----------------- debug ports  ----------------
        gt0_txpmareset_in              =>    gt0_txpmareset_in        , 
        gt0_txpcsreset_in              =>    gt0_txpcsreset_in        , 
        gt0_rxpmareset_in              =>    gt0_rxpmareset_in        , 
        gt0_rxpcsreset_in              =>    rxpcsreset_comb          , 
        gt0_rxpmaresetdone_out         =>    gt0_rxpmaresetdone_out   , 
        gt0_dmonitorout_out            =>    gt0_dmonitorout_out      ,        
    --____________________________common ports________________________________
    ---------------------- common block  - ref clock ports ---------------------
        gt0_qplloutclk_in                  =>      gt0_qplloutclk,
        gt0_qplloutrefclk_in               =>      gt0_qplloutrefclk

    );


   gt0_rxbufstatus_out   <=      rxbufstatus;
   gt0_txbufstatus_out   <=      txbufstatus;
   -- Hold the transmitter and receiver paths of the GT transceiver in reset
   -- until the PLL has locked.
   gt_reset_rx <= (rxreset_int and resetdone_rx);
   gt_reset_tx <= (txreset_int and resetdone_tx);
   gt0_rxresetdone_out <= resetdone_rx;
   gt0_txresetdone_out <= resetdone_tx;

   -- Output the PLL locked status
   plllkdet <= cplllock;


   -- Report overall status for both transmitter and receiver reset done signals
   resetdone <= cplllock;

   -- reset to PCS part of GT
   pcsreset <= not mmcm_locked;

   -- temporary
   rxrundisp_int <= "00";


   -- Decode the GT transceiver buffer status signals
   process (usrclk2)
   begin
     if usrclk2'event and usrclk2= '1' then
       rxbuferr    <= rxbufstatus_reg(2);
       txbuferr    <= txbufstatus_reg(1);
     end if;
   end process;




end wrapper;
