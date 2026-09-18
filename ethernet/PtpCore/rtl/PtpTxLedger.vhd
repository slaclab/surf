-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Bounded ownership and lifetime tracking for PTP Delay_Req wire
-- keys.
--
-- Reserves a sequence/domain/requester identity before PtpPort presents the
-- first TX beat. Each entry retains its generation and physical fate while the
-- MAC may queue or pause the request. A validated TX wire observation and the
-- corresponding Delay_Resp can arrive in either order; both are required to
-- publish a complete delay sample through the ready/valid output.
--
-- Configuration comes directly from PtpPort's active record in clk. Allocation
-- captures localIdentity and domainNumber; retirement uses associationTimeout
-- in raw ticks. Servo settings are owned and consumed separately.
--
-- Logical restart, generation change or association timeout retires a request
-- but cannot release a key whose transmission fate is unknown. Known wire
-- completions retain their keys for PACKET_LIFETIME_G raw ticks, and duplicate
-- wire observations renew quarantine. This prevents late traffic from being
-- attached to a newer request after sequence reuse, within the configured
-- finite network-lifetime bound.
--
-- Admission requires explicit confirmation that the complete MAC TX path was
-- reset, followed by startup quarantine. Only that physical reset confirmation
-- can discard unresolved wire ownership. Exhaustion deliberately stops
-- allocation rather than guessing that queued frames disappeared. Status and
-- rejection/timeout counters expose these conditions to the endpoint register
-- block.
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

entity PtpTxLedger is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      DEPTH_G           : positive               := 4;  -- 1..255; occupancy status uses eight bits.
      SEQUENCE_BITS_G   : positive range 1 to 16 := 16;
      PACKET_LIFETIME_G : positive               := 156250000);
   port (
      clk              : in  sl;
      rst              : in  sl;
      restart          : in  sl;
      macResetDone     : in  sl;
      ticks            : in  slv(63 downto 0);
      generation       : in  slv(31 downto 0);
      config           : in  PtpPortConfigType;
      allocate         : in  sl;
      allocateReady    : out sl;
      allocateSequence : out slv(15 downto 0);
      wireMessage      : in  PtpRxMessageType;
      wireValid        : in  sl;
      response         : in  PtpRxMessageType;
      responseValid    : in  sl;
      sample           : out PtpDelaySampleType;
      -- Registered valid; restart/system reset cancel a coincident transfer.
      -- macResetDone confirms that shared system reset has drained the MAC.
      sampleValid      : out sl;
      sampleReady      : in  sl;
      ledgerStatus     : out slv(31 downto 0);
      -- Registered completion for the response sampled on the previous edge.
      -- The caller retains that response's metadata until this result arrives.
      responseAccepted : out sl;
      timeoutCount     : out slv(31 downto 0);
      rejectedCount    : out slv(31 downto 0));
end entity PtpTxLedger;

architecture rtl of PtpTxLedger is

   type EntryType is record
      used         : sl;
      retired      : sl;
      wireSeen     : sl;
      responseSeen : sl;
      sequenceId   : slv(15 downto 0);
      generation   : slv(31 downto 0);
      identity     : slv(79 downto 0);
      domainNumber : slv(7 downto 0);
      born         : slv(63 downto 0);
      wireTicks    : slv(63 downto 0);
      sample       : PtpDelaySampleType;
   end record;

   constant ENTRY_INIT_C : EntryType := (
      used         => '0',
      retired      => '0',
      wireSeen     => '0',
      responseSeen => '0',
      sequenceId   => (others => '0'),
      generation   => (others => '0'),
      identity     => (others => '0'),
      domainNumber => (others => '0'),
      born         => (others => '0'),
      wireTicks    => (others => '0'),
      sample       => PTP_DELAY_SAMPLE_INIT_C);

   type EntryArray is array (natural range <>) of EntryType;

   -- Low status bits also own the startup-quarantine state.
   constant STARTUP_BIT_C    : natural := 0;
   constant RESET_SEEN_BIT_C : natural := 1;
   type RegType is record
      -- Registered capacity promise and one-cycle response completion.
      ready            : sl;
      responseAccepted : sl;

      ledgerStatus  : slv(31 downto 0);
      entries       : EntryArray(0 to DEPTH_G-1);
      nextSequence  : unsigned(SEQUENCE_BITS_G-1 downto 0);
      resetTick     : slv(63 downto 0);
      resetPrevious : sl;
      sample        : PtpDelaySampleType;
      sampleValid   : sl;
      timeoutCount  : slv(31 downto 0);
      rejectedCount : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      ready            => '0',
      responseAccepted => '0',
      ledgerStatus     => (
         STARTUP_BIT_C => '1',
         others        => '0'),
      entries          => (others => ENTRY_INIT_C),
      nextSequence     => (others => '0'),
      resetTick        => (others => '0'),
      resetPrevious    => '0',
      sample           => PTP_DELAY_SAMPLE_INIT_C,
      sampleValid      => '0',
      timeoutCount     => (others => '0'),
      rejectedCount    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -- Occupied and unresolved counts each occupy one byte in the status ABI.
   assert DEPTH_G <= 255
      report "PtpTxLedger DEPTH_G must fit the eight-bit occupancy counters"
      severity failure;

   comb : process (r, rst, restart, macResetDone, ticks, generation, config, allocate,
                   wireMessage, wireValid, response, responseValid, sampleReady) is
      variable v : RegType;

      -- Calculations used only during this evaluation.
      variable freeSlot  : integer range -1 to DEPTH_G-1;
      variable collision : boolean;
   begin
      v := r;

      v.responseAccepted := '0';
      freeSlot           := -1;
      collision          := false;
      v.ready            := '0';
      v.resetPrevious    := macResetDone;
      -- Retire the previous output before selecting a new completed entry.
      if r.sampleValid = '1' and sampleReady = '1' then
         v.sampleValid := '0';
      end if;
      -- Account for occupancy, retire timed-out associations and reclaim only
      -- entries whose known wire completion has finished quarantine.
      for i in 0 to DEPTH_G-1 loop
         -- Quarantine consumes bounded physical storage. An unresolved frame
         -- cannot free its slot through timeout or logical restart. After a
         -- known wire completion, keep its key for the full network lifetime.
         if r.entries(i).used = '1' then
            if r.entries(i).retired = '1' and r.entries(i).wireSeen = '1' and
               unsigned(ticks)-unsigned(r.entries(i).wireTicks) > PACKET_LIFETIME_G then
               v.entries(i) := ENTRY_INIT_C;
            end if;
            if r.entries(i).sequenceId = slv(resize(r.nextSequence, 16)) then
               collision := true;
            end if;
            if r.entries(i).retired = '0' and
               unsigned(ticks)-unsigned(r.entries(i).born) > unsigned(config.associationTimeout) then
               v.entries(i).retired := '1';
               v.timeoutCount       := ptpSatInc(v.timeoutCount);
            end if;
         elsif freeSlot = -1 then
            freeSlot := i;
         end if;
      end loop;

      -- Match observed wire completions after retiring expired associations.
      for i in 0 to DEPTH_G-1 loop
         if wireValid = '1' and r.entries(i).used = '1' and
            wireMessage.sequenceId = r.entries(i).sequenceId and
            wireMessage.sourcePortIdentity = r.entries(i).identity and
            wireMessage.domainNumber = r.entries(i).domainNumber and wireMessage.messageType = PTP_MSG_DELAY_REQ_C then
            v.entries(i).wireSeen       := '1';
            v.entries(i).wireTicks      := wireMessage.capture.ticks;
            v.entries(i).sample.capture := wireMessage.capture;
            -- Duplicate physical keys violate exclusive ownership. Retire and
            -- restart quarantine from the latest observation; never guess which
            -- timestamp a stored response belongs to.
            if r.entries(i).wireSeen = '1' or wireMessage.capture.error = '1' or
               wireMessage.capture.generation /= r.entries(i).generation then
               v.entries(i).retired := '1';
               v.rejectedCount      := ptpSatInc(v.rejectedCount);
            end if;
         end if;
      end loop;

      -- Attach responses only to entries that remain eligible after wire checks.
      -- responseAccepted is registered on this edge. The caller retains the
      -- submitted response metadata for that completion on the following edge.
      for i in 0 to DEPTH_G-1 loop
         if responseValid = '1' and r.entries(i).used = '1' and v.entries(i).retired = '0' and
            response.sequenceId = r.entries(i).sequenceId and response.domainNumber = r.entries(i).domainNumber and
            ptpRequestingIdentity(response) = r.entries(i).identity and
            response.capture.generation = r.entries(i).generation then
            if r.entries(i).responseSeen = '1' then
               -- Even identical repeats cannot refresh transaction age.
               if r.entries(i).sample.remoteTime /= ptpMessageTimestamp(response) or
                  r.entries(i).sample.correction /= response.correction then
                  v.entries(i).retired := '1';
                  v.rejectedCount      := ptpSatInc(v.rejectedCount);
               end if;
            else
               v.entries(i).responseSeen         := '1';
               v.responseAccepted                := '1';
               v.entries(i).sample.remoteTime    := ptpMessageTimestamp(response);
               v.entries(i).sample.correction    := response.correction;
               v.entries(i).sample.responseTicks := response.capture.ticks;
            end if;
         end if;
      end loop;

      -- Publish at most one completed entry, retaining ascending-slot priority.
      for i in 0 to DEPTH_G-1 loop
         if v.entries(i).used = '1' and v.entries(i).retired = '0' and
            v.entries(i).wireSeen = '1' and v.entries(i).responseSeen = '1' and v.sampleValid = '0' then
            v.entries(i).retired := '1';
            if unsigned(v.entries(i).sample.responseTicks) >= unsigned(v.entries(i).wireTicks) and
               unsigned(v.entries(i).sample.responseTicks)-unsigned(v.entries(i).wireTicks) <= PACKET_LIFETIME_G and
               unsigned(ticks)-unsigned(v.entries(i).wireTicks)                             <= PACKET_LIFETIME_G and
               v.entries(i).generation = generation then
               v.sample      := v.entries(i).sample;
               v.sampleValid := '1';
            else
               v.rejectedCount := ptpSatInc(v.rejectedCount);
            end if;
         end if;
      end loop;
      -- Allocate from pre-edge free space after resolving existing ownership.
      if r.ledgerStatus(STARTUP_BIT_C) = '1' and r.ledgerStatus(RESET_SEEN_BIT_C) = '1' and
         unsigned(ticks)-unsigned(r.resetTick) > PACKET_LIFETIME_G then
         v.ledgerStatus(STARTUP_BIT_C) := '0';
      end if;
      if r.ready = '1' and restart = '0' then
         if allocate = '1' then
            v.entries(freeSlot)                   := ENTRY_INIT_C;
            v.entries(freeSlot).used              := '1';
            v.entries(freeSlot).sequenceId        := slv(resize(r.nextSequence, 16));
            v.entries(freeSlot).generation        := generation;
            v.entries(freeSlot).identity          := config.localIdentity;
            v.entries(freeSlot).domainNumber      := config.domainNumber;
            v.entries(freeSlot).born              := ticks;
            v.entries(freeSlot).sample.sequenceId := slv(resize(r.nextSequence, 16));
            v.entries(freeSlot).sample.generation := generation;
            v.nextSequence                        := r.nextSequence + 1;
         end if;
      elsif collision and r.ledgerStatus(STARTUP_BIT_C) = '0' then
         -- Search at most one wire key per clock; no associative 65536-entry
         -- bitmap or unbounded combinational allocator is required.
         v.nextSequence := r.nextSequence + 1;
      end if;
      -- Logical restart retires keys but cannot claim an unknown wire fate.
      if restart = '1' then
         v.responseAccepted := '0';
         for i in 0 to DEPTH_G-1 loop
            v.entries(i).retired := '1';
         end loop;
         v.sampleValid := '0';
      end if;
      -- Only an explicit confirmation that the whole MAC TX path was reset
      -- permits unknown wire fates to be discarded. Startup quarantine then
      -- excludes surviving network responses. A port reset is insufficient.
      if macResetDone = '1' and r.resetPrevious = '0' then
         v.entries                        := (others => ENTRY_INIT_C);
         v.ledgerStatus(STARTUP_BIT_C)    := '1';
         v.ledgerStatus(RESET_SEEN_BIT_C) := '1';
         v.resetTick                      := ticks;
         v.sampleValid                    := '0';
         v.ready                          := '0';
         v.responseAccepted               := '0';
      end if;
      if rst = RST_POLARITY_G then
         v.ready := '0';
      end if;
      -- Count the final next entries so the registered summary describes the
      -- same edge as allocation, completion, retirement and physical reset.
      -- Status bytes 1/2 contain occupied/unknown-wire slot counts.
      v.ledgerStatus(15 downto 8)  := (others => '0');
      v.ledgerStatus(23 downto 16) := (others => '0');
      for i in v.entries'range loop
         if v.entries(i).used = '1' then
            v.ledgerStatus(15 downto 8) := slv(unsigned(v.ledgerStatus(15 downto 8))+1);
            if v.entries(i).wireSeen = '0' then
               v.ledgerStatus(23 downto 16) := slv(unsigned(v.ledgerStatus(23 downto 16))+1);
            end if;
         end if;
      end loop;

      -- Promise capacity for the next edge from the fully resolved table and
      -- candidate key. Only this owner allocates entries; retirement cannot
      -- invalidate a free-slot promise. Shared restart/reset cancel admission.
      freeSlot  := -1;
      collision := false;
      for i in v.entries'range loop
         if v.entries(i).used = '0' then
            freeSlot := i;
         elsif v.entries(i).sequenceId = slv(resize(v.nextSequence, 16)) then
            collision := true;
         end if;
      end loop;
      v.ready := '0';
      if v.ledgerStatus(STARTUP_BIT_C) = '0' and freeSlot /= -1 and not collision and
         restart = '0' and rst /= RST_POLARITY_G then
         v.ready := '1';
      end if;
      -- Apply synchronous reset before publishing next state and outputs.
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;

      allocateReady    <= r.ready;
      responseAccepted <= r.responseAccepted;
      allocateSequence <= slv(resize(r.nextSequence, 16));
      sample           <= r.sample;
      sampleValid      <= r.sampleValid;
      ledgerStatus     <= r.ledgerStatus;
      timeoutCount     <= r.timeoutCount;
      rejectedCount    <= r.rejectedCount;
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
