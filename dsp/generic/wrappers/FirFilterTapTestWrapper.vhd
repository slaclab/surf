-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.FirFilterTap coverage.
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

entity FirFilterTapTestWrapper is
   port (
      clk     : in  sl;
      en      : in  sl;
      datain  : in  slv(5 downto 0);
      coeffin : in  slv(4 downto 0);
      coeffce : in  sl;
      cascin  : in  slv(11 downto 0);
      cascout : out slv(11 downto 0));
end entity FirFilterTapTestWrapper;

architecture rtl of FirFilterTapTestWrapper is

begin

   U_DUT : entity surf.FirFilterTap
      generic map (
         DATA_WIDTH_G  => 6,
         COEFF_WIDTH_G => 5,
         CASC_WIDTH_G  => 12,
         COEFF_INIT_G  => "00010")
      port map (
         clk     => clk,
         en      => en,
         datain  => datain,
         coeffin => coeffin,
         coeffce => coeffce,
         cascin  => cascin,
         cascout => cascout);

end architecture rtl;
