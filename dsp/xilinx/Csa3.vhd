-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 3 input add/sub module y = +/- a +/- b + c
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
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

library surf;
use surf.StdRtlPkg.all;

library UNISIM;
use UNISIM.VComponents.all;

-- Manually instantie LUT6_2 and CARRY8 blocks for optimized 3 input adder
-- See UG579 p. 62 == 3:2 compressor followed by 2 input adder
-- see https://www.element14.com/community/groups/fpga-group/blog/2018/10/23/the-art-of-fpga-design-post-16

entity csa3 is
  generic (
      TPD_G        : time    := 1 ns;
      XIL_DEVICE_G : string  := "ULTRASCALE_PLUS";
      REG_IN_G     : boolean := false;
      REG_OUT_G    : boolean := true;
      NEGATIVE_A_G : boolean := false;
      NEGATIVE_B_G : boolean := false;
      EXTRA_MSB_G  : integer := 2);
  port (
      clk : in  sl;
      rst : in  sl := '0';
      a   : in  sfixed;
      b   : in  sfixed;
      c   : in  sfixed;
      y   : out sfixed);   -- y = +/- a +/- b + c
end csa3;

architecture rtl of csa3 is

   constant INT_OVERFLOW_STYLE_C : fixed_overflow_style_type := fixed_wrap;
   constant INT_ROUNDING_STYLE_C : fixed_round_style_type    := fixed_truncate;

   constant HIGH_ARRAY_C : IntegerArray(2 downto 0) := (
      0 => a'high,
      1 => b'high,
      2 => c'high);

   constant LOW_ARRAY_C  : IntegerArray(2 downto 0) := (
      0 => a'low,
      1 => b'low,
      2 => c'low);

   constant HIGH_BIT_C : integer := maximum(HIGH_ARRAY_C) + EXTRA_MSB_G;
   constant MED_BIT_C  : integer := median(LOW_ARRAY_C);
   constant LOW_BIT_C  : integer := minimum(LOW_ARRAY_C);

   type RegType is record
      a   : sfixed(a'range);
      b   : sfixed(b'range);
      c   : sfixed(c'range);
      sum : sfixed(y'range);
   end record RegType;

   constant REG_INIT_C : RegType := (
      a   => (others => '0'),
      b   => (others => '0'),
      c   => (others => '0'),
      sum => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inputA : sfixed(HIGH_BIT_C downto LOW_BIT_C);
   signal inputB : sfixed(HIGH_BIT_C downto LOW_BIT_C);
   signal inputC : sfixed(HIGH_BIT_C downto LOW_BIT_C);
   signal sum    : sfixed(HIGH_BIT_C downto LOW_BIT_C);

   signal O5 : signed(HIGH_BIT_C-MED_BIT_C+1 downto 0);
   signal O6 : signed(HIGH_BIT_C-MED_BIT_C downto 0);
   signal CY : slv((HIGH_BIT_C-MED_BIT_C+1+7)/8*8 downto 0);
   signal SI : slv((HIGH_BIT_C-MED_BIT_C+1+7)/8*8-1 downto 0);
   signal DI : slv((HIGH_BIT_C-MED_BIT_C+1+7)/8*8-1 downto 0);
   signal O  : slv((HIGH_BIT_C-MED_BIT_C+1+7)/8*8-1 downto 0);

begin

-- if subtracting, the corresponding carry input is set high
   O5(0) <= '1' when NEGATIVE_A_G else '0';
   CY(0) <= '1' when NEGATIVE_B_G else '0';

-- generate loop to instantiate a LUT6_2 for every bit
   GEN_L6 : for i in MED_BIT_C to HIGH_BIT_C generate
      constant I0 : bit_vector(63 downto 0):=X"AAAAAAAAAAAAAAAA";
      constant I1 : bit_vector(63 downto 0):=X"CCCCCCCCCCCCCCCC";
      constant I2 : bit_vector(63 downto 0):=X"F0F0F0F0F0F0F0F0" xor (63 downto 0=>BIT'val(BOOLEAN'pos(NEGATIVE_B_G))); -- this inverts B if NEGATIVE_B
      constant I3 : bit_vector(63 downto 0):=X"FF00FF00FF00FF00" xor (63 downto 0=>BIT'val(BOOLEAN'pos(NEGATIVE_A_G))); -- this inverts A if NEGATIVE_A_G
      constant I4 : bit_vector(63 downto 0):=X"FFFF0000FFFF0000";
      constant I5 : bit_vector(63 downto 0):=X"FFFFFFFF00000000";
   begin
      l6 : LUT6_2
         generic map (
            INIT => (I5 and (I1 xor I2 xor I3 xor I4)) or (not I5 and ((I2 and I3) or (I3 and I1) or (I1 and I2))))
         port map (
            I0   => '0',
            I1   => inputC(i),
            I2   => inputB(i),
            I3   => inputA(i),
            I4   => O5(i-MED_BIT_C),
            I5   => '1',
            O5   => O5(i+1-MED_BIT_C),
            O6   => O6(i-MED_BIT_C));
   end generate GEN_L6;

-- generate loop to instantiate a CARRY8 for every 8 bits
   SI <= std_logic_vector(resize(O6, SI'length));
   DI <= std_logic_vector(resize(O5, DI'length));
   GEN_CARRY8 : for i in 0 to (HIGH_BIT_C - MED_BIT_C)/8 generate
      c8 : CARRY8
         generic map (
            CARRY_TYPE => "SINGLE_CY8")         -- 8-bit or dual 4-bit carry (DUAL_CY4, SINGLE_CY8)
         port map (
            CI         => CY(8*i),                -- 1-bit input: Lower Carry-In
            CI_TOP     => '0',                    -- 1-bit input: Upper Carry-In
            DI         => DI(8*i+7 downto 8*i),   -- 8-bit input: Carry-MUX data in
            S          => SI(8*i+7 downto 8*i),   -- 8-bit input: Carry-mux select
            CO         => CY(8*i+8 downto 8*i+1), -- 8-bit output: Carry-out
            O          =>  O(8*i+7 downto 8*i));  -- 8-bit output: Carry chain XOR data out
   end generate GEN_CARRY8;

-- the upper portion of the result (HIGH_BIT_C downto MED_BIT_C) is given by the adder
   GEN_UPPER_BITS : for i in MED_BIT_C to HIGH_BIT_C generate
      sum(i) <= O(i - MED_BIT_C);
   end generate GEN_UPPER_BITS;

-- the lower portion of the result (MED_BIT_C-1 downto LOW_BIT_C) is given by the operand with the smallest 'low
   --GEN_LOWER_BITS_A : if (A'low < B'low) and (A'low < C'low) generate
   GEN_LOWER_BITS_A : if (A'low < MED_BIT_C) generate
      sum(MED_BIT_C - 1 downto LOW_BIT_C) <= inputA(MED_BIT_C - 1 downto LOW_BIT_C);
   end generate;

   GEN_LOWER_BITS_B : if (B'low < MED_BIT_C) generate
      sum(MED_BIT_C - 1 downto LOW_BIT_C) <= inputB(MED_BIT_C - 1 downto LOW_BIT_C);
   end generate;

   GEN_LOWER_BITS_C : if (C'low < MED_BIT_C) generate
      sum(MED_BIT_C - 1 downto LOW_BIT_C) <= inputC(MED_BIT_C - 1 downto LOW_BIT_C);
   end generate;


  comb : process( a, b, c, inputA, inputB, inputC, sum, r ) is
      variable v : RegType;
  begin

      v     := r;

      v.a   := a;
      v.b   := b;
      v.c   := c;

      v.sum := resize(sum, v.sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);

      rin <= v;

      if REG_IN_G then
         inputA <= resize(r.a, inputA, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         inputB <= resize(r.b, inputB, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         inputC <= resize(r.c, inputC, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      else
         inputA <= resize(v.a, inputA, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         inputB <= resize(v.b, inputB, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         inputC <= resize(v.c, inputC, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      end if;

      if REG_OUT_G then
          y <= r.sum;
      else
          y <= v.sum;
      end if;

  end process comb;

  seq : process ( clk ) is
  begin

      if rising_edge(clk) then
         if rst = '1' then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
  end process seq;

end rtl;
