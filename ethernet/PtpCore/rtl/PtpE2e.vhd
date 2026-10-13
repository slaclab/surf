-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rate-corrected end-to-end PTP path-delay arithmetic.
--
-- Consumes an associated Sync sample and completed Delay_Req/Delay_Resp sample
-- from PtpProtocolEngine. These supply master timestamps t1/t4, correction fields and
-- local RX/TX captures t2/t3. A qualified Q48 master-nanoseconds-per-raw-cycle
-- ratio converts the raw tick/phase separation between t2 and t3 into master
-- elapsed time, avoiding an assumption that the steered PHC rate stayed
-- constant during the exchange.
--
-- The endpoint-owned word processor holds all working values. Input valid
-- reserves this sequencer while its producer holds the sample; inputReady
-- acknowledges the completed word upload. No duplicate sample or wide arithmetic
-- staging is retained here. The producer may change operands after that edge.
-- A single registered publication record holds the completed result.
--
-- Zero calibration skips its work; nonzero planes use their own captured
-- increment. Timestamp/correction additions intentionally wrap signed128, while
-- products/divisions remain checked. Cancellation invalidates only this owner's
-- workspace and publication, independently of unrelated arithmetic and PHC ticks.
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
use surf.PtpComputePkg.all;

entity PtpE2e is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0');
      NORMALIZED_SYNC_G : boolean          := false);
   port (
      clk    : in  sl;
      rst    : in  sl;
      cancel : in  sl;
      -- Private history stream: words 0..3 forward, 4..7 corrected Sync Q16.
      -- Accepted words occupy this owner's workspace until input/result release.
      normalizedValid : in sl               := '0';
      normalizedReady : out sl;
      normalizedWord  : in slv(2 downto 0)  := (others => '0');
      normalizedData  : in slv(31 downto 0) := (others => '0');
      inputValid      : in  sl;
      inputReady      : out sl;
      syncSample      : in  PtpSyncSampleType;
      delaySample     : in  PtpDelaySampleType;
      ratio           : in  slv(63 downto 0);
      maxPathDelay    : in  slv(63 downto 0);
      resultValue     : out PtpMeasurementType;
      -- Registered valid; transfer requires valid/ready high and cancel/reset inactive.
      resultValid   : out sl;
      resultReady   : in  sl;
      resultError   : out sl;
      computeMaster : out PtpComputeMasterType;
      computeSlave  : in PtpComputeSlaveType);
end entity PtpE2e;

architecture rtl of PtpE2e is

   -- Workspace slots: normalized timestamps replace their seconds operands.
   constant LOCAL_C : natural := 0;
   constant LOCAL_NS_C : natural := 1;
   constant SYNC_C : natural := 2;
   constant SYNC_NS_C : natural := 3;
   constant REMOTE_C : natural := 4;
   constant REMOTE_NS_C : natural := 5;
   constant SYNC_CORRECTION_C : natural := 6;
   constant DELAY_CORRECTION_C : natural := 7;
   constant ELAPSED_C : natural := 8;
   constant FORWARD_C : natural := 9;
   constant RATIO_C : natural := 10;
   constant RX_INCREMENT_C : natural := 11;
   constant TX_INCREMENT_C : natural := 12;
   constant MAXIMUM_C : natural := 13;
   constant TEMP_C : natural := 14;
   constant REMAINDER_C : natural := 15;
   constant INPUT_WORDS_C : positive := 4*TEMP_C;
   constant ELAPSED_SHIFT_C : natural := PTP_TICK_PHASE_BITS_C+PTP_RATIO_FRAC_BITS_C-PTP_TIME_FRAC_BITS_C;
   type StateType is (
      IDLE_S, LOAD_S, ACCEPT_S, PLAN_S, CONSTANT_S,
      ISSUE_S, WAIT_S, READ_S, READ_WAIT_S, DONE_S);

   type RegType is record
      inputReady  : sl;
      state       : StateType;
      compute     : PtpComputeMasterType;
      wordIndex   : natural range 0 to INPUT_WORDS_C-1;
      step        : natural range 0 to 26;
      checked     : boolean;
      resultValue : PtpMeasurementType;
      resultValid : sl;
      error       : sl;
   end record;

   constant REG_INIT_C : RegType := (
      inputReady  => '0',
      state       => IDLE_S,
      compute     => PTP_COMPUTE_MASTER_INIT_C,
      wordIndex   => 0,
      step        => 0,
      checked     => false,
      resultValue => PTP_MEASUREMENT_INIT_C,
      resultValid => '0',
      error       => '0');

   signal r : RegType := REG_INIT_C;
   signal rin : RegType;
   -- Only wiring/sign extension and word selection; all numerical conversion
   -- and elapsed arithmetic runs in the shared processor.
   function inputWord (
      syncValue  : PtpSyncSampleType;
      delayValue : PtpDelaySampleType;
      ratioValue : slv(63 downto 0);
      maximum    : slv(63 downto 0);
      index      : natural) return slv is
      variable value : slv(127 downto 0) := (others => '0');
   begin

      case index/4 is
         when LOCAL_C =>
            value(47 downto 0) := syncValue.capture.timestamp(95 downto 48);
         when LOCAL_NS_C =>
            value(47 downto 0) := syncValue.capture.timestamp(47 downto 0);
         when SYNC_C =>
            value(47 downto 0) := syncValue.remoteTime(79 downto 32);
         when SYNC_NS_C =>
            value(47 downto 16) := syncValue.remoteTime(31 downto 0);
         when REMOTE_C =>
            value(47 downto 0) := delayValue.remoteTime(79 downto 32);
         when REMOTE_NS_C =>
            value(47 downto 16) := delayValue.remoteTime(31 downto 0);
         when SYNC_CORRECTION_C =>
            value := syncValue.correction;
         when DELAY_CORRECTION_C =>
            value := slv(resize(signed(delayValue.correction), 128));
         when ELAPSED_C =>
            value(66 downto 0) := syncValue.capture.ticks & syncValue.capture.tickPhase;
         when FORWARD_C =>
            value(66 downto 0) := delayValue.capture.ticks & delayValue.capture.tickPhase;
         when RATIO_C =>
            value(63 downto 0) := ratioValue;
         when RX_INCREMENT_C =>
            value(79 downto 16) := syncValue.capture.increment;
         when TX_INCREMENT_C =>
            value(79 downto 16) := delayValue.capture.increment;
         when MAXIMUM_C =>
            value := slv(resize(signed(maximum), 128));
         when others =>
            null;
      end case;

      return value(32*(index mod 4)+31 downto 32*(index mod 4));
   end function inputWord;

begin

   comb : process (all) is
      variable v             : RegType;
      variable constantValue : signed(127 downto 0);
      variable job           : PtpComputeJobType;
   begin
      v := r;
      v.inputReady := '0';
      v.compute.cancel := '0';
      v.compute.resultReady := '0';
      v.compute.readReady := '0';
      job := PTP_COMPUTE_JOB_INIT_C;
      job.remainder := toSlv(REMAINDER_C, 4);
      normalizedReady <= '0';
      constantValue := shift_left(to_signed(PTP_NANOSECONDS_PER_SECOND_C, 128), PTP_TIME_FRAC_BITS_C);

      if r.step = 11 then
         constantValue := resize(signed(INGRESS_LATENCY_G), 128);
      elsif r.step = 15 then
         constantValue := resize(signed(EGRESS_LATENCY_G), 128);
      elsif r.step = 24 then
         constantValue := (others => '0');
      end if;

      case r.state is
         when IDLE_S =>

            if NORMALIZED_SYNC_G and normalizedValid = '1' then
               if r.compute.memValid = '0' then
                  v.compute.memValid := '1';
                  v.compute.memWrite := '1';
                  v.compute.memWord := toSlv(to_integer(unsigned(normalizedWord)),6);
                  if normalizedWord(2) = '1' then
                     v.compute.memWord := toSlv(8+to_integer(unsigned(normalizedWord(1 downto 0))),6);
                  end if;
                  v.compute.memData := normalizedData;
               elsif computeSlave.memReady = '1' then
                  v.compute.memValid := '0';
                  normalizedReady <= '1';
               end if;
            end if;

            if inputValid = '1' and r.compute.cancel = '0' then
               v.resultValue := PTP_MEASUREMENT_INIT_C;
               v.error := '0';
               v.wordIndex := 0;
               v.step := 0;
               if NORMALIZED_SYNC_G then
                  v.wordIndex := 16;
                  v.step := 5;
               end if;
               v.state := LOAD_S;
               if unsigned(ratio) = 0 or unsigned(syncSample.capture.increment) = 0 or
                  unsigned(delaySample.capture.increment) = 0 or
                  syncSample.capture.generation /= delaySample.generation then
                  v.inputReady := '1';
                  v.error := '1';
                  v.resultValid := '1';
                  v.state := DONE_S;
               end if;
            end if;

         when LOAD_S =>

            if r.compute.memValid = '0' then
               v.compute.memValid := '1';
               v.compute.memWrite := '1';
               v.compute.memWord := toSlv(r.wordIndex, 6);
               v.compute.memData := inputWord(syncSample, delaySample, ratio, maxPathDelay, r.wordIndex);
            elsif computeSlave.memReady = '1' then
               v.compute.memValid := '0';
               if r.wordIndex = INPUT_WORDS_C-1 then
                  v.state := ACCEPT_S;
               else
                  v.wordIndex := r.wordIndex+1;
               end if;
            end if;

         when ACCEPT_S =>
            v.inputReady := '1';

            if inputValid = '1' then
               v.resultValue.isDelay := '1';
               v.resultValue.generation := delaySample.generation;
               v.resultValue.ticks := delaySample.capture.ticks;
               v.resultValue.syncSequence := syncSample.sequenceId;
               v.resultValue.delaySequence := delaySample.sequenceId;
               v.resultValue.ratio := ratio;
               v.resultValue.ratioValid := '1';
               v.wordIndex := 0;
               v.state := CONSTANT_S;
            end if;

         when CONSTANT_S =>

            if r.compute.memValid = '0' then
               v.compute.memValid := '1';
               v.compute.memWrite := '1';
               v.compute.memWord := toSlv(4*TEMP_C+r.wordIndex, 6);
               v.compute.memData := slv(constantValue(32*r.wordIndex+31 downto 32*r.wordIndex));
            elsif computeSlave.memReady = '1' then
               v.compute.memValid := '0';
               if r.wordIndex = 3 then
                  v.state := PLAN_S;
                  if r.step = 11 or r.step = 15 or r.step = 24 then
                     v.step := r.step+1;
                  end if;
               else
                  v.wordIndex := r.wordIndex+1;
               end if;
            end if;

         when PLAN_S =>
            v.checked := false;
            v.state := ISSUE_S;

            case r.step is
               when 0 =>
                  job := ptpComputeJob(PTP_COMPUTE_MUL_C, LOCAL_C, TEMP_C, LOCAL_C, REMAINDER_C);
               when 1 =>
                  job := ptpComputeJob(PTP_COMPUTE_ADD_C, LOCAL_C, LOCAL_NS_C, LOCAL_C, REMAINDER_C);
               when 2 =>
                  job := ptpComputeJob(PTP_COMPUTE_MUL_C, SYNC_C, TEMP_C, SYNC_C, REMAINDER_C);
               when 3 =>
                  job := ptpComputeJob(PTP_COMPUTE_ADD_C, SYNC_C, SYNC_NS_C, SYNC_C, REMAINDER_C);
               when 4 =>
                  job := ptpComputeJob(PTP_COMPUTE_ADD_C, SYNC_C, SYNC_CORRECTION_C, SYNC_C, REMAINDER_C);
               when 5 =>
                  job := ptpComputeJob(PTP_COMPUTE_MUL_C, REMOTE_C, TEMP_C, REMOTE_C, REMAINDER_C);
               when 6 =>
                  job := ptpComputeJob(PTP_COMPUTE_ADD_C, REMOTE_C, REMOTE_NS_C, REMOTE_C, REMAINDER_C);
               when 7 =>
                  job := ptpComputeJob(PTP_COMPUTE_SUB_C, REMOTE_C, DELAY_CORRECTION_C, REMOTE_C, REMAINDER_C);
               when 8 =>
                  job := ptpComputeJob(PTP_COMPUTE_SUB_C, FORWARD_C, ELAPSED_C, ELAPSED_C, REMAINDER_C);
               when 9 =>
                  job := ptpComputeJob(PTP_COMPUTE_MUL_C, ELAPSED_C, RATIO_C, ELAPSED_C, REMAINDER_C);
                  v.checked := true;
               when 10 =>
                  job := ptpComputeJob(PTP_COMPUTE_SHR_C, ELAPSED_C, 0, ELAPSED_C, REMAINDER_C, ELAPSED_SHIFT_C, '1');
               when 11 | 15 | 24 =>
                  v.wordIndex := 0;
                  v.state := CONSTANT_S;

                  if r.step = 11 and signed(INGRESS_LATENCY_G) = 0 then
                     v.step := 15;
                     v.state := PLAN_S;
                  elsif r.step = 15 and signed(EGRESS_LATENCY_G) = 0 then
                     v.step := 19;
                     v.state := PLAN_S;
                  end if;

               when 12 | 16 =>
                  job := ptpComputeJob(PTP_COMPUTE_MUL_C, TEMP_C, RATIO_C, TEMP_C, REMAINDER_C);
                  v.checked := true;
               when 13 =>
                  job := ptpComputeJob(PTP_COMPUTE_DIV_C, TEMP_C, RX_INCREMENT_C, TEMP_C, REMAINDER_C, 0, '1');
                  v.checked := true;
               when 17 =>
                  job := ptpComputeJob(PTP_COMPUTE_DIV_C, TEMP_C, TX_INCREMENT_C, TEMP_C, REMAINDER_C, 0, '1');
                  v.checked := true;
               when 14 | 18 =>
                  job := ptpComputeJob(PTP_COMPUTE_ADD_C, ELAPSED_C, TEMP_C, ELAPSED_C, REMAINDER_C);
               when 19 =>
                  job := ptpComputeJob(PTP_COMPUTE_SUB_C, LOCAL_C, SYNC_C, FORWARD_C, REMAINDER_C);

                  if NORMALIZED_SYNC_G then
                     job := ptpComputeJob(PTP_COMPUTE_COPY_C, LOCAL_C, 0, FORWARD_C, REMAINDER_C);
                  end if;

               when 20 =>
                  job := ptpComputeJob(PTP_COMPUTE_SUB_C, REMOTE_C, SYNC_C, REMOTE_C, REMAINDER_C);
               when 21 =>
                  job := ptpComputeJob(PTP_COMPUTE_SUB_C, REMOTE_C, ELAPSED_C, ELAPSED_C, REMAINDER_C);
               when 22 =>
                  job := ptpComputeJob(PTP_COMPUTE_SHR_C, ELAPSED_C, 0, ELAPSED_C, REMAINDER_C, 1, '1');
               when 23 =>
                  job := ptpComputeJob(PTP_COMPUTE_CMP_C, MAXIMUM_C, ELAPSED_C, TEMP_C, REMAINDER_C);
               when 25 =>
                  job := ptpComputeJob(PTP_COMPUTE_CMP_C, ELAPSED_C, TEMP_C, TEMP_C, REMAINDER_C);
               when 26 =>
                  v.wordIndex := 0;
                  v.state := READ_S;
            end case;

            if v.state = ISSUE_S then
               v.compute.job := job;
               v.compute.jobValid := '1';
            end if;

         when ISSUE_S =>

            if computeSlave.jobReady = '1' then
               v.compute.jobValid := '0';
               v.state := WAIT_S;
            end if;

         when WAIT_S =>

            if computeSlave.resultValid = '1' then
               v.compute.resultReady := '1';
               v.step := r.step+1;
               v.state := PLAN_S;
               if r.checked and computeSlave.resultError = '1' then
                  v.error := '1';
                  v.resultValid := '1';
                  v.state := DONE_S;
               elsif (r.step = 23 or r.step = 25) and computeSlave.resultLess = '1' then
                  v.error := '1';
               end if;
            end if;

         when READ_S =>
            v.compute.memWrite := '0';
            v.compute.memValid := '1';
            v.compute.memWord := toSlv(4*FORWARD_C+r.wordIndex, 6);

            if r.wordIndex >= 4 then
               v.compute.memWord := toSlv(4*ELAPSED_C+r.wordIndex-4, 6);
            end if;

            if r.compute.memValid = '1' and computeSlave.memReady = '1' then
               v.compute.memValid := '0';
               v.compute.readReady := '1';
               v.state := READ_WAIT_S;
            end if;

         when READ_WAIT_S =>
            v.compute.readReady := '1';

            if computeSlave.readValid = '1' then
               if r.wordIndex < 4 then
                  v.resultValue.forward(32*r.wordIndex+31 downto 32*r.wordIndex) := computeSlave.readData;
               else
                  v.resultValue.delayValue(32*(r.wordIndex-4)+31 downto 32*(r.wordIndex-4)) := computeSlave.readData;
               end if;
               if r.wordIndex = 7 then
                  v.resultValid := '1';
                  v.state := DONE_S;
               else
                  v.wordIndex := r.wordIndex+1;
                  v.state := READ_S;
               end if;
            end if;

         when DONE_S =>

            if resultReady = '1' then
               v.resultValid := '0';
               v.state := IDLE_S;
            end if;

      end case;

      if cancel = '1' or rst = RST_POLARITY_G then
         normalizedReady <= '0';
      end if;

      if cancel = '1' then
         v := REG_INIT_C;
         v.compute.cancel := '1';
      end if;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
      computeMaster <= r.compute;
      inputReady <= v.inputReady;
      resultValue <= r.resultValue;
      resultValid <= r.resultValid;
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
