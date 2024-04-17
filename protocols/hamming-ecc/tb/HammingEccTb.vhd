-------------------------------------------------------------------------------
-- Title      : Hamming-ECC: https://en.wikipedia.org/wiki/Hamming_code
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Testbench for design "hamming-ecc"
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
use surf.HammingEccPkg.all;

entity HammingEccTb is
end entity HammingEccTb;

architecture sim of HammingEccTb is

   constant CLK_PERIOD_C : time := 4 ns;
   constant TPD_G        : time := CLK_PERIOD_C/4;

   constant DATA_WIDTH_C : positive := 8;
   constant ENC_WIDTH_C  : positive := hammingEccDataWidth(DATA_WIDTH_C);

   -- Useful values to see in simulation
   constant k : positive := DATA_WIDTH_C;
   constant m : positive := hammingEccPartiyWidth(k);
   constant n : positive := hammingEccDataWidth(k);

   type StateType is (
      LOAD_S,
      WAIT_S,
      FAILED_S,
      PASSED_S);

   type RegType is record
      passed       : sl;
      failed       : sl;
      ibValid      : sl;
      ibData       : slv(DATA_WIDTH_C-1 downto 0);
      bitErrorMask : slv(ENC_WIDTH_C downto 0);
      state        : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed       => '0',
      failed       => '0',
      ibValid      => '0',
      ibData       => (others => '0'),
      bitErrorMask => (others => '0'),
      state        => LOAD_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal encValid    : sl                        := '0';
   signal encData     : slv(ENC_WIDTH_C downto 0) := (others => '0');
   signal encDataMask : slv(ENC_WIDTH_C downto 0) := (others => '0');

   signal obValid   : sl                           := '0';
   signal obData    : slv(DATA_WIDTH_C-1 downto 0) := (others => '0');
   signal obErrSbit : sl                           := '0';
   signal obErrDbit : sl                           := '0';

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
   -- Modules to be testing
   -----------------------
   U_Encoder : entity surf.HammingEccEncoder
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => DATA_WIDTH_C)
      port map (
         -- Clock and Reset
         clk     => clk,
         rst     => rst,
         -- Inbound Interface
         ibValid => r.ibValid,
         ibData  => r.ibData,
         -- Outbound Interface
         obValid => encValid,
         obData  => encData);

   encDataMask <= encData xor r.bitErrorMask;  -- Insert the bit error

   U_Decoder : entity surf.HammingEccDecoder
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => DATA_WIDTH_C)
      port map (
         -- Clock and Reset
         clk       => clk,
         rst       => rst,
         -- Inbound Interface
         ibValid   => encValid,
         ibData    => encDataMask,
         -- Outbound Interface
         obValid   => obValid,
         obData    => obData,
         obErrSbit => obErrSbit,
         obErrDbit => obErrDbit);

   -------------------------------------------------
   -- FSM to sweep through all possible combination
   ------------------------------------------------
   comb : process (obData, obErrDbit, obErrSbit, obValid, r, rst) is
      variable v    : RegType;
      variable eq   : sl;
      variable gt   : sl;
      variable gtEq : sl;
      variable ls   : sl;
      variable lsEq : sl;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.ibValid := '0';

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when LOAD_S =>
            -- Set the flag
            v.ibValid := '1';
            -- Next state
            v.state   := WAIT_S;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Wait for the results
            if (obValid = '1') then

               -- Check if no inserted errors
               if (r.bitErrorMask = 0) then

                  -- Check the results
                  if (r.ibData = obData) and (obErrSbit = '0') and (obErrDbit = '0') then
                     -- Next state
                     v.state := LOAD_S;
                  else
                     -- Next state
                     v.state := FAILED_S;
                  end if;

               -- Check for only 1 bit error that should be corrected
               elsif (onesCount(r.bitErrorMask) = 1) then

                  -- Check the results
                  if (r.ibData = obData) and (obErrSbit = '1') and (obErrDbit = '0') then
                     -- Next state
                     v.state := LOAD_S;
                  else
                     -- Next state
                     v.state := FAILED_S;
                  end if;


               -- Else 2 or more errors
               else

                  -- Check the results
                  if (obErrDbit = '1') then
                     -- Next state
                     v.state := LOAD_S;
                  else
                     -- Next state
                     v.state := FAILED_S;
                  end if;

               end if;

               -- Check if next state is LOAD_S
               if (v.state = LOAD_S) then

                  -- Increment the counter
                  v.ibData := r.ibData + 1;

                  -- Check for roll over
                  if (v.ibData = 0) then

                     -- Increment the counter
                     v.bitErrorMask := r.bitErrorMask + 1;

                     -- Only allow sweep of 0, 1 or 2 bit errors
                     while (onesCount(v.bitErrorMask) > 2) loop
                        -- Increment the counter
                        v.bitErrorMask := v.bitErrorMask + 1;
                     end loop;

                     -- Check for roll over
                     if (v.bitErrorMask = 0) then

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
         r <= rin after TPD_G;
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

end architecture sim;
