--------------------------------------------------------------------------------
-- Title      : 
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
-- File       : Salt7SeriesCore_sgmii_eye_monitor.vhd
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
-- Description:  This module monitors the N-node IDELAY to determine the margin of the current 
--  P-node (data) IDELAY tap value.    
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;

library unisim;
use unisim.vcomponents.all;

entity Salt7SeriesCore_sgmii_eye_monitor is
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
end Salt7SeriesCore_sgmii_eye_monitor;

architecture xilinx of Salt7SeriesCore_sgmii_eye_monitor is 
signal o_eye_mon_done_s : std_logic;
signal right_margin_s        : std_logic_vector(4 downto 0);
signal left_margin_s         : std_logic_vector(4 downto 0);
signal wait_cntr : std_logic_vector(11 downto 0);
signal cid_error : std_logic;       -- Too many continuous identical digits to be 8b/10b
signal mismatch_error : std_logic;  -- data != ~mon
signal data_bad : std_logic;        -- Sticky bit flagging that monitor and data don't vibe
signal old_em_state: std_logic_vector(9 downto 0);
signal mon_idly_val: std_logic_vector(4 downto 0);
signal mon_idly_update : std_logic;
signal em_state : std_logic_vector(9 downto 0);
signal tap_edge_error : std_logic;

constant RST_S           : std_logic_vector(9 downto 0) := "0000000001";
constant IDLE          : std_logic_vector(9 downto 0) := "0000000010";
constant DEC           : std_logic_vector(9 downto 0) := "0000000100";
constant WAIT_LEFT     : std_logic_vector(9 downto 0) := "0000001000";
constant CHECK_LEFT    : std_logic_vector(9 downto 0) := "0000010000";
constant SAVE_LEFT     : std_logic_vector(9 downto 0) := "0000100000";
constant INC           : std_logic_vector(9 downto 0) := "0001000000";
constant WAIT_RIGHT    : std_logic_vector(9 downto 0) := "0010000000";
constant CHECK_RIGHT   : std_logic_vector(9 downto 0) := "0100000000";
constant SAVE_RIGHT    : std_logic_vector(9 downto 0) := "1000000000";

begin

-- *** Eye Monitor FSM ***
process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if (rst = '1') then em_state <= RST_S;
     else 
       case em_state is 
       when RST_S =>
           em_state <= IDLE;
       when IDLE => 
           if (enable_eye_mon='1') then em_state <= DEC;
           else  em_state <= IDLE; end if;
       when DEC => 
           em_state <= WAIT_LEFT;
       when WAIT_LEFT => 
           if (wait_cntr = eye_mon_wait_time) then em_state <= CHECK_LEFT;
           else                             em_state <= WAIT_LEFT;
           end if;
       when CHECK_LEFT =>
           if (data_bad = '1') then  em_state <= SAVE_LEFT;
           else          em_state <= DEC;
           end if;
       when SAVE_LEFT =>
           em_state <= INC;
       when INC => 
           em_state <= WAIT_RIGHT;
       when WAIT_RIGHT =>
           if (wait_cntr = eye_mon_wait_time) then  em_state <= CHECK_RIGHT;
           else                              em_state <= WAIT_RIGHT;			
           end if;
       when CHECK_RIGHT => 
           if (data_bad = '1') then em_state <= SAVE_RIGHT;
           else          em_state <= INC;
           end if;
       when SAVE_RIGHT =>
           em_state <= IDLE;
       when others => 
           em_state <= RST_S; -- ERROR Condition
       end case;
     end if; -- end else
   end if;
end process;

process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if (em_state = RST_S or enable_eye_mon = '1') then o_eye_mon_done_s <= '0';
     elsif (em_state = SAVE_RIGHT) then o_eye_mon_done_s <= '1';
     else o_eye_mon_done_s <= o_eye_mon_done_s;
     end if;
   end if;
end process;
o_eye_mon_done <= o_eye_mon_done_s;
-- Register Updates

process (clk104)
begin
   if clk104'event and clk104 = '1' then
     old_em_state <= em_state;
   end if;
end process;

process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if (em_state /= WAIT_LEFT and em_state /= WAIT_RIGHT) then wait_cntr <= x"000";
     else wait_cntr <= wait_cntr + '1';
     end if;
   end if;
end process;
-- Manipulate and control MONITOR Idelay value.  
process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if (em_state = RST_S) then  mon_idly_val <= (others => '0');
     elsif (em_state = IDLE or em_state = SAVE_LEFT)    then mon_idly_val <= data_idelay_val;
     elsif (em_state = DEC and mon_idly_val /= "00000") then mon_idly_val <= mon_idly_val - '1';
     elsif (em_state = INC and mon_idly_val /= "11111") then mon_idly_val <= mon_idly_val + '1';
     else mon_idly_val <= mon_idly_val;
     end if;
   end if;
end process;

process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if ((em_state = WAIT_LEFT and old_em_state = DEC) or 
        (em_state = WAIT_RIGHT and old_em_state = INC) or 
        (em_state = IDLE and old_em_state = SAVE_RIGHT) ) then  mon_idly_update <= '1';
     else mon_idly_update <= '0';
     end if;
   end if;
end process;

 o_mon_idelay_val    <= mon_idly_val;
 o_mon_idelay_update <= mon_idly_update;
 left_margin         <= left_margin_s;
 right_margin        <= right_margin_s;
-- Update margin output register
process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if (em_state = RST_S)  then left_margin_s <= (others => '0');
     elsif (em_state = CHECK_LEFT and data_bad = '1') then left_margin_s <= data_idelay_val - mon_idly_val;
     else left_margin_s <= left_margin_s;
     end if;
   end if;
end process;

process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if (em_state = RST_S)  then right_margin_s <= (others => '0');
     elsif (em_state = CHECK_RIGHT and data_bad = '1') then right_margin_s <= mon_idly_val - data_idelay_val;
     else right_margin_s <= right_margin_s;
     end if;
   end if;
end process;
-- Determine if current monitor IDELAY value is sitting on a good tap or on a metastable tap.
process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if ( rst = '1' or (wait_cntr < x"00F") ) then  data_bad <= '0';
     elsif (cid_error = '1' or mismatch_error = '1' or tap_edge_error = '1') then data_bad <= '1';
     else data_bad <= data_bad;
     end if;
   end if;
end process;

tap_edge_error <=   '1' when ((mon_idly_val = "00000") or (mon_idly_val = "11111")) else '0';

process (clk104)
begin
   if clk104'event and clk104 = '1' then
     if (rx_data = x"000" or rx_data = x"FFF") then 
        cid_error <= '1';
     else 
        cid_error <= '0';
     end if;
     if (rx_data /= not rx_mon) then 
       mismatch_error <= '1' ;
     else 
       mismatch_error <= '0' ;
     end if;
   end if;
end process;

end xilinx;
