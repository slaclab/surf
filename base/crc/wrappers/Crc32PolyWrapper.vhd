-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Test-only wrapper for cocotb regression that converts an
--              integer generic into the `slv(31 downto 0)` CRC polynomial
--              because the local GHDL flow rejects direct command-line
--              overrides of the `CRC_POLY_G` vector generic.
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

entity Crc32PolyWrapper is
   generic (
      TPD_G            : time             := 1 ns;
      RST_POLARITY_G   : sl               := '1';
      RST_ASYNC_G      : boolean          := false;
      BYTE_WIDTH_G     : positive         := 4;
      INPUT_REGISTER_G : boolean          := true;
      CRC_INIT_G       : slv(31 downto 0) := x"FFFFFFFF";
      CRC_POLY_INT_G   : integer          := 16#04C11DB7#);
   port (
      crcClk       : in  sl;
      crcDataValid : in  sl;
      crcDataWidth : in  slv(2 downto 0);
      crcIn        : in  slv((BYTE_WIDTH_G*8)-1 downto 0);
      crcReset     : in  sl;
      crcInit      : in  slv(31 downto 0);
      crcOut       : out slv(31 downto 0);
      crcRem       : out slv(31 downto 0);
      crcPwrOnRst  : in  sl);
end entity Crc32PolyWrapper;

architecture rtl of Crc32PolyWrapper is

   constant CRC_POLY_C : slv(31 downto 0) := toSlv(CRC_POLY_INT_G, 32);

begin

   U_DUT : entity surf.Crc32
      generic map (
         TPD_G            => TPD_G,
         RST_POLARITY_G   => RST_POLARITY_G,
         RST_ASYNC_G      => RST_ASYNC_G,
         BYTE_WIDTH_G     => BYTE_WIDTH_G,
         INPUT_REGISTER_G => INPUT_REGISTER_G,
         CRC_INIT_G       => CRC_INIT_G,
         CRC_POLY_G       => CRC_POLY_C)
      port map (
         crcClk       => crcClk,
         crcDataValid => crcDataValid,
         crcDataWidth => crcDataWidth,
         crcIn        => crcIn,
         crcReset     => crcReset,
         crcInit      => crcInit,
         crcOut       => crcOut,
         crcRem       => crcRem,
         crcPwrOnRst  => crcPwrOnRst);

end architecture rtl;
