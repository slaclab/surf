-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the DspComparator module
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


library surf;
use surf.StdRtlPkg.all;

entity DspComparatorTb is end DspComparatorTb;

architecture testbed of DspComparatorTb is

   constant CLK_PERIOD_C : time := 4 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   constant WIDTH_C : positive := 8;

   type StateType is (
      TX_VALUES_S,
      RX_RESULTS_S,
      FAILED_S,
      PASSED_S);

   type RegType is record
      passed    : sl;
      failed    : sl;
      failedVec : slv(4 downto 0);
      ibValid   : sl;
      ain       : slv(WIDTH_C-1 downto 0);
      bin       : slv(WIDTH_C-1 downto 0);
      state     : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed    => '0',
      failed    => '0',
      failedVec => (others => '0'),
      ibValid   => '0',
      ain       => (others => '0'),
      bin       => (others => '0'),
      state     => TX_VALUES_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal obValid : sl := '0';
   signal eqDsp   : sl := '0';
   signal gtDsp   : sl := '0';
   signal gtEqDsp : sl := '0';
   signal lsDsp   : sl := '0';
   signal lsEqDsp : sl := '0';

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
   U_DspComparator : entity surf.DspComparator
      generic map (
         TPD_G   => TPD_C,
         WIDTH_G => WIDTH_C)
      port map (
         clk     => clk,
         rst     => rst,
         -- Inbound Interface
         ibValid => r.ibValid,
         ain     => r.ain,
         bin     => r.bin,
         -- Outbound Interface
         obValid => obValid,
         eq      => eqDsp,              -- equal                    (a =  b)
         gt      => gtDsp,              -- greater than             (a >  b)
         gtEq    => gtEqDsp,            -- greater than or equal to (a >= b)
         ls      => lsDsp,              -- less than                (a <  b)
         lsEq    => lsEqDsp);           -- less than or equal to    (a <= b)

   -------------------------------------------------
   -- FSM to sweep through all possible combination
   ------------------------------------------------
   comb : process (eqDsp, gtDsp, gtEqDsp, lsDsp, lsEqDsp, obValid, r, rst) is
      variable v    : RegType;
      variable eq   : sl;
      variable gt   : sl;
      variable gtEq : sl;
      variable ls   : sl;
      variable lsEq : sl;
   begin
      -- Latch the current value
      v := r;

      -- equal (a = b)
      if (r.ain = r.bin) then
         eq := '1';
      else
         eq := '0';
      end if;

      -- greater than (a > b)
      if (r.ain > r.bin) then
         gt := '1';
      else
         gt := '0';
      end if;

      -- greater than or equal to (a >= b)
      if (r.ain >= r.bin) then
         gtEq := '1';
      else
         gtEq := '0';
      end if;

      -- less than (a <  b)
      if (r.ain < r.bin) then
         ls := '1';
      else
         ls := '0';
      end if;

      -- less than or equal to (a <= b)
      if (r.ain <= r.bin) then
         lsEq := '1';
      else
         lsEq := '0';
      end if;

      -- Reset the flags
      v.ibValid := '0';

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when TX_VALUES_S =>
            -- Set the flag
            v.ibValid := '1';
            -- Next state
            v.state   := RX_RESULTS_S;
         ----------------------------------------------------------------------
         when RX_RESULTS_S =>
            -- Wait for the results
            if (obValid = '1') then
               -- Compare the results
               if (eq /= eqDsp) then
                  v.failedVec(0) := '1';
               end if;
               if (gt /= gtDsp) then
                  v.failedVec(1) := '1';
               end if;
               if (gtEq /= gtEqDsp) then
                  v.failedVec(2) := '1';
               end if;
               if (ls /= lsDsp) then
                  v.failedVec(3) := '1';
               end if;
               if (lsEq /= lsEqDsp) then
                  v.failedVec(4) := '1';
               end if;
               -- Check for error
               if v.failedVec /= 0 then
                  -- Next state
                  v.state := FAILED_S;
               else
                  -- Default Next state
                  v.state := TX_VALUES_S;
                  -- Increment the counter
                  v.ain   := r.ain + 1;
                  -- Check for roll over
                  if (v.ain = 0) then
                     -- Increment the counter
                     v.bin := r.bin + 1;
                     -- Check for roll over
                     if (v.bin = 0) then
                        -- Next state
                        v.state := PASSED_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when FAILED_S =>
            v.failed := '1';
         ----------------------------------------------------------------------
         when PASSED_S =>
            v.passed := '1';
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      passed <= r.passed;
      failed <= r.failed;

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
