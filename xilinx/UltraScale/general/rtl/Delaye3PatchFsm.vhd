-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: FSM that patches the silicon's issue of increments > 8
-- https://forums.xilinx.com/t5/Versal-and-UltraScale/IDELAY-ODELAY-Usage/td-p/812362
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

library unisim;
use unisim.vcomponents.all;

entity Delaye3PatchFsm is
   generic (
      TPD_G           : time    := 1 ns;
      DELAY_TYPE      : string  := "FIXED";  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
      DELAY_VALUE     : integer := 0;   -- Input delay value setting
      IS_CLK_INVERTED : bit     := '0';     -- Optional inversion for CLK
      IS_RST_INVERTED : bit     := '0');    -- Optional inversion for RST
   port (
      -- Inputs
      CLK           : in  sl;           -- 1-bit input: Clock input
      RST           : in  sl;  -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
      LOAD          : in  sl;           -- 1-bit input: Load DELAY_VALUE input
      CNTVALUEIN    : in  slv(8 downto 0);  -- 9-bit input: Counter value input
      CNTVALUEOUT   : in  slv(8 downto 0);  -- 9-bit output: Counter value output
      -- outputs
      patchLoad     : out sl;
      patchCntValue : out slv(8 downto 0);
      busy          : out sl);          -- 1-bit output: Patch module is busy
end Delaye3PatchFsm;

architecture rtl of Delaye3PatchFsm is

   type StateType is (
      IDLE_S,
      CHECK_CNT_S,
      LOAD_S,
      WAIT_S);

   type RegType is record
      Load      : sl;
      dlyValue  : slv(8 downto 0);
      dlyTarget : slv(8 downto 0);
      waitCnt   : slv(2 downto 0);
      state     : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      Load      => '0',
      dlyValue  => toSlv(DELAY_VALUE, 9),
      dlyTarget => toSlv(DELAY_VALUE, 9),
      waitCnt   => (others => '0'),
      state     => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   GEN_PATCH : if (DELAY_TYPE = "VAR_LOAD") generate

      comb : process (CNTVALUEIN, CNTVALUEOUT, LOAD, r) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Reset strobes
         v.Load := '0';

         -- Check for load request
         -- Main state machine
         case r.state is
            ----------------------------------------------------------------------
            when IDLE_S =>
               if (LOAD = '1') then
                  -- Update the target delay value on load request
                  v.dlyTarget := CNTVALUEIN;
                  v.state     := CHECK_CNT_S;
               end if;
            ----------------------------------------------------------------------
            when CHECK_CNT_S =>
               -- Check if load target different from current output
               if (r.dlyTarget /= CNTVALUEOUT) then
                  -- Check if we should increment the value
                  if (r.dlyTarget > CNTVALUEOUT) then
                     v.dlyValue := CNTVALUEOUT + 1;
                  -- Else decrement the value
                  else
                     v.dlyValue := CNTVALUEOUT - 1;
                  end if;
                  -- Next state
                  v.state := LOAD_S;
               else
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when LOAD_S =>
               -- "Wait at least one clock cycle after applying a new value on the
               -- CNTVALUEIN bus before applying the LOAD signal." UG571 (v1.12, page172)
               v.Load  := '1';
               -- Next state
               v.state := WAIT_S;
            ----------------------------------------------------------------------
            when WAIT_S =>
               -- Increment the counter
               v.waitCnt := r.waitCnt + 1;
               -- "Option for multiple updates: Wait 5 clock cycles." UG571 (v1.12, page181)
               if (r.waitCnt = 4) then
                  -- Reset the counter
                  v.waitCnt := (others => '0');
                  -- Next state
                  v.state   := CHECK_CNT_S;
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Outputs
         patchLoad     <= r.Load;
         patchCntValue <= r.dlyValue;
         if (r.state /= IDLE_S) then
            busy <= '1';
         else
            busy <= '0';
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

      end process comb;

      seq : process (CLK, RST) is
      begin
         -- Check for non-inverted clock
         if (IS_CLK_INVERTED = '0') then
            if (rising_edge(CLK)) then
               r <= rin after TPD_G;
            end if;
         -- Else inverted clock
         else
            if (falling_edge(CLK)) then
               r <= rin after TPD_G;
            end if;
         end if;
         -- Asynchronous Reset to the DELAY_VALUE
         if ((RST = '1') and (IS_RST_INVERTED = '0')) or ((RST = '0') and (IS_RST_INVERTED = '1')) then
            r <= REG_INIT_C after TPD_G;
         end if;
      end process seq;

   end generate;

   BYP_PATCH : if (DELAY_TYPE /= "VAR_LOAD") generate
      patchLoad     <= LOAD;
      patchCntValue <= CNTVALUEIN;
      busy          <= '0';
   end generate;

end rtl;
