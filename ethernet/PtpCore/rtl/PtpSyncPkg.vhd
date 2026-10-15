-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Private Sync-table word format and shared scan transactions.
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

   function syncWord(sample : PtpSyncSampleType; index : natural) return slv;
   procedure takeSyncWord(variable sample : inout PtpSyncSampleType;
      constant index : natural; constant word : slv(31 downto 0));

end package PtpSyncPkg;

package body PtpSyncPkg is

   function syncWord(sample : PtpSyncSampleType;
   index : natural) return slv is
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
