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

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,              -- 128-bit data interface
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 3,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 4,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant TKEEP_INIT_C : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0) := toSlv((2**AXIS_CONFIG_C.TDATA_BYTES_C)-1, AXI_STREAM_MAX_TKEEP_WIDTH_C);

   type RegType is record
      passed   : sl;
      failed   : sl;
      txMaster : AxiStreamMasterType;
      cnt      : slv(7 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed   => '0',
      failed   => '0',
      txMaster => axiStreamMasterInit(AXIS_CONFIG_C),
      cnt      => (others => '0'));

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

         -- Increment the counter
         v.cnt := r.cnt + 1;

         case r.cnt is
            ----------------------------------------------------------------------
            when x"00" =>
               -- Verify genTKeep() function
               if (r.txMaster.tKeep = TKEEP_INIT_C) then
                  v.cnt := r.cnt + 1;
               else
                  v.failed := '1';
               end if;
            ----------------------------------------------------------------------
            when others =>
               v.passed := '1';
         ----------------------------------------------------------------------
         end case;
      end if;

      -- Outputs
      failed <= r.failed;
      passed <= r.passed;

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
