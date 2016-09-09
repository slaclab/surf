--------------------------------------------------------------------------------
-- Title      : 
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
-- File       : Salt7SeriesCore_gpio_sgmii_top.vhd
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
-- Description:   This module is the top level for GPIO based SGMII's.  
--  It's responsible for:
--  1)  TX TBI -> Output DDR.
--  2)  RX - READ PHY Calibration
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;
USE IEEE.std_logic_misc.ALL;

library unisim;
use unisim.vcomponents.all;


entity Salt7SeriesCore_gpio_sgmii_top is
port (

      reset               : in std_logic; 
      soft_tx_reset       : in std_logic; 
      soft_rx_reset       : in std_logic; 
      clk625              : in std_logic;
      clk208              : in std_logic;
      clk104              : in std_logic;

      enable_initial_cal  : in std_logic;
      o_init_cal_done     : out std_logic;
      o_loss_of_sync      : out std_logic;
      tx_data_6b          : in std_logic_vector (5 downto 0);
      o_rx_data_6b        : out std_logic_vector (5 downto 0);
      code_error          : in std_logic;

      eye_mon_wait_time   : in std_logic_vector (11 downto 0);

      pin_sgmii_rxp       : in std_logic;  
      pin_sgmii_rxn       : in std_logic;  
      pin_sgmii_txp       : out std_logic;  
      pin_sgmii_txn       : out std_logic;

      o_r_margin          : out std_logic_vector (4 downto 0);
      o_l_margin          : out std_logic_vector (4 downto 0)

);
end Salt7SeriesCore_gpio_sgmii_top;

architecture xilinx of Salt7SeriesCore_gpio_sgmii_top is

-- Component Declarations 

component Salt7SeriesCore_sgmii_phy_iob
port (
    clk625            : in  std_logic;
    clk208            : in  std_logic;
    clk104            : in  std_logic;
    rst               : in  std_logic;  -- 104
    soft_tx_reset     : in std_logic;
    soft_rx_reset     : in std_logic;
    data_idly_rst     : in  std_logic;
    mon_idly_rst      : in  std_logic;

-- RX Data and Control
    data_dly_val_in   : in   std_logic_vector(4 downto 0);
    data_dly_val_out  : out  std_logic_vector(4 downto 0);
    mon_dly_val_in    : in   std_logic_vector(4 downto 0);
    mon_dly_val_out   : out  std_logic_vector(4 downto 0); 
 
    o_rx_data_12b     : out  std_logic_vector(11 downto 0);
    o_rx_mon          : out  std_logic_vector(11 downto 0);
   
    o_rx_data_6b      : out std_logic_vector (5 downto 0);
   
    pin_sgmii_rxp     : in  std_logic;  
    pin_sgmii_rxn     : in  std_logic;
 
-- TX Data
    tx_data_6b        : in  std_logic_vector(5 downto 0);

    pin_sgmii_txp     : out std_logic;  
    pin_sgmii_txn     : out std_logic

);
end component ; 
component Salt7SeriesCore_sgmii_eye_monitor
port (
    clk104              : in std_logic;
    rst                 : in std_logic;
    enable_eye_mon      : in std_logic;
    o_eye_mon_done      : out std_logic;
   
    rx_data             : in std_logic_vector(11 downto 0);
    rx_mon              : in std_logic_vector(11 downto 0);
    data_idelay_val     : in std_logic_vector(4 downto 0);

    eye_mon_wait_time   : in std_logic_vector(11 downto 0);
   
    o_mon_idelay_val    : out std_logic_vector(4 downto 0);
    o_mon_idelay_update : out std_logic;
   
    right_margin        : out std_logic_vector(4 downto 0);
    left_margin         : out std_logic_vector(4 downto 0)
);
end component ; 
component Salt7SeriesCore_sgmii_phy_calibration
port (
    clk104             : in std_logic;
    rst                : in std_logic;
    enable_initial_cal : in std_logic;
    o_initial_cal_done : out std_logic;
   
    o_enable_eye_mon   : out std_logic;
    eye_mon_done       : in std_logic;
    left_margin        : in std_logic_vector(4 downto 0);
    right_margin       : in std_logic_vector(4 downto 0);
  
    o_data_idelay_val  : out std_logic_vector(4 downto 0);
    o_data_idelay_update  : out std_logic;
   
    o_eye_mon_done_fe  : out std_logic_vector(1 downto 0)
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

-- SGMII 0
signal rx_data_12b_raw        : std_logic_vector (11 downto 0);
signal rx_mon_12b             : std_logic_vector (11 downto 0);
signal data_dly_val_in0       : std_logic_vector (4 downto 0);
signal data_dly_val_out0      : std_logic_vector (4 downto 0);
signal mon_dly_val_in0        : std_logic_vector (4 downto 0);
signal mon_dly_val_out0       : std_logic_vector (4 downto 0);
signal enable_eye_mon         : std_logic;
signal enable_eye_mon_s       : std_logic;
signal eye_mon_done           : std_logic;
signal initial_cal_done       : std_logic;
signal data_idly_update0      : std_logic;
signal mon_idly_update0       : std_logic;
signal right_margin0          : std_logic_vector (4 downto 0);
signal left_margin0           : std_logic_vector (4 downto 0);
signal bad_mon_trig           : std_logic;
signal panic_bucket           : std_logic_vector (3 downto 0);
signal code_error_r           : std_logic;
signal eye_mon_timeout        : std_logic_vector (23 downto 0);  -- Periodically enable the eye monitor FSM 
signal eye_mon_timeout_r      : std_logic;
signal eye_mon_done_fe        : std_logic_vector (1 downto 0);
signal rx_rst                 : std_logic;

begin 
 
 o_init_cal_done <= initial_cal_done;

 o_r_margin      <= right_margin0;
 o_l_margin      <= left_margin0;

 rx_rst          <= reset or soft_rx_reset;

-- *** SGMII PHY IOB's ***
sgmii_phy_iob : Salt7SeriesCore_sgmii_phy_iob 
port map (
   clk625           => clk625, 
   clk208           => clk208, 
   clk104           => clk104, 
   rst              => reset, 
   soft_tx_reset    => soft_tx_reset, 
   soft_rx_reset    => soft_rx_reset, 
   data_idly_rst    => data_idly_update0, 
   mon_idly_rst     => mon_idly_update0,

   data_dly_val_in  => data_dly_val_in0, 
   data_dly_val_out => data_dly_val_out0, 
   mon_dly_val_in   => mon_dly_val_in0, 
   mon_dly_val_out  => mon_dly_val_out0, 

   o_rx_data_12b    => rx_data_12b_raw, 
   o_rx_mon         => rx_mon_12b, 
   
   o_rx_data_6b     => o_rx_data_6b,   
   tx_data_6b       => tx_data_6b, 

   pin_sgmii_rxp    => pin_sgmii_rxp, 
   pin_sgmii_rxn    => pin_sgmii_rxn, 
   pin_sgmii_txp    => pin_sgmii_txp, 
   pin_sgmii_txn    => pin_sgmii_txn
   );

-- This FSM monitors the eye width and reports it
sgmii_eye_mon : Salt7SeriesCore_sgmii_eye_monitor
port map (
    clk104              => (clk104), 
    rst                 => (rx_rst), 
    enable_eye_mon      => (enable_eye_mon_s ), 
    o_eye_mon_done      => (eye_mon_done), 
    rx_data             => (rx_data_12b_raw), 
    rx_mon              => (rx_mon_12b), 
    eye_mon_wait_time   => (eye_mon_wait_time),
    data_idelay_val     => (data_dly_val_out0), 
    o_mon_idelay_val    => (mon_dly_val_in0), 
    o_mon_idelay_update => (mon_idly_update0), 
    right_margin        => (right_margin0), 
    left_margin         => (left_margin0) 
    );
    
process (clk104)-- Periodically enable eye monitor
begin
  if (clk104'event and clk104 ='1') then 
    if (eye_mon_done /= '1') then
      eye_mon_timeout <= (others => '0');
    else 
      eye_mon_timeout <= eye_mon_timeout + '1';
    end if;
  end if;
end process;
 
enable_eye_mon_s <= enable_eye_mon or eye_mon_timeout_r ;

process (clk104)
begin
  if (clk104'event and clk104 ='1') then
    eye_mon_timeout_r <= eye_mon_timeout(23) or eye_mon_timeout(22) or  eye_mon_timeout(21) or  eye_mon_timeout(20) or  eye_mon_timeout(19) or  eye_mon_timeout(18) or  eye_mon_timeout(17) or 
                         eye_mon_timeout(16) or  eye_mon_timeout(15) or  eye_mon_timeout(14) or eye_mon_timeout(13) or  eye_mon_timeout(12) or  eye_mon_timeout(11) or  eye_mon_timeout(10) or 
                         eye_mon_timeout(9) or  eye_mon_timeout(8) or  eye_mon_timeout(7) or  eye_mon_timeout(6) or  eye_mon_timeout(5) or  eye_mon_timeout(4) or  eye_mon_timeout(3) or 
                         eye_mon_timeout(2) or  eye_mon_timeout(1) or  eye_mon_timeout(0)  ;
  end if;
end process;

-- This FSM update the RX Data capture IDELAY values  
sgmii_phy_cal : Salt7SeriesCore_sgmii_phy_calibration 
port map  (
    clk104               => clk104, 
    rst                  => rx_rst, 
    enable_initial_cal   => enable_initial_cal, 
    o_initial_cal_done   => initial_cal_done, 
    o_enable_eye_mon     => enable_eye_mon, 
    eye_mon_done         => eye_mon_done, 
    o_eye_mon_done_fe    => eye_mon_done_fe,
    left_margin          => left_margin0, 
    right_margin         => right_margin0, 
    o_data_idelay_val    => data_dly_val_in0, 
    o_data_idelay_update => data_idly_update0 
    );

-- gearbox_4b_10b - Converts 4b @ 312.5 MHz to 10b @ 125 MHz.

process (clk104)
begin
  if (clk104'event and clk104 ='1') then
     if (initial_cal_done  = '1' and eye_mon_done_fe = "10" and (left_margin0 <= "00010" or right_margin0 <= "00010") ) then 
       bad_mon_trig <= '1';
     else 
       bad_mon_trig <= '0';
     end if;
  end if;
end process;

process (clk104)
begin
  if (clk104'event and clk104 ='1') then
    o_loss_of_sync <=  panic_bucket(3 ) and panic_bucket(2 ) and panic_bucket(1 ) and panic_bucket(0);
  end if;
end process;

-- *** Panic Bucket ***
-- This logic flags a high probability that the Strider stopped transmitting
-- Leaky Bucket that accumulates errors and slowly forgives them.  Errors include:
-- - 8b/10b code error bucket overflow has been detected
-- - Eye shrinking (bad_mon_trig) 
sync_block_code_error : Salt7SeriesCore_sync_block
port map
       (
          clk             => clk104 ,
          data_in         => code_error ,
          data_out        => code_error_r
       );


-- Leacky Bucket for 8b/10b code group errors
process (clk104)
begin
  if (clk104'event and clk104 ='1') then
    if (rx_rst = '1') then
      panic_bucket <= "0000";
    elsif  (code_error_r = '1' and bad_mon_trig = '1') then 
      if (panic_bucket = x"F") then 
        panic_bucket <= panic_bucket; 
      else 
        panic_bucket <= panic_bucket + '1';
      end if;
    elsif (eye_mon_done_fe = "10" and  code_error_r /= '1' ) then 
      if (panic_bucket = x"0") then 
        panic_bucket <= panic_bucket; 
      else 
        panic_bucket <= panic_bucket - '1';
      end if;
    else 
      panic_bucket <= panic_bucket;
    end if; 
  end if;
end process;

end xilinx ;
