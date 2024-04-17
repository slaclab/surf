-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Manual instantiation of RAM64X1S, RAM128X1S or RAM256X1S for
--              LUT based delays
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
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;

entity LutFixedDelay is
   generic (
      TPD_G        : time                    := 1 ns;
      XIL_DEVICE_G : string                  := "ULTRASCALE_PLUS";
      DELAY_G      : natural range 33 to 513 := 256;  -- default number of clock cycle delays
      WIDTH_G      : positive                := 16);
   port (
      clk  : in  sl;
      din  : in  slv(WIDTH_G-1 downto 0);
      dout : out slv(WIDTH_G-1 downto 0));
end entity LutFixedDelay;

architecture rtl of LutFixedDelay is

   constant DELAY_C     : integer := DELAY_G - 1;
   constant ADDR_BITS_C : integer := log2(DELAY_C);

   type RegType is record
      addr : unsigned(ADDR_BITS_C - 1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      addr => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal q : slv(WIDTH_G - 1 downto 0) := (others => '0');

   signal addra : slv(ADDR_BITS_C - 1 downto 0);

begin

   U_RAM_PRIM : entity surf.SinglePortRamPrimitive
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G,
         DEPTH_G      => DELAY_C,
         WIDTH_G      => WIDTH_G)
      port map (
         clk  => clk,
         we   => '1',
         addr => std_logic_vector(r.addr),
         din  => din,
         dout => dout);

   comb : process(r) is
      variable v : RegType;
   begin
      v := r;

      if r.addr = (DELAY_C - 1) then
         v.addr := (others => '0');
      else
         v.addr := r.addr + 1;
      end if;

      rin <= v;

   end process comb;

   seq : process(clk)
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
