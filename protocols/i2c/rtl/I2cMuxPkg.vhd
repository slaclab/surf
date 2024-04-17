-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: I2C Multiplexer VHDL Package
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
use surf.I2cPkg.all;

package I2cMuxPkg is

   constant I2C_MUX_DECODE_MAP_TCA9548_C : Slv8Array(7 downto 0) := (
      0 => b"0000_0001",
      1 => b"0000_0010",
      2 => b"0000_0100",
      3 => b"0000_1000",
      4 => b"0001_0000",
      5 => b"0010_0000",
      6 => b"0100_0000",
      7 => b"1000_0000");

   constant I2C_MUX_DECODE_MAP_PCA9547_C : Slv8Array(7 downto 0) := (
      0 => b"0000_1000",
      1 => b"0000_1001",
      2 => b"0000_1010",
      3 => b"0000_1011",
      4 => b"0000_1100",
      5 => b"0000_1101",
      6 => b"0000_1110",
      7 => b"0000_1111");

   constant I2C_MUX_DECODE_MAP_PCA9544A_C : Slv8Array(3 downto 0) := (
      0 => b"0000_0100",
      1 => b"0000_0101",
      2 => b"0000_0110",
      3 => b"0000_0111");

   constant I2C_MUX_DECODE_MAP_PCA9546A_C : Slv8Array(3 downto 0) := (
      0 => b"0000_0001",
      1 => b"0000_0010",
      2 => b"0000_0100",
      3 => b"0000_1000");

   constant I2C_MUX_DECODE_MAP_PCA9540B_C : Slv8Array(1 downto 0) := (
      0 => b"0000_0100",
      1 => b"0000_0101");

end;

package body I2cMuxPkg is



end package body I2cMuxPkg;
