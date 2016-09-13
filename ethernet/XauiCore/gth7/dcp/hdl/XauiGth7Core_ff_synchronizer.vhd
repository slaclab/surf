-------------------------------------------------------------------------------
-- Title      : FF Synchronizer
-- Project    : XAUI
-------------------------------------------------------------------------------
-- File       : XauiGth7Core_ff_synchronizer.vhd
-------------------------------------------------------------------------------
-- Description: This module provides a FF Synchronizer
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

entity XauiGth7Core_ff_synchronizer is
    generic (
      C_NUM_SYNC_REGS  : integer := 3
    );
    port (
      clk              : in  std_logic;
      data_in          : in  std_logic;
      data_out         : out std_logic
      );
end XauiGth7Core_ff_synchronizer;

architecture rtl of XauiGth7Core_ff_synchronizer is
  signal sync1_r : std_logic_vector(C_NUM_SYNC_REGS -1 downto 0) := (others => '0');

  --ASYNC_REG attributes
  attribute ASYNC_REG : string;
  attribute shreg_extract : string;
  attribute ASYNC_REG of sync1_r        : signal is "TRUE";
  attribute shreg_extract of sync1_r    : signal is "no";

begin
  process(clk) begin
    if rising_edge(clk) then
      sync1_r <= sync1_r(C_NUM_SYNC_REGS - 2 downto 0) & data_in;
    end if;
  end process;

  data_out <= sync1_r(C_NUM_SYNC_REGS - 1);
end rtl;
