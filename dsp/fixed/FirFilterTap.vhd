-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Using Transpose Multiply-Accumulate for FIR engine stage
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

library surf;
use surf.StdRtlPkg.all;

entity FirFilterTap is
   generic (
      TPD_G         : time      := 1 ns;
      DATA_WIDTH_G  : positive  := 12;
      COEFF_WIDTH_G : positive  := 12;
      CASC_WIDTH_G  : positive  := 25);
   port (
      -- Clock Only (Infer into DSP)
      clk     : in  sl;
      en      : in  sl := '1';
      -- Data and tap coefficient Interface
      datain  : in  slv(DATA_WIDTH_G-1 downto 0);
      coeffin : in  slv(COEFF_WIDTH_G-1 downto 0);
      -- Cascade Interface
      cascin  : in  slv(CASC_WIDTH_G-1 downto 0);
      cascout : out slv(CASC_WIDTH_G-1 downto 0));
end FirFilterTap;

architecture rtl of FirFilterTap is

   constant PROD_WIDTH_C : integer := DATA_WIDTH_G + COEFF_WIDTH_G;

   type RegType is record
      accum : signed(CASC_WIDTH_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      accum => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (cascin, coeffin, datain, r) is
      variable v       : RegType;
      variable din     : signed(DATA_WIDTH_G-1 downto 0);
      variable coeff   : signed(COEFF_WIDTH_G-1 downto 0);
      variable product : signed(PROD_WIDTH_C-1 downto 0);
      variable cascade : signed(CASC_WIDTH_G-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- typecast from slv to signed
      din     := signed(datain);
      coeff   := signed(coeffin);
      cascade := signed(cascin);

      -- Multiplier
      product := din * coeff;

      -- Accumulator
      v.accum := resize(product, PROD_WIDTH_C) + cascade;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      cascout <= std_logic_vector(r.accum);

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         if (en = '1') then
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end rtl;
