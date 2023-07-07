-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Generalized DSP inferred comparator
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

entity DspComparator is
   generic (
      TPD_G          : time                   := 1 ns;
      RST_POLARITY_G : sl                     := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean                := false;
      USE_DSP_G      : string                 := "yes";
      PIPE_STAGES_G  : natural range 0 to 1   := 0;
      WIDTH_G        : positive range 2 to 96 := 32);
   port (
      clk     : in  sl;
      rst     : in  sl := not(RST_POLARITY_G);
      -- Inbound Interface
      ibValid : in  sl := '1';
      ibReady : out sl;
      ain     : in  slv(WIDTH_G-1 downto 0);
      bin     : in  slv(WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid : out sl;
      obReady : in  sl := '1';
      aout    : out slv(WIDTH_G-1 downto 0);  -- Registered copy of ain
      bout    : out slv(WIDTH_G-1 downto 0);  -- Registered copy of bin
      eq      : out sl;                 -- equal                    (a =  b)
      gt      : out sl;                 -- greater than             (a >  b)
      gtEq    : out sl;                 -- greater than or equal to (a >= b)
      ls      : out sl;                 -- less than                (a <  b)
      lsEq    : out sl);                -- less than or equal to    (a <= b)
end DspComparator;

architecture rtl of DspComparator is

   subtype PIPE_AOUT_RANGE_C is integer range WIDTH_G-1+5 downto 5;
   subtype PIPE_BOUT_RANGE_C is integer range 2*WIDTH_G-1+5 downto WIDTH_G+5;

   type RegType is record
      ibReady : sl;
      tValid  : sl;
      aout    : slv(WIDTH_G-1 downto 0);
      bout    : slv(WIDTH_G-1 downto 0);
      diff    : signed(WIDTH_G downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      ibReady => '0',
      tValid  => '0',
      aout    => (others => '0'),
      bout    => (others => '0'),
      diff    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tReady  : sl;
   signal eqInt   : sl;
   signal gtInt   : sl;
   signal gtEqInt : sl;
   signal lsInt   : sl;
   signal lsEqInt : sl;

   signal sData : slv(2*WIDTH_G-1+5 downto 0);
   signal mData : slv(2*WIDTH_G-1+5 downto 0);

   attribute use_dsp      : string;
   attribute use_dsp of r : signal is USE_DSP_G;

begin

   comb : process (ain, bin, ibValid, r, rst, tReady) is
      variable v : RegType;
      variable a : signed(WIDTH_G downto 0);
      variable b : signed(WIDTH_G downto 0);
   begin
      -- Latch the current value
      v := r;

      -- typecast from slv to signed
      a := signed(resize(ain,WIDTH_G+1));
      b := signed(resize(bin,WIDTH_G+1));

      -- Flow Control
      v.ibReady := '0';
      if tReady = '1' then
         v.tValid := '0';
      end if;

      -- Check if ready to process data
      if (v.tValid = '0') and (ibValid = '1') then

         -- Set the flow control flags
         v.ibReady := '1';
         v.tValid  := '1';

         -- Process the data
         v.diff := a - b;

         -- Registered copy
         v.aout := ain;
         v.bout := bin;

      end if;

      -- Outputs
      ibReady <= v.ibReady;

      -- Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   eqInt   <= '1' when (r.diff(WIDTH_G downto 0) = 0)                              else '0';
   gtInt   <= '1' when (r.diff(WIDTH_G) = '0' and r.diff(WIDTH_G-1 downto 0) /= 0) else '0';
   gtEqInt <= '1' when (r.diff(WIDTH_G) = '0')                                     else '0';
   lsInt   <= '1' when (r.diff(WIDTH_G) = '1')                                     else '0';
   lsEqInt <= '1' when (r.diff(WIDTH_G) = '1' or r.diff(WIDTH_G downto 0) = 0)     else '0';

   U_Pipe : entity surf.FifoOutputPipeline
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RST_POLARITY_G => RST_POLARITY_G,
         DATA_WIDTH_G   => 5+2*WIDTH_G,
         PIPE_STAGES_G  => PIPE_STAGES_G)
      port map (
         -- Slave Port
         sData  => sData,
         sValid => r.tValid,
         sRdEn  => tReady,
         -- Master Port
         mData  => mData,
         mValid => obValid,
         mRdEn  => obReady,
         -- Clock and Reset
         clk    => clk,
         rst    => rst);

   -- Slave Port Mapping
   sData(0)                 <= eqInt;
   sData(1)                 <= gtInt;
   sData(2)                 <= gtEqInt;
   sData(3)                 <= lsInt;
   sData(4)                 <= lsEqInt;
   sData(PIPE_AOUT_RANGE_C) <= r.aout;
   sData(PIPE_BOUT_RANGE_C) <= r.bout;

   -- Master Port Mapping
   eq   <= mData(0);
   gt   <= mData(1);
   gtEq <= mData(2);
   ls   <= mData(3);
   lsEq <= mData(4);
   aout <= mData(PIPE_AOUT_RANGE_C);
   bout <= mData(PIPE_BOUT_RANGE_C);

end rtl;
