--------------------------------------------------------------------------------
-- File       : Salt7SeriesCore_reset_sync.vhd
-- Author     : Xilinx Inc.
--------------------------------------------------------------------------------
-- Description: Both flip-flops have the same asynchronous reset signal.
--              Together the flops create a minimum of a 1 clock period
--              duration pulse which is used for synchronous reset.
--
--              The flops are placed, using RLOCs, into the same slice.
--------------------------------------------------------------------------------
-- (c) Copyright 2006-2008 Xilinx, Inc. All rights reserved.
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

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity Salt7SeriesCore_reset_sync is

  generic (INITIALISE : bit_vector(1 downto 0) := "11");
  port (
    reset_in    : in  std_logic;          -- Active high asynchronous reset
    clk         : in  std_logic;          -- clock to be sync'ed to
    reset_out   : out std_logic           -- "Synchronised" reset signal
    );

end Salt7SeriesCore_reset_sync;



architecture rtl of Salt7SeriesCore_reset_sync is
  signal reset_sync_reg1 : std_logic;
  signal reset_sync_reg2 : std_logic;
  signal reset_sync_reg3 : std_logic;
  signal reset_sync_reg4 : std_logic;
  signal reset_sync_reg5 : std_logic;

  -- These attributes will stop timing errors being reported in back annotated
  -- SDF simulation.
  attribute ASYNC_REG                       : string;
  attribute ASYNC_REG of reset_sync1        : label is "true";
  attribute ASYNC_REG of reset_sync2        : label is "true";
  attribute ASYNC_REG of reset_sync3        : label is "true";
  attribute ASYNC_REG of reset_sync4        : label is "true";
  attribute ASYNC_REG of reset_sync5        : label is "true";
  attribute ASYNC_REG of reset_sync6        : label is "true";

  -- These attributes will stop XST translating the desired flip-flops into an
  -- SRL based shift register.
  attribute shreg_extract                   : string;
  attribute shreg_extract of reset_sync1    : label is "no";
  attribute shreg_extract of reset_sync2    : label is "no";
  attribute shreg_extract of reset_sync3    : label is "no";
  attribute shreg_extract of reset_sync4    : label is "no";
  attribute shreg_extract of reset_sync5    : label is "no";
  attribute shreg_extract of reset_sync6    : label is "no";

begin

  reset_sync1 : FDP
  generic map (
    INIT => INITIALISE(0)
  )
  port map (
    C    => clk,
    PRE  => reset_in,
    D    => '0',
    Q    => reset_sync_reg1
  );

  reset_sync2 : FDP
  generic map (
    INIT => INITIALISE(1)
  )
  port map (
    C    => clk,
    PRE  => reset_in,
    D    => reset_sync_reg1,
    Q    => reset_sync_reg2
  );

  reset_sync3 : FDP
  generic map (
    INIT => INITIALISE(1)
  )
  port map (
    C    => clk,
    PRE  => reset_in,
    D    => reset_sync_reg2,
    Q    => reset_sync_reg3
  );

  reset_sync4 : FDP
  generic map (
    INIT => INITIALISE(1)
  )
  port map (
    C    => clk,
    PRE  => reset_in,
    D    => reset_sync_reg3,
    Q    => reset_sync_reg4
  );

  reset_sync5 : FDP
  generic map (
    INIT => INITIALISE(1)
  )
  port map (
    C    => clk,
    PRE  => reset_in,
    D    => reset_sync_reg4,
    Q    => reset_sync_reg5
  );

  reset_sync6 : FDP
  generic map (
    INIT => INITIALISE(1)
  )
  port map (
    C    => clk,
    PRE  => '0',
    D    => reset_sync_reg5,
    Q    => reset_out
  );


end rtl;
