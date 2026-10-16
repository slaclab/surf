-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Sync/Follow_Up table, duplicate policy and completed-sample ownership.
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
use surf.PtpProtocolPkg.all;
use surf.PtpPkg.all;
use surf.PtpSyncPkg.all;

entity PtpSyncPair is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false;
      MEMORY_TYPE_G  : string  := "block");
   port (
      clk    : in  sl;
      rst    : in  sl;
      cancel : in  sl;
      -- enable permits a new search; RX holds the message through result.done/take.
      enable          : in  sl;
      ticks           : in  slv(63 downto 0);
      rxMessageMaster : in  PtpRxMessageMasterType;
      admission       : in  PtpAdmissionType;
      -- A completion may have no sample (incomplete or rejected pair). The
      -- completed sample remains retained until enable permits another search.
      idle         : out sl;
      take         : in  sl;
      result       : out PtpSyncPairResultType;
      syncAdmitted : out sl;
      rejected     : out natural range 0 to 2;
      -- Held row request; consume the unbackpressured result on its valid edge.
      scanRequest : out PtpScanRequestType;
      scanResult  : in  PtpScanResultType);
end entity PtpSyncPair;

architecture rtl of PtpSyncPair is

   constant PAIR_DEPTH_C : positive := 4;
   -- Temporary decision flags only; payload fields stay in the pair word RAM.
   type PairType is record
      used       : sl;
      syncSeen   : sl;
      twoStep    : sl;                  -- Meaningful only after syncSeen.
      followSeen : sl;
      complete   : sl;
      sequenceId : slv(15 downto 0);
   end record;

   constant PAIR_INIT_C : PairType := (
      used       => '0',
      syncSeen   => '0',
      twoStep    => '0',
      followSeen => '0',
      complete   => '0',
      sequenceId => (others => '0'));

   constant PAIR_WORDS_C      : positive := 20;
   constant PAIR_ADDR_WIDTH_C : positive := log2(PAIR_DEPTH_C*PAIR_WORDS_C);
   type PairStateType is (
      PAIR_IDLE_S,
      PAIR_READ_S,
      PAIR_CHECK_S,
      PAIR_SCAN_S,
      PAIR_NEXT_S,
      PAIR_SELECT_S,
      PAIR_COMPARE_READ_S,
      PAIR_COMPARE_S,
      PAIR_DECIDE_S,
      PAIR_UPDATE_S,
      PAIR_PUBLISH_S,
      PAIR_PUBLISH_READ_S,
      PAIR_PUBLISH_CAPTURE_S,
      PAIR_ACK_S);

   type RegType is record
      pairState          : PairStateType;
      pairUsed       : slv(PAIR_DEPTH_C-1 downto 0);
      pairSyncSeen   : slv(PAIR_DEPTH_C-1 downto 0);
      pairTwoStep    : slv(PAIR_DEPTH_C-1 downto 0);
      pairFollowSeen : slv(PAIR_DEPTH_C-1 downto 0);
      pairComplete   : slv(PAIR_DEPTH_C-1 downto 0);
      pairIndex      : natural range 0 to PAIR_DEPTH_C-1;
      pairSlot           : integer range -1 to PAIR_DEPTH_C-1;
      pairMatch          : integer range -1 to PAIR_DEPTH_C-1;
      pairFree           : integer range -1 to PAIR_DEPTH_C-1;
      pairOldest         : integer range -1 to PAIR_DEPTH_C-1;
      pairOldestBorn     : slv(63 downto 0);
      pairTicks          : slv(63 downto 0);
      pairReadEnable     : sl;
      pairReadAddress    : slv(PAIR_ADDR_WIDTH_C-1 downto 0);
      pairWriteEnable    : sl;
      pairWriteAddress   : slv(PAIR_ADDR_WIDTH_C-1 downto 0);
      pairWriteData      : slv(31 downto 0);
      result             : PtpSyncPairResultType;
      pairWord           : natural range 0 to PAIR_WORDS_C-1;
      pairKey            : slv(15 downto 0);
      pairBorn           : slv(63 downto 0);
      pairNew            : sl;
      pairDuplicateEqual : sl;
      pairWriteSync      : sl;
      pairWriteFollow    : sl;
   end record;

   constant REG_INIT_C : RegType := (
      pairState          => PAIR_IDLE_S,
      pairUsed           => (others => '0'),
      pairSyncSeen       => (others => '0'),
      pairTwoStep        => (others => '0'),
      pairFollowSeen     => (others => '0'),
      pairComplete       => (others => '0'),
      pairIndex          => 0,
      pairSlot           => -1,
      pairMatch          => -1,
      pairFree           => -1,
      pairOldest         => -1,
      pairOldestBorn     => (others => '0'),
      pairTicks          => (others => '0'),
      pairReadEnable     => '0',
      pairReadAddress    => (others => '0'),
      pairWriteEnable    => '0',
      pairWriteAddress   => (others => '0'),
      pairWriteData      => (others => '0'),
      result             => PTP_SYNC_PAIR_RESULT_INIT_C,
      pairWord           => 0,
      pairKey            => (others => '0'),
      pairBorn           => (others => '0'),
      pairNew            => '0',
      pairDuplicateEqual => '1',
      pairWriteSync      => '0',
      pairWriteFollow    => '0');

   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;
   signal pairReadData : slv(31 downto 0);

begin

   assert MEMORY_TYPE_G = "distributed" or MEMORY_TYPE_G = "block"
      report "PtpSyncPair memory must be distributed or block" severity failure;
   idle                    <= toSl(r.pairState = PAIR_IDLE_S);
   result                  <= r.result;
   scanRequest.valid       <= toSl(r.pairState = PAIR_SCAN_S);
   scanRequest.ticks       <= r.pairTicks;
   scanRequest.rowTicks    <= r.pairBorn;
   scanRequest.best        <= x"0" & r.pairOldestBorn;
   scanRequest.rowPhase    <= (others => '0');
   scanRequest.targetTicks <= (others => '0');
   scanRequest.targetPhase <= (others => '0');

   U_PairRam : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         DATA_WIDTH_G   => 32,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
         ADDR_WIDTH_G   => PAIR_ADDR_WIDTH_C,
         SYNTH_MODE_G   => "inferred",
         COMMON_CLK_G   => true,
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,                 -- [in]
         wea   => r.pairWriteEnable,   -- [in]
         addra => r.pairWriteAddress,  -- [in]
         dina  => r.pairWriteData,     -- [in]
         clkb  => clk,                 -- [in]
         enb   => r.pairReadEnable,    -- [in]
         rstb  => rst,                 -- [in]
         addrb => r.pairReadAddress,   -- [in]
         doutb => pairReadData);       -- [out]

   comb : process (all) is
      variable v              : RegType;
      variable syncAdmission  : sl;
      variable rejectedEvents : natural range 0 to 2;
      variable malformed      : boolean;
      variable slot           : integer range -1 to PAIR_DEPTH_C-1;
      variable pair           : PairType;
      variable pairUpdated    : boolean;
      variable pairWord       : slv(31 downto 0);
      variable remoteTime     : slv(95 downto 0);
      variable inputSample    : PtpSyncSampleType;
   begin
      v                      := r;
      syncAdmission          := '0';
      rejectedEvents         := 0;
      pair                   := PAIR_INIT_C;
      pairUpdated            := false;
      pairWord               := (others => '0');
      remoteTime             := x"0000" & ptpMessageTimestamp(rxMessageMaster.data);
      inputSample            := PTP_SYNC_SAMPLE_INIT_C;
      inputSample.sequenceId := rxMessageMaster.data.sequenceId;
      inputSample.capture    := rxMessageMaster.data.capture;
      inputSample.remoteTime := ptpMessageTimestamp(rxMessageMaster.data);
      v.pairReadEnable       := '0';
      v.pairWriteEnable      := '0';
      case r.pairState is
         when PAIR_IDLE_S =>

            if enable = '1' and cancel = '0' and r.pairWriteEnable = '0' and
               rxMessageMaster.valid = '1' and (rxMessageMaster.data.messageType = PTP_MSG_SYNC_C or
               rxMessageMaster.data.messageType = PTP_MSG_FOLLOW_UP_C) then
               v.pairTicks          := ticks;
               v.pairIndex          := 0;
               v.pairWord           := 0;
               v.pairMatch          := -1;
               v.pairFree           := -1;
               v.pairOldest         := -1;
               v.result.sampleValid := '0';
               v.pairReadAddress    := (others => '0');
               v.pairReadEnable     := '1';
               v.pairState          := PAIR_READ_S;
            end if;

         when PAIR_READ_S =>
            v.pairState := PAIR_CHECK_S;
         when PAIR_CHECK_S =>

            case r.pairWord is
               when 0 =>
                  v.pairKey := pairReadData(15 downto 0);
               when 1 =>
                  v.pairBorn(31 downto 0) := pairReadData;
               when others =>
                  v.pairBorn(63 downto 32) := pairReadData;
            end case;

            if r.pairWord /= 2 then
               v.pairWord        := r.pairWord+1;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairIndex+r.pairWord+1, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable  := '1';
               v.pairState       := PAIR_READ_S;
            else
               v.pairState := PAIR_NEXT_S;
               if r.pairUsed(r.pairIndex) = '1' then
                  v.pairState := PAIR_SCAN_S;
               end if;
            end if;

         when PAIR_SCAN_S =>

            if scanResult.valid = '1' then
               if scanResult.expired = '1' then
                  v.pairUsed(r.pairIndex) := '0';
               else
                  if r.pairKey = rxMessageMaster.data.sequenceId then
                     v.pairMatch := r.pairIndex;
                  end if;
                  if r.pairComplete(r.pairIndex) = '1' and
                     (r.pairOldest = -1 or scanResult.better = '1') then
                     v.pairOldest     := r.pairIndex;
                     v.pairOldestBorn := r.pairBorn;
                  end if;
               end if;
               v.pairState := PAIR_NEXT_S;
            end if;

         when PAIR_NEXT_S =>

            if r.pairUsed(r.pairIndex) = '0' and r.pairFree = -1 then
               v.pairFree := r.pairIndex;
            end if;
            if r.pairIndex = PAIR_DEPTH_C-1 then
               v.pairState := PAIR_SELECT_S;
            else
               v.pairIndex       := r.pairIndex+1;
               v.pairWord        := 0;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*(r.pairIndex+1), PAIR_ADDR_WIDTH_C);
               v.pairReadEnable  := '1';
               v.pairState       := PAIR_READ_S;
            end if;

         when PAIR_SELECT_S =>
            v.pairSlot           := r.pairMatch;
            v.pairNew            := '0';
            v.pairDuplicateEqual := '1';
            v.pairWriteSync      := '0';
            v.pairWriteFollow    := '0';
            v.pairState          := PAIR_DECIDE_S;

            if r.pairMatch = -1 then
               v.pairNew  := '1';
               v.pairSlot := r.pairFree;
               if r.pairFree = -1 then
                  v.pairSlot := r.pairOldest;
               end if;
            elsif rxMessageMaster.data.messageType = PTP_MSG_FOLLOW_UP_C and r.pairFollowSeen(r.pairMatch) = '1' then
               -- Duplicate identity is checked without reconstructing the row.
               v.pairWord        := 5;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairMatch+5, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable  := '1';
               v.pairState       := PAIR_COMPARE_READ_S;
            end if;

         when PAIR_COMPARE_READ_S =>
            v.pairState := PAIR_COMPARE_S;
         when PAIR_COMPARE_S =>

            if r.pairWord <= 6 then
               pairWord := rxMessageMaster.data.correction(32*(r.pairWord-5)+31 downto 32*(r.pairWord-5));
            else
               pairWord := remoteTime(32*(r.pairWord-17)+31 downto 32*(r.pairWord-17));
            end if;

            v.pairDuplicateEqual := r.pairDuplicateEqual and toSl(pairWord = pairReadData);

            if r.pairWord = 19 then
               v.pairState := PAIR_DECIDE_S;
            else
               v.pairWord := r.pairWord+1;
               if r.pairWord = 6 then
                  v.pairWord := 17;
               end if;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairSlot+v.pairWord, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable  := '1';
               v.pairState       := PAIR_COMPARE_READ_S;
            end if;

         when PAIR_DECIDE_S =>
            v.pairState := PAIR_ACK_S;

            if r.pairSlot /= -1 and r.pairNew = '0' then
               pair.used       := '1';
               pair.sequenceId := rxMessageMaster.data.sequenceId;
               pair.syncSeen   := r.pairSyncSeen(r.pairSlot);
               pair.twoStep    := r.pairTwoStep(r.pairSlot);
               pair.followSeen := r.pairFollowSeen(r.pairSlot);
               pair.complete   := r.pairComplete(r.pairSlot);
            end if;

         when PAIR_UPDATE_S =>
            v.pairWriteEnable := r.pairNew;

            case r.pairWord is
               when 0 =>
                  pairWord(15 downto 0) := rxMessageMaster.data.sequenceId;
               when 1 to 2 =>
                  pairWord := r.pairTicks(32*(r.pairWord-1)+31 downto 32*(r.pairWord-1));
               when 3 to 4 =>

                  if r.pairWriteSync = '1' then
                     pairWord          := rxMessageMaster.data.correction(32*(r.pairWord-3)+31 downto 32*(r.pairWord-3));
                     v.pairWriteEnable := '1';
                  end if;

               when 5 to 6 =>

                  if r.pairWriteFollow = '1' then
                     if rxMessageMaster.data.messageType = PTP_MSG_FOLLOW_UP_C then
                        pairWord := rxMessageMaster.data.correction(32*(r.pairWord-5)+31 downto 32*(r.pairWord-5));
                     end if;
                     v.pairWriteEnable := '1';
                  end if;

               when 7 to 16 =>

                  if r.pairWriteSync = '1' then
                     pairWord          := syncWord(inputSample, r.pairWord-7);
                     v.pairWriteEnable := '1';
                  end if;

               when 17 to 19 =>

                  if r.pairWriteFollow = '1' then
                     pairWord          := syncWord(inputSample, r.pairWord-7);
                     v.pairWriteEnable := '1';
                  end if;

            end case;

            v.pairWriteAddress := toSlv(PAIR_WORDS_C*r.pairSlot+r.pairWord, PAIR_ADDR_WIDTH_C);
            v.pairWriteData    := pairWord;

            if r.pairWord = PAIR_WORDS_C-1 then
               v.pairState := PAIR_PUBLISH_S;
            else
               v.pairWord := r.pairWord+1;
            end if;

         when PAIR_PUBLISH_S =>
            v.pairState := PAIR_ACK_S;

            if r.result.sampleValid = '1' then
               v.pairWord        := 3;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairSlot+3, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable  := '1';
               v.pairState       := PAIR_PUBLISH_READ_S;
            end if;

         when PAIR_PUBLISH_READ_S =>
            v.pairState := PAIR_PUBLISH_CAPTURE_S;
         when PAIR_PUBLISH_CAPTURE_S =>

            if r.pairWord <= 6 then
               -- Keep both signed wire corrections for the rate estimator to sum
               -- at full width when forming the corrected remote timestamp.
               v.result.sample.correction(32*(r.pairWord-3)+31 downto 32*(r.pairWord-3)) := pairReadData;
            else
               takeSyncWord(v.result.sample, r.pairWord-7, pairReadData);
            end if;

            if r.pairWord = PAIR_WORDS_C-1 then
               v.pairState := PAIR_ACK_S;
            else
               v.pairWord        := r.pairWord+1;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairSlot+r.pairWord+1, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable  := '1';
               v.pairState       := PAIR_PUBLISH_READ_S;
            end if;

         when PAIR_ACK_S =>
            if take = '1' then
               v.pairState := PAIR_IDLE_S;
            end if;
      end case;

      malformed := false;
      if rxMessageMaster.valid = '1' and r.pairState = PAIR_DECIDE_S then
         if admission.valid = '0' then
            malformed := true;
         else
            -- Validate message semantics before allocating or changing a slot.
            if rxMessageMaster.data.messageType = PTP_MSG_SYNC_C then
               if admission.flags /= PTP_ONE_STEP_FLAGS_C and admission.flags /= PTP_TWO_STEP_FLAGS_C then
                  malformed := true;
               elsif admission.flags = PTP_ONE_STEP_FLAGS_C then
                  -- Only one-step Sync carries the authoritative timestamp.
                  -- The two-step Sync body is ignored in favor of Follow_Up.
                  if unsigned(ptpMessageNanoseconds(rxMessageMaster.data)) >= PTP_NANOSECONDS_PER_SECOND_C then
                     malformed := true;
                  end if;
               end if;
            else
               -- Follow_Up ignores reserved bits and controlField.
               if admission.flags /= PTP_ONE_STEP_FLAGS_C then
                  malformed := true;
               elsif unsigned(ptpMessageNanoseconds(rxMessageMaster.data)) >= PTP_NANOSECONDS_PER_SECOND_C then
                  malformed := true;
               end if;
            end if;
            if not malformed then
               slot := r.pairSlot;
               if slot /= -1 then
                  pairUpdated := true;
                  if pair.used = '0' or pair.sequenceId /= rxMessageMaster.data.sequenceId then
                     pair            := PAIR_INIT_C;
                     pair.used       := '1';
                     pair.sequenceId := rxMessageMaster.data.sequenceId;
                  end if;
               end if;
               if slot = -1 then
                  malformed := true;
               elsif rxMessageMaster.data.correction = PTP_CORRECTION_OVERFLOW_C then
                  -- Retain a completed key even when this is the first
                  -- half received. Neither arrival order nor a later
                  -- finite duplicate may revive an overflowed exchange.
                  pair.complete := '1';
                  malformed     := true;
               elsif rxMessageMaster.data.messageType = PTP_MSG_SYNC_C then
                  if pair.syncSeen = '1' or
                     (admission.flags = PTP_ONE_STEP_FLAGS_C and pair.followSeen = '1') then
                     -- Duplicate Sync is ambiguous even if its headers match:
                     -- the physical capture is a different wire event.
                     -- One-step cannot inherit an earlier Follow_Up either.
                     pair.complete := '1';
                     malformed     := true;
                  else
                     v.pairWriteSync := '1';
                     pair.syncSeen   := '1';
                     pair.twoStep    := '0';
                     if admission.flags = PTP_TWO_STEP_FLAGS_C then
                        pair.twoStep := '1';
                     else
                        v.pairWriteFollow := '1';
                     end if;
                     syncAdmission := '1';
                     if admission.intervalValid = '0' and
                        rxMessageMaster.data.logInterval /= PTP_LOG_INTERVAL_UNSPECIFIED_C then
                        rejectedEvents := rejectedEvents+1;
                     end if;
                  end if;
               else
                  if pair.syncSeen = '1' and pair.twoStep = '0' then
                     -- Count inconsistent Follow_Up without changing any
                     -- part of the one-step association, even after use.
                     malformed := true;
                  elsif pair.followSeen = '1' then
                     if r.pairDuplicateEqual = '0' then
                        pair.complete := '1';
                        malformed     := true;
                     end if;
                  else
                     v.pairWriteFollow := '1';
                     pair.followSeen   := '1';
                  end if;
               end if;
            end if;
         end if;
      end if;
      if malformed then
         rejectedEvents := rejectedEvents+1;
      end if;
      -- Ownership changes precede field writes, but RX and rate admission
      -- remain blocked until the selected row has drained its registered write.
      if pairUpdated then
         v.result.sampleValid := '0';
         if pair.used = '1' and pair.syncSeen = '1' and pair.complete = '0' and
            (pair.twoStep = '0' or pair.followSeen = '1') then
            v.result.sampleValid := '1';
            pair.complete        := '1';
         end if;
         v.pairUsed(r.pairSlot) := pair.used;
         v.pairSyncSeen(r.pairSlot) := pair.syncSeen;
         v.pairTwoStep(r.pairSlot) := pair.twoStep;
         v.pairFollowSeen(r.pairSlot) := pair.followSeen;
         v.pairComplete(r.pairSlot) := pair.complete;
         v.pairWord  := 0;
         v.pairState := PAIR_UPDATE_S;
      end if;

      if cancel = '1' then
         v.pairUsed        := (others => '0');
         v.pairState       := PAIR_IDLE_S;
         v.pairReadEnable  := '0';
         v.pairWriteEnable := '0';
      end if;
      -- Events retain their detection edge; policy applies cancellation priority.
      syncAdmitted <= syncAdmission;
      rejected     <= rejectedEvents;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      -- Compute completion from resolved next state, on the same edge as the
      -- final sample update. No extra publication cycle or payload register.
      v.result.done := toSl(v.pairState = PAIR_ACK_S);
      rin           <= v;
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
