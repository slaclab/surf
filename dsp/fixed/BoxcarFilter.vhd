-------------------------------------------------------------------------------
-- File       : BoxcarFilter.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simple boxcar filter 
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity BoxcarFilter is
   generic (
      TPD_G        : time     := 1 ns;
      DATA_WIDTH_G : positive := 16;
      ADDR_WIDTH_G : positive := 10);
   port (
      clk     : in  sl;
      rst     : in  sl;
      -- Inbound Interface
      ibValid : in  sl := '1';
      ibData  : in  slv(DATA_WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid : out sl;
      obData  : out slv(DATA_WIDTH_G-1 downto 0));
end BoxcarFilter;

architecture rtl of BoxcarFilter is

   constant ACCUM_WIDTH_C : positive                     := (DATA_WIDTH_G+ADDR_WIDTH_G);
   constant MAX_CNT_C     : slv(ADDR_WIDTH_G-1 downto 0) := (others => '1');

   type RegType is record
      init    : sl;
      accum   : slv(ACCUM_WIDTH_C-1 downto 0);
      addr    : slv(ADDR_WIDTH_G-1 downto 0);
      obValid : sl;
      obData  : slv(DATA_WIDTH_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      init    => '0',
      accum   => (others => '0'),
      addr    => MAX_CNT_C,
      obValid => '0',
      obData  => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal waddr   : slv(ADDR_WIDTH_G-1 downto 0);
   signal raddr   : slv(ADDR_WIDTH_G-1 downto 0);
   signal ramDout : slv(DATA_WIDTH_G-1 downto 0);

begin

   U_RAM : entity work.SimpleDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => true,
         DOB_REG_G    => false,
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => ADDR_WIDTH_G)
      port map (
         -- Port A     
         clka  => clk,
         wea   => ibValid,
         addra => waddr,
         dina  => ibData,
         -- Port B
         clkb  => clk,
         addrb => raddr,
         doutb => ramDout);

   comb : process (ibData, ibValid, r, ramDout, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.obValid := '0';

      -- Check for inbound data
      if (ibValid = '1') then

         -- Update the accumulator 
         v.accum := r.accum + resize(ibData, ACCUM_WIDTH_C);

         -- Check if initialized
         if (r.init = '1') then

            -- Update the accumulator 
            v.accum := v.accum - resize(ramDout, ACCUM_WIDTH_C);

            -- Forward the result
            v.obValid := '1';
            v.obData  := v.accum(ACCUM_WIDTH_C-1 downto ADDR_WIDTH_G);  -- Truncate the accumulator 

         end if;

         -- Increment the address
         v.addr := r.addr + 1;

         -- Check if the ram has been initialized
         if (v.addr = MAX_CNT_C) then
            -- Set the flag
            v.init := '1';
         end if;

      end if;

      -- Outputs              
      waddr   <= v.addr;
      raddr   <= v.addr + 1;            -- Look ahead 1 sample
      obValid <= r.obValid;
      obData  <= r.obData;

      -- Reset
      if (rst = '1') then
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
