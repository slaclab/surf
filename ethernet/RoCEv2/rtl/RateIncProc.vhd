-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rate increment process
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

entity RateIncProc is
   generic (
      TPD_G          : time    := 1 ns;
      LINE_RATE_G    : integer := 1_250_000_000;  -- 1.25 GB/s = 10 Gb/s
      RST_ASYNC_G    : boolean := false;
      RST_POLARITY_G : sl      := '1'
   );
   port (
      clk                : in  sl;
      rst                : in  sl;
      -- Flags
      start              : in  sl;
      rstTimers          : in  sl;
      rateIncInterval    : in  slv(31 downto 0);
      Rai                : in  slv(31 downto 0);
      Rhai               : in  slv(31 downto 0);
      curRc              : in  slv(31 downto 0);
      curRt              : in  slv(31 downto 0);
      timeStageThreshold : in  slv(7 downto 0);
      -- Outputs
      timeStage          : out slv(7 downto 0);
      newRc              : out slv(31 downto 0);
      newRt              : out slv(31 downto 0);
      valid              : out sl
      );
end entity RateIncProc;

architecture rtl of RateIncProc is

   type StateType is (
      IDLE_S,
      COUNTING_S,
      FAST_REC_S,
      ADDITIVE_INC_S,
      HYPER_INC_S);

   type RegType is record
      timer     : slv(31 downto 0);
      timeStage : slv(7 downto 0);
      newRc     : slv(31 downto 0);
      newRt     : slv(31 downto 0);
      valid     : sl;
      state     : StateType;
   end record RegType;

   constant LINE_RATE_SLV_C : slv(31 downto 0) := toSlv(LINE_RATE_G, 32);

   constant REG_INIT_C : RegType := (
      timer     => (others => '0'),
      timeStage => (others => '0'),
      newRc     => (others => '0'),
      newRt     => (others => '0'),
      valid     => '0',
      state     => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin  -- architecture rtl

   comb : process (Rai, Rhai, curRc, curRt, r, rateIncInterval, rst, rstTimers,
                   start, timeStageThreshold) is
      variable v : RegType;
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
            if r.timer > rateIncInterval then
               if r.timeStage < timeStageThreshold - 1 then
                  v.state := FAST_REC_S;
               elsif r.timeStage = timeStageThreshold - 1 then
                  v.state := ADDITIVE_INC_S;
               else
                  v.state := HYPER_INC_S;
               end if;
            else
               if rstTimers = '1' then
                  v.timer     := (others => '0');
                  v.timeStage := (others => '0');
               end if;
            end if;
         -----------------------------------------------------------------------
         when FAST_REC_S =>
            -- v.newRc     := (curRc srl 1) + (curRt srl 1);  -- Rc = Rc/2+Rt/2
            v.newRc     := ('0' & curRc(31 downto 1)) + ('0' & curRt(31 downto 1));  -- Rc = Rc/2 + Rt/2
            v.newRt     := curRt;
            v.valid     := '1';
            v.timeStage := r.timeStage + 1;
            v.timer     := (others => '0');
            v.state     := COUNTING_S;
         -----------------------------------------------------------------------
         when ADDITIVE_INC_S =>
            v.newRt := curRt + Rai;
            if v.newRt > LINE_RATE_SLV_C then
               v.newRt := LINE_RATE_SLV_C;
            end if;
            -- v.newRc     := (curRc srl 1) + (v.newRt srl 1);
            v.newRc     := ('0' & curRc(31 downto 1)) + ('0' & v.newRt(31 downto 1));
            v.valid     := '1';
            v.timeStage := r.timeStage + 1;
            v.timer     := (others => '0');
            v.state     := COUNTING_S;
         -----------------------------------------------------------------------
         when HYPER_INC_S =>
            v.newRt := curRt + Rhai;
            if v.newRt > LINE_RATE_SLV_C then
               v.newRt := LINE_RATE_SLV_C;
            end if;
            -- v.newRc := (curRc srl 1) + (v.newRt srl 1);
            v.newRc := ('0' & curRc(31 downto 1)) + ('0' & v.newRt(31 downto 1));
            v.valid := '1';
            v.timer := (others => '0');
            v.state := COUNTING_S;
      -----------------------------------------------------------------------
      end case;

      -- Outputs
      newRc     <= r.newRc;
      newRt     <= r.newRt;
      valid     <= r.valid;
      timeStage <= r.timeStage;

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
