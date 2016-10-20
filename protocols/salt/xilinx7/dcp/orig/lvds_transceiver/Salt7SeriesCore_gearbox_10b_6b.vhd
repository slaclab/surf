--------------------------------------------------------------------------------
-- Title      : 
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
-- File       : Salt7SeriesCore_gearbox_10b_6b.vhd
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
-- Description:  TX Side - This module converts 10-bit @ 125 MHz to 6-bits @ 208 MHz.
--------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;

library unisim;
use unisim.vcomponents.all;

entity Salt7SeriesCore_gearbox_10b_6b is
port (
   reset : in std_logic;
   clk125 : in std_logic;
   txdata_10b : in std_logic_vector(9 downto 0);
   
   clk208 :in std_logic;
   o_txdata_6b : out std_logic_vector(5 downto 0)

);
end Salt7SeriesCore_gearbox_10b_6b;

architecture xilinx of Salt7SeriesCore_gearbox_10b_6b is 
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
signal reset_125 : std_logic;
signal accumulator_60b  : std_logic_vector(59 downto 0);
signal txdata_10b_r : std_logic_vector(9 downto 0);
signal wr_ptr : std_logic_vector(2 downto 0); 
--signal wr_ptr : unsigned(2 downto 0); 
signal rd_ptr  : std_logic_vector(3 downto 0);

begin

reset_sync_reset_208 : Salt7SeriesCore_reset_sync
port map(
   clk       => clk208,
   reset_in  => reset,
   reset_out => reset_208
);


process (clk125)
begin
  if clk125'event and clk125 ='1' then
    txdata_10b_r <= txdata_10b; --Register input of block for timing
  end if;
end process;

-- Step the Write Pointer
process (clk125)
begin
  if clk125'event and clk125 ='1' then
    if (reset ='1' ) then 
      wr_ptr <= "000";
    elsif (wr_ptr = "101") then 
      wr_ptr <= "000";
    else 
      wr_ptr <= wr_ptr + 1;
    end if ;
  end if;
end process;


-- Step the Read Pointer
process (clk208)
begin
  if clk208'event and clk208 ='1' then
    if (reset_208 ='1' ) then
      rd_ptr <= x"0";
    elsif (rd_ptr = x"9") then
      rd_ptr <= x"0";
    else 
      rd_ptr <= rd_ptr + '1';
    end if;
  end if;
end process;


-- Fill the accumulator (Write)
process (clk125)
begin
  if clk125'event and clk125 ='1' then
    if (reset ='1' ) then 
      accumulator_60b <= (others => '0');
    elsif (wr_ptr = "000") then   
       accumulator_60b  (9 downto 0) <= txdata_10b_r;
       accumulator_60b(19 downto 10) <= accumulator_60b(19 downto 10);
       accumulator_60b(29 downto 20) <= accumulator_60b(29 downto 20);
       accumulator_60b(39 downto 30) <= accumulator_60b(39 downto 30);
       accumulator_60b(49 downto 40) <= accumulator_60b(49 downto 40);
       accumulator_60b(59 downto 50) <= accumulator_60b(59 downto 50);
    elsif (wr_ptr = "001") then   
       accumulator_60b  (9 downto 0) <= accumulator_60b  (9 downto 0);
       accumulator_60b(19 downto 10) <= txdata_10b_r;  
       accumulator_60b(29 downto 20) <= accumulator_60b(29 downto 20);
       accumulator_60b(39 downto 30) <= accumulator_60b(39 downto 30);
       accumulator_60b(49 downto 40) <= accumulator_60b(49 downto 40);
       accumulator_60b(59 downto 50) <= accumulator_60b(59 downto 50);
    elsif (wr_ptr = "010") then  
       accumulator_60b  (9 downto 0) <= accumulator_60b  (9 downto 0);
       accumulator_60b(19 downto 10) <= accumulator_60b(19 downto 10);
       accumulator_60b(29 downto 20) <= txdata_10b_r;  
       accumulator_60b(39 downto 30) <= accumulator_60b(39 downto 30);
       accumulator_60b(49 downto 40) <= accumulator_60b(49 downto 40);
       accumulator_60b(59 downto 50) <= accumulator_60b(59 downto 50);
    elsif (wr_ptr = "011") then   
       accumulator_60b  (9 downto 0) <= accumulator_60b  (9 downto 0);
       accumulator_60b(19 downto 10) <= accumulator_60b(19 downto 10);
       accumulator_60b(29 downto 20) <= accumulator_60b(29 downto 20);
       accumulator_60b(39 downto 30) <= txdata_10b_r;  
       accumulator_60b(49 downto 40) <= accumulator_60b(49 downto 40);
       accumulator_60b(59 downto 50) <= accumulator_60b(59 downto 50);
    elsif (wr_ptr = "100") then   
       accumulator_60b  (9 downto 0) <= accumulator_60b (9 downto 0);
       accumulator_60b(19 downto 10) <= accumulator_60b(19 downto 10);
       accumulator_60b(29 downto 20) <= accumulator_60b(29 downto 20);
       accumulator_60b(39 downto 30) <= accumulator_60b(39 downto 30);
       accumulator_60b(49 downto 40) <= txdata_10b_r;
       accumulator_60b(59 downto 50) <= accumulator_60b(59 downto 50);
    elsif (wr_ptr = "101") then   
       accumulator_60b  (9 downto 0)  <= accumulator_60b  (9 downto 0);
       accumulator_60b(19 downto 10)  <= accumulator_60b(19 downto 10);
       accumulator_60b(29 downto 20)  <= accumulator_60b(29 downto 20);
       accumulator_60b(39 downto 30)  <= accumulator_60b(39 downto 30);
       accumulator_60b(49 downto 40)  <= accumulator_60b(49 downto 40);
       accumulator_60b(59 downto 50) <= txdata_10b_r;   
    end if;
  end if;
end process;

-- Pull from the Accumulator (Read)
process (clk208)
begin
  if clk208'event and clk208 ='1' then
   if (reset_208 = '1' ) then  o_txdata_6b <= (others => '0');
   elsif (rd_ptr = "0000") then  o_txdata_6b <= accumulator_60b(5 downto 0) ;
   elsif (rd_ptr = "0001") then  o_txdata_6b <= accumulator_60b(11 downto 6);
   elsif (rd_ptr = "0010") then  o_txdata_6b <= accumulator_60b(17 downto 12);
   elsif (rd_ptr = "0011") then  o_txdata_6b <= accumulator_60b(23 downto 18);
   elsif (rd_ptr = "0100") then  o_txdata_6b <= accumulator_60b(29 downto 24);
   elsif (rd_ptr = "0101") then  o_txdata_6b <= accumulator_60b(35 downto 30);
   elsif (rd_ptr = "0110") then  o_txdata_6b <= accumulator_60b(41 downto 36);
   elsif (rd_ptr = "0111") then  o_txdata_6b <= accumulator_60b(47 downto 42);
   elsif (rd_ptr = "1000") then  o_txdata_6b <= accumulator_60b(53 downto 48);
   elsif (rd_ptr = "1001") then  o_txdata_6b <= accumulator_60b(59 downto 54);
   end if;
  end if;
end process;


end xilinx;













