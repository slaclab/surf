-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Signed-by-unsigned product using one reused DSP multiplier.
--
-- Multiplies a signed A_G-bit value by an unsigned B_G-bit value, consuming B
-- from its most significant 17-bit limb with Horner accumulation. One A-by-17
-- product is instantiated and reused across limbs, so a wide product costs one
-- DSP chain rather than a full parallel array. A single-cycle product of this
-- width fails setup at the endpoint clocks; the per-limb register boundary is
-- what makes the path closeable.
--
-- The full product and its signed128 overflow indication are published only
-- after every limb is accumulated. This preserves the existing rejection
-- semantics: callers that reject an overflowing pre-shift product must still
-- see that overflow, and no early shift or rounding may convert a rejected
-- intermediate into an accepted representable result.
--
-- All ports use clk. One request is outstanding at a time and the result is
-- held until resultReady. Input ready is combinational; result valid, payload
-- and overflow are registered. Synchronous reset or cancel discards pending
-- and held work and wins over a result completing on that edge.
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

entity PtpLimbProduct is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      A_G            : positive := 96;
      B_G            : positive := 95);
   port (
      clk         : in  sl;
      rst         : in  sl;
      -- Owner-local cancellation; discards pending and held work.
      cancel      : in  sl;
      inputValid  : in  sl;
      inputReady  : out sl;
      operandA    : in  slv(A_G-1 downto 0);
      operandB    : in  slv(B_G-1 downto 0);
      resultValid : out sl;
      resultReady : in  sl;
      resultValue : out slv(A_G+B_G-1 downto 0);
      -- Asserted when the full product does not fit signed 128 bits,
      -- independent of whether any later shifted result would be
      -- representable.
      overflow    : out sl);
end entity PtpLimbProduct;

architecture rtl of PtpLimbProduct is

   constant LIMB_BITS_C : positive := 17;
   constant LIMBS_C     : positive := (B_G+LIMB_BITS_C-1)/LIMB_BITS_C;
   constant WIDTH_C     : positive := A_G+B_G;

   -- B occupies whole limbs, so a width that is not a multiple of the limb
   -- size is padded. The padding must sit below B's least significant bit:
   -- the loop consumes limbs from the top, so left-padding would shift every
   -- limb and silently scale the product.
   constant PAD_BITS_C : natural := LIMB_BITS_C*LIMBS_C-B_G;

   type StateType is (IDLE_S, MULTIPLY_S, ADD_S, FINISH_S, DONE_S);

   type RegType is record
      state       : StateType;
      a           : unsigned(A_G-1 downto 0);
      b           : unsigned(LIMB_BITS_C*LIMBS_C-1 downto 0);
      count       : natural range 0 to LIMBS_C-1;
      negative    : sl;
      accumulator : unsigned(WIDTH_C+PAD_BITS_C-1 downto 0);
      inputReady  : sl;
      value       : slv(WIDTH_C-1 downto 0);
      valid       : sl;
      overflow    : sl;
   end record;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      a           => (others => '0'),
      b           => (others => '0'),
      count       => 0,
      negative    => '0',
      accumulator => (others => '0'),
      inputReady  => '0',
      value       => (others => '0'),
      valid       => '0',
      overflow    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Name the multiplication itself so the mapping directive applies to it.
   signal partialProduct : unsigned(A_G+LIMB_BITS_C-1 downto 0);
   signal product        : unsigned(A_G+LIMB_BITS_C-1 downto 0) := (others => '0');

   attribute use_dsp : string;
   attribute use_dsp of partialProduct : signal is "yes";

begin

   partialProduct <= r.a*r.b(r.b'high downto r.b'high-LIMB_BITS_C+1);

   comb : process (all) is
      variable v     : RegType;
      variable value : signed(WIDTH_C-1 downto 0);
   begin
      v := r;
      v.inputReady := '0';

      -- B was left-aligned into whole limbs, so the accumulator carries
      -- 2**PAD_BITS_C times the true product. Shifting it back is exact: the
      -- discarded low bits are the zeros introduced by that alignment.
      value := signed(resize(shift_right(r.accumulator, PAD_BITS_C), WIDTH_C));

      if r.negative = '1' then
         value := -value;
      end if;

      case r.state is
         when IDLE_S =>
            v.inputReady := '1';

            if inputValid = '1' then
               -- Clear only the transaction state. A whole-record reset here
               -- would also clear the ready just advertised, so the accepting
               -- edge would never be observable to the client.
               v.count := 0;
               v.accumulator := (others => '0');
               v.valid := '0';
               v.overflow := '0';

               -- Negate in the operand's own width so the signed endpoint is
               -- representable as a magnitude.
               v.a := unsigned(operandA);
               v.negative := operandA(A_G-1);
               if operandA(A_G-1) = '1' then
                  v.a := unsigned(-signed(operandA));
               end if;

               -- Left-align B in its padded container so the first limb read
               -- is B's most significant limb. Plain resize would zero-pad on
               -- the left and shift every limb when B_G is not a multiple of
               -- the limb width.
               v.b := shift_left(resize(unsigned(operandB), v.b'length), PAD_BITS_C);
               v.state := MULTIPLY_S;
            end if;

         when MULTIPLY_S =>
            v.state := ADD_S;

         when ADD_S =>
            v.accumulator := shift_left(r.accumulator, LIMB_BITS_C)+
                             resize(product, v.accumulator'length);
            v.b := shift_left(r.b, LIMB_BITS_C);

            if r.count = LIMBS_C-1 then
               v.state := FINISH_S;
            else
               v.count := r.count+1;
               v.state := MULTIPLY_S;
            end if;

         when FINISH_S =>
            v.value := slv(value);
            v.overflow := '0';

            if resize(resize(value, 128), WIDTH_C) /= value then
               v.overflow := '1';
            end if;

            v.valid := '1';
            v.state := DONE_S;

         when DONE_S =>
            if resultReady = '1' then
               v.valid := '0';
               v.state := IDLE_S;
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

      rin <= v;

      resultValid <= r.valid;
      resultValue <= r.value;
      overflow <= r.overflow;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
         product <= (others => '0') after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
         product <= partialProduct after TPD_G;
      end if;
   end process seq;

end architecture rtl;
