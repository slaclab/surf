-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP protocol policy and ledger interface records.
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
library surf;
use surf.StdRtlPkg.all;
use surf.PtpPkg.all;

package PtpProtocolPkg is

   -- Ledger offer in clk: allocate and ready reserve sequenceId on that edge.
   -- The transmitter must freeze the accepted identifier. Ledger restart wins over
   -- reservation; logical TX cancellation separately preserves accepted frames.
   type PtpLedgerAllocationType is record
      ready      : sl;
      sequenceId : slv(15 downto 0);
   end record;

   constant PTP_LEDGER_ALLOCATION_INIT_C : PtpLedgerAllocationType := (
      ready      => '0',
      sequenceId => (others => '0'));

   -- Combinational policy view of the held RX message in clk. valid admits
   -- identity/domain/capture; flags are masked protocol flags. announceValid and
   -- intervalValid qualify their respective semantics. Cancel has final priority.
   type PtpAdmissionType is record
      valid         : sl;
      flags         : slv(15 downto 0);
      announceValid : sl;
      intervalValid : sl;
   end record;

   constant PTP_ADMISSION_INIT_C : PtpAdmissionType := (
      valid         => '0',
      flags         => (others => '0'),
      announceValid => '0',
      intervalValid => '0');

   -- Current-edge flow decisions in clk; each event is consumed on that edge.
   -- Ticks identify the accepted sample in raw cycles and are qualified by sample.
   -- Policy applies its own reset/cancel priority; idle capacity is separate.
   type PtpAdmissionEventsType is record
      sync     : sl;
      announce : sl;
      sample   : sl;
      ticks    : slv(63 downto 0);
   end record;

   constant PTP_ADMISSION_EVENTS_INIT_C : PtpAdmissionEventsType := (
      sync     => '0',
      announce => '0',
      sample   => '0',
      ticks    => (others => '0'));

   -- Decoded interval in clk, in raw cycles. valid qualifies ticks. The sender
   -- qualifies this view with ledger acceptance before updating the TX interval;
   -- that accepted event does not alter a simultaneous reservation's old interval.
   type PtpIntervalType is record
      valid : sl;
      ticks : slv(63 downto 0);
   end record;

   constant PTP_INTERVAL_INIT_C : PtpIntervalType := (
      valid => '0',
      ticks => (others => '0'));

end package PtpProtocolPkg;
