--------------------------------------------------------------------------------
-- Title      : 
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
-- File       : Salt7SeriesCore_sgmii_phy_calibration.vhd
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
-- Description: This module uses the Eye_monitor block to determine the optimal RXD idelay
--  sample point.   
--------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;
USE STD.textio.ALL;
USE IEEE.std_logic_misc.ALL;
library unisim;
use unisim.vcomponents.all;

entity Salt7SeriesCore_sgmii_phy_calibration is 
port(
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
end Salt7SeriesCore_sgmii_phy_calibration;

architecture xilinx of Salt7SeriesCore_sgmii_phy_calibration is 

signal o_eye_mon_done_fe_s  : std_logic_vector(1 downto 0) ;
signal o_initial_cal_done_s : std_logic;
signal viable_tap_found : std_logic;
signal initial_cal_complete: std_logic;
signal best_tap : std_logic_vector(4 downto 0);
signal best_tap_window: std_logic_vector(4 downto 0);
signal current_tap: std_logic_vector(4 downto 0);
signal current_tap_window: std_logic_vector(4 downto 0);
signal maint_best_tap: std_logic_vector(4 downto 0);
signal cal_state: std_logic_vector(11 downto 0);

constant RST_S            : std_logic_vector(11 downto 0 ) := "000000000001";
constant SET_VAL        : std_logic_vector(11 downto 0 ) := "000000000010";
constant LOAD_VAL       : std_logic_vector(11 downto 0 ) := "000000000100";
constant WAIT_EYE_MON   : std_logic_vector(11 downto 0 ) := "000000001000";
constant INIT_CALC_EYE  : std_logic_vector(11 downto 0 ) := "000000010000";
constant INIT_COMPARE   : std_logic_vector(11 downto 0 ) := "000000100000";
constant INIT_INC       : std_logic_vector(11 downto 0 ) := "000001000000";
constant MAINT_BEGIN    : std_logic_vector(11 downto 0 ) := "000010000000";
constant MAINT_IDLE     : std_logic_vector(11 downto 0 ) := "000100000000";
constant MAINT_CALC_VAL : std_logic_vector(11 downto 0 ) := "001000000000";
constant MAINT_SET_VAL  : std_logic_vector(11 downto 0 ) := "010000000000";
constant MAINT_LOAD_VAL : std_logic_vector(11 downto 0 ) := "100000000000";

begin


-- *** Initial RX Data Calibration FSM ***
process (clk104)
begin
if clk104'event and clk104 = '1' then
   if (rst = '1') then cal_state <= RST_S;
   else 
      case cal_state is
      when RST_S => 
         if (enable_initial_cal = '1') then cal_state <= SET_VAL;
         else                    cal_state <= RST_S;
         end if;
      when SET_VAL => 
         cal_state <= LOAD_VAL;
      when LOAD_VAL => -- And Enable Eye Scan
         cal_state <= WAIT_EYE_MON;
      when WAIT_EYE_MON => 
         if (o_eye_mon_done_fe_s = "10" and initial_cal_complete = '1')       then cal_state <= MAINT_BEGIN;
         elsif (o_eye_mon_done_fe_s = "10" and initial_cal_complete /= '1') then cal_state <= INIT_CALC_EYE;
         else                                            cal_state <= WAIT_EYE_MON;
         end if;
-- * Initial part * 
      when INIT_CALC_EYE => 
         cal_state <= INIT_COMPARE;
      when INIT_COMPARE => 
         cal_state <= INIT_INC;
      when INIT_INC => 
         cal_state <= SET_VAL;
-- * Maintenance part * 
-- Needs to:
-- 1) Periodically update Capture taps by monitoring left and right margin.
--
      when MAINT_BEGIN => 
         if (current_tap /= best_tap) then cal_state <= SET_VAL;
         else cal_state <= MAINT_IDLE;
         end if ;
      when MAINT_IDLE =>
         if (o_eye_mon_done_fe_s = "10") then 
            if (left_margin = right_margin or 
                left_margin = right_margin + '1' or
                left_margin = right_margin - '1' ) then cal_state <= MAINT_IDLE;
            else cal_state <= MAINT_CALC_VAL;
            end if;
         else 
           cal_state <= MAINT_IDLE;
         end if;
      when MAINT_CALC_VAL =>
         cal_state <= MAINT_SET_VAL; 
      when MAINT_SET_VAL => 
         cal_state <= MAINT_LOAD_VAL; 
      when MAINT_LOAD_VAL =>
         cal_state <= MAINT_IDLE;
      when others => 
         cal_state <=  RST_S;
   end case;
end if ;-- end else
end if ;
end process;

process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if (rst = '1') then                       o_initial_cal_done_s <= '0'; 
     elsif (cal_state = MAINT_IDLE) then o_initial_cal_done_s <= '1';
     else                                o_initial_cal_done_s <= o_initial_cal_done_s;
     end if;
end if ;
end process;
o_initial_cal_done <= o_initial_cal_done_s;
-- current_tap
process (clk104)
begin
if clk104'event and clk104 = '1' then
   if (cal_state = RST_S) then current_tap <= "10001";
   elsif (cal_state = INIT_INC) then 
     if (current_tap = "10111") then 
       current_tap <= "01000";
     else 
       current_tap <= current_tap + '1';
     end if;
   elsif (cal_state = MAINT_BEGIN)  then current_tap <= best_tap;
   elsif (cal_state = MAINT_SET_VAL)then current_tap <= maint_best_tap;
   else current_tap <= current_tap;
   end if; 
end if ;
end process;

-- In maintenence mode, the best tap value is determined by Left/Right margin
process (clk104)
begin
if clk104'event and clk104 = '1' then
   if (cal_state = RST_S) then maint_best_tap <= (others => '0');
   elsif (cal_state = MAINT_CALC_VAL) then
      if (left_margin >= right_margin) then maint_best_tap <= current_tap - '1'; 
      else                             maint_best_tap <= current_tap + '1'; 
      end if;
   else 
      maint_best_tap <= maint_best_tap;
   end if;
end if ;
end process;

-- In Initialization mode, the best tap value is determined by Eye Width.
process (clk104)
begin
if clk104'event and clk104 = '1' then
   if (cal_state = RST_S or cal_state = LOAD_VAL) then current_tap_window <= "00000";
   elsif (cal_state = INIT_CALC_EYE) then
      if (right_margin <= left_margin) then current_tap_window <= right_margin;
      else current_tap_window <= left_margin;
      end if; 
   else current_tap_window <= current_tap_window;
   end if;
end if ;
end process;

process (clk104)
begin
if clk104'event and clk104 = '1' then
   if (cal_state = RST_S) then
      best_tap_window <= (others => '0');
      best_tap <= (others => '0');
   elsif ( (cal_state = INIT_COMPARE) and (current_tap_window > best_tap_window) ) then
      best_tap_window <= current_tap_window;
      best_tap <= current_tap;
   else 
      best_tap_window <= best_tap_window;
      best_tap <= best_tap;
   end if;
end if ;
end process;

-- Status updates for the State Machine
process (clk104)
begin
if clk104'event and clk104 = '1' then
   if (cal_state = RST_S) then viable_tap_found <= '0';
   elsif (cal_state = INIT_INC) then
     if  (best_tap_window > "00010") then
       viable_tap_found <= '1';
     else 
       viable_tap_found <= '0';
     end if;
   else viable_tap_found <= viable_tap_found;
   end if ;
end if ;
end process;

process (clk104)
begin
if clk104'event and clk104 = '1' then
   if (cal_state = RST_S) then initial_cal_complete <= '0';
   elsif (current_tap = "10110" and viable_tap_found = '1') then initial_cal_complete <= '1';
   else initial_cal_complete <= initial_cal_complete;
   end if;
end if ;
end process;

process (clk104)
begin
if clk104'event and clk104 = '1' then
   if (cal_state = RST_S) then o_eye_mon_done_fe_s <= "00";
   else  
      o_eye_mon_done_fe_s(0)  <= eye_mon_done;
      o_eye_mon_done_fe_s(1)  <= o_eye_mon_done_fe_s(0);
   end if;
end if ;
end process;

o_eye_mon_done_fe  <= o_eye_mon_done_fe_s;
process (clk104)
begin
if clk104'event and clk104 = '1' then
  if (cal_state = LOAD_VAL) or (cal_state = MAINT_LOAD_VAL) then 
    o_data_idelay_update <=  '1';--(cal_state = LOAD_VAL) or (cal_state = MAINT_LOAD_VAL) ;
  else 
    o_data_idelay_update <= '0';
  end if;
end if ;
end process;

o_data_idelay_val <= current_tap;
o_enable_eye_mon  <= '1' when ( cal_state = LOAD_VAL ) else '0';

end xilinx;

