-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.CRC7Rtl
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity CRC7RtlWrapper is
   port (
      clk       : in  sl;
      rst       : in  sl;
      dataIn    : in  slv(15 downto 0) := (others => '0');
      crcEn     : in  sl               := '0';
      crcOut    : out slv(7 downto 0);
      crcOutReg : out slv(7 downto 0));
end entity CRC7RtlWrapper;

architecture rtl of CRC7RtlWrapper is

begin

   U_DUT : entity surf.CRC7Rtl
      port map (
         rst       => rst,
         clk       => clk,
         data_in   => dataIn,
         crc_en    => crcEn,
         crc_out   => crcOut,
         crc_out_r => crcOutReg);

end architecture rtl;
