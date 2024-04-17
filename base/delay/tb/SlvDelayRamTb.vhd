-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the SlvDelayRam module
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;

entity SlvDelayRamTb is end SlvDelayRamTb;

architecture testbed of SlvDelayRamTb is

   constant CLK_PERIOD_C : time := 4 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   constant WIDTH_C     : integer := 16;
   constant MAX_DELAY_C : integer := 514;
   constant DELAY_C     : integer := MAX_DELAY_C;

   constant DO_REG_C      : boolean := true;
   constant MEMORY_TYPE_C : string := "block";

   -- may save a bit if MAX_DELAY is just over pow2 ex 514 elements only needs 9 bits
   constant MAX_COUNT_BITS_C : integer := log2(MAX_DELAY_C - ite(DO_REG_C, 2, 1));

   -- delay = maxCount + ite(DO_REG_G, 3, 2);
   constant MAX_COUNT_C : integer := DELAY_C - ite(DO_REG_C, 3, 2);

   type countDelayType is array(MAX_DELAY_C - 1 downto 0) of integer range 0 to (2**WIDTH_C - 1);

   type RegType is record
      passed         : sl;
      failed         : sl;
      count          : integer range 0 to (2**WIDTH_C - 1);
      countDelay     : countDelayType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      passed     => '0',
      failed     => '0',
      count      => 0,
      countDelay => (others => 0));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal din  : slv(WIDTH_C - 1 downto 0) := (others => '0');
   signal dout : slv(WIDTH_C - 1 downto 0) := (others => '0');

   signal maxCount : slv(MAX_COUNT_BITS_C - 1 downto 0) := toSlv(MAX_COUNT_C, MAX_COUNT_BITS_C);

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => clk,
         rst  => rst);

   -----------------------
   -- Module to be testing
   -----------------------
   U_SlvDelayRam : entity surf.SlvDelayRam
      generic map (
         TPD_G         => TPD_C,
         MEMORY_TYPE_G => MEMORY_TYPE_C,
         DO_REG_G      => DO_REG_C,
         DELAY_G       => MAX_DELAY_C,
         WIDTH_G       => WIDTH_C)
      port map (
         clk     => clk,
         maxCount => maxCount,
         din     => din,
         dout    => dout);

   -------------------------------------------------
   -- FSM to sweep through all possible combination
   ------------------------------------------------
   comb : process (dout, r, rst) is
      variable v    : RegType;
      variable countDelay : integer;
   begin
      -- Latch the current value
      v := r;



      v.count := r.count + 1;

      v.countDelay(0) := r.count;
      v.countDelay(MAX_DELAY_C - 1 downto 1) := r.countDelay(MAX_DELAY_C - 2 downto 0);

      -- test for failure
      if r.count > MAX_DELAY_C then
         if r.countDelay(DELAY_C - 1) /= dout then
            v.failed := '1';
         end if;
      end if;

      -- if we haven't failed yet
      if r.count > 10*MAX_DELAY_C then
         v.passed := '1';
      end if;

      -- Outputs
      passed <= r.passed;
      failed <= r.failed;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      din <= std_logic_vector(to_unsigned(r.count, din'length));

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_C;
      end if;
   end process seq;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
