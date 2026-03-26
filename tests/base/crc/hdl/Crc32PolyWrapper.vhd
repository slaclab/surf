-------------------------------------------------------------------------------
-- Test-only wrapper for cocotb regression.
--
-- GHDL accepts integer generic overrides reliably from the command line, but
-- direct overrides of a 32-bit `slv` generic were failing during elaboration.
-- This wrapper keeps the external port list identical to `surf.Crc32` and
-- converts an integer generic into the `slv(31 downto 0)` polynomial that the
-- real RTL expects internally.
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
      crcPwrOnRst  : in  sl               := not RST_POLARITY_G;
      crcOut       : out slv(31 downto 0);
      crcRem       : out slv(31 downto 0);
      crcClk       : in  sl;
      crcDataValid : in  sl;
      crcDataWidth : in  slv(2 downto 0);
      crcIn        : in  slv((BYTE_WIDTH_G*8-1) downto 0);
      crcInit      : in  slv(31 downto 0) := CRC_INIT_G;
      crcReset     : in  sl);
end entity Crc32PolyWrapper;

architecture rtl of Crc32PolyWrapper is

begin

   U_CRC : entity surf.Crc32
      generic map (
         TPD_G            => TPD_G,
         RST_POLARITY_G   => RST_POLARITY_G,
         RST_ASYNC_G      => RST_ASYNC_G,
         BYTE_WIDTH_G     => BYTE_WIDTH_G,
         INPUT_REGISTER_G => INPUT_REGISTER_G,
         CRC_INIT_G       => CRC_INIT_G,
         CRC_POLY_G       => toSlv(CRC_POLY_INT_G, 32))
      port map (
         crcPwrOnRst  => crcPwrOnRst,
         crcOut       => crcOut,
         crcRem       => crcRem,
         crcClk       => crcClk,
         crcDataValid => crcDataValid,
         crcDataWidth => crcDataWidth,
         crcIn        => crcIn,
         crcInit      => crcInit,
         crcReset     => crcReset);

end architecture rtl;
