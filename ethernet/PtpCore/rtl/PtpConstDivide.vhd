-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Exact signed division by a compile-time positive constant.
--
-- Converts a signed WIDTH_G-bit dividend to an unsigned magnitude, divides by
-- the selected constant and restores the sign. The divisor factors as
-- `d = odd << k`; the magnitude splits as `m = h*2**k + l`. A restoring serial
-- loop consumes one bit of `h` per clock, keeping a residual below `odd`, and
-- the exact remainder is reassembled as `(r << k) or l`. Retaining `l` is
-- required: shifting first and rounding the reduced division afterward
-- misclassifies whole bands of dividends, not only tie points.
--
-- Two quotient modes share one remainder definition. With roundNearest low the
-- quotient truncates toward zero; with roundNearest high it rounds to nearest
-- with ties away from zero, decided by comparing the exact unsigned remainder
-- against `ceil(d/2)` at the full remainder width. The published remainder always
-- describes truncation, carries the dividend's sign and satisfies
-- `operand = quotient*d + remainder` with `abs(remainder) < d` in truncating
-- mode. A rounded quotient and this remainder are not a division pair.
--
-- A power-of-two divisor needs no loop and completes in one clock. All ports
-- use clk. One request is outstanding at a time; the result is held until
-- resultReady. Input ready is combinational so cancellation suppresses
-- admission immediately; the result and its valid are registered. Synchronous
-- reset or cancel discards pending and held work, including a result
-- completing on that edge.
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
use surf.PtpPkg.all;

entity PtpConstDivide is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      -- Signed dividend width. Every supported divisor exceeds one, so a
      -- signed WIDTH_G-bit quotient cannot overflow; narrower consumers apply
      -- their own fit checks.
      WIDTH_G : positive         := 96;
      -- Positive constant divisor, as a 64-bit value because SECOND_Q16
      -- exceeds the range of a VHDL integer. Callers pass the named constant
      -- that carries the units for their conversion.
      DIVISOR_G : slv(63 downto 0) := (others => '1'));
   port (
      clk : in  sl;
      rst : in  sl;
      -- Owner-local cancellation; discards pending and held work.
      cancel      : in  sl;
      request     : in  PtpConstDivideRequestType(operand(WIDTH_G-1 downto 0));
      inputReady  : out sl;
      result      : out PtpConstDivideResultType(value(WIDTH_G-1 downto 0), remainder(WIDTH_G-1 downto 0));
      resultReady : in  sl);
end entity PtpConstDivide;

architecture rtl of PtpConstDivide is

   constant DIVISOR_C  : unsigned(63 downto 0) := unsigned(DIVISOR_G);
   constant SHIFT_C    : natural               := ptpTrailingZeros(DIVISOR_C);
   constant ODD_C      : unsigned(63 downto 0) := shift_right(DIVISOR_C, SHIFT_C);
   constant ODD_BITS_C : positive              := ptpUsedBits(ODD_C);

   -- High part consumed by the serial loop, and the exact remainder range.
   constant HIGH_C     : positive := WIDTH_G-SHIFT_C;
   constant REM_BITS_C : positive := ptpUsedBits(DIVISOR_C-1);
   -- ceil(divisor/2) preserves nearest rounding for odd nominal increments.
   -- Form the half first so the maximum unsigned64 divisor cannot overflow.
   constant ROUND_THRESHOLD_C : unsigned(63 downto 0) :=
      shift_right(DIVISOR_C, 1)+resize(DIVISOR_C(0 downto 0), 64);

   type StateType is (
      IDLE_S, SERIAL_S, PUBLISH_S, DONE_S);

   type RegType is record
      state      : StateType;
      negative   : sl;
      rounding   : sl;
      highValue  : unsigned(HIGH_C-1 downto 0);
      lowValue   : unsigned(SHIFT_C-1 downto 0);
      quotient   : unsigned(HIGH_C-1 downto 0);
      residual   : unsigned(ODD_BITS_C downto 0);
      count      : natural range 0 to HIGH_C-1;
      inputReady : sl;
      result     : PtpConstDivideResultType(value(WIDTH_G-1 downto 0), remainder(WIDTH_G-1 downto 0));
   end record;

   constant REG_INIT_C : RegType := (
      state      => IDLE_S,
      negative   => '0',
      rounding   => '0',
      highValue  => (others => '0'),
      lowValue   => (others => '0'),
      quotient   => (others => '0'),
      residual   => (others => '0'),
      count      => 0,
      inputReady => '0',
      result     => ptpConstDivideResultInit(WIDTH_G));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert DIVISOR_C > 1
      report "PtpConstDivide requires a divisor above one"
      severity failure;

   assert WIDTH_G > SHIFT_C and HIGH_C >= ODD_BITS_C
      report "PtpConstDivide width cannot represent the divisor's odd part"
      severity failure;

   comb : process (all) is
      variable v              : RegType;
      variable magnitude      : unsigned(WIDTH_G-1 downto 0);
      variable remainderValue : unsigned(REM_BITS_C-1 downto 0);
      variable quotientValue  : unsigned(WIDTH_G-1 downto 0);
      variable trial          : unsigned(ODD_BITS_C+1 downto 0);
   begin
      v            := r;
      v.inputReady := '0';

      -- Negating in the operand's own width covers the signed endpoint, where
      -- an absolute value in a narrower container would be invalid.
      magnitude := unsigned(request.operand);
      if request.operand(WIDTH_G-1) = '1' then
         magnitude := unsigned(-signed(request.operand));
      end if;

      -- Exact truncation remainder, reassembled from the retained low bits.
      remainderValue := shift_left(resize(r.residual, REM_BITS_C), SHIFT_C) or
                        resize(r.lowValue, REM_BITS_C);
      quotientValue := resize(r.quotient, WIDTH_G);
      trial         := (others => '0');

      case r.state is
         when IDLE_S =>
            v.inputReady := '1';

            if request.valid = '1' then
               -- Clear only the transaction state. A whole-record reset here
               -- would also clear the ready just advertised, so the accepting
               -- edge would never be observable to the client.
               v.count        := 0;
               v.quotient     := (others => '0');
               v.residual     := (others => '0');
               v.result.valid := '0';
               v.negative     := request.operand(WIDTH_G-1);
               v.rounding     := request.roundNearest;
               v.highValue    := magnitude(WIDTH_G-1 downto SHIFT_C);
               v.lowValue     := magnitude(SHIFT_C-1 downto 0);
               v.state        := SERIAL_S;

               -- A power-of-two divisor leaves the shifted value exact.
               if ODD_C = 1 then
                  v.quotient := magnitude(WIDTH_G-1 downto SHIFT_C);
                  v.state    := PUBLISH_S;
               end if;
            end if;

         when SERIAL_S =>
            -- Shift one dividend bit into a residual already below odd, so the
            -- trial stays below 2*odd and one subtraction suffices per bit.
            trial := shift_left(resize(r.residual, trial'length), 1);
            trial(0) := r.highValue(HIGH_C-1);
            v.highValue := shift_left(r.highValue, 1);
            v.quotient  := shift_left(r.quotient, 1);

            if trial >= ODD_C then
               trial := trial-resize(ODD_C, trial'length);
               v.quotient(0) := '1';
            end if;

            v.residual := resize(trial, v.residual'length);

            if r.count = HIGH_C-1 then
               v.state := PUBLISH_S;
            else
               v.count := r.count+1;
            end if;

         when PUBLISH_S =>
            -- Compare against ceil(d/2) at the full remainder width. Even
            -- divisors retain ties away from zero; odd divisors have no tie.
            if r.rounding = '1' and remainderValue >= ROUND_THRESHOLD_C then
               quotientValue := quotientValue+1;
            end if;

            v.result.value     := slv(quotientValue);
            v.result.remainder := slv(resize(remainderValue, WIDTH_G));

            if r.negative = '1' then
               v.result.value     := slv(-signed(v.result.value));
               v.result.remainder := slv(-signed(v.result.remainder));
            end if;

            v.result.valid := '1';
            v.state        := DONE_S;

         when DONE_S =>
            if resultReady = '1' then
               v.result.valid := '0';
               v.state        := IDLE_S;
            end if;
      end case;

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
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
