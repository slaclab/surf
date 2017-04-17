-------------------------------------------------------------------------------
-- File       : i2cRamSlave.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-01-24
-- Last update: 2013-01-28
-------------------------------------------------------------------------------
-- Description: Simulation testbed for i2cRamSlave
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.i2cPkg.all;

entity i2cRamSlave is
  
  generic (
    TPD_G : time := 1 ns;

    I2C_ADDR_G : integer range 0 to 1023 := 0;
    TENBIT_G   : integer range 0 to 1    := 0;
    FILTER_G   : integer range 2 to 512  := 4;

    ADDR_SIZE_G  : positive             := 2;
    DATA_SIZE_G  : positive             := 2;
    ENDIANNESS_G : integer range 0 to 1 := 0);

  port (
    clk    : in    sl;
    rst    : in    sl;
    i2cSda : inout sl;
    i2cScl : inout sl);

end entity i2cRamSlave;

architecture rtl of i2cRamSlave is

  type RamType is array (0 to 2**(8*ADDR_SIZE_G)-1) of slv(8*DATA_SIZE_G-1 downto 0);

  signal i2ci : i2c_in_type;
  signal i2co : i2c_out_type;

  signal ram    : RamType;
  signal addr   : slv(8*ADDR_SIZE_G-1 downto 0);
  signal wrEn   : sl;
  signal wrData : slv(8*DATA_SIZE_G-1 downto 0);
  signal rdEn   : sl;
  signal rdData : slv(8*DATA_SIZE_G-1 downto 0);

begin

  i2cRegSlave_1 : entity work.i2cRegSlave
    generic map (
      TENBIT_G             => TENBIT_G,
      I2C_ADDR_G           => I2C_ADDR_G,
      OUTPUT_EN_POLARITY_G => 0,
      FILTER_G             => FILTER_G,
      ADDR_SIZE_G          => ADDR_SIZE_G,
      DATA_SIZE_G          => DATA_SIZE_G,
      ENDIANNESS_G         => ENDIANNESS_G)
    port map (
      sRst    => rst,
      clk    => clk,
      addr   => addr,
      wrEn   => wrEn,
      wrData => wrData,
      rdEn   => rdEn,
      rdData => rdData,
      i2ci   => i2ci,
      i2co   => i2co);

  ram_proc : process (clk) is
  begin
    if (rising_edge(clk)) then
      if (wrEn = '1') then
        ram(to_integer(unsigned(addr))) <= wrData;
      end if;
    end if;
  end process ram_proc;
  rdData <= ram(to_integer(unsigned(addr)));

  i2cSda <= i2co.sda when i2co.sdaoen = '0' else 'Z';
  i2ci.sda <= i2cSda;

  i2cScl <= i2co.scl when i2co.scloen = '0' else 'Z';
  i2ci.scl <= i2cScl;

end architecture rtl;
