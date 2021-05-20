-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SRL16 delay module - pack 2 SRL16 per slice
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

library UNISIM;
use UNISIM.VComponents.all;

library surf;
use surf.StdRtlPkg.all;

entity Srl16Delay is
   generic (
      TPD_G          : time     := 1 ns;
      XIL_DEVICE_G   : string   := "ULTRASCALE_PLUS"; -- "7SERIES" or "ULTRASCALE" or "ULTRASCALE_PLUS"
      DELAY_G        : natural range 3 to 17 := 3;    -- default number of clock cycle delays
      WIDTH_G        : positive := 16);
   port (
      clk   : in  sl;
      din   : in  slv(WIDTH_G-1 downto 0);
      dout  : out slv(WIDTH_G-1 downto 0);
      dly_2 : in  slv(3 downto 0) := toSlv(DELAY_G-2, 4)); -- slv for DELAY-2, runtime optional
end entity Srl16Delay;

architecture rtl of Srl16Delay is

   signal q        : slv(WIDTH_G-1 downto 0);

   attribute rloc : string;

begin

   assert (XIL_DEVICE_G ="7SERIES" or XIL_DEVICE_G ="ULTRASCALE" or XIL_DEVICE_G ="ULTRASCALE_PLUS")
      report "XIL_DEVICE_G must be either [7SERIES,ULTRASCALE,ULTRASCALE_PLUS]" severity failure;

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      BIT_DELAY : for i in WIDTH_G-1 downto 0 generate
         -- https://www.element14.com/community/groups/fpga-group/blog/2018/09/04/the-art-of-fpga-design-post-9
         attribute rloc of shift_reg:label is "X0Y"&INTEGER'image(i/8);
      begin
         shift_reg: SRL16E
         generic map (
            INIT => x"0000")
         port map (
            clk => clk,
            ce  => '1',
            a0  => dly_2(0),
            a1  => dly_2(1),
            a2  => dly_2(2),
            a3  => dly_2(3),
            d   => din(i),
            q   => q(i));
      end generate BIT_DELAY;
   end generate GEN_7SERIES;

   GEN_ULTRASCALE : if (XIL_DEVICE_G = "ULTRASCALE") or (XIL_DEVICE_G = "ULTRASCALE_PLUS") generate
      BIT_DELAY : for i in WIDTH_G-1 downto 0 generate
         -- https://www.element14.com/community/groups/fpga-group/blog/2018/09/04/the-art-of-fpga-design-post-9
         attribute rloc of shift_reg:label is "X0Y"&INTEGER'image(i/16);
      begin
         shift_reg: SRL16E
         generic map (
            INIT => x"0000")
         port map (
            clk => clk,
            ce  => '1',
            a0  => dly_2(0),
            a1  => dly_2(1),
            a2  => dly_2(2),
            a3  => dly_2(3),
            d   => din(i),
            q   => q(i));
      end generate BIT_DELAY;
   end generate GEN_ULTRASCALE;

   seq : process(clk)
   begin
      if rising_edge(clk) then
         dout <= q after TPD_G;
      end if;
   end process seq;

end architecture rtl;
