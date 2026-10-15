-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Fixed-source PTP admission, receipt deadlines and lifecycle.
-- Policy decisions are combinational so cancellation can veto work on this
-- edge. Lifecycle/ledger cancellation and diagnostic state remain registered.
-- Admission events from the association owner update deadlines on the same
-- edge as the corresponding message or accepted rate sample.
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

entity PtpPortPolicy is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      clk             : in sl;
      rst             : in sl;
      config          : in PtpPortConfigType;
      applyConfig     : in sl;
      identityChanged : in sl;
      enable          : in sl;
      restart         : in sl;
      linkReady       : in sl;
      phcStatus       : in PtpPhcStatusType;
      captureAbort    : in sl;
      rxQueueOverflow : in sl;
      rxAbort         : in sl;
      txAbort         : in sl;
      rxMessage       : in PtpRxMessageType;
      rxValid         : in sl;
      -- Current-edge admission from the flow owner; no extra pipeline stage.
      idle                  : in sl;
      syncAdmitted          : in sl;
      announceAdmitted      : in sl;
      sampleAccepted        : in sl;
      sampleTicks           : in slv(63 downto 0);
      responseLog           : in slv(7 downto 0);
      policyValid           : out sl;
      policyFlags           : out slv(15 downto 0);
      announceValid         : out sl;
      intervalValid         : out sl;
      responseIntervalValid : out sl;
      responseIntervalTicks : out slv(63 downto 0);
      cancel                : out sl;
      abortRegistered       : out sl;
      lastSyncTicks         : out slv(63 downto 0);
      lifecycle             : out PtpPortLifecycleType;
      status                : out PtpPortStatusType);
end entity PtpPortPolicy;

architecture rtl of PtpPortPolicy is

   -- Supported profile interval policy: roughly 1 ms through 48.5 days.
   -- These are admission bounds, not the representable signed wire range.
   constant MIN_LOG_INTERVAL_C : integer := -10;
   constant MAX_LOG_INTERVAL_C : integer := 22;
   -- Receipt timeout spans three advertised intervals; Announce uses twice
   -- the configured Sync receipt cap.
   constant RECEIPT_INTERVALS_C   : positive         := 3;
   constant ANNOUNCE_CAP_FACTOR_C : positive         := 2;

   -- Elaborate the accepted exponent range once. Negative exponents first
   -- round down to whole ticks, then receipt timeouts multiply those ticks by
   -- three, matching the wire policy. No runtime shifter or multiplier is used.
   type IntervalType is record
      valid   : boolean;
      ticks   : unsigned(63 downto 0);
      receipt : unsigned(63 downto 0);
   end record;

   type IntervalArray is array (MIN_LOG_INTERVAL_C to MAX_LOG_INTERVAL_C) of IntervalType;

   function intervalTable return IntervalArray is
      variable values : IntervalArray;
      variable ticks  : unsigned(63 downto 0);
   begin
      for exponent in values'range loop
         ticks := to_unsigned(CLK_FREQ_G, 64);
         if exponent < 0 then
            ticks := shift_right(ticks, -exponent);
         else
            ticks := shift_left(ticks, exponent);
         end if;
         values(exponent).valid := true;
         values(exponent).ticks := ticks;
         values(exponent).receipt := resize(ticks*RECEIPT_INTERVALS_C, 64);
      end loop;
      return values;
   end function;

   constant INTERVAL_TABLE_C : IntervalArray := intervalTable;

   function decodeInterval(logInterval : slv(7 downto 0)) return IntervalType is
      variable value : IntervalType := (false, (others => '0'), (others => '0'));
   begin
      for exponent in INTERVAL_TABLE_C'range loop
         if logInterval = slv(to_signed(exponent, 8)) then
            value := INTERVAL_TABLE_C(exponent);
         end if;
      end loop;
      return value;
   end function;

   -- IEEE 1588-2019 13.2 and Table 37: reserved flags are ignored on receipt.
   constant RESERVED_FLAGS_MASK_C : slv(15 downto 0) := x"9880";
   -- Leap flags are mutually exclusive. Unsupported assigned upper-octet
   -- flags remain outside this multicast endpoint's selected options.
   -- Layer-2 controlField is ignored per 13.3.2.13, including legacy values.
   function validAnnounce (message : PtpRxMessageType) return boolean is
   begin
      return (message.flags and PTP_LEAP_FLAGS_MASK_C) /= PTP_LEAP_FLAGS_MASK_C and
         (message.flags and PTP_GENERAL_RESERVED_C and not RESERVED_FLAGS_MASK_C) = x"0000";
   end function;

   type RegType is record
      portStatus : PtpPortStatusType;
      syncLimit : slv(63 downto 0);
      announceLimit : slv(63 downto 0);
      lastTicks : slv(63 downto 0);
      announceSeen : sl;
      announceTicks : slv(63 downto 0);
      generation : slv(31 downto 0);
      abortEvent : sl;
      lifecycle : PtpPortLifecycleType;
   end record;

   constant REG_INIT_C : RegType := (
      portStatus => PTP_PORT_STATUS_INIT_C,
      syncLimit => (others => '0'),
      announceLimit => (others => '0'),
      lastTicks => (others => '0'),
      announceSeen => '0',
      announceTicks => (others => '0'),
      generation => (others => '0'),
      abortEvent => '0',
      lifecycle => PTP_PORT_LIFECYCLE_INIT_C);

   signal r : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (all) is
      variable v                : RegType;
      variable admitted         : sl;
      variable announceChange   : sl;
      variable externalAbort    : sl;
      variable abortPort        : sl;
      variable rxInterval       : IntervalType;
      variable responseInterval : IntervalType;
      variable rxReceiptLimit   : unsigned(63 downto 0);
   begin
      v := r;
      v.generation := phcStatus.generation;
      -- Compare the retained Announce deadline before admission/cancellation
      -- selects the next state. A new Announce selects its own comparison;
      -- final cancellation clears validity without feeding another age ALU.
      v.portStatus.announceValid := '0';
      if not ptpAgeExpired(phcStatus.ticks, r.announceTicks, r.announceLimit) then
         v.portStatus.announceValid := r.announceSeen;
      end if;
      -- Sync and Announce share one decoder and capped receipt preparation.
      -- A previously submitted Delay_Resp may complete on this same edge, so
      -- its held log interval needs an independent lookup (no added latency).
      rxInterval := decodeInterval(rxMessage.logInterval);
      responseInterval := decodeInterval(responseLog);
      rxReceiptLimit := unsigned(config.syncTimeout);
      if rxMessage.messageType = PTP_MSG_ANNOUNCE_C then
         rxReceiptLimit := resize(rxReceiptLimit*ANNOUNCE_CAP_FACTOR_C, 64);
      end if;
      if rxInterval.valid and rxInterval.receipt < rxReceiptLimit then
         rxReceiptLimit := rxInterval.receipt;
      end if;

      -- First check Ethernet/PTP identity, then capture provenance and age.
      -- A rejected record is still consumed below and counted as a rejection.
      admitted := '1';

      if rxMessage.destination /= PTP_PRIMARY_MULTICAST_MAC_C then
         admitted := '0';
      elsif rxMessage.sourcePortIdentity /= config.sourceIdentity then
         admitted := '0';
      elsif rxMessage.domainNumber /= config.domainNumber or rxMessage.transportSpecific /= PTP_TRANSPORT_SPECIFIC_C then
         admitted := '0';
      elsif rxMessage.capture.generation /= phcStatus.generation or rxMessage.capture.error /= '0' then
         admitted := '0';
      elsif unsigned(phcStatus.ticks) < unsigned(rxMessage.capture.ticks) then
         admitted := '0';
      elsif ptpAgeExpired(phcStatus.ticks, rxMessage.capture.ticks, config.associationTimeout) then
         admitted := '0';
      end if;

      -- A changed grandmaster or timescale cancels the old measurements on
      -- this edge. This decision precedes readiness and cannot depend on it.
      announceChange := '0';

      if rxValid = '1' and idle = '1' then
         if admitted = '1' and r.announceSeen = '1' and rxMessage.messageType = PTP_MSG_ANNOUNCE_C then
            if validAnnounce(rxMessage) then
               if ptpGrandmasterIdentity(rxMessage) /= r.portStatus.grandmasterIdentity or rxMessage.flags(PTP_TIMESCALE_BIT_C) /= r.portStatus.announceFlags(PTP_TIMESCALE_BIT_C) then
                  announceChange := '1';
               end if;
            end if;
         end if;
      end if;

      -- Independent protocol causes may revoke an accepted PHC command. Its
      -- own capture invalidation only flushes measurement/association work.
      externalAbort := '0';

      if rst = RST_POLARITY_G or restart = '1' or applyConfig = '1' or identityChanged = '1' then
         externalAbort := '1';
      elsif linkReady = '0' or enable = '0' then
         externalAbort := '1';
      elsif rxQueueOverflow = '1' or txAbort = '1' or announceChange = '1' then
         externalAbort := '1';
      elsif r.portStatus.active = '1' then
         if ptpAgeExpired(phcStatus.ticks, r.lastTicks, r.syncLimit) then
            externalAbort := '1';
         end if;
      end if;

      abortPort := '0';

      if externalAbort = '1' or captureAbort = '1' or rxAbort = '1' or
         phcStatus.generation /= r.generation then
         abortPort := '1';
      end if;

      -- Publish lifecycle events after this detection edge. The PHC observes
      -- commandAbort on the next edge, in time to veto a command admitted on
      -- this edge. Earlier committed work is not retroactively revoked.
      v.lifecycle              := PTP_PORT_LIFECYCLE_INIT_C;
      v.lifecycle.commandAbort := externalAbort;

      if identityChanged = '1' then
         v.lifecycle.identityRestart := '1';
      end if;

      v.abortEvent := abortPort;
      -- Drain the registered child cancellation before admitting new work.
      -- Do not feed that old event back into its own next value above.
      abortPort      := abortPort or r.abortEvent;
      if syncAdmitted = '1' then
         v.syncLimit := slv(rxReceiptLimit);
      end if;
      if sampleAccepted = '1' then
         v.portStatus.active := '1';
         v.lastTicks := sampleTicks;
      end if;
      if announceAdmitted = '1' then
         if not validAnnounce(rxMessage) then
            v.announceSeen := '0';
            v.portStatus.announceValid := '0';
         else
            v.announceSeen := '1';
            v.portStatus.announceValid := toSl(not ptpAgeExpired(
               phcStatus.ticks, rxMessage.capture.ticks, slv(rxReceiptLimit)));
            v.portStatus.announceBody := rxMessage.messageBody;
            v.announceTicks := rxMessage.capture.ticks;
            v.portStatus.grandmasterIdentity := ptpGrandmasterIdentity(rxMessage);
            v.portStatus.announceFlags := rxMessage.flags;
            v.portStatus.utcOffset := ptpUtcOffset(rxMessage);
            v.announceLimit := slv(rxReceiptLimit);
         end if;
      end if;
      -- Cancellation has final priority, including a simultaneous admission.
      if abortPort = '1' then
         v.portStatus.active := '0';
         v.syncLimit := config.syncTimeout;
         v.announceLimit := slv(resize(unsigned(config.syncTimeout)*ANNOUNCE_CAP_FACTOR_C, 64));
         v.announceSeen := '0';
         v.portStatus.announceValid := '0';
         if announceChange = '1' then
            v.portStatus.grandmasterIdentity := ptpGrandmasterIdentity(rxMessage);
         end if;
      end if;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;
      policyValid <= admitted;
      policyFlags <= rxMessage.flags and not RESERVED_FLAGS_MASK_C;
      announceValid <= toSl(validAnnounce(rxMessage));
      intervalValid <= toSl(rxInterval.valid);
      responseIntervalValid <= toSl(responseInterval.valid);
      responseIntervalTicks <= slv(responseInterval.ticks);
      cancel <= abortPort;
      abortRegistered <= r.abortEvent;
      lastSyncTicks <= r.lastTicks;
      lifecycle <= r.lifecycle;
      status <= r.portStatus;
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
