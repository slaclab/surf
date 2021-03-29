-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Manual instantation of RAM32X1S, RAM64X1S, RAM128X1S,
--                 RAM256X1S, or RAM512X1S.
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

library UNISIM;
use UNISIM.VComponents.all;

entity SinglePortRamPrimitive is
   generic (
      TPD_G          : time     := 1 ns;
      XIL_DEVICE_G   : string   := "ULTRASCALE_PLUS";
      DEPTH_G        : integer  range 1 to 512 := 64;
      WIDTH_G        : positive := 16);
   port (
      clk   : in  sl;
      we    : in  sl := '1';
      addr  : in  slv(log2(DEPTH_G) - 1 downto 0);
      din   : in  slv(WIDTH_G - 1 downto 0);
      dout  : out slv(WIDTH_G - 1 downto 0));
end entity SinglePortRamPrimitive;

architecture rtl of SinglePortRamPrimitive is

   signal q   : slv(WIDTH_G - 1 downto 0) := (others => '0');

begin

   BIT_RAM : for i in WIDTH_G - 1 downto 0 generate

      GEN_LUT32 : if DEPTH_G <= 32 generate
          LUT32 : RAM32X1S
          generic map (
             INIT => x"00000000")
          port map (
             wclk => clk,
             we   => we,
             a0   => addr(0),
             a1   => addr(1),
             a2   => addr(2),
             a3   => addr(3),
             a4   => addr(4),
             d    => din(i),
             o    => q(i));
      end generate GEN_LUT32;

      GEN_LUT64 : if ( (DEPTH_G > 32) and  (DEPTH_G <= 64) ) generate
          LUT64 : RAM64X1S
          generic map (
             INIT => x"0000000000000000")
          port map (
             wclk => clk,
             we   => we,
             a0   => addr(0),
             a1   => addr(1),
             a2   => addr(2),
             a3   => addr(3),
             a4   => addr(4),
             a5   => addr(5),
             d    => din(i),
             o    => q(i));
      end generate GEN_LUT64;

      GEN_LUT128 : if ( (DEPTH_G > 64) and (DEPTH_G <= 128) ) generate
          LUT128 : RAM128X1S
          generic map (
             INIT => x"00000000000000000000000000000000")
          port map (
             wclk => clk,
             we   => we,
             a0   => addr(0),
             a1   => addr(1),
             a2   => addr(2),
             a3   => addr(3),
             a4   => addr(4),
             a5   => addr(5),
             a6   => addr(6),
             d    => din(i),
             o    => q(i));
      end generate GEN_LUT128;

      GEN_LUT256 : if ( ( (DEPTH_G > 128) and (DEPTH_G <= 256) ) or
                   ( (DEPTH_G > 128) and (XIL_DEVICE_G = "7SERIES") ) ) generate
          assert (DEPTH_G < 257)
             report "DEPTH_G > 256 not supported for 7SERIES device" severity failure;
          LUT256 : RAM256X1S
          generic map (
             INIT => x"0000000000000000000000000000000000000000000000000000000000000000")
          port map (
             wclk => clk,
             we   => we,
             a    => addr,
             d    => din(i),
             o    => q(i));
      end generate GEN_LUT256;

      GEN_LUT512 : if (DEPTH_G > 256) and ( (XIL_DEVICE_G = "ULTRASCALE") or (XIL_DEVICE_G = "ULTRASCALE_PLUS") ) generate
          constant INIT_C : bit_vector(511 downto 0) := (others => '0');
      begin
          LUT512 : RAM512X1S
          generic map (
             INIT => x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
          port map (
             wclk => clk,
             we   => we,
             a    => addr,
             d    => din(i),
             o    => q(i));
      end generate GEN_LUT512;

   end generate BIT_RAM;

   seq : process(clk)
   begin
      if rising_edge(clk) then
            dout <= q after TPD_G;
      end if;
   end process seq;

end architecture rtl;
