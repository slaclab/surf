-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Alpha update process
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

entity RoCEv2AlphaUpdate is
   generic (
      TPD_G          : time    := 1 ns;
      RST_ASYNC_G    : boolean := false;
      RST_POLARITY_G : sl      := '1'
   );
   port (
      clk              : in  sl;
      rst              : in  sl;
      -- Flags
      start            : in  sl;
      -- Regs
      curAlpha         : in  slv(9 downto 0);
      alphaG           : in  slv(9 downto 0);
      cnpDetected      : in  sl;
      alphaUpdInterval : in  slv(15 downto 0);
      -- Outputs
      newAlpha         : out slv(9 downto 0);
      valid            : out sl
      );
end entity RoCEv2AlphaUpdate;

architecture rtl of RoCEv2AlphaUpdate is

   type StateType is (
      IDLE_S,
      COUNTING_S,
      UPDATE_S);

   type RegType is record
      timer    : slv(15 downto 0);
      newAlpha : slv(9 downto 0);
      valid    : sl;
      state    : StateType;
   end record RegType;

   constant ONE_FP_C : std_logic_vector(10 downto 0) := "10000000000";  -- 1024

   constant REG_INIT_C : RegType := (
      timer    => (others => '0'),
      newAlpha => (others => '0'),
      valid    => '0',
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin  -- architecture rtl


   comb : process (AlphaG, alphaUpdInterval, cnpDetected, curAlpha, r, rst,
                   start) is
      variable v         : RegType;
      variable mult      : slv(19 downto 0);
      variable multS     : slv(19 downto 0);
      variable multRound : slv(19 downto 0);
      variable term2     : slv(10 downto 0);
   begin  -- process comb
      -- Latch the current value
      v       := r;
      -- Reset flags
      v.valid := '0';
      -- FSM
      case r.state is
         -------------------------------------------------------------------------
         when IDLE_S =>
            v.timer := (others => '0');
            if start = '1' then
               v.state := COUNTING_S;
            end if;
         -----------------------------------------------------------------------
         when COUNTING_S =>
            v.timer := r.timer + 1;
            if r.timer >= alphaUpdInterval then
               v.state := UPDATE_S;
            end if;
         -----------------------------------------------------------------------
         when UPDATE_S =>
            if cnpDetected = '1' then
               mult               := curAlpha * AlphaG;
               -- multS     := mult srl 10;
               -- multS := (mult + 512) srl 10;  -- add 0.5 in Q0.10 before shifting
               multRound         := mult + 512;
               multS             := (others => '0');
               multS(9 downto 0) := multRound(19 downto 10);
               term2              := ONE_FP_C - AlphaG;
               v.newAlpha         := multS(9 downto 0) + term2(9 downto 0);
            else
               mult               := curAlpha * AlphaG;
               -- multS     := mult srl 10;
               -- multS := (mult + 512) srl 10;  -- add 0.5 in Q0.10 before shifting
               multRound         := mult + 512;
               multS             := (others => '0');
               multS(9 downto 0) := multRound(19 downto 10);
               v.newAlpha         := multS(9 downto 0);
            end if;
            v.valid := '1';
            v.timer := (others => '0');
            v.state := COUNTING_S;
      -----------------------------------------------------------------------
      end case;

      -- Outputs
      newAlpha <= r.newAlpha;
      valid    <= r.valid;

      -- Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register update
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

end architecture rtl;
