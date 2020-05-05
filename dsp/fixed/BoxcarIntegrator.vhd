-------------------------------------------------------------------------------
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;


entity BoxcarIntegrator is
   generic (
      TPD_G        : time     := 1 ns;
      SIGNED_G     : boolean  := false;  -- Treat data as unsigned by default
      DOB_REG_G    : boolean  := false;  -- Extra reg on doutb (folded into BRAM)
      DATA_WIDTH_G : positive := 16;
      ADDR_WIDTH_G : positive := 10);
   port (
      clk      : in  sl;
      rst      : in  sl;
      -- Configuration, intCount is 0 based, 0 = 1, 1 = 2, 1023 = 1024
      intCount : in  slv(ADDR_WIDTH_G-1 downto 0);
      -- Inbound Interface
      ibValid  : in  sl := '1';
      ibData   : in  slv(DATA_WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid  : out sl;
      obAck    : in  sl := '1';
      obData   : out slv(DATA_WIDTH_G+ADDR_WIDTH_G-1 downto 0);
      obFull   : out sl;
      obPeriod : out sl);

end BoxcarIntegrator;

architecture rtl of BoxcarIntegrator is

   constant ACCUM_WIDTH_C : positive := (DATA_WIDTH_G+ADDR_WIDTH_G);

   type RegType is record
      obFull    : sl;
      intCount  : unsigned(ADDR_WIDTH_G-1 downto 0);
      rAddr     : unsigned(ADDR_WIDTH_G-1 downto 0);
      wAddr     : unsigned(ADDR_WIDTH_G-1 downto 0);
      ibValid   : sl;
      ibData    : slv(DATA_WIDTH_G-1 downto 0);
      obValid   : sl;
      obPeriod  : sl;
      obData    : signed(ACCUM_WIDTH_C-1 downto 0);
      ibDataE   : signed(DATA_WIDTH_G downto 0);
      obFullD   : sl;
      ibValidD  : sl;
      obPeriodD : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      obFull    => '0',
      intCount  => (others => '0'),
      rAddr     => (others => '0'),
      wAddr     => (others => '0'),
      ibValid   => '0',
      ibData    => (others => '0'),
      obValid   => '0',
      obPeriod  => '0',
      obData    => (others => '0'),
      ibDataE   => (others => '0'),
      obFullD   => '0',
      ibValidD  => '0',
      obPeriodD => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramDout  : slv(DATA_WIDTH_G-1 downto 0);
   signal ramDoutE : signed(DATA_WIDTH_G downto 0);
   signal ibDataE  : signed(DATA_WIDTH_G downto 0);
   signal rAddr    : slv(ADDR_WIDTH_G-1 downto 0);
   signal wAddr    : slv(ADDR_WIDTH_G-1 downto 0);

begin

   UNSIGNED_DATA : if (SIGNED_G = false) generate
      ramDoutE <= signed('0' & ramDout);
      ibDataE  <= signed('0' & r.ibData);
   end generate;

   SIGNED_DATA : if (SIGNED_G = true) generate
      ramDoutE <= signed(ramDout(DATA_WIDTH_G-1) & ramDout);
      ibDataE  <= signed(ibDataE(DATA_WIDTH_G-1)& r.ibData);
   end generate;

   U_RAM : entity surf.SimpleDualPortRam
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "block",
         DOB_REG_G     => DOB_REG_G,
         DATA_WIDTH_G  => DATA_WIDTH_G,
         ADDR_WIDTH_G  => ADDR_WIDTH_G)
      port map (
         -- Port A
         clka  => clk,
         wea   => r.ibValid,
         addra => wAddr,
         dina  => r.ibData,
         -- Port B
         clkb  => clk,
         addrb => rAddr,
         doutb => ramDout);

   comb : process (ibData, ibDataE, ibValid, intCount, obAck, r, ramDoutE, rst) is
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

      v.ibDataE  := ibDataE;
      v.ibValidD := r.ibValid;

      -- Setup address for next cycle
      if ibValid = '1' then

         -- Read address
         if r.rAddr = r.intCount then
            v.rAddr := (others => '0');
         else
            v.rAddr := r.rAddr + '1';
         end if;

         -- Write lags read
         v.wAddr := r.rAddr;

      end if;

      -- Check for inbound data
      if r.ibValid = '1' then
         -- Ready after writing last location
         if r.wAddr = r.intCount then
            v.obFullD   := '1';
            v.obPeriodD := '1';
         end if;
      end if;

      if DOB_REG_G then
         -- Ready after writing last location
         v.obFull   := r.obFullD;
         v.obPeriod := r.obPeriodD;
         if r.ibValidD = '1' then
            -- Update the accumulator
            v.obData := r.obData + r.ibDataE;

            -- Check if full
            if r.obFullD = '1' then
               v.obData := v.obData - ramDoutE;
            end if;

            -- Output valid latch
            v.obValid := '1';
         end if;
      else
         if r.ibValid = '1' then

            -- Ready after writing last location
            if r.wAddr = r.intCount then
               v.obFull   := '1';
               v.obPeriod := '1';
            end if;
            -- Update the accumulator
            v.obData := r.obData + ibDataE;

            -- Check if full
            if r.obFull = '1' then
               v.obData := v.obData - ramDoutE;
            end if;

            -- Output valid latch
            v.obValid := '1';

         end if;
      end if;


      -- Outputs
      obValid  <= r.obValid;
      obFull   <= r.obFull;
      obPeriod <= r.obPeriod;
      obData   <= std_logic_vector(r.obData);
      rAddr    <= std_logic_vector(r.rAddr);
      wAddr    <= std_logic_vector(r.wAddr);

      -- Reset
      if rst = '1' or r.intCount /= unsigned(intCount) then
         v          := REG_INIT_C;
         v.intCount := unsigned(intCount);
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
