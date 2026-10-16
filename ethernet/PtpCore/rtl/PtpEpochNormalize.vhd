-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Converts a PTP seconds/subsecond pair to a Q16-nanosecond scalar.
--
-- Computes `seconds48 * (1e9 * 2**16) + subsecondQ16`. The constant factors as
-- `1953125 * 2**25`, so the product uses a 48-by-21 multiply and the remaining
-- scaling is a wiring shift. Multiplying by the 21-bit odd part instead of the
-- 46-bit constant keeps the product 69 bits wide before the shift and 94 after,
-- which is strictly narrower than the unfactored form.
--
-- Every unsigned48 subsecond value is accepted, matching the arithmetic this
-- replaces; a noncanonical subsecond still fits because the maximum is below
-- 2**48 * (1e9*2**16 + 1) < 2**94. Timestamp admission and signed correction
-- handling stay with the caller, so bit 94 of the result is a signed zero bit.
--
-- All ports use clk. One request is outstanding at a time; the result appears
-- two clocks after acceptance and is held until resultReady, giving a minimum
-- request interval of four clocks. Input ready is combinational; the result
-- and its valid are registered. Synchronous reset or cancel discards pending
-- and held responses and wins over acceptance and completion.
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

entity PtpEpochNormalize is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk : in  sl;
      rst : in  sl;
      -- Owner-local cancellation; discards pending and held work.
      cancel      : in  sl;
      request     : in  PtpEpochRequestType;
      inputReady  : out sl;
      result      : out PtpEpochResultType;
      resultReady : in  sl);
end entity PtpEpochNormalize;

architecture rtl of PtpEpochNormalize is

   -- 1e9 * 2**16 = 1953125 * 2**25. Both factors come from the same constant,
   -- so the odd part and shift cannot drift apart.
   constant SECOND_DIVISOR_C : unsigned(63 downto 0) := unsigned(PTP_SECOND_Q16_DIVISOR_C);
   constant SECOND_SHIFT_C   : natural               := ptpTrailingZeros(SECOND_DIVISOR_C);
   constant SECOND_ODD_C     : unsigned(20 downto 0) :=
      resize(shift_right(SECOND_DIVISOR_C, SECOND_SHIFT_C), 21);

   type StateType is (IDLE_S, MULTIPLY_S, ADD_S, DONE_S);

   type RegType is record
      state        : StateType;
      inputReady   : sl;
      seconds      : unsigned(47 downto 0);
      subsecondQ16 : unsigned(47 downto 0);
      product      : unsigned(68 downto 0);
      result       : PtpEpochResultType;
   end record;

   constant REG_INIT_C : RegType := (
      state        => IDLE_S,
      inputReady   => '0',
      seconds      => (others => '0'),
      subsecondQ16 => (others => '0'),
      product      => (others => '0'),
      result       => PTP_EPOCH_RESULT_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Name the multiplication itself so the mapping directive applies to it.
   signal fullProduct : unsigned(68 downto 0);

   attribute use_dsp : string;
   attribute use_dsp of fullProduct : signal is "yes";

begin

   assert ptpUsedBits(shift_right(SECOND_DIVISOR_C, SECOND_SHIFT_C)) <= 21
      report "PtpEpochNormalize expects a 21-bit odd part in the second constant"
      severity failure;

   fullProduct <= r.seconds*SECOND_ODD_C;

   comb : process (all) is
      variable v : RegType;
   begin
      v            := r;
      v.inputReady := '0';

      case r.state is
         when IDLE_S =>
            v.inputReady := '1';

            if request.valid = '1' then
               v.seconds      := unsigned(request.seconds);
               v.subsecondQ16 := unsigned(request.subsecondQ16);
               v.state        := MULTIPLY_S;
            end if;

         when MULTIPLY_S =>
            v.product := fullProduct;
            v.state   := ADD_S;

         when ADD_S =>
            v.result.value := '0' & slv(shift_left(resize(r.product, 94), SECOND_SHIFT_C) +
                                resize(r.subsecondQ16, 94));
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
