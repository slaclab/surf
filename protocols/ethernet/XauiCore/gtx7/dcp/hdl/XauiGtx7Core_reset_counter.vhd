-------------------------------------------------------------------------------
-- Title      : Reset Counter
-------------------------------------------------------------------------------
-- File       : XauiGtx7Core_reset_counter.vhd
-------------------------------------------------------------------------------
-- Description: This module counts for a minimum of 500ns after configuration,
--              then raises the 'done' flag. This is based on a worst case
--              200MHz Clock which is the maximum DRP frequency for Artix-7
--             (Higher than Kintex-7 and Virtex-7)
-------------------------------------------------------------------------------
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

entity XauiGtx7Core_reset_counter is
    port (
      clk              : in  std_logic;
      done             : out std_logic;
      initial_reset    : out std_logic
      );
end XauiGtx7Core_reset_counter;

architecture rtl of XauiGtx7Core_reset_counter is
  constant COUNT_WIDTH : integer := 8;

  signal count : unsigned (COUNT_WIDTH-1 downto 0) := (others => '0');
  signal count_d1 : std_logic := '0';

begin
  process(clk) begin
    if rising_edge(clk) then
      if (count(COUNT_WIDTH-1) = '0') then
        count <= count + 1;
      end if;
    end if;
  end process;

  process(clk) begin
    if rising_edge(clk) then
      count_d1 <= std_logic(count(COUNT_WIDTH -1));
    end if;
  end process;

  process(clk) begin
    if rising_edge(clk) then
      if ((count_d1 = '0') and (std_logic(count(COUNT_WIDTH-1)) = '1')) then
        initial_reset <= std_logic(count(COUNT_WIDTH -1));
      else
        initial_reset <= '0';
      end if;
    end if;
  end process;


  done <= std_logic(count(COUNT_WIDTH -1));

end rtl;
