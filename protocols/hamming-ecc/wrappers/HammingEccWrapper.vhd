-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for the Hamming ECC encoder/decoder pair
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
use surf.HammingEccPkg.all;

entity HammingEccWrapper is
   generic (
      TPD_G        : time     := 1 ns;
      DATA_WIDTH_G : positive := 8);
   port (
      clk          : in  sl;
      rst          : in  sl;
      ibValid      : in  sl;
      ibData       : in  slv(DATA_WIDTH_G-1 downto 0);
      bitErrorMask : in  slv(hammingEccDataWidth(DATA_WIDTH_G) downto 0);
      obValid      : out sl;
      obData       : out slv(DATA_WIDTH_G-1 downto 0);
      obErrSbit    : out sl;
      obErrDbit    : out sl);
end entity HammingEccWrapper;

architecture rtl of HammingEccWrapper is

   constant ENC_WIDTH_C : positive := hammingEccDataWidth(DATA_WIDTH_G);

   signal encValid    : sl                        := '0';
   signal encData     : slv(ENC_WIDTH_C downto 0) := (others => '0');
   signal encDataMask : slv(ENC_WIDTH_C downto 0) := (others => '0');

begin

   encDataMask <= encData xor bitErrorMask;

   U_Encoder : entity surf.HammingEccEncoder
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => DATA_WIDTH_G)
      port map (
         clk     => clk,
         rst     => rst,
         ibValid => ibValid,
         ibData  => ibData,
         obValid => encValid,
         obData  => encData);

   U_Decoder : entity surf.HammingEccDecoder
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => DATA_WIDTH_G)
      port map (
         clk       => clk,
         rst       => rst,
         ibValid   => encValid,
         ibData    => encDataMask,
         obValid   => obValid,
         obData    => obData,
         obErrSbit => obErrSbit,
         obErrDbit => obErrDbit);

end architecture rtl;
