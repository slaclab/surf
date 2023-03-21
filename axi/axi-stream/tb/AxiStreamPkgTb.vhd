-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamPkg Package
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
use surf.AxiStreamPkg.all;

entity AxiStreamPkgTb is end AxiStreamPkgTb;

architecture testbed of AxiStreamPkgTb is

   constant CLK_PERIOD_C : time := 4 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   type RegType is record
      passed        : sl;
      passedDly     : sl;
      failed        : sl;
      failedDly     : sl;
      tKeepResult   : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      tKeepExpected : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      cnt           : slv(7 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed        => '0',
      passedDly     => '0',
      failed        => '0',
      failedDly     => '0',
      tKeepResult   => (others => '0'),
      tKeepExpected => (others => '0'),
      cnt           => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk    : sl := '0';
   signal rst    : sl := '0';
   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   ClkRst_Inst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);

   comb : process (r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Check if simulation not completed
      if (r.passed = '0') and (r.failed = '0') then

         case r.cnt is
            ----------------------------------------------------------------------
            when x"00" =>
               -- genTKeep(bytes=0) case
               v.tKeepResult   := genTKeep(0);
               v.tKeepExpected := resize(x"0", AXI_STREAM_MAX_TKEEP_WIDTH_C);
               if v.tKeepResult /= v.tKeepExpected then
                  v.failed := '1';
               end if;
            ----------------------------------------------------------------------
            when x"01" =>
               -- genTKeep(bytes=1) case
               v.tKeepResult   := genTKeep(1);
               v.tKeepExpected := resize(x"1", AXI_STREAM_MAX_TKEEP_WIDTH_C);
               if v.tKeepResult /= v.tKeepExpected then
                  v.failed := '1';
               end if;
            ----------------------------------------------------------------------
            when x"02" =>
               -- genTKeep(bytes=31) case
               v.tKeepResult   := genTKeep(31);
               v.tKeepExpected := resize(x"7FFF_FFFF", AXI_STREAM_MAX_TKEEP_WIDTH_C);
               if v.tKeepResult /= v.tKeepExpected then
                  v.failed := '1';
               end if;
            ----------------------------------------------------------------------
            when x"03" =>
               -- genTKeep(bytes=32) case
               v.tKeepResult   := genTKeep(32);
               v.tKeepExpected := resize(x"FFFF_FFFF", AXI_STREAM_MAX_TKEEP_WIDTH_C);
               if v.tKeepResult /= v.tKeepExpected then
                  v.failed := '1';
               end if;
            ----------------------------------------------------------------------
            when x"04" =>
               -- genTKeep(bytes=64) case
               v.tKeepResult   := genTKeep(64);
               v.tKeepExpected := resize(x"FFFF_FFFF_FFFF_FFFF", AXI_STREAM_MAX_TKEEP_WIDTH_C);
               if v.tKeepResult /= v.tKeepExpected then
                  v.failed := '1';
               end if;
            ----------------------------------------------------------------------
            when others =>
               v.passed := '1';
         ----------------------------------------------------------------------
         end case;

         -- Check if didn't fail
         if (v.failed = '0') then
            -- Increment the counter
            v.cnt := r.cnt + 1;
         end if;

      end if;

      -- Delay by 1 cycle to make it easier to read in simulation waveform
      v.passedDly := r.passed;
      v.failedDly := r.failed;

      -- Outputs
      passed <= r.passedDly;
      failed <= r.failedDly;

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
      if failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end testbed;
