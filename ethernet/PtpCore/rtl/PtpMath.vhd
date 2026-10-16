-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Checked sequential signed 128-bit multiplier and divider.
--
-- Accepts one operand pair and operation on request.valid/inputReady.
-- Multiplication uses unsigned magnitudes, a 128-bit shift/add accumulator
-- and sticky overflow bits; division uses restoring division with a widened trial
-- subtraction. DIVISOR_WIDTH_G bounds the unsigned divisor magnitude and sizes
-- the retained remainder. A zero or out-of-bound divisor returns zero quotient
-- and remainder with resultError; multiplication always keeps its full width.
-- Both iterative paths consume 128 steps, then restore the result sign and
-- check that the answer fits in signed 128 bits. Divide by zero terminates
-- with resultError.
--
-- Division optionally rounds to nearest with ties away from zero. The
-- separately returned remainder always corresponds to a quotient truncated
-- toward zero, even when the published quotient is rounded. This distinction
-- lets PHC command producers normalize signed phase adjustments exactly.
--
-- Holds the result and error stable until resultReady. Valid is registered;
-- both producer and consumer exclude cancel/reset edges from transfers.
-- PtpProtocolEngine, PtpE2e, PtpServo and PtpPhc use this engine for serialized calculations; each
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
use surf.PtpMathPkg.all;

entity PtpMath is
   generic (
      TPD_G           : time                          := 1 ns;
      RST_POLARITY_G  : sl                            := '1';
      RST_ASYNC_G     : boolean                       := false;
      DIVISOR_WIDTH_G : positive range 1 to 128       := 128);
   port (
      clk        : in  sl;
      rst        : in  sl;
      cancel     : in  sl := '0';
      request    : in  PtpMathRequestType;
      inputReady : out sl;
      -- Registered valid; transfer requires valid/ready high and cancel/reset inactive.
      result      : out PtpMathResultType;
      resultReady : in  sl := '1');  -- Default consumer accepts every result.
end entity PtpMath;

architecture rtl of PtpMath is

   type StateType is (
      IDLE_S,
      RUN_S,
      DONE_S);

   type RegType is record
      -- Combinational interface controls; resolve and publish from v.
      -- Ready includes current cancel/reset: no second operand slot is
      -- reserved to honor a delayed withdrawal of admission.
      inputReady : sl;

      state           : StateType;
      count           : natural range 0 to 127;
      divide          : sl;
      rounding        : sl;
      negative        : sl;
      negativeA       : sl;
      a               : unsigned(127 downto 0);
      b               : unsigned(127 downto 0);
      product         : unsigned(127 downto 0);
      productOverflow : sl;
      multiplicand    : unsigned(127 downto 0);
      shiftOverflow   : sl;
      remainderValue  : unsigned(DIVISOR_WIDTH_G-1 downto 0);
      result          : PtpMathResultType;
   end record;

   constant REG_INIT_C : RegType := (
      inputReady      => '0',
      state           => IDLE_S,
      count           => 0,
      divide          => '0',
      rounding        => '0',
      negative        => '0',
      negativeA       => '0',
      a               => (others => '0'),
      b               => (others => '0'),
      product         => (others => '0'),
      productOverflow => '0',
      multiplicand    => (others => '0'),
      shiftOverflow   => '0',
      remainderValue  => (others => '0'),
      result          => PTP_MATH_RESULT_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, cancel, request.valid, request.divide, request.roundNearest, request.operandA, request.operandB, resultReady) is
      variable v : RegType;

      -- Calculations used only during this evaluation.
      variable magnitude        : unsigned(128 downto 0);
      variable limitValue       : unsigned(128 downto 0);
      variable shiftedRemainder : unsigned(DIVISOR_WIDTH_G downto 0);
      variable trialRemainder   : unsigned(DIVISOR_WIDTH_G+1 downto 0);
   begin
      v := r;

      v.inputReady := '0';
      magnitude    := (others => '0');
      limitValue   := shift_left(to_unsigned(1, 129), 127);
      if r.negative = '0' then
         limitValue := limitValue - 1;
      end if;

      -- Accept immutable operands, consume one arithmetic bit per cycle, then
      -- hold the signed result until the consumer takes it.
      case r.state is
         when IDLE_S =>
            if request.valid = '1' then
               v           := REG_INIT_C;
               v.state     := RUN_S;
               v.divide    := request.divide;
               v.rounding  := request.roundNearest;
               v.negative  := request.operandA(127) xor request.operandB(127);
               v.negativeA := request.operandA(127);
               -- Unsigned magnitudes retain abs(MIN_SIGNED), which needs all
               -- 128 bits. Never take abs in a narrower signed representation.
               v.a := unsigned(request.operandA);
               if request.operandA(127) = '1' then
                  v.a := unsigned(-signed(request.operandA));
               end if;

               v.b := unsigned(request.operandB);
               if request.operandB(127) = '1' then
                  v.b := unsigned(-signed(request.operandB));
               end if;

               v.multiplicand := v.b;
               if request.divide = '1' and (v.b = 0 or shift_right(v.b, DIVISOR_WIDTH_G) /= 0) then
                  v.result.error := '1';
                  v.state        := DONE_S;
               end if;
            end if;

            -- Ready describes this edge's admission, even when accepting the
            -- operands above starts work. Set it after the whole-record
            -- transaction reset, which would otherwise clear it. Cancellation
            -- is applied below and withdraws this ready.
            if cancel = '0' then
               v.inputReady := '1';
            end if;
         when RUN_S =>
            if r.divide = '1' then
               -- Restoring division consumes the dividend MSB first and shifts
               -- each quotient bit into the same register. The retained
               -- remainder is less than the divisor, so it fits the configured
               -- width. Widen before shifting and add one more subtraction bit
               -- for borrow; this selects the quotient without another compare.
               shiftedRemainder := shift_left(resize(r.remainderValue, DIVISOR_WIDTH_G+1), 1);
               shiftedRemainder(0) := r.a(127);

               trialRemainder := resize(shiftedRemainder, DIVISOR_WIDTH_G+2) -
                                 resize(r.b(DIVISOR_WIDTH_G-1 downto 0), DIVISOR_WIDTH_G+2);

               v.a              := shift_left(r.a, 1);
               v.remainderValue := shiftedRemainder(DIVISOR_WIDTH_G-1 downto 0);
               if trialRemainder(DIVISOR_WIDTH_G+1) = '0' then
                  v.remainderValue := trialRemainder(DIVISOR_WIDTH_G-1 downto 0);
                  v.a(0)           := '1';
               end if;

               magnitude := resize(v.a, 129);
            else
               -- Keep the exact low 128 product bits plus whether any higher
               -- bit was nonzero. Magnitude partial products are nonnegative,
               -- so discarded high bits can never cancel in a later addition.
               if r.a(0) = '1' then
                  magnitude         := resize(r.product, 129) + resize(r.multiplicand, 129);
                  v.product         := magnitude(127 downto 0);
                  v.productOverflow := r.productOverflow or r.shiftOverflow or magnitude(128);
               end if;

               -- A shifted-out bit matters only if this multiplicand is later
               -- selected. Shifting after the last set bit of a must not turn
               -- a small or zero product into an overflow error.
               v.a             := shift_right(r.a, 1);
               v.multiplicand  := shift_left(r.multiplicand, 1);
               v.shiftOverflow := r.shiftOverflow or r.multiplicand(127);
               magnitude       := resize(v.product, 129);
            end if;

            -- Only the final bit triggers rounding, range checking and sign restoration.
            if r.count = 127 then
               if r.divide = '1' then
                  if r.rounding = '1' and
                     shift_left(resize(v.remainderValue, DIVISOR_WIDTH_G+1), 1) >=
                     resize(r.b(DIVISOR_WIDTH_G-1 downto 0), DIVISOR_WIDTH_G+1) then
                     magnitude := magnitude + 1;
                  end if;

                  -- Remainder always describes truncation toward zero, even
                  -- when the separately returned quotient is rounded nearest.
                  v.result.remainder := slv(resize(v.remainderValue, 128));
                  if r.negativeA = '1' then
                     v.result.remainder := slv(-signed(v.result.remainder));
                  end if;
               end if;

               if magnitude > limitValue or (r.divide = '0' and v.productOverflow = '1') then
                  v.result.error := '1';
               end if;

               v.result.value := slv(magnitude(127 downto 0));
               if r.negative = '1' then
                  v.result.value := slv(-signed(v.result.value));
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
      v.result.valid := '0';
      if v.state = DONE_S then
         v.result.valid := '1';
      end if;

      -- Owner-local cancellation discards pending and held work. It is a
      -- functional override, so it is applied above the publication below.
      if cancel = '1' then
         v := REG_INIT_C;
      end if;

      -- Combinatorial outputs before the reset
      inputReady <= v.inputReady;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin    <= v;
      result <= r.result;
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
