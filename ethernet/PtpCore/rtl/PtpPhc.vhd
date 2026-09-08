-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP numerical clock with atomic commands and capture invalidation
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
use surf.PtpPkg.all;

entity PtpPhc is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      clk           : in  sl;
      rst           : in  sl;
      monotonic     : in  sl                := '1';
      command       : in  PtpPhcCommandType := PTP_PHC_COMMAND_INIT_C;
      commandValid  : in  sl                := '0';
      clearValid    : in  sl                := '0';
      commandCancel : in  sl                := '0';
      commandReady  : out sl;
      phcTime       : out PtpTimeType;
      status        : out PtpPhcStatusType;
      pps           : out sl;
      captureAbort  : out sl);
end entity PtpPhc;

architecture rtl of PtpPhc is

   constant NOMINAL_C : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));
   constant SECOND_C  : signed(66 downto 0) := shift_left(to_signed(1000000000, 67), 32);

   type RegType is record
      timeValue : PtpTimeType;
      status    : PtpPhcStatusType;
      command   : PtpPhcCommandType;
      pending   : sl;
      ppsEnable : sl;
      pps       : sl;
   end record;

   constant REG_INIT_C : RegType := (
      timeValue => PTP_TIME_INIT_C,
      status    => PTP_PHC_STATUS_INIT_C,
      command   => PTP_PHC_COMMAND_INIT_C,
      pending   => '0',
      ppsEnable => '0',
      pps       => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert NOMINAL_C > 0 and NOMINAL_C < unsigned(SECOND_C)
      report "PHC nominal increment must be positive and below one second" severity failure;

   comb : process (r, rst, command, commandValid, commandCancel, clearValid, monotonic) is
      variable v             : RegType;
      variable ns            : signed(66 downto 0);
      variable sec           : signed(65 downto 0);
      variable increment     : signed(64 downto 0);
      variable nextIncrement : signed(64 downto 0);
      variable rejectCommand : boolean;
      variable jump          : boolean;
      variable abortNow      : sl;
   begin
      v := r;

      v.status.ack           := '0';
      v.status.error         := '0';
      v.status.discontinuity := '0';
      v.pps                  := '0';
      abortNow               := r.status.fault;
      increment              := signed('0' & slv(NOMINAL_C)) + resize(signed(r.status.rate), 65);
      v.status.increment     := slv(increment(63 downto 0));
      v.status.ticks         := slv(unsigned(r.status.ticks) + 1);
      ns                     := signed(resize(unsigned(slv'(r.timeValue.nanoseconds & r.timeValue.fraction)), 67)) + resize(increment, 67);
      sec                    := signed(resize(unsigned(r.timeValue.seconds), 66));
      if ns >= SECOND_C then
         ns    := ns - SECOND_C;
         sec   := sec + 1;
         v.pps := r.ppsEnable and r.status.timeValid;
      end if;

      -- The registered command commits against normally advanced time. A rate
      -- replacement affects the next tick; absolute set names this commit edge.
      rejectCommand := false;
      jump          := false;
      if r.pending = '1' then
         v.pending    := '0';
         v.status.ack := '1';
         if commandCancel = '1' or r.command.generation /= r.status.generation or r.status.fault = '1' then
            rejectCommand := true;
         else
            case r.command.kind is
               when PTP_CMD_SET_C =>
                  if unsigned(r.command.setTime.nanoseconds) >= 1000000000 or
                     (monotonic = '1' and r.status.timeValid = '1') then
                     rejectCommand := true;
                  else
                     sec  := signed(resize(unsigned(r.command.setTime.seconds), 66));
                     ns   := signed(resize(unsigned(slv'(r.command.setTime.nanoseconds & r.command.setTime.fraction)), 67));
                     jump := true;
                  end if;
               when PTP_CMD_PHASE_C =>
                  if abs(resize(signed(r.command.phaseFraction), 67)) >= SECOND_C or
                     (monotonic = '1' and r.status.timeValid = '1' and
                      (signed(r.command.phaseSeconds) < 0 or
                       (signed(r.command.phaseSeconds) = 0 and signed(r.command.phaseFraction) < 0))) then
                     rejectCommand := true;
                  else
                     sec := sec + resize(signed(r.command.phaseSeconds), 66);
                     ns  := ns + resize(signed(r.command.phaseFraction), 67);
                     if ns < 0 then
                        ns  := ns + SECOND_C;
                        sec := sec - 1;
                     elsif ns >= SECOND_C then
                        ns  := ns - SECOND_C;
                        sec := sec + 1;
                     end if;
                     jump := true;
                  end if;
               when PTP_CMD_RATE_C =>
                  nextIncrement := signed('0' & slv(NOMINAL_C)) + resize(signed(r.command.rate), 65);
                  if nextIncrement <= 0 or nextIncrement >= SECOND_C then
                     rejectCommand := true;
                  else
                     v.status.rate      := r.command.rate;
                     v.status.increment := slv(nextIncrement(63 downto 0));
                  end if;
               when PTP_CMD_VALID_C =>
                  v.status.timeValid := r.command.value;
               when PTP_CMD_PPS_C =>
                  v.ppsEnable := r.command.value;
               when others =>
 rejectCommand := true;
            end case;
         end if;
         if rejectCommand then
            v.status.error := '1';
         end if;
      end if;
      if jump then
         abortNow               := '1';
         v.pps                  := '0';
         v.status.timeValid     := '0';
         v.status.discontinuity := '1';
         if unsigned(r.status.generation) = x"FFFFFFFF" then
            v.status.fault := '1';
            v.status.error := '1';
         else
            v.status.generation := slv(unsigned(r.status.generation) + 1);
         end if;
      end if;
      -- A malformed epoch cannot wrap into a plausible timestamp. Keep the last
      -- representable time on fatal overflow and prohibit further commands.
      if sec < 0 or shift_right(sec, 48) /= 0 or unsigned(r.status.ticks) = x"FFFFFFFFFFFFFFFF" then
         v.status.fault := '1';
         v.status.error := '1';
         v.status.ticks := r.status.ticks;
      end if;
      if v.status.fault = '1' then
         v.timeValue        := r.timeValue;
         v.status.timeValid := '0';
         v.pps              := '0';
         abortNow           := '1';
      else
         v.timeValue.seconds     := slv(sec(47 downto 0));
         v.timeValue.nanoseconds := slv(ns(63 downto 32));
         v.timeValue.fraction    := slv(ns(31 downto 0));
      end if;
      if clearValid = '1' then
         v.status.timeValid := '0';
      end if;
      -- Revocation wins over a natural rollover on this edge. Never publish a
      -- PPS alongside invalid time or after a committing PPS-disable command.
      if v.status.timeValid = '0' or v.ppsEnable = '0' then
         v.pps := '0';
      end if;
      -- No fallthrough: the input is accepted only while the command slot was
      -- empty before this edge. Producers hold the complete record until ready.
      if r.pending = '0' and r.status.fault = '0' and commandCancel = '0' and commandValid = '1' then
         v.command := command;
         v.pending := '1';
      end if;
      if RST_ASYNC_G = false and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin          <= v;
      commandReady <= not r.pending and not r.status.fault and not commandCancel;
      if rst = RST_POLARITY_G then
         abortNow     := '1';
         commandReady <= '0';
      end if;
      captureAbort <= abortNow;
      phcTime      <= r.timeValue;
      status       <= r.status;
      -- Increment is combinational from registered rate so it is canonical even
      -- during initial reset recovery, before the first ordinary PHC tick.
      status.increment <= slv(increment(63 downto 0));
      pps              <= r.pps;
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
