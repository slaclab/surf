--------------------------------------------------------------------------------
-- Title      : 
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
-- File       : Salt7SeriesCore_lvds_transceiver_k7.vhd
-- Author     : Xilinx
--------------------------------------------------------------------------------
-- (c) Copyright 2006 Xilinx, Inc. All rights reserved.
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
-- Description:  This module makes the GPIO SGMII logic look like a hardened SERDES.
--  Making it easier to hook into the existing GEMAC+PCS/PMA cores
--------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;
USE IEEE.std_logic_misc.ALL;
USE STD.textio.ALL;

library unisim;
use unisim.vcomponents.all;

LIBRARY work;
USE work.Salt7SeriesCore_encode_8b10b_pkg.ALL;
USE work.Salt7SeriesCore_decode_8b10b_pkg.ALL;

entity Salt7SeriesCore_lvds_transceiver_k7 is
port (
-- Transceiver Transmitter Interface (synchronous to clk125m)
  txchardispmode      : in std_logic ;
  txchardispval       : in std_logic ;
  txcharisk           : in std_logic ;
  txdata              : in std_logic_vector(7 downto 0) ;
  txbuferr            : out std_logic;

-- Transceiver Receiver Interface (synchronous to clk125m)
  enmcommaalign       : in std_logic ;
  enpcommaalign       : in std_logic ;
  rxchariscomma       : out std_logic ;
  rxcharisk           : out std_logic ;
  rxclkcorcnt         : out std_logic_vector(2 downto 0) ;
  rxdata              : out std_logic_vector(7 downto 0) ;
  rxdisperr           : out std_logic ;
  rxnotintable        : out std_logic ;
  rxrundisp           : out std_logic ;
  rxbuferr            : out std_logic ;

-- clocks and reset
  phy_cdr_lock        : out std_logic ;
  clk625              : in std_logic ;
  clk208              : in std_logic ;
  refClk200           : in std_logic ;
  clk104              : in std_logic ;
  clk125              : in std_logic ;
  soft_tx_reset       : in std_logic ; 
  soft_rx_reset       : in std_logic ; 
  reset               : in std_logic ; -- CLK125

  o_r_margin          : out std_logic_vector(4 downto 0) ;
  o_l_margin          : out std_logic_vector (4 downto 0) ;

  eye_mon_wait_time   : in std_logic_vector(11 downto 0) ;

-- Serial input wire and output wire differential pairs
  pin_sgmii_txn       : out std_logic ;
  pin_sgmii_txp       : out std_logic ;
  pin_sgmii_rxn       : in std_logic ;
  pin_sgmii_rxp       : in std_logic 
);
end Salt7SeriesCore_lvds_transceiver_k7;

architecture xilinx of Salt7SeriesCore_lvds_transceiver_k7 is 

--- component declarations 
component Salt7SeriesCore_gearbox_10b_6b 
port (
   reset       : in std_logic;
   clk125      : in std_logic;
   txdata_10b  : in std_logic_vector(9 downto 0);
   clk208      :in std_logic;
   o_txdata_6b : out std_logic_vector(5 downto 0)
);
end component ;
component Salt7SeriesCore_encode_8b10b_lut_base 
  GENERIC (
    C_HAS_DISP_IN     :     INTEGER :=0 ;
    C_HAS_FORCE_CODE  :     INTEGER :=0 ;
    C_FORCE_CODE_VAL  :     STRING  :="1010101010" ;
    C_FORCE_CODE_DISP :     INTEGER :=0 ;
    C_HAS_ND          :     INTEGER :=0 ;
    C_HAS_KERR        :     INTEGER :=0
    );
  PORT (
    DIN               : IN  STD_LOGIC_VECTOR(7 DOWNTO 0) :=(OTHERS => '0');
    KIN               : IN  STD_LOGIC                    :='0' ;
    CLK               : IN  STD_LOGIC                    :='0' ;
    DOUT              : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)  ;
    CE                : IN  STD_LOGIC                    :='0' ;
    FORCE_CODE        : IN  STD_LOGIC                    :='0' ;
    FORCE_DISP        : IN  STD_LOGIC                    :='0' ;
    DISP_IN           : IN  STD_LOGIC                    :='0' ;
    DISP_OUT          : OUT STD_LOGIC                    ;
    KERR              : OUT STD_LOGIC                    :='0' ;
    ND                : OUT STD_LOGIC                    :='0'

);
end component ;
component Salt7SeriesCore_gearbox_6b_10b
port (
   reset        : in std_logic;
   clk208       : in std_logic;
   rxdata_6b    : in std_logic_vector(5 downto 0);
   
   bitslip      : in std_logic;
   clk125       : in std_logic;
   o_rxdata_10b : out std_logic_vector(9 downto 0)

);
end component ;
component Salt7SeriesCore_sgmii_comma_alignment
port (
    clk         : in std_logic;
    reset       : in std_logic;
    clken       : in std_logic;
    enablealign : in std_logic;

    data_in     : in std_logic_vector(9 downto 0);
    comma_det   : out std_logic;
    bitslip     : out std_logic

);
end component ;
component Salt7SeriesCore_decode_8b10b_lut_base
  GENERIC (
    C_HAS_CODE_ERR   : INTEGER := 0;
    C_HAS_DISP_ERR   : INTEGER := 0;
    C_HAS_DISP_IN    : INTEGER := 0;
    C_HAS_ND         : INTEGER := 0;
    C_HAS_SYM_DISP   : INTEGER := 0;
    C_HAS_RUN_DISP   : INTEGER := 0;
    C_SINIT_DOUT     : STRING  := "00000000";
    C_SINIT_KOUT     : INTEGER := 0;
    C_SINIT_RUN_DISP : INTEGER := 0
    );
  PORT (
    CLK              : IN  STD_LOGIC                     := '0';
    DIN              : IN  STD_LOGIC_VECTOR(9 DOWNTO 0)  := (OTHERS => '0');
    DOUT             : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)  ;
    KOUT             : OUT STD_LOGIC                     ;

    CE               : IN  STD_LOGIC                     := '0';
    DISP_IN          : IN  STD_LOGIC                     := '0';
    SINIT            : IN  STD_LOGIC                     := '0';
    CODE_ERR         : OUT STD_LOGIC                     := '0';
    DISP_ERR         : OUT STD_LOGIC                     := '0';
    ND               : OUT STD_LOGIC                     := '0';
    RUN_DISP         : OUT STD_LOGIC                     ;
    SYM_DISP         : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
);
end component ;

component Salt7SeriesCore_gpio_sgmii_top
port (
      reset               : in std_logic; 
      soft_tx_reset       : in std_logic; 
      soft_rx_reset       : in std_logic; 
     
      clk625              : in std_logic;
      refClk200           : in std_logic;
      clk208              : in std_logic;
      clk104              : in std_logic;

      enable_initial_cal  : in std_logic;
      o_init_cal_done     : out std_logic;
      o_loss_of_sync      : out std_logic;
      tx_data_6b          : in std_logic_vector (5 downto 0);
      o_rx_data_6b        : out std_logic_vector (5 downto 0);
      code_error          : in std_logic;

      eye_mon_wait_time   : in std_logic_vector(11 downto 0);

      pin_sgmii_rxp       : in std_logic;  
      pin_sgmii_rxn       : in std_logic;  
      pin_sgmii_txp       : out std_logic;  
      pin_sgmii_txn       : out std_logic;

      o_r_margin          : out std_logic_vector (4 downto 0);
      o_l_margin          : out std_logic_vector (4 downto 0)

);
end component ;

component Salt7SeriesCore_sync_block
generic (
  INITIALISE : bit_vector(1 downto 0) := "00"
);
port  (
          clk           : in  std_logic;
          data_in       : in  std_logic;
          data_out      : out std_logic
       );
end component;

-----------------------------------------------------------------------------
-- Component declaration for the reset synchroniser
-----------------------------------------------------------------------------
component Salt7SeriesCore_reset_sync
port (
   reset_in                   : in  std_logic;
   clk                        : in  std_logic;
   reset_out                  : out std_logic
);
end component;

-- Wires and Regs
signal  rx_data_6b             : std_logic_vector(5 downto 0);
signal  rx_data_10b            : std_logic_vector(9 downto 0);
signal  tx_data_6b             : std_logic_vector(5 downto 0);
signal  tx_data_10b            : std_logic_vector(9 downto 0);
signal  phy_init_cal_done_104  : std_logic;
signal  phy_loss_of_sync_104   : std_logic;
signal  phy_init_cal_done      : std_logic;
signal  phy_init_cal_done_r    : std_logic;
signal  phy_loss_of_sync_r     : std_logic;
signal  bitslip                : std_logic ;

signal rx_data_10b_swapped     : std_logic_vector(9 downto 0);

signal code_error_stretch      : std_logic_vector(3 downto 0);
signal rst_dly                 : std_logic_vector(3 downto 0);
signal rst_dly_or              : std_logic; 
signal code_error_stretch_or   : std_logic; 
signal rst_dly_3_b             : std_logic; 
signal enable_align_s          : std_logic;
signal rxchariscomma_s         : std_logic ;
signal rxdata_s                : std_logic_vector(7 downto 0) ;
signal rxcharisk_s             : std_logic ;
signal rxdisperr_s             : std_logic ;
signal rxrundisp_s             : std_logic ;
signal rxnotintable_s          : std_logic ;
signal reset_104               : std_logic ;
signal soft_tx_reset_104       : std_logic ;
signal soft_rx_reset_104       : std_logic ; 
signal tx_rst                  : std_logic ; 
signal rx_rst                  : std_logic ; 

begin 
-- Assignments

txbuferr     <= '0'; -- There is no TX buffer
rxbuferr     <= '0'; -- There is no RX Elastic Buffer
rxclkcorcnt  <= "000";
phy_cdr_lock <= phy_init_cal_done;

sync_block_phy_init_cal_done : Salt7SeriesCore_sync_block
port map
(
   clk             => clk125 ,
   data_in         => phy_init_cal_done_r ,
   data_out        => phy_init_cal_done 
);

reset_sync_reset_104 : Salt7SeriesCore_reset_sync
port map(
   clk       => clk104,
   reset_in  => reset,
   reset_out => reset_104
);

reset_sync_soft_tx_reset_104 : Salt7SeriesCore_reset_sync
port map(
   clk       => clk104,
   reset_in  => soft_tx_reset,
   reset_out => soft_tx_reset_104
);

reset_sync_soft_rx_reset_104 : Salt7SeriesCore_reset_sync
port map(
   clk       => clk104,
   reset_in  => soft_rx_reset,
   reset_out => soft_rx_reset_104
);

process (clk104)
begin
  if clk104'event and clk104 ='1' then 
    phy_init_cal_done_r <= phy_init_cal_done_104;
  end if;
end process;
process (clk104)
begin
  if clk104'event and clk104 ='1' then 
    phy_loss_of_sync_r <= phy_loss_of_sync_104;
  end if;
end process;

tx_rst    <= reset or soft_tx_reset;
rx_rst    <= reset or soft_rx_reset;
------------------------------------------------------------------------------
-- TX Data Path
------------------------------------------------------------------------------

-- TX Gearbox - Converts 10b @ 125MHz -to- 6b @ 208 MHz
tx_gearbox_i : Salt7SeriesCore_gearbox_10b_6b 
port map (
   reset       => tx_rst, 
   clk125      => clk125, 
   txdata_10b  => tx_data_10b, 
   clk208      => clk208, 
   o_txdata_6b => tx_data_6b
    );

-- 8b/10b from XAPP 1122
encode_8b10b : Salt7SeriesCore_encode_8b10b_lut_base 
  generic map (
    C_HAS_DISP_IN      => 1,
    C_HAS_FORCE_CODE   => 0,
    C_FORCE_CODE_VAL   => "0000000000",
    C_FORCE_CODE_DISP  => 1,
    C_HAS_ND           => 0,
    C_HAS_KERR         => 0

  ) 
port map (
    din            =>   txdata,  -- 8 bit
    kin            =>   txcharisk,
    clk            =>   clk125,  -- 125 MHz
    dout           =>   tx_data_10b,  -- 10 bit
    ce             =>   '1',
    force_code     =>   '0',
    force_disp     =>   txchardispmode,
    disp_in        =>   txchardispval,
    disp_out       =>   open,
    kerr           =>   open,
    nd             =>   open
  );


------------------------------------------------------------------------------
-- RX Data Path
------------------------------------------------------------------------------

-- RX Gearbox - Converts 6b @ 208 MHz -to- 10b @ 125MHz
rx_gearbox_i : Salt7SeriesCore_gearbox_6b_10b 
port map (
   reset        => rx_rst, 
   clk208       => clk208, 
   rxdata_6b    => rx_data_6b, 
   bitslip      => bitslip, 
   clk125       => clk125, 
   o_rxdata_10b => rx_data_10b
    );

-- Comma Alignment    
rx_data_10b_swapped(9) <= rx_data_10b(0);
rx_data_10b_swapped(8) <= rx_data_10b(1);
rx_data_10b_swapped(7) <= rx_data_10b(2);
rx_data_10b_swapped(6) <= rx_data_10b(3);
rx_data_10b_swapped(5) <= rx_data_10b(4);
rx_data_10b_swapped(4) <= rx_data_10b(5);
rx_data_10b_swapped(3) <= rx_data_10b(6);
rx_data_10b_swapped(2) <= rx_data_10b(7);
rx_data_10b_swapped(1) <= rx_data_10b(8);
rx_data_10b_swapped(0) <= rx_data_10b(9);

enable_align_s <= enmcommaalign and enpcommaalign and phy_init_cal_done;
-- This module toggles bitslip to the RX Gearbox, which does the actual alignment
comma_alignment_inst : Salt7SeriesCore_sgmii_comma_alignment 
   port map (
   clk                 =>  clk125,
   reset               =>  rx_rst,
   clken               =>  '1',
   enablealign         =>  enable_align_s ,

   data_in             =>  rx_data_10b_swapped ,
   comma_det           =>  rxchariscomma_s,
   bitslip             =>  bitslip
   );    

    
-- 8b/10b Decoder
 decode_8b10b :  Salt7SeriesCore_decode_8b10b_lut_base 
  generic map (
    C_HAS_CODE_ERR       => 1,
    C_HAS_DISP_ERR       => 1,
    C_HAS_DISP_IN        => 0,
    C_HAS_ND             => 0,
    C_HAS_SYM_DISP       => 0,
    C_HAS_RUN_DISP       => 1,
    C_SINIT_DOUT         => x"00",
    C_SINIT_KOUT         => 0,
    C_SINIT_RUN_DISP     => 0

  ) 
port map (
    clk                 =>  clk125,
    din                 =>  rx_data_10b,
    dout                =>  rxdata_s,
    kout                =>  rxcharisk_s,

    ce                  =>  '1',
    disp_in             =>  '0',
    sinit               =>  '0',
    code_err            =>  rxnotintable_s,
    disp_err            =>  rxdisperr_s,
    nd                  =>  open,
    run_disp            =>  rxrundisp_s,
    sym_disp            =>  open
  );
   
-- Pulse Strectcher 8b/10b code group errors
process (clk125)
begin
  if clk125'event and clk125 ='1' then 
    if (rx_rst = '1')  then
      code_error_stretch <= x"0";
    elsif (rxdisperr_s = '1' or rxnotintable_s = '1') then
       code_error_stretch <= x"F";
    elsif (code_error_stretch /= x"0") then 
      code_error_stretch <= code_error_stretch - '1';
    else
      code_error_stretch <= code_error_stretch;
    end if;
  end if;
end process;
  
process (clk125)
begin
  if clk125'event and clk125 ='1' then 
    if (rx_rst = '1')  then
      rxchariscomma <= '0';
	    rxcharisk     <= '0';
	    rxdisperr     <= '0';
	    rxdata        <= x"00";
	    rxnotintable  <= '0';
	    rxrundisp     <= '0';
    else
	    rxchariscomma <= rxchariscomma_s;
	    rxcharisk     <= rxcharisk_s;
      rxdisperr     <= rxdisperr_s;
	    rxdata        <= rxdata_s;
      rxnotintable  <= rxnotintable_s;
	    rxrundisp     <= rxrundisp_s;
    end if;
  end if;
end process;
  


------------------------------------------------------------------------------
-- LVDS PHY
------------------------------------------------------------------------------

process (clk104)
begin
  if clk104'event and clk104 ='1' then 
   if (reset_104 = '1' or phy_loss_of_sync_104 = '1') then
     rst_dly <= x"0";
   elsif (rst_dly = x"F") then 
     rst_dly <= rst_dly;
   else         
     rst_dly <= rst_dly + '1';
   end if;
  end if;
end process;

rst_dly_or            <= rst_dly(3) and rst_dly(2) and rst_dly(1) and rst_dly(0);
code_error_stretch_or <= code_error_stretch(3) or code_error_stretch(2) or  code_error_stretch(1) or  code_error_stretch(0) ; 
rst_dly_3_b           <= not rst_dly(3);

gpio_sgmii_top_i : Salt7SeriesCore_gpio_sgmii_top
port map (

   reset              => rst_dly_3_b, -- CLK104 
   soft_tx_reset      => soft_tx_reset_104,
   soft_rx_reset      => soft_rx_reset_104,
   
   clk625             => clk625, 
   refClk200          => refClk200, 
   clk208             => clk208, 
   clk104             => clk104, 

   enable_initial_cal => rst_dly_or,-- or enable_initial_cal ,
   o_init_cal_done    => phy_init_cal_done_104,
   o_loss_of_sync     => phy_loss_of_sync_104,
   tx_data_6b         => tx_data_6b,
   o_rx_data_6b       => rx_data_6b,
   code_error         => code_error_stretch_or  ,

   eye_mon_wait_time  => eye_mon_wait_time,

   pin_sgmii_rxp      => pin_sgmii_rxp, 
   pin_sgmii_rxn      => pin_sgmii_rxn, 
   pin_sgmii_txp      => pin_sgmii_txp, 
   pin_sgmii_txn      => pin_sgmii_txn,
   
   o_r_margin         => o_r_margin,
   o_l_margin         => o_l_margin
 );

end xilinx ;
