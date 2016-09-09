--------------------------------------------------------------------------------
-- File       : Salt7SeriesCore_johnson_cntr.vhd
-- Author     : Xilinx Inc.
--------------------------------------------------------------------------------
-- (c) Copyright 2004-2008 Xilinx, Inc. All rights reserved.
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
-- Description:  This logic describes a standard johnson counter to
--               create divided down clocks.  A divide by 10 clock is
--               created.
--
--               The capabilities of this Johnson counter are extended
--               with the use of the clock enables - it is only the
--               clock-enabled cycles which are divided down.
--
--               The divide by 10 clock is output directly from a rising
--               edge triggered flip-flop (clocked on the input clk).



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity Salt7SeriesCore_johnson_cntr is

  port (
    reset             : in  std_logic;      -- Synchronous Reset
    clk               : in  std_logic;      -- Input clock
    clk_en            : in std_logic;       -- Clock enable for rising edge triggered flip flops
    clk_div10         : out std_logic       -- (Clock, gated with clock enable) divide by 10
    );

end Salt7SeriesCore_johnson_cntr;


architecture rtl  of Salt7SeriesCore_johnson_cntr is


  signal reg1         : std_logic;          -- first flip flop
  signal reg2         : std_logic;          -- second flip flop
  signal reg3         : std_logic;          -- third flip flop
  signal reg4         : std_logic;          -- fourth flip flop
  signal reg5         : std_logic;          -- fifth flip flop



begin



  -- Create a 5-stage shift register
  reg_gen: process (clk)
  begin
    if clk'event and clk = '1' then
      if reset = '1' then
        reg1    <= '0';
        reg2    <= '0';
        reg3    <= '0';
        reg4    <= '0';
        reg5    <= '0';
      elsif clk_en = '1' then
         if reg5 = '1' and reg4 = '0' then  -- ensure that LFSR self corrects on every repetition
           reg1    <= '0';
           reg2    <= '0';
           reg3    <= '0';
           reg4    <= '0';
           reg5    <= '0';
         else
           reg1    <= not reg5;
           reg2    <= reg1;
           reg3    <= reg2;
           reg4    <= reg3;
           reg5    <= reg4;
         end if;
      end if;
    end if;
  end process reg_gen;



  -- The 5-stage shift register causes reg3 to toggle every 5 clock
  -- enabled cycles, effectively creating a divide by 10 clock
  clk_div10 <= reg3;



end rtl;

