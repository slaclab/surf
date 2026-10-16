-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Signed-A/unsigned-B product with explicit registered sum tree.
-- B is split into parallel 17-bit limbs. A-by-17 products, each tree level,
-- and final full-product/overflow publication have separate register stages.
-- All ports use clk; backpressure freezes payload and valid together. Synchronous
-- reset/cancel clears every token and wins over acceptance/publication.
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

entity PtpTreeProduct is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      A_G            : positive := 68;
      B_G            : positive := 64);
   port (
      clk         : in  sl;
      rst         : in  sl;
      cancel      : in  sl;
      request     : in  PtpProductRequestType(operandA(A_G-1 downto 0), operandB(B_G-1 downto 0));
      inputReady  : out sl;
      result      : out PtpProductResultType(value(A_G+B_G-1 downto 0));
      resultReady : in  sl);
end entity PtpTreeProduct;

architecture rtl of PtpTreeProduct is

   constant LIMBS_C  : positive := (B_G+16)/17;
   constant LEVELS_C : natural := bitSize(LIMBS_C-1);
   constant PIPE_C   : positive := LEVELS_C+2;
   constant LEAVES_C : positive := 2**LEVELS_C;
   constant WIDTH_C  : positive := A_G+B_G+1;
   type ProductArray is array (natural range <>) of signed(WIDTH_C-1 downto 0);

   type RegType is record
      a : signed(A_G downto 0);
      b : unsigned(17*LIMBS_C-1 downto 0);
      nodes    : ProductArray(0 to 2*LEAVES_C-2);
      valid    : slv(PIPE_C downto 0);
      value    : slv(WIDTH_C-1 downto 0);
      overflow : sl;
   end record;

   constant REG_INIT_C : RegType := (
      a        => (others => '0'),
      b        => (others => '0'),
      nodes    => (others => (others => '0')),
      valid    => (others => '0'),
      value    => (others => '0'),
      overflow => '0');

   signal r      : RegType := REG_INIT_C;
   signal rin    : RegType;
   signal leaves : ProductArray(0 to LEAVES_C-1);

begin

   GEN_LEAF : for i in 0 to LEAVES_C-1 generate
      GEN_PRODUCT : if i < LIMBS_C generate
         signal partialProduct : signed(A_G+18 downto 0);
         attribute use_dsp : string;
         attribute use_dsp of partialProduct : signal is "yes";
      begin
         partialProduct <= r.a*signed('0' & r.b(17*i+16 downto 17*i));
         leaves(i)      <= shift_left(resize(partialProduct, WIDTH_C), 17*i);
      end generate GEN_PRODUCT;
      GEN_ZERO : if i >= LIMBS_C generate
         leaves(i) <= (others => '0');
      end generate GEN_ZERO;
   end generate GEN_LEAF;

   comb : process (all) is
      variable v : RegType;
   begin
      v          := r;
      inputReady <= '0';
      if r.valid(PIPE_C) = '0' or resultReady = '1' then
         v.a     := resize(signed(request.operandA), A_G+1);
         v.b     := resize(unsigned(request.operandB), v.b'length);
         v.valid := r.valid(PIPE_C-1 downto 0) & request.valid;
         for i in 0 to LEAVES_C-1 loop
            v.nodes(LEAVES_C-1+i) := leaves(i);
         end loop;
         for i in 0 to LEAVES_C-2 loop
            v.nodes(i) := r.nodes(2*i+1)+r.nodes(2*i+2);
         end loop;
         v.value    := slv(r.nodes(0));
         v.overflow := '0';
         if resize(resize(r.nodes(0), 128), WIDTH_C) /= r.nodes(0) then
            v.overflow := '1';
         end if;
         if cancel = '0' then
            inputReady <= '1';
         end if;
      end if;
      if cancel = '1' then
         v := REG_INIT_C;
      end if;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;
      -- Pack existing DSP-pipeline registers without another product copy or stage.
      result <=
      (
         valid    => r.valid(PIPE_C),
         value    => r.value(A_G+B_G-1 downto 0),
         overflow => r.overflow
      );
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
