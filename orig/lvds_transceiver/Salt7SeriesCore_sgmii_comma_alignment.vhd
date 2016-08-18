--------------------------------------------------------------------------------
-- Title      : 
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
-- File       : Salt7SeriesCore_sgmii_comma_alignment.vhd
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
-- Description: Accepts the input stream (10 bit unaligned data obtained from
--              the DRU).  This module will detect for the presence of comma
--              characters in this data stream, and will produce the bitslip
--              control signal: this is connected to the bitslip input of the
--              DRU and the effect will be to shift the comma to occur in the
--              correct position, to obtain correct 10-bit alignment.


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;
USE IEEE.std_logic_misc.ALL;

library unisim;
use unisim.vcomponents.all;

--------------------------------------------------------------------------------
-- Module declaration.
--------------------------------------------------------------------------------

entity Salt7SeriesCore_sgmii_comma_alignment is
port (
    clk         : in std_logic;
    reset       : in std_logic;
    clken       : in std_logic;
    enablealign : in std_logic;

    data_in     : in std_logic_vector(9 downto 0);
    comma_det   : out std_logic;
    bitslip     : out std_logic
);
end Salt7SeriesCore_sgmii_comma_alignment;

architecture xilinx of Salt7SeriesCore_sgmii_comma_alignment is

   attribute DowngradeIPIdentifiedWarnings: string;
   attribute DowngradeIPIdentifiedWarnings of xilinx : architecture is "yes";

  ------------------------------------------------------------------------------
  -- Signal declarations
  ------------------------------------------------------------------------------

 signal    comma_position     : std_logic_vector(9 downto 0);
 signal    data_reg           : std_logic_vector(9 downto 0);
 signal    timer              : std_logic_vector(4 downto 0);
 signal    bitslip_s        : std_logic;
 signal    enablealign_r      : std_logic;
begin 
  ------------------------------------------------------------------------------
  -- Comma Detection comparators
  ------------------------------------------------------------------------------


  -- register the input data for comparator pipelining
process (clk)
begin
   if clk'event and clk = '1' then
    if (reset = '1') then
      data_reg    <= "0000000000";
    elsif (clken = '1') then 
        data_reg  <= data_in;
    end if;
  end if;
end process;


  -- Detect a comma in the correct position of the data_in word
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  ----------  |  0011111--- | -ve comma
  -- |  ----------  |  1100000--- | +ve comma
  -- |----------------------------|
  comma_position(0) <= '1' when (data_in(9 downto 3) = "0011111" or data_in(9 downto 3) = "1100000") else '0';


  -- Detect a comma which is slipped by 1 bit from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  ---------0  |  011111---- | -ve comma
  -- |  ---------1  |  100000---- | +ve comma
  -- |----------------------------|
  comma_position(1) <= '1' when ((data_reg(0)& data_in(9 downto 4)) = "0011111" or  (data_reg(0) & data_in(9 downto 4)) = "1100000") else '0';


  -- Detect a comma which is slipped by 2 bits from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  --------00  |  11111----- | -ve comma
  -- |  --------11  |  10000----- | +ve comma
  -- |----------------------------|
   comma_position(2) <= '1' when
       ((data_reg(1 downto 0) & data_in(9 downto 5)) = "0011111" or
        (data_reg(1 downto 0) & data_in(9 downto 5)) = "1100000") else '0';


  -- Detect a comma which is slipped by 3 bits from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  -------001  |  1111------ | -ve comma
  -- |  -------110  |  1000------ | +ve comma
  -- |----------------------------|
   comma_position(3) <= '1' when 
       ((data_reg(2 downto 0) & data_in(9 downto 6)) = "0011111" or
        (data_reg(2 downto 0) & data_in(9 downto 6)) = "1100000") else '0';


  -- Detect a comma which is slipped by 4 bits from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  ------0011  |  111------- | -ve comma
  -- |  ------1100  |  100------- | +ve comma
  -- |----------------------------|
   comma_position(4) <= '1' when 
       ((data_reg(3 downto 0) & data_in(9 downto 7)) = "0011111" or
        (data_reg(3 downto 0) & data_in(9 downto 7)) = "1100000") else '0';


  -- Detect a comma which is slipped by 5 bits from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  -----00111  |  11-------- | -ve comma
  -- |  -----11000  |  10-------- | +ve comma
  -- |----------------------------|
   comma_position(5) <= '1' when
       ((data_reg(4 downto 0) & data_in(9 downto 8)) = "0011111" or
        (data_reg(4 downto 0) & data_in(9 downto 8)) = "1100000") else '0';


  -- Detect a comma which is slipped by 6 bits from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  ----001111  |  1--------- | -ve comma
  -- |  ----110000  |  1--------- | +ve comma
  -- |----------------------------|
   comma_position(6) <= '1' when
       ((data_reg(5 downto 0) & data_in(9)) = "0011111" or
        (data_reg(5 downto 0) & data_in(9)) = "1100000") else '0';


  -- Detect a comma which is slipped by 7 bits from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  ---0011111  |  ---------- | -ve comma
  -- |  ---1100000  |  ---------- | +ve comma
  -- |----------------------------|
   comma_position(7) <= '1' when
       (data_in(6 downto 0) = "0011111" or
        data_in(6 downto 0) = "1100000") else '0';


  -- Detect a comma which is slipped by 8 bits from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  --0011111-  |  ---------- | -ve comma
  -- |  --1100000-  |  ---------- | +ve comma
  -- |----------------------------|
   comma_position(8) <= '1' when
       (data_in(7 downto 1) = "0011111" or
        data_in(7 downto 1) = "1100000") else '0';


  -- Detect a comma which is slipped by 9 bits from the correct position
  -- |----------------------------|
  -- |   data_reg   |   data_in   |
  -- |----------------------------|
  -- |  -0011111--  |  ---------- | -ve comma
  -- |  -1100000--  |  ---------- | +ve comma
  -- |----------------------------|
   comma_position(9) <= '1' when
       (data_in(8 downto 2) = "0011111" or
        data_in(8 downto 2) = "1100000") else '0';


process (clk)
begin
if clk'event and clk = '1' then
  enablealign_r <= enablealign;
end if;
end process;

process (clk)
begin
if clk'event and clk = '1' then
   if ( reset = '1' ) then bitslip_s <= '0';
   elsif ( enablealign_r = '1' and comma_position(9 downto 1) /= "000000000" and  timer = "11111" ) then  bitslip_s <= '1';
   else bitslip_s <= '0';
   end if;
end if;
end process;
bitslip <= bitslip_s;
process (clk)
begin
if clk'event and clk = '1' then
   if (reset = '1')  then      timer <= (others => '0');
   elsif (bitslip_s = '1') then timer <= (others => '0');
   else   
     if timer = "11111" then 
       timer <= timer;
     else 
       timer <=timer + '1';
     end if;           
   end if;
end if;
end process;

process (clk)
begin
if clk'event and clk = '1' then
   if ( reset = '1' ) then comma_det <= '0';
   elsif ( comma_position(0) = '1' ) then comma_det <= '1';
   else comma_det <= '0';
   end if;
end if;
end process;


end xilinx;
