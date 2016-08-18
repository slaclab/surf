--------------------------------------------------------------------------------
-- Title      : Reset watch dog timer
-- File       : Salt7SeriesCore_reset_wtd_timer.vhd
-- Author     : Xilinx
--------------------------------------------------------------------------------
-- (c) Copyright 2011 Xilinx, Inc. All rights reserved.
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
-- 
-- 
--------------------------------------------------------------------------------
--  Description:  This logic describes a watch dog counter for 3 seconds.
--                If data valid is not received withing 3 seconds a reset is
--                asserted.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


------------------------------------------------------------------------------
--Entity declaration.
-----------------------------------------------------------------------------

entity Salt7SeriesCore_reset_wtd_timer is
  generic (
    WAIT_TIME  : std_logic_vector(23 downto 0) := x"8F0D18"
  );
  port (
    clk        : in  std_logic;    -- Input clock
    data_valid : in  std_logic;    -- Indication that data is received
    reset      : out std_logic     -- Reset on timer timeout
  );
end Salt7SeriesCore_reset_wtd_timer;

architecture rtl of Salt7SeriesCore_reset_wtd_timer is
   signal   counter_stg1        : std_logic_vector (5  downto 0) := (others => '0');
   signal   counter_stg2        : std_logic_vector (11 downto 0) := (others => '0');
   signal   counter_stg3        : std_logic_vector (11 downto 0) := (others => '0');
   signal   counter_stg1_roll   : std_logic;
   signal   counter_stg2_roll   : std_logic;
   signal   timer_reset         : std_logic;
   signal   three_sec_timeout   : std_logic;

 begin
   process (clk)
   begin
       if rising_edge(clk) then	   
           if ((data_valid = '1') OR (timer_reset = '1')) then
               counter_stg1 <= "000000";
          else
              if (data_valid = '0') then
                 counter_stg1 <= counter_stg1 + 1;
              end if;
          end if;
       end if;
   end process;
   
   counter_stg1_roll <= '1' when (counter_stg1 = "111111") else '0';

   process (clk)
   begin
       if rising_edge(clk) then	   
           if ((data_valid = '1') OR (timer_reset = '1')) then
               counter_stg2 <= "000000000000";
           else
               if ((data_valid = '0') AND (counter_stg1_roll = '1')) then
                   counter_stg2 <= counter_stg2 + 1;
               end if;
           end if;
       end if;
   end process;

   counter_stg2_roll <= '1' when (counter_stg2 = "111111111111") else '0';

   process (clk)
   begin
       if rising_edge(clk) then	   
           if ((data_valid = '1') OR (timer_reset = '1')) then
               counter_stg3 <= "000000000000";
           else
	       if ((data_valid = '0') AND (counter_stg2_roll = '1') AND (counter_stg1_roll = '1')) then
                   counter_stg3 <= counter_stg3 + 1;
               end if;
           end if;
       end if;
   end process;


   three_sec_timeout <= '1' when ((counter_stg3 = WAIT_TIME(23 downto 12)) AND (counter_stg2 = WAIT_TIME(11 downto 0))) else '0';
   timer_reset       <= '1' when ((counter_stg3 = WAIT_TIME(23 downto 12)) AND (counter_stg2 = WAIT_TIME(11 downto 0)) AND (counter_stg1 = x"3F")) else '0';

   process (clk)
   begin
       if rising_edge(clk) then	   
           if ((three_sec_timeout = '1') AND (counter_stg1(5) = '1')) then
               reset <= '1';
           else
               reset <= '0';
           end if;
       end if;
   end process;

end rtl;

