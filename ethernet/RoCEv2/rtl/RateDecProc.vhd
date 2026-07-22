-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rate decrement process
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

entity RateDecProc is
  generic (
    TPD_G          : time    := 1 ns;
    RST_ASYNC_G    : boolean := false;
    RST_POLARITY_G : sl      := '1'
    );
  port (
    clk             : in  sl;
    rst             : in  sl;
    -- Flags
    start           : in  sl;
    cnpDetected     : in  sl;
    -- Regs
    clampTgtRate    : in  sl;
    alpha           : in  slv(9 downto 0);
    dec_gain        : in  slv(3 downto 0);
    Rmin            : in  slv(31 downto 0);
    rateDecInterval : in  slv(15 downto 0);
    timeStage       : in  slv(7 downto 0);
    curRc           : in  slv(31 downto 0);
    curRt           : in  slv(31 downto 0);
    -- Outputs
    newRc           : out slv(31 downto 0);
    newRt           : out slv(31 downto 0);
    valid           : out sl
    );
end entity RateDecProc;

architecture rtl of RateDecProc is

  type StateType is (
    IDLE_S,
    COUNTING_S,
    UPDATE1_S,
    UPDATE2_S);

  type RegType is record
    timer     : slv(15 downto 0);
    newRc     : slv(31 downto 0);
    newRt     : slv(31 downto 0);
    doUpdate  : sl;
    mult      : slv(41 downto 0);
    shift_val : integer;
    valid     : sl;
    state     : StateType;
  end record RegType;

  constant REG_INIT_C : RegType := (
    timer     => (others => '0'),
    newRc     => (others => '0'),
    newRt     => (others => '0'),
    doUpdate  => '0',
    mult      => (others => '0'),
    shift_val => 0,
    valid     => '0',
    state     => IDLE_S);

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- architecture rtl

  comb : process (Rmin, alpha, clampTgtRate, cnpDetected, curRc, curRt,
                  dec_gain, r, rateDecInterval, rst, start, timeStage) is
    variable v         : RegType;
    variable clamp     : boolean;
    variable shifted   : slv(41 downto 0);
    variable delta     : slv(31 downto 0);
  begin  -- process comb
    -- Latch the current value
    v       := r;
    -- Reset flags
    v.valid := '0';
    clamp   := true;
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
        if r.timer >= rateDecInterval then
          v.state := UPDATE1_S;
        end if;
      -----------------------------------------------------------------------
      when UPDATE1_S =>
        if cnpDetected = '1' then
          -- Compute target rate
          if clampTgtRate = '0' and timeStage = x"00" then
            clamp := false;
          end if;
          if clamp then
            v.newRt := curRc;
          else
            v.newRt := curRt;
          end if;
          -- Multiply only (heavy op)
          v.mult      := curRc * alpha;
          -- store shift value if needed
          v.shift_val := conv_integer(dec_gain) + 10;
          v.doUpdate  := '1';
        else
          v.doUpdate := '0';
        end if;
        v.state := UPDATE2_S;
      -----------------------------------------------------------------------
      when UPDATE2_S =>
        if r.doUpdate = '1' then
          -- shift
          shifted                                      := (others => '0');
          shifted(shifted'high - r.shift_val downto 0) := r.mult(shifted'high downto r.shift_val);
          delta                                        := shifted(31 downto 0);
          -- subtraction
          v.newRc                                      := curRc - delta;
          if v.newRc < Rmin then
            v.newRc := Rmin;
          end if;
          v.valid := '1';
        end if;
        v.timer := (others => '0');
        v.state := COUNTING_S;
    -----------------------------------------------------------------------
    end case;

    -- Outputs
    newRc <= r.newRc;
    newRt <= r.newRt;
    valid <= r.valid;

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
