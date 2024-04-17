-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shift Register Delay module for std_logic_vector
--              Uses a counter and single port RAM (distributed, block, ultra)
--              Single port RAM setup in read first mode
--              Counter counts 0...maxCount
--              Optional data out register (DO_REG_G) on the RAM
--
--              delay = maxCount + ite(DO_REG_G, 3, 2)
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

entity SlvFixedDelay is
   generic (
      TPD_G          : time      := 1 ns;
      XIL_DEVICE_G   : string    := "ULTRASCALE_PLUS";
      DELAY_STYLE_G  : string    := "srl_reg"; -- "reg", "srl", "srl_reg", "reg_srl", "reg_srl_reg" or "block"
      DELAY_G        : integer   := 256;
      WIDTH_G        : positive  := 16);
   port (
      clk      : in  sl;
      din      : in  slv(WIDTH_G - 1 downto 0);
      dout     : out slv(WIDTH_G - 1 downto 0));
end entity SlvFixedDelay;

architecture rtl of SlvFixedDelay is

   type VectorArray is array (DELAY_G downto 0) of slv(WIDTH_G-1 downto 0);

   type RegType is record
      shift : VectorArray;
   end record RegType;

   constant REG_INIT_C : RegType := (
      shift => (others => (others => '0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   attribute srl_style      : STRING;
   attribute srl_style of r : signal is DELAY_STYLE_G;

begin

   GEN_SRL16_DELAY : if ( (DELAY_G > 3) and (DELAY_G < 18) and (DELAY_STYLE_G /= "block") ) generate
       -- This will always be srl_reg style
       U_SRL16_DELAY : entity surf.Srl16Delay
       generic map (
          TPD_G        => TPD_G,
          XIL_DEVICE_G => XIL_DEVICE_G,
          DELAY_G      => DELAY_G,
          WIDTH_G      => WIDTH_G)
       port map (
          clk          => clk,
          din          => din,
          dout         => dout);
   end generate GEN_SRL16_DELAY;

   GEN_RAM_DELAY : if ( (DELAY_G > 32) and (DELAY_G < 258) and (DELAY_STYLE_G /= "block") ) generate
      -- Manually pack into Xilinx primitives
      U_RAM_DELAY : entity surf.LutFixedDelay
      generic map (
         TPD_G         => TPD_G,
         DELAY_G       => DELAY_G,
         WIDTH_G       => WIDTH_G)
      port map (
         clk           => clk,
         din           => din,
         dout          => dout);
   end generate GEN_RAM_DELAY;

   GEN_INFERRED_DELAY : if ( (DELAY_G < 4) or (DELAY_G > 17 and DELAY_G < 33) or (DELAY_G > 257) or (DELAY_STYLE_G = "block") ) generate
      comb : process (din, r) is
         variable v : RegType;
      begin
         v.shift(0) := din;
         for i in v.shift'high downto 1 loop
             v.shift(i) := r.shift(i-1);
         end loop;

         rin  <= v;
         dout <= v.shift(v.shift'high);
      end process comb;

      seq : process (clk) is
      begin
         if rising_edge(clk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
   end generate GEN_INFERRED_DELAY;

end rtl;
