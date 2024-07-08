-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: ADS1217 package with constants
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

library surf;
use surf.StdRtlPkg.all;

package AxiAds1217Pkg is
  -- PGA values
  constant AXI_ADS1217_PGA_1_C    : slv(2 downto 0) := "000";
  constant AXI_ADS1217_PGA_2_C    : slv(2 downto 0) := "001";
  constant AXI_ADS1217_PGA_4_C    : slv(2 downto 0) := "010";
  constant AXI_ADS1217_PGA_8_C    : slv(2 downto 0) := "011";
  constant AXI_ADS1217_PGA_16_C   : slv(2 downto 0) := "100";
  constant AXI_ADS1217_PGA_32_C   : slv(2 downto 0) := "101";
  constant AXI_ADS1217_PGA_64_C   : slv(2 downto 0) := "110";
  constant AXI_ADS1217_PGA_128_C  : slv(2 downto 0) := "111";

  -- AIN channels
  constant AXI_ADS1217_AIN0_C     : slv(3 downto 0) := "0000";
  constant AXI_ADS1217_AIN1_C     : slv(3 downto 0) := "0001";
  constant AXI_ADS1217_AIN2_C     : slv(3 downto 0) := "0010";
  constant AXI_ADS1217_AIN3_C     : slv(3 downto 0) := "0011";
  constant AXI_ADS1217_AIN4_C     : slv(3 downto 0) := "0100";
  constant AXI_ADS1217_AIN5_C     : slv(3 downto 0) := "0101";
  constant AXI_ADS1217_AIN6_C     : slv(3 downto 0) := "0110";
  constant AXI_ADS1217_AIN7_C     : slv(3 downto 0) := "0111";
  constant AXI_ADS1217_AINCOM_C   : slv(3 downto 0) := "1000";
  constant AXI_ADS1217_TEMP_C     : slv(3 downto 0) := "1111";
  -- Default AIN channels using only the AIN pins
  constant AXI_ADS1217_AIN_PINS_DEFAULT_C : Slv4Array(7 downto 0) := (
    AXI_ADS1217_AIN7_C, AXI_ADS1217_AIN6_C, AXI_ADS1217_AIN5_C, AXI_ADS1217_AIN4_C,
    AXI_ADS1217_AIN3_C, AXI_ADS1217_AIN2_C, AXI_ADS1217_AIN1_C, AXI_ADS1217_AIN0_C
  );

  -- DIR values
  constant AXI_ADS1217_DIR_INPUT_C  : sl := '1';
  constant AXI_ADS1217_DIR_OUTPUT_C : sl := '0';

end package AxiAds1217Pkg;

package body AxiAds1217Pkg is
end package body AxiAds1217Pkg;
