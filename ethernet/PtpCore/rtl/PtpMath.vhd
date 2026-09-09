-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Checked sequential signed 128-bit multiplier and divider.
--
-- Accepts one operand pair and operation on inputValid/inputReady.
-- Multiplication uses unsigned magnitudes, shift/add accumulation and a
-- 256-bit product; division uses restoring division with a widened remainder.
-- Both iterative paths consume 128 steps, then restore the result sign and
-- check that the answer fits in signed 128 bits. Divide by zero terminates
-- with resultError.
--
-- Division optionally rounds to nearest with ties away from zero. The
-- separately returned remainder always corresponds to a quotient truncated
-- toward zero, even when the published quotient is rounded. This distinction
-- lets PHC command producers normalize signed phase adjustments exactly.
--
-- Holds the result and error stable until resultReady. Cancel discards active
-- work and suppresses a pending result transfer. PtpPort, PtpE2e, PtpServo and
-- PtpReg instantiate this engine for their own serialized calculations; each
-- caller owns fixed-point scaling and transaction provenance.
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

entity PtpMath is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk             : in  sl;
      rst             : in  sl;
      cancel          : in  sl := '0';
      inputValid      : in  sl;
      inputReady      : out sl;
      divide          : in  sl;
      roundNearest    : in  sl := '1';
      operandA        : in  slv(127 downto 0);
      operandB        : in  slv(127 downto 0);
      resultValid     : out sl;
      resultReady     : in  sl := '1';
      resultValue     : out slv(127 downto 0);
      resultRemainder : out slv(127 downto 0);
      resultError     : out sl);
end entity PtpMath;

architecture rtl of PtpMath is

   type StateType is (
      IDLE_S,
      RUN_S,
      DONE_S);

   type RegType is record
      -- Current-cycle calculations and diagnostics. Use v for same-edge
      -- decisions; these fields do not introduce a protocol pipeline stage.
      magnitude       : unsigned(255 downto 0);
      limitValue      : unsigned(255 downto 0);

      state           : StateType;
      count           : natural range 0 to 127;
      divide          : sl;
      rounding        : sl;
      negative        : sl;
      negativeA       : sl;
      a               : unsigned(127 downto 0);
      b               : unsigned(127 downto 0);
      product         : unsigned(255 downto 0);
      multiplicand    : unsigned(255 downto 0);
      remainderValue  : unsigned(128 downto 0);
      resultValue     : slv(127 downto 0);
      resultRemainder : slv(127 downto 0);
      error           : sl;
   end record;

   constant REG_INIT_C : RegType := (
      magnitude       => (others => '0'),
      limitValue      => (others => '0'),
      state           => IDLE_S,
      count           => 0,
      divide          => '0',
      rounding        => '0',
      negative        => '0',
      negativeA       => '0',
      a               => (others => '0'),
      b               => (others => '0'),
      product         => (others => '0'),
      multiplicand    => (others => '0'),
      remainderValue  => (others => '0'),
      resultValue     => (others => '0'),
      resultRemainder => (others => '0'),
      error           => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, cancel, inputValid, divide, roundNearest, operandA, operandB, resultReady) is
      variable v : RegType;
   begin
      v := r;

      v.magnitude  := (others => '0');
      v.limitValue := shift_left(to_unsigned(1, 256), 127);
      if r.negative = '0' then
         v.limitValue := v.limitValue - 1;
      end if;
      -- Accept immutable operands, consume one arithmetic bit per cycle, then
      -- hold the signed result until the consumer takes it.
      case r.state is
         when IDLE_S =>
            if inputValid = '1' then
               v           := REG_INIT_C;
               v.state     := RUN_S;
               v.divide    := divide;
               v.rounding  := roundNearest;
               v.negative  := operandA(127) xor operandB(127);
               v.negativeA := operandA(127);
               -- Unsigned magnitudes retain abs(MIN_SIGNED), which needs all
               -- 128 bits. Never take abs in a narrower signed representation.
               v.a := unsigned(operandA);
               if operandA(127) = '1' then
                  v.a := unsigned(-signed(operandA));
               end if;
               v.b := unsigned(operandB);
               if operandB(127) = '1' then
                  v.b := unsigned(-signed(operandB));
               end if;
               v.multiplicand := resize(v.b, 256);
               if divide = '1' and v.b = 0 then
                  v.error := '1';
                  v.state := DONE_S;
               end if;
            end if;
         when RUN_S =>
            if r.divide = '1' then
               -- Restoring division consumes the dividend MSB first and shifts
               -- each quotient bit into the same register. Remainder is widened
               -- before the trial subtraction, including a 128-bit divisor.
               v.remainderValue    := shift_left(r.remainderValue, 1);
               v.remainderValue(0) := r.a(127);
               v.a                 := shift_left(r.a, 1);
               if v.remainderValue >= resize(r.b, 129) then
                  v.remainderValue := v.remainderValue - resize(r.b, 129);
                  v.a(0)           := '1';
               end if;
               v.magnitude := resize(v.a, 256);
            else
               if r.a(0) = '1' then
                  v.product := r.product + r.multiplicand;
               end if;
               v.a            := shift_right(r.a, 1);
               v.multiplicand := shift_left(r.multiplicand, 1);
               v.magnitude    := v.product;
            end if;
            -- Only the final bit triggers rounding, range checking and sign restoration.
            if r.count = 127 then
               if r.divide = '1' then
                  if r.rounding = '1' and shift_left(v.remainderValue, 1) >= resize(r.b, 129) then
                     v.magnitude := v.magnitude + 1;
                  end if;
                  -- Remainder always describes truncation toward zero, even
                  -- when the separately returned quotient is rounded nearest.
                  v.resultRemainder := slv(v.remainderValue(127 downto 0));
                  if r.negativeA = '1' then
                     v.resultRemainder := slv(-signed(v.resultRemainder));
                  end if;
               end if;
               if v.magnitude > v.limitValue then
                  v.error := '1';
               end if;
               v.resultValue := slv(v.magnitude(127 downto 0));
               if r.negative = '1' then
                  v.resultValue := slv(-signed(v.resultValue));
               end if;
               v.state := DONE_S;
            else
               v.count := r.count + 1;
            end if;
         when DONE_S =>
            if resultReady = '1' then
               v.state := IDLE_S;
            end if;
      end case;
      -- A generation/port abort cancels both active arithmetic and a stalled
      -- result before transfer. The caller owns the associated provenance.
      if cancel = '1' or (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;
      rin         <= v;
      inputReady  <= '0';
      resultValid <= '0';
      if cancel = '0' and rst /= RST_POLARITY_G then
         if r.state = IDLE_S then
            inputReady <= '1';
         elsif r.state = DONE_S then
            resultValid <= '1';
         end if;
      end if;
      resultValue     <= r.resultValue;
      resultRemainder <= r.resultRemainder;
      resultError     <= r.error;
   end process comb;

   seq : process (clk, rst) is
   begin
      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
