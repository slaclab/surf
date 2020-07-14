-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Delay module for std_logic_vector
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

entity SlvDelayRam is
   generic (
      TPD_G          : time                        := 1 ns;
      RST_POLARITY_G : sl                          := '1';  -- '1' for active high rst, '0' for active low
      MEMORY_TYPE_G  : string                      := "block";
      DO_REG_G       : boolean                     := true;
      DELAY_G        : positive range 3 to (2**24) := 3;  --max number of clock cycle delays. MAX delay stages when using
      WIDTH_G        : positive                    := 1);
   port (
      clk       : in  sl;
      rst       : in  sl                                                    := not(RST_POLARITY_G);
      en        : in  sl                                                    := '1';  -- Optional clock enable
      dlyConfig : in  slv(log2(DELAY_G - ite(DO_REG_G, 2, 1)) - 1 downto 0) := toSlv(DELAY_G - ite(DO_REG_G, 3, 2), log2(DELAY_G - ite(DO_REG_G, 2, 1)));  -- Optional runtime configurable
      din       : in  slv(WIDTH_G - 1 downto 0);
      dout      : out slv(WIDTH_G - 1 downto 0));
end entity SlvDelayRam;

architecture rtl of SlvDelayRam is

   constant ADDR_WIDTH_C : positive := log2(DELAY_G - ite(DO_REG_G, 2, 1)) + 1;

   type RegType is record
      waddr : slv(ADDR_WIDTH_C-1 downto 0);
      raddr : slv(ADDR_WIDTH_C-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      waddr => (others => '0'),
      raddr => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal waddr : slv(ADDR_WIDTH_C-1 downto 0);
   signal raddr : slv(ADDR_WIDTH_C-1 downto 0);

begin

   U_Ram : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         DOB_REG_G      => DO_REG_G,
         DATA_WIDTH_G   => WIDTH_G,
         ADDR_WIDTH_G   => ADDR_WIDTH_C)
      port map (
         -- Port A
         clka   => clk,
         ena    => en,
         wea    => '1',
         addra  => waddr,
         dina   => din,
         -- Port B
         clkb   => clk,
         enb    => en,
         regceb => en,
         rstb   => rst,
         addrb  => raddr,
         doutb  => dout);

   comb : process (dlyConfig, en, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Check for clock enable
      if en = '1' then

         -- Increment the write address
         v.waddr := r.waddr + 1;

         -- Delay the read address
         v.raddr := r.waddr - resize(dlyConfig, ADDR_WIDTH_C);

      end if;

      -- Outputs
      waddr <= r.waddr;
      raddr <= r.raddr;

      -- Reset
      if rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
