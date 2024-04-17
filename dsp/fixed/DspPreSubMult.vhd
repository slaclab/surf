-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Generalized DSP inferred multiplier with pre-adder
--              configured as subtractor (based on UG901)
-- Equation: p = (a - b) x c
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

entity DspPreSubMult is
   generic (
      TPD_G          : time                 := 1 ns;
      RST_POLARITY_G : sl                   := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean              := false;
      USE_DSP_G      : string               := "yes";
      PIPE_STAGES_G  : natural range 0 to 1 := 0;
      A_WIDTH_G      : natural              := 12;
      B_WIDTH_G      : natural              := 16;
      C_WIDTH_G      : natural              := 17);
   port (
      clk     : in  sl;
      rst     : in  sl := not(RST_POLARITY_G);
      -- Inbound Interface
      ibValid : in  sl := '1';
      ibReady : out sl;
      ain     : in  slv(A_WIDTH_G-1 downto 0);
      bin     : in  slv(B_WIDTH_G-1 downto 0);
      cin     : in  slv(C_WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid : out sl;
      obReady : in  sl := '1';
      pOut    : out slv(B_WIDTH_G + C_WIDTH_G downto 0));
end DspPreSubMult;

architecture rtl of DspPreSubMult is

   type RegType is record
      ibReady : sl;
      tReady  : sl;
      tValid  : slv(1 downto 0);
      diff    : signed(B_WIDTH_G downto 0);
      c       : signed(C_WIDTH_G - 1 downto 0);
      p       : signed(B_WIDTH_G + C_WIDTH_G downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      ibReady => '0',
      tReady  => '0',
      tValid  => (others => '0'),
      diff    => (others => '0'),
      c       => (others => '0'),
      p       => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tReady : slv(1 downto 0);

   signal p : slv(B_WIDTH_G + C_WIDTH_G downto 0);

   attribute use_dsp      : string;
   attribute use_dsp of r : signal is USE_DSP_G;

begin

   comb : process (ain, bin, cin, ibValid, r, rst, tReady) is
      variable v : RegType;
      variable a : signed(A_WIDTH_G - 1 downto 0);
      variable b : signed(B_WIDTH_G - 1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- typecast from slv to signed
      a := signed(ain);
      b := signed(bin);

      --------------------------------------------------------------------
      -- 1st latency cycle
      --------------------------------------------------------------------

      -- Reset the flags
      v.ibReady := '0';
      if tReady(0) = '1' then
         v.tValid(0) := '0';
      end if;

      -- Check if ready to process data
      if (v.tValid(0) = '0') and (ibValid = '1') then
         -- Set the flow control flags
         v.ibReady   := '1';
         v.tValid(0) := '1';
         -- Process the data
         v.diff      := resize(a, B_WIDTH_G + 1) - resize(b, B_WIDTH_G + 1);
         v.c         := signed(cin);
      end if;

      --------------------------------------------------------------------
      -- 2nd latency cycle
      --------------------------------------------------------------------

      -- Reset the flags
      v.tReady := '0';
      if tReady(1) = '1' then
         v.tValid(1) := '0';
      end if;

      -- Check if ready to process data
      if (v.tValid(1) = '0') and (r.tValid(0) = '1') then
         -- Set the flow control flags
         v.tReady    := '1';
         v.tValid(1) := '1';
         -- Process the data
         v.p         := r.diff * r.c;
      end if;

      --------------------------------------------------------------------
      -- Combinatorial outputs before the reset
      ibReady   <= v.ibReady;
      tReady(0) <= v.tReady;

      -- Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      p <= std_logic_vector(r.p);

   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Pipe : entity surf.FifoOutputPipeline
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RST_POLARITY_G => RST_POLARITY_G,
         DATA_WIDTH_G   => (B_WIDTH_G + C_WIDTH_G + 1),
         PIPE_STAGES_G  => PIPE_STAGES_G)
      port map (
         -- Slave Port
         sData  => p,
         sValid => r.tValid(1),
         sRdEn  => tReady(1),
         -- Master Port
         mData  => pOut,
         mValid => obValid,
         mRdEn  => obReady,
         -- Clock and Reset
         clk    => clk,
         rst    => rst);

end rtl;
