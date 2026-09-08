-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Bounded PTP TX ownership, out-of-order response association and quarantine
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
      DEPTH_G           : positive               := 4;
      SEQUENCE_BITS_G   : positive range 1 to 16 := 16;
      PACKET_LIFETIME_G : positive               := 156250000);
   port (
      clk              : in  sl;
      rst              : in  sl;
      restart          : in  sl;
      macResetDone     : in  sl;
      ticks            : in  slv(63 downto 0);
      generation       : in  slv(31 downto 0);
      config           : in  PtpConfigType;
      allocate         : in  sl;
      allocateReady    : out sl;
      allocateSequence : out slv(15 downto 0);
      wireMessage      : in  PtpRxMessageType;
      wireValid        : in  sl;
      response         : in  PtpRxMessageType;
      responseValid    : in  sl;
      sample           : out PtpDelaySampleType;
      sampleValid      : out sl;
      sampleReady      : in  sl;
      ledgerStatus     : out slv(31 downto 0);
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
   type RegType is record
      entries       : EntryArray(0 to DEPTH_G-1);
      nextSequence  : unsigned(SEQUENCE_BITS_G-1 downto 0);
      startup       : sl;
      resetSeen     : sl;
      resetTick     : slv(63 downto 0);
      resetPrevious : sl;
      sample        : PtpDelaySampleType;
      valid         : sl;
      timeoutCount  : slv(31 downto 0);
      rejectedCount : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      entries       => (others => ENTRY_INIT_C),
      nextSequence  => (others => '0'),
      startup       => '1',
      resetSeen     => '0',
      resetTick     => (others => '0'),
      resetPrevious => '0',
      sample        => PTP_DELAY_SAMPLE_INIT_C,
      valid         => '0',
      timeoutCount  => (others => '0'),
      rejectedCount => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, restart, macResetDone, ticks, generation, config, allocate,
                   wireMessage, wireValid, response, responseValid, sampleReady) is
      variable v            : RegType;
      variable freeSlot     : integer range -1 to DEPTH_G-1;
      variable collision    : boolean;
      variable usedSlots    : natural range 0 to DEPTH_G;
      variable unknownSlots : natural range 0 to DEPTH_G;
      variable ready        : sl;
   begin
      v := r;

      responseAccepted <= '0';
      usedSlots        := 0;
      unknownSlots     := 0;
      freeSlot         := -1;
      collision        := false;
      ready            := '0';
      v.resetPrevious  := macResetDone;
      if r.valid = '1' and sampleReady = '1' then
         v.valid := '0';
      end if;
      for i in 0 to DEPTH_G-1 loop
         -- Quarantine consumes bounded physical storage. An unresolved frame
         -- cannot free its slot through timeout or logical restart. After a
         -- known wire completion, keep its key for the full network lifetime.
         if r.entries(i).used = '1' then
            usedSlots := usedSlots+1;
            if r.entries(i).wireSeen = '0' then
               unknownSlots := unknownSlots+1;
            end if;
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
         if wireValid = '1' and r.entries(i).used = '1' and
            wireMessage.sequenceId = r.entries(i).sequenceId and
            wireMessage.sourcePortIdentity = r.entries(i).identity and
            wireMessage.domainNumber = r.entries(i).domainNumber and wireMessage.messageType = x"1" then
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
         if responseValid = '1' and r.entries(i).used = '1' and v.entries(i).retired = '0' and
            response.sequenceId = r.entries(i).sequenceId and response.domainNumber = r.entries(i).domainNumber and
            response.messageBody(159 downto 80) = r.entries(i).identity and
            response.capture.generation = r.entries(i).generation then
            if r.entries(i).responseSeen = '1' then
               -- Even identical repeats cannot refresh transaction age.
               if r.entries(i).sample.remoteTime /= response.messageBody(239 downto 160) or
                  r.entries(i).sample.correction /= response.correction then
                  v.entries(i).retired := '1';
                  v.rejectedCount      := ptpSatInc(v.rejectedCount);
               end if;
            else
               v.entries(i).responseSeen         := '1';
               responseAccepted                  <= '1';
               v.entries(i).sample.remoteTime    := response.messageBody(239 downto 160);
               v.entries(i).sample.correction    := response.correction;
               v.entries(i).sample.responseTicks := response.capture.ticks;
            end if;
         end if;
         if v.entries(i).used = '1' and v.entries(i).retired = '0' and
            v.entries(i).wireSeen = '1' and v.entries(i).responseSeen = '1' and v.valid = '0' then
            v.entries(i).retired := '1';
            if unsigned(v.entries(i).sample.responseTicks) >= unsigned(v.entries(i).wireTicks) and
               unsigned(v.entries(i).sample.responseTicks)-unsigned(v.entries(i).wireTicks) <= PACKET_LIFETIME_G and
               unsigned(ticks)-unsigned(v.entries(i).wireTicks) <= PACKET_LIFETIME_G and
               v.entries(i).generation = generation then
               v.sample := v.entries(i).sample;
               v.valid  := '1';
            else
               v.rejectedCount := ptpSatInc(v.rejectedCount);
            end if;
         end if;
      end loop;
      if r.startup = '1' and r.resetSeen = '1' and
         unsigned(ticks)-unsigned(r.resetTick) > PACKET_LIFETIME_G then
         v.startup := '0';
      end if;
      if r.startup = '0' and freeSlot /= -1 and not collision and restart = '0' then
         ready := '1';
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
      elsif collision and r.startup = '0' then
         -- Search at most one wire key per clock; no associative 65536-entry
         -- bitmap or unbounded combinational allocator is required.
         v.nextSequence := r.nextSequence + 1;
      end if;
      if restart = '1' then
         responseAccepted <= '0';
         for i in 0 to DEPTH_G-1 loop
            v.entries(i).retired := '1';
         end loop;
         v.valid := '0';
      end if;
      -- Only an explicit confirmation that the whole MAC TX path was reset
      -- permits unknown wire fates to be discarded. Startup quarantine then
      -- excludes surviving network responses. A port reset is insufficient.
      if macResetDone = '1' and r.resetPrevious = '0' then
         v.entries   := (others => ENTRY_INIT_C);
         v.startup   := '1';
         v.resetSeen := '1';
         v.resetTick := ticks;
         v.valid     := '0';
         ready       := '0';
      end if;
      if rst = RST_POLARITY_G then
         ready := '0';
         if not RST_ASYNC_G then
            v := REG_INIT_C;
         end if;
      end if;
      rin              <= v;
      allocateReady    <= ready;
      allocateSequence <= slv(resize(r.nextSequence, 16));
      sample           <= r.sample;
      sampleValid      <= r.valid and not restart;
      if rst = RST_POLARITY_G or (macResetDone = '1' and r.resetPrevious = '0') then
         sampleValid <= '0';
      end if;
      ledgerStatus               <= (others => '0');
      ledgerStatus(0)            <= r.startup;
      ledgerStatus(1)            <= r.resetSeen;
      ledgerStatus(15 downto 8)  <= slv(to_unsigned(usedSlots, 8));
      ledgerStatus(23 downto 16) <= slv(to_unsigned(unknownSlots, 8));
      timeoutCount               <= r.timeoutCount;
      rejectedCount              <= r.rejectedCount;
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
