-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Serialized rate-corrected PTP E2E arithmetic and reference-plane conversion
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

entity PtpE2e is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk          : in  sl;
      rst          : in  sl;
      cancel       : in  sl;
      inputValid   : in  sl;
      inputReady   : out sl;
      syncSample   : in  PtpSyncSampleType;
      delaySample  : in  PtpDelaySampleType;
      ratio        : in  slv(63 downto 0);
      maxPathDelay : in  slv(63 downto 0);
      resultValue  : out PtpMeasurementType;
      resultValid  : out sl;
      resultReady  : in  sl;
      resultError  : out sl);
end entity PtpE2e;

architecture rtl of PtpE2e is

   type StateType is (
      IDLE_S,
      ISSUE_S,
      WAIT_S,
      DONE_S);

   type RegType is record
      state       : StateType;
      operation   : natural range 0 to 4;
      a           : slv(127 downto 0);
      b           : slv(127 downto 0);
      divide      : sl;
      elapsed     : signed(127 downto 0);
      syncSample  : PtpSyncSampleType;
      delaySample : PtpDelaySampleType;
      ratio       : slv(63 downto 0);
      maximum     : slv(63 downto 0);
      resultValue : PtpMeasurementType;
      error       : sl;
   end record;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      operation   => 0,
      a           => (others => '0'),
      b           => (others => '0'),
      divide      => '0',
      elapsed     => (others => '0'),
      syncSample  => PTP_SYNC_SAMPLE_INIT_C,
      delaySample => PTP_DELAY_SAMPLE_INIT_C,
      ratio       => (others => '0'),
      maximum     => (others => '0'),
      resultValue => PTP_MEASUREMENT_INIT_C,
      error       => '0');

   signal r          : RegType := REG_INIT_C;
   signal rin        : RegType;
   signal mathInput  : sl;
   signal mathReady  : sl;
   signal mathValid  : sl;
   signal mathResult : slv(127 downto 0);
   signal mathError  : sl;

begin

   mathInput <= '1' when r.state = ISSUE_S else '0';

   U_Math : entity surf.PtpMath
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk             => clk,         -- [in]
         rst             => rst,         -- [in]
         cancel          => cancel,      -- [in]
         inputValid      => mathInput,   -- [in]
         inputReady      => mathReady,   -- [out]
         divide          => r.divide,    -- [in]
         roundNearest    => '1',         -- [in]
         operandA        => r.a,         -- [in]
         operandB        => r.b,         -- [in]
         resultValid     => mathValid,   -- [out]
         resultReady     => '1',         -- [in]
         resultValue     => mathResult,  -- [out]
         resultRemainder => open,        -- [out]
         resultError     => mathError);  -- [out]

   comb : process (r, rst, cancel, inputValid, syncSample, delaySample, ratio, maxPathDelay,
                   resultReady, mathReady, mathValid, mathResult, mathError) is
      variable v          : RegType;
      variable delayValue : signed(127 downto 0);
   begin
      v := r;

      case r.state is
         when IDLE_S =>
            if inputValid = '1' then
               v             := REG_INIT_C;
               v.syncSample  := syncSample;
               v.delaySample := delaySample;
               v.ratio       := ratio;
               v.maximum     := maxPathDelay;
               v.a           := slv(ptpTickPhase(delaySample.capture)-ptpTickPhase(syncSample.capture));
               v.b           := slv(resize(unsigned(ratio), 128));
               v.state       := ISSUE_S;
               if unsigned(ratio) = 0 or unsigned(syncSample.capture.increment) = 0 or
                  unsigned(delaySample.capture.increment) = 0 or
                  syncSample.capture.generation /= delaySample.generation then
                  v.error := '1';
                  v.state := DONE_S;
               end if;
            end if;
         when ISSUE_S =>
            if mathReady = '1' then
               v.state := WAIT_S;
            end if;
         when WAIT_S =>
            if mathValid = '1' then
               v.state := ISSUE_S;
               if mathError = '1' then
                  v.error := '1';
                  v.state := DONE_S;
               else
                  case r.operation is
                     when 0 =>
                        -- Q3 raw cycles times Q48 ns/cycle -> Q16 nanoseconds.
                        v.elapsed   := ptpRoundShift(signed(mathResult), 35);
                        v.a         := slv(resize(signed(INGRESS_LATENCY_G), 128));
                        v.b         := slv(resize(unsigned(r.ratio), 128));
                        v.operation := 1;
                     when 1 =>
                        v.a         := mathResult;
                        v.b         := slv(shift_left(resize(unsigned(r.syncSample.capture.increment), 128), 16));
                        v.divide    := '1';
                        v.operation := 2;
                     when 2 =>
                        -- Calibration is in local PHC ns. Convert each plane
                        -- displacement with that capture's actual PHC increment,
                        -- including a rate replacement between RX and TX.
                        v.elapsed   := r.elapsed + signed(mathResult);
                        v.a         := slv(resize(signed(EGRESS_LATENCY_G), 128));
                        v.b         := slv(resize(unsigned(r.ratio), 128));
                        v.divide    := '0';
                        v.operation := 3;
                     when 3 =>
                        v.a         := mathResult;
                        v.b         := slv(shift_left(resize(unsigned(r.delaySample.capture.increment), 128), 16));
                        v.divide    := '1';
                        v.operation := 4;
                     when 4 =>
                        v.elapsed                   := r.elapsed + signed(mathResult);
                        delayValue                  := ptpRoundShift(ptpWireTimeQ16(r.delaySample.remoteTime) -
                           resize(signed(r.delaySample.correction), 128) -
                           ptpWireTimeQ16(r.syncSample.remoteTime) - signed(r.syncSample.correction) - v.elapsed, 1);
                        v.resultValue.isDelay       := '1';
                        v.resultValue.generation    := r.delaySample.generation;
                        v.resultValue.ticks         := r.delaySample.capture.ticks;
                        v.resultValue.syncSequence  := r.syncSample.sequenceId;
                        v.resultValue.delaySequence := r.delaySample.sequenceId;
                        v.resultValue.forward       := slv(ptpTimeQ16(r.syncSample.capture.timestamp) -
                           ptpWireTimeQ16(r.syncSample.remoteTime) - signed(r.syncSample.correction));
                        v.resultValue.delayValue    := slv(delayValue);
                        v.resultValue.ratio         := r.ratio;
                        v.resultValue.ratioValid    := '1';
                        if delayValue < 0 or delayValue > signed(r.maximum) then
                           v.error := '1';
                        end if;
                        v.state := DONE_S;
                  end case;
               end if;
            end if;
         when DONE_S =>
            if resultReady = '1' then
               v.state := IDLE_S;
            end if;
      end case;
      if cancel = '1' or (not RST_ASYNC_G and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;
      rin         <= v;
      inputReady  <= '0';
      resultValid <= '0';
      if cancel = '0' and rst /= RST_POLARITY_G then
         if r.state = IDLE_S then
            inputReady <= '1';
         elsif r.state = DONE_S then
            resultValid <= '1';
         end if;
      end if;
      resultValue <= r.resultValue;
      resultError <= r.error;
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
