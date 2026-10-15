-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Private Sync association transactions and table word format.
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

package PtpSyncPkg is

   -- All transactions below use the protocol clk. Reset/cancel discards pending
   -- work; consumers must not acknowledge or use a completion on that edge.
   -- Clocks, cancellation, admission enables and reverse single-bit handshakes
   -- remain separate ports because they are not forward transaction payloads.

   -- Pair owner holds done until take. done may describe an incomplete/rejected
   -- pair, so sampleValid qualifies sample. The sample is retained after take
   -- until enable permits another search; the rate path borrows it meanwhile.
   type PtpSyncPairResultType is record
      done        : sl;
      sampleValid : sl;
      sample      : PtpSyncSampleType;
   end record;

   constant PTP_SYNC_PAIR_RESULT_INIT_C : PtpSyncPairResultType := (
      done        => '0',
      sampleValid => '0',
      sample      => PTP_SYNC_SAMPLE_INIT_C);

   -- Pulse start only when lookupIdle and lookupReady; qualified is sampled
   -- on that edge. The separate delaySample port borrows coordinator storage,
   -- valid from the following edge through lookupResult.done. Its raw ticks
   -- and Q3 phase select the nearest same-generation Sync.
   type PtpSyncLookupRequestType is record
      start     : sl;
      qualified : sl;
   end record;

   constant PTP_SYNC_LOOKUP_REQUEST_INIT_C : PtpSyncLookupRequestType := (
      start     => '0',
      qualified => '0');

   -- History owner pulses done for one cycle; matched qualifies sample.
   -- The selected sample persists until the next lookup and is borrowed by E2E.
   -- Normalized words are a separate stream sent before this completion.
   type PtpSyncLookupResultType is record
      done    : sl;
      matched : sl;
      sample  : PtpSyncSampleType;
   end record;

   constant PTP_SYNC_LOOKUP_RESULT_INIT_C : PtpSyncLookupResultType := (
      done    => '0',
      matched => '0',
      sample  => PTP_SYNC_SAMPLE_INIT_C);

   -- Pulse start while append status is not busy; hold all payload through done.
   -- Values are signed Q16 nanoseconds. Sample provenance belongs to Pair;
   -- corrected sample/time and forward value belong to the held rate result.
   -- A concurrent lookup can defer writes without changing payload ownership.
   type PtpSyncAppendRequestType is record
      start          : sl;
      sample         : PtpSyncSampleType;
      forwardValue   : slv(127 downto 0);
      normalizedTime : slv(127 downto 0);
   end record;

   constant PTP_SYNC_APPEND_REQUEST_INIT_C : PtpSyncAppendRequestType := (
      start          => '0',
      sample         => PTP_SYNC_SAMPLE_INIT_C,
      forwardValue   => (others => '0'),
      normalizedTime => (others => '0'));

   -- History owner keeps busy high from admission through the commit edge.
   -- done marks that commit edge (still busy); cancel takes priority over commit.
   type PtpSyncAppendStatusType is record
      busy : sl;
      done : sl;
   end record;

   constant PTP_SYNC_APPEND_STATUS_INIT_C : PtpSyncAppendStatusType := (
      busy => '0',
      done => '0');

   -- History-to-E2E stream, transferred on valid/ready. Hold word/data on stall.
   -- Little-endian words 0..3 carry signed128 forward value; 4..7 carry signed128
   -- corrected Sync time, both Q16 ns. Registered RAM data is the payload owner;
   -- the history FSM owns valid/word. Cancel/reset invalidates the transfer.
   type PtpSyncNormalizedMasterType is record
      valid : sl;
      word  : slv(2 downto 0);
      data  : slv(31 downto 0);
   end record;

   constant PTP_SYNC_NORMALIZED_MASTER_INIT_C : PtpSyncNormalizedMasterType := (
      valid => '0',
      word  => (others => '0'),
      data  => (others => '0'));

   -- A client holds all request fields through its result.valid edge.
   -- Arbitration keeps only owner/scratch state, never a second row payload.
   type PtpScanRequestType is record
      valid       : sl;
      ticks       : slv(63 downto 0);
      rowTicks    : slv(63 downto 0);
      rowPhase    : slv(PTP_TICK_PHASE_BITS_C-1 downto 0);
      targetTicks : slv(63 downto 0);
      targetPhase : slv(PTP_TICK_PHASE_BITS_C-1 downto 0);
      best        : slv(67 downto 0);
   end record;

   constant PTP_SCAN_REQUEST_INIT_C : PtpScanRequestType := (
      valid       => '0',
      ticks       => (others => '0'),
      rowTicks    => (others => '0'),
      rowPhase    => (others => '0'),
      targetTicks => (others => '0'),
      targetPhase => (others => '0'),
      best        => (others => '0'));
   type PtpScanResultType is record
      valid    : sl;
      expired  : sl;
      better   : sl;
      distance : slv(67 downto 0);
   end record;

   constant PTP_SCAN_RESULT_INIT_C : PtpScanResultType := (
      valid    => '0',
      expired  => '0',
      better   => '0',
      distance => (others => '0'));

   function syncWord(sample : PtpSyncSampleType; index : natural) return slv;
   procedure takeSyncWord(variable sample : inout PtpSyncSampleType;
      constant index : natural; constant word : slv(31 downto 0));

end package PtpSyncPkg;

package body PtpSyncPkg is

   function syncWord(sample : PtpSyncSampleType;
   index            : natural) return slv is
      variable word : slv(31 downto 0) := (others => '0');
   begin

      case index is
         when 0 to 1 =>
            word := sample.capture.ticks(32*index+31 downto 32*index);
         when 2 =>
            word(PTP_TICK_PHASE_BITS_C-1 downto 0) := sample.capture.tickPhase;
            word(3) := sample.capture.timeValid;
            word(4) := sample.capture.error;
         when 3 =>
            word := sample.capture.generation;
         when 4 =>
            word(15 downto 0) := sample.sequenceId;
         when 5 to 7 =>
            word := sample.capture.timestamp(32*(index-5)+31 downto 32*(index-5));
         when 8 to 9 =>
            word := sample.capture.increment(32*(index-8)+31 downto 32*(index-8));
         when 10 to 11 =>
            word := sample.remoteTime(32*(index-10)+31 downto 32*(index-10));
         when 12 =>
            word(15 downto 0) := sample.remoteTime(79 downto 64);
         when 13 to 16 =>
            word := sample.correction(32*(index-13)+31 downto 32*(index-13));
         when others =>
            null;
      end case;

      return word;
   end function;

   procedure takeSyncWord(variable sample : inout PtpSyncSampleType;
   constant index : natural;
   constant word  : slv(31 downto 0)) is
   begin

      case index is
         when 0 to 1 =>
            sample.capture.ticks(32*index+31 downto 32*index) := word;
         when 2 =>
            sample.capture.tickPhase := word(PTP_TICK_PHASE_BITS_C-1 downto 0);
            sample.capture.timeValid := word(3);
            sample.capture.error := word(4);
         when 3 =>
            sample.capture.generation := word;
         when 4 =>
            sample.sequenceId := word(15 downto 0);
         when 5 to 7 =>
            sample.capture.timestamp(32*(index-5)+31 downto 32*(index-5)) := word;
         when 8 to 9 =>
            sample.capture.increment(32*(index-8)+31 downto 32*(index-8)) := word;
         when 10 to 11 =>
            sample.remoteTime(32*(index-10)+31 downto 32*(index-10)) := word;
         when 12 =>
            sample.remoteTime(79 downto 64) := word(15 downto 0);
         when 13 to 16 =>
            sample.correction(32*(index-13)+31 downto 32*(index-13)) := word;
         when others =>
            null;
      end case;

   end procedure;

end package body PtpSyncPkg;
