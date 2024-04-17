-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: General Purpose MUX designed.
--       Useful if you want "All the LUTs in a slice can be combined
--       together as a 32:1 MUX in one level of logic." (UG574, v1.5, page7)
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
use IEEE.NUMERIC_STD.all;

library surf;
use surf.StdRtlPkg.all;

entity Mux is
   generic(
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean  := false;
      REG_DIN_G      : boolean  := true;
      REG_SEL_G      : boolean  := true;
      REG_DOUT_G     : boolean  := true;
      SEL_WIDTH_G    : positive := 5);
   port(
      clk  : in  sl;
      rst  : in  sl := not(RST_POLARITY_G);
      sel  : in  slv(SEL_WIDTH_G-1 downto 0);
      din  : in  slv(2**SEL_WIDTH_G-1 downto 0);
      dout : out sl);
end Mux;

architecture rtl of Mux is

   type RegType is record
      sel  : unsigned(SEL_WIDTH_G-1 downto 0);
      din  : slv(2**SEL_WIDTH_G-1 downto 0);
      dout : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (
      sel  => (others => '0'),
      din  => (others => '0'),
      dout => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (din, r, rst, sel) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Register input
      v.din := din;

      -- typecast from slv to unsigned
      v.sel := unsigned(sel);

      -- MUX
      if (REG_DIN_G = true) and (REG_SEL_G = true) then
         v.dout := r.din(to_integer(r.sel));

      elsif (REG_DIN_G = true) and (REG_SEL_G = false) then
         v.dout := r.din(to_integer(v.sel));

      elsif (REG_DIN_G = false) and (REG_SEL_G = true) then
         v.dout := v.din(to_integer(r.sel));

      else  -- (REG_DIN_G=false) and (REG_SEL_G=false)
         v.dout := v.din(to_integer(v.sel));
      end if;

      -- Outputs
      if REG_DOUT_G then
         dout <= r.dout;
      else
         dout <= v.dout;
      end if;

      -- Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
