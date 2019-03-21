-------------------------------------------------------------------------------
-- File       : BoxcarIntegrator.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simple boxcar integrator
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

entity BoxcarIntegrator is
   generic (
      TPD_G        : time     := 1 ns;
      DATA_WIDTH_G : positive := 16;
      ADDR_WIDTH_G : positive := 10);
   port (
      clk       : in  sl;
      rst       : in  sl;
      -- Configuration, intCount is 0 based, 0 = 1, 1 = 2, 1023 = 1024
      intCount  : in slv(ADDR_WIDTH_G-1 downto 0);
      -- Inbound Interface
      ibValid   : in  sl := '1';
      ibData    : in  slv(DATA_WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid   : out sl;
      obAck     : in  sl := '1';
      obData    : out slv(DATA_WIDTH_G+ADDR_WIDTH_G-1 downto 0);
      obFull    : out sl;
      obPeriod  : out sl);

end BoxcarIntegrator;

architecture rtl of BoxcarIntegrator is

   constant ACCUM_WIDTH_C : positive := (DATA_WIDTH_G+ADDR_WIDTH_G);

   type RegType is record
      obFull     : sl;
      intCount   : slv(ADDR_WIDTH_G-1 downto 0);
      rAddr      : slv(ADDR_WIDTH_G-1 downto 0);
      wAddr      : slv(ADDR_WIDTH_G-1 downto 0);
      ibValid    : sl;
      ibData     : slv(DATA_WIDTH_G-1 downto 0);
      obValid    : sl;
      obPeriod   : sl;
      obData     : slv(ACCUM_WIDTH_C-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      obFull     => '0',
      intCount   => (others=>'0'),
      rAddr      => (others=>'0'),
      wAddr      => (others=>'0'),
      ibValid    => '0',
      ibData     => (others=>'0'),
      obValid    => '0',
      obPeriod   => '0',
      obData     => (others=>'0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramDout   : slv(DATA_WIDTH_G-1 downto 0);

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
         addra => r.wAddr,
         dina  => r.ibData,
         -- Port B
         clkb  => clk,
         addrb => r.rAddr,
         doutb => ramDout);


   comb : process (ibData, ibValid, r, ramDout, rst, intCount, obAck) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Clear the output valid and period latches
      if obAck = '1' then
         v.obValid  := '0';
         v.obPeriod := '0';
      end if;

      -- Input stage, setup addresses
      v.ibData  := ibData;
      v.ibValid := ibValid;

      -- Setup address for next cycle
      if ibValid = '1' then

         -- Read address
         if r.rAddr = r.intCount then
            v.rAddr  := (others=>'0');
         else
            v.rAddr  := r.rAddr + 1;
         end if;

         -- Write lags read
         v.wAddr := r.rAddr;

      end if;

      -- Check for inbound data
      if r.ibValid = '1' then

         -- Ready after writing last location
         if r.wAddr = r.intCount then
            v.obFull   := '1';
            v.obPeriod := '1';
         end if;

         -- Update the accumulator 
         v.obData := r.obData + resize(r.ibData, ACCUM_WIDTH_C);

         -- Check if full
         if r.obFull = '1' then
            v.obData := v.obData - resize(ramDout, ACCUM_WIDTH_C);
         end if;

         -- Output valid latch
         v.obValid := '1';

      end if;

      -- Outputs              
      obValid  <= r.obValid;
      obFull   <= r.obFull;
      obPeriod <= r.obPeriod;
      obData   <= r.obData;

      -- Reset
      if rst = '1' or r.intCount /= intCount then
         v          := REG_INIT_C;
         v.intCount := intCount;
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

