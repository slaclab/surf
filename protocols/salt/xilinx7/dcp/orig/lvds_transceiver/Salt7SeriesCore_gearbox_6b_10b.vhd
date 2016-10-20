--------------------------------------------------------------------------------
-- Title      : 
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
-- File       : Salt7SeriesCore_gearbox_6b_10b.vhd
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
-- Description:  RX Side - This module converts 6-bit @ 208 MHz to 10-bits @ 125 MHz.
--------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;

library unisim;
use unisim.vcomponents.all;



entity Salt7SeriesCore_gearbox_6b_10b is
port (

   reset        : in std_logic;
   clk208       : in std_logic;
   rxdata_6b    : in std_logic_vector(5 downto 0);
   
   bitslip      : in std_logic;
   clk125       : in std_logic;
   o_rxdata_10b : out std_logic_vector(9 downto 0)

);
end Salt7SeriesCore_gearbox_6b_10b;
architecture xilinx of Salt7SeriesCore_gearbox_6b_10b is 
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

signal reset_208 : std_logic;
signal accumulator_60b  : std_logic_vector(59 downto 0);
signal rxdata_6b_r      : std_logic_vector(5 downto 0);
signal bitslip_position : std_logic_vector(4 downto 0);

signal wr_ptr : std_logic_vector(3 downto 0); 
signal rd_ptr : std_logic_vector(2 downto 0);
signal rxdata_10b_r : std_logic_vector(19 downto 0);
begin

reset_sync_reset_208 : Salt7SeriesCore_reset_sync
port map(
   clk       => clk208,
   reset_in  => reset,
   reset_out => reset_208
);

process (clk208)
begin
  if clk208'event and clk208 ='1' then 
    rxdata_6b_r <= rxdata_6b; -- Register input of block for timing
  end if;
end process;

-- Step the Read Pointer
process (clk125)
begin
  if clk125'event and clk125 ='1' then 
    if (reset = '1') then 
      rd_ptr <= "000";
    elsif (rd_ptr = "101") then 
      rd_ptr <= "000";
    else   
      rd_ptr <= rd_ptr + '1';
    end if;
  end if;
end process;

-- Step the Write Pointer
process (clk208)
begin
  if clk208'event and clk208 ='1' then 
    if (reset_208 = '1' ) then wr_ptr <= x"0";
    elsif (wr_ptr = x"9") then wr_ptr <= x"0";
    else wr_ptr <= wr_ptr + '1';
    end if;
  end if;
end process;


-- Fill the accumulator (Write)
process (clk208)
begin
  if clk208'event and clk208 ='1' then 
    if (reset_208 = '1')  then 
      accumulator_60b <= (others => '0');
    elsif (wr_ptr = x"0")   then 
       accumulator_60b(5 downto  0 ) <= rxdata_6b_r;
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"1")  then 
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= rxdata_6b_r;
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"2")  then 
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= rxdata_6b_r;
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"3")  then 
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= rxdata_6b_r;
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"4")  then
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= rxdata_6b_r;
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"5")  then 
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= rxdata_6b_r;
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"6")  then 
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= rxdata_6b_r;   
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"7")  then 
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= rxdata_6b_r;   
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"8")  then 
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= rxdata_6b_r;   
       accumulator_60b(59 downto 54) <= accumulator_60b(59 downto 54);
    elsif (wr_ptr = x"9")  then 
       accumulator_60b(5 downto  0 ) <= accumulator_60b(5 downto  0 );
       accumulator_60b(11 downto 6 ) <= accumulator_60b(11 downto 6 );
       accumulator_60b(17 downto 12) <= accumulator_60b(17 downto 12);
       accumulator_60b(23 downto 18) <= accumulator_60b(23 downto 18);
       accumulator_60b(29 downto 24) <= accumulator_60b(29 downto 24);
       accumulator_60b(35 downto 30) <= accumulator_60b(35 downto 30);
       accumulator_60b(41 downto 36) <= accumulator_60b(41 downto 36);
       accumulator_60b(47 downto 42) <= accumulator_60b(47 downto 42);
       accumulator_60b(53 downto 48) <= accumulator_60b(53 downto 48);
       accumulator_60b(59 downto 54) <= rxdata_6b_r;   
    end if;
  end if;
end process;

-- Pull from the Accumulator (Read)

process (clk125)
begin
  if clk125'event and clk125 ='1' then 
    if (reset = '1') then rxdata_10b_r(19 downto 10) <= (others => '0');
    elsif (rd_ptr = "000") then rxdata_10b_r(19 downto 10) <= accumulator_60b(9 downto 0);
    elsif (rd_ptr = "001") then rxdata_10b_r(19 downto 10) <= accumulator_60b(19 downto 10);
    elsif (rd_ptr = "010") then rxdata_10b_r(19 downto 10) <= accumulator_60b(29 downto 20);
    elsif (rd_ptr = "011") then rxdata_10b_r(19 downto 10) <= accumulator_60b(39 downto 30);
    elsif (rd_ptr = "100") then rxdata_10b_r(19 downto 10) <= accumulator_60b(49 downto 40);
    elsif (rd_ptr = "101") then rxdata_10b_r(19 downto 10) <= accumulator_60b(59 downto 50);
    end if ;
  end if;
end process;

process (clk125)
begin
  if clk125'event and clk125 ='1' then
    rxdata_10b_r(9 downto 0) <= rxdata_10b_r(19 downto 10);
  end if;
end process;

-- Bitslip operation for comma alignment
process (clk125)
begin
  if clk125'event and clk125 ='1' then
    if (reset = '1') then 
      bitslip_position <= "10000";  -- change for simulation alignment
    elsif (bitslip = '1') then
      case bitslip_position is
        when "10001" =>
          bitslip_position <= "00000" ;
        when others => 
          bitslip_position <= bitslip_position + '1' ;
       end case;
    else 
      bitslip_position <= bitslip_position;
    end if;
  end if;
end process;

process (clk125)
begin
  if clk125'event and clk125 ='1' then
    if (reset = '1')  then                    o_rxdata_10b <= (others => '0');
    elsif (bitslip_position = "00000") then o_rxdata_10b <= rxdata_10b_r(9  downto 0);
    elsif (bitslip_position = "00001") then o_rxdata_10b <= rxdata_10b_r(10 downto 1);
    elsif (bitslip_position = "00010") then o_rxdata_10b <= rxdata_10b_r(11 downto 2);
    elsif (bitslip_position = "00011") then o_rxdata_10b <= rxdata_10b_r(12 downto 3);
    elsif (bitslip_position = "00100") then o_rxdata_10b <= rxdata_10b_r(13 downto 4);
    elsif (bitslip_position = "00101") then o_rxdata_10b <= rxdata_10b_r(14 downto 5);
    elsif (bitslip_position = "00110") then o_rxdata_10b <= rxdata_10b_r(15 downto 6);
    elsif (bitslip_position = "00111") then o_rxdata_10b <= rxdata_10b_r(16 downto 7);
    elsif (bitslip_position = "01000") then o_rxdata_10b <= rxdata_10b_r(17 downto 8);
    elsif (bitslip_position = "01001") then o_rxdata_10b <= rxdata_10b_r(18 downto 9);
    else o_rxdata_10b <= rxdata_10b_r(19 downto 10);
    end if;
  end if;
end process;

end xilinx;


