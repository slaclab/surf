-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Bounded ownership and lifetime tracking for PTP Delay_Req wire
-- keys.
--
-- Reserves a sequence/domain/requester identity before PtpProtocolEngine presents the
-- first TX beat. Each entry retains its generation and physical fate while the
-- MAC may queue or pause the request. A validated TX wire observation and the
-- corresponding Delay_Resp can arrive in either order; both are required to
-- publish a complete delay sample through the ready/valid output.
--
-- Each 636-bit record uses synchronous RAM; only four ownership flags per
-- slot remain in registers. A shared read/modify/write path visits one row
-- every two clocks. Each scan services one stable wire record and one stable
-- response, then acknowledges them and offers allocation on its final edge.
-- At depth D, scans repeat every 2*D+2 clocks. Producers must hold their entire
-- record until ready; logical restart may cancel a response. RAM is not reset.
--
-- Configuration comes directly from PtpProtocolEngine's active record in clk. Allocation
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
      PACKET_LIFETIME_G : positive               := 156250000;
      MEMORY_TYPE_G     : string                 := "distributed");
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
      wireReady        : out sl;
      response         : in  PtpRxMessageType;
      responseValid    : in  sl;
      responseReady    : out sl;
      sample           : out PtpDelaySampleType;
      -- Registered valid; restart/system reset cancel a coincident transfer.
      -- macResetDone confirms that shared system reset has drained the MAC.
      sampleValid      : out sl;
      sampleReady      : in  sl;
      ledgerStatus     : out slv(31 downto 0);
      -- Registered completion for the response transferred on the previous edge.
      -- The caller retains that response's metadata until this result arrives.
      responseAccepted : out sl;
      timeoutCount     : out slv(31 downto 0);
      rejectedCount    : out slv(31 downto 0));
end entity PtpTxLedger;

architecture rtl of PtpTxLedger is

   constant RAM_ADDR_WIDTH_C : positive := log2(DEPTH_G);
   constant ENTRY_WIDTH_C    : positive := 633+PTP_TICK_PHASE_BITS_C;
   subtype EntryPayloadType is slv(ENTRY_WIDTH_C-1 downto 0);

   -- Only four ownership bits per slot need parallel reset/retirement. All
   -- keys, ages and timestamp payloads live in the same synchronous RAM row.
   type EntryType is record
      sequenceId    : slv(15 downto 0);
      generation    : slv(31 downto 0);
      identity      : slv(79 downto 0);
      domainNumber  : slv(7 downto 0);
      born          : slv(63 downto 0);
      wireTicks     : slv(63 downto 0);
      remoteTime    : slv(79 downto 0);
      correction    : slv(63 downto 0);
      responseTicks : slv(63 downto 0);
      timestamp     : slv(95 downto 0);
      increment     : slv(63 downto 0);
      tickPhase     : slv(PTP_TICK_PHASE_BITS_C-1 downto 0);
      timeValid     : sl;
   end record;

   constant ENTRY_INIT_C : EntryType := (
      sequenceId       => (others => '0'),
      generation       => (others => '0'),
      identity         => (others => '0'),
      domainNumber     => (others => '0'),
      born             => (others => '0'),
      wireTicks        => (others => '0'),
      remoteTime       => (others => '0'),
      correction       => (others => '0'),
      responseTicks    => (others => '0'),
      timestamp        => (others => '0'),
      increment        => (others => '0'),
      tickPhase        => (others => '0'),
      timeValid        => '0');

   function packEntry (entry : EntryType) return EntryPayloadType is
   begin
      return entry.sequenceId & entry.generation & entry.identity & entry.domainNumber &
         entry.born & entry.wireTicks & entry.remoteTime & entry.correction & entry.responseTicks &
         entry.timestamp & entry.increment & entry.tickPhase & entry.timeValid;
   end function;

   function unpackEntry (payload : EntryPayloadType) return EntryType is
      variable entry : EntryType;
      variable index : natural := ENTRY_WIDTH_C;
      procedure take (variable field : out slv) is
      begin
         field := payload(index-1 downto index-field'length);
         index := index-field'length;
      end procedure;

   begin
      take(entry.sequenceId);
      take(entry.generation);
      take(entry.identity);
      take(entry.domainNumber);
      take(entry.born);
      take(entry.wireTicks);
      take(entry.remoteTime);
      take(entry.correction);
      take(entry.responseTicks);
      take(entry.timestamp);
      take(entry.increment);
      take(entry.tickPhase);
      entry.timeValid := payload(0);
      return entry;
   end function;

   constant STARTUP_BIT_C    : natural := 0;
   constant RESET_SEEN_BIT_C : natural := 1;
   type StateType is (START_S, READ_S, CHECK_S, ADMIT_S);
   type RegType is record
      state            : StateType;
      used             : slv(DEPTH_G-1 downto 0);
      retired          : slv(DEPTH_G-1 downto 0);
      wireSeen         : slv(DEPTH_G-1 downto 0);
      responseSeen     : slv(DEPTH_G-1 downto 0);
      index            : natural range 0 to DEPTH_G-1;
      freeSlot         : natural range 0 to DEPTH_G-1;
      freeFound        : sl;
      collision        : sl;
      wireActive       : sl;
      responseActive   : sl;
      accepted         : sl;
      ready            : sl;
      wireReady        : sl;
      responseReady    : sl;
      responseAccepted : sl;
      ledgerStatus     : slv(31 downto 0);
      nextSequence     : unsigned(SEQUENCE_BITS_G-1 downto 0);
      resetTick        : slv(63 downto 0);
      resetPrevious    : sl;
      sample           : PtpDelaySampleType;
      sampleValid      : sl;
      writeEnable      : sl;
      writeAddress     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      writeData        : EntryPayloadType;
      readEnable       : sl;
      readAddress      : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      timeoutCount     : slv(31 downto 0);
      rejectedCount    : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      state            => START_S,
      used             => (others => '0'),
      retired          => (others => '0'),
      wireSeen         => (others => '0'),
      responseSeen     => (others => '0'),
      index            => 0,
      freeSlot         => 0,
      freeFound        => '0',
      collision        => '0',
      wireActive       => '0',
      responseActive   => '0',
      accepted         => '0',
      ready            => '0',
      wireReady        => '0',
      responseReady    => '0',
      responseAccepted => '0',
      ledgerStatus     => (STARTUP_BIT_C => '1', others => '0'),
      nextSequence     => (others => '0'),
      resetTick        => (others => '0'),
      resetPrevious    => '0',
      sample           => PTP_DELAY_SAMPLE_INIT_C,
      sampleValid      => '0',
      writeEnable      => '0',
      writeAddress     => (others => '0'),
      writeData        => (others => '0'),
      readEnable       => '0',
      readAddress      => (others => '0'),
      timeoutCount     => (others => '0'),
      rejectedCount    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal readData : EntryPayloadType;

   -- One row can contribute a wire rejection and a response/sample rejection.
   -- Sum local events before the single saturating diagnostic update.
   function addEvents (value : slv(31 downto 0); events : natural) return slv is
      variable total : unsigned(32 downto 0);
   begin
      total := resize(unsigned(value), total'length) + to_unsigned(events, total'length);
      if total(32) = '1' then
         return slv'(x"FFFFFFFF");
      end if;
      return slv(total(31 downto 0));
   end function;

begin

   assert DEPTH_G <= 255
      report "PtpTxLedger DEPTH_G must fit the eight-bit occupancy counters" severity failure;
   assert MEMORY_TYPE_G = "distributed" or MEMORY_TYPE_G = "block"
      report "PtpTxLedger MEMORY_TYPE_G must be distributed or block" severity failure;

   U_EntryRam : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         DATA_WIDTH_G   => ENTRY_WIDTH_C,
         -- Whole-row writes also keep the unused byte-enable port one bit wide.
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => ENTRY_WIDTH_C,
         ADDR_WIDTH_G   => RAM_ADDR_WIDTH_C,
         SYNTH_MODE_G   => "inferred",
         COMMON_CLK_G   => true,
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,             -- [in]
         wea   => r.writeEnable,   -- [in]
         addra => r.writeAddress,  -- [in]
         dina  => r.writeData,     -- [in]
         clkb  => clk,             -- [in]
         enb   => r.readEnable,    -- [in]
         rstb  => rst,             -- [in]
         addrb => r.readAddress,   -- [in]
         doutb => readData);       -- [out]

   comb : process (r, rst, restart, macResetDone, ticks, generation, config, allocate,
                   wireMessage, wireValid, response, responseValid, sampleReady, readData) is
      variable v              : RegType;
      variable entry          : EntryType;
      variable rejectedEvents : natural range 0 to 2;
      variable pendingInput   : boolean;
   begin
      v                  := r;
      entry              := ENTRY_INIT_C;
      rejectedEvents     := 0;
      v.ready            := '0';
      v.wireReady        := '0';
      v.responseReady    := '0';
      v.responseAccepted := '0';
      v.writeEnable      := '0';
      v.readEnable       := '0';
      v.resetPrevious    := macResetDone;
      if r.sampleValid = '1' and sampleReady = '1' then
         v.sampleValid := '0';
      end if;

      -- Inputs are held by their producers through the end-of-scan handshake.
      -- A flush may withdraw valid; it cannot substitute a new record halfway
      -- through the scan. Logical restart cancels only response eligibility.
      if wireValid = '0' then
         v.wireActive := '0';
      end if;
      if responseValid = '0' or restart = '1' then
         v.responseActive := '0';
         v.accepted       := '0';
      end if;
      -- Do not publish or reclaim past a record that arrived after START.
      -- Its next scan may retire a completed association or renew quarantine.
      pendingInput := (wireValid = '1' and v.wireActive = '0') or
                      (responseValid = '1' and v.responseActive = '0');

      case r.state is
         when START_S =>
            v.index          := 0;
            v.freeFound      := '0';
            v.collision      := '0';
            v.accepted       := '0';
            v.wireActive     := wireValid;
            v.responseActive := responseValid and not restart;
            v.readAddress    := (others => '0');
            v.readEnable     := '1';
            v.state          := READ_S;

         when READ_S =>
            -- The RAM samples its registered request on this edge.
            v.state := CHECK_S;

         when CHECK_S =>
            entry := unpackEntry(readData);
            if r.used(r.index) = '1' then
               -- Timeout is checked before event attachment and publication.
               if r.retired(r.index) = '0' and
                  unsigned(ticks)-unsigned(entry.born) > unsigned(config.associationTimeout) then
                  v.retired(r.index) := '1';
                  v.timeoutCount     := ptpSatInc(r.timeoutCount);
               end if;
               if restart = '1' then
                  v.retired(r.index) := '1';
               end if;
               if v.wireActive = '1' and wireMessage.sequenceId = entry.sequenceId and
                  wireMessage.sourcePortIdentity = entry.identity and
                  wireMessage.domainNumber = entry.domainNumber and wireMessage.messageType = PTP_MSG_DELAY_REQ_C then
                  v.wireSeen(r.index) := '1';
                  entry.wireTicks     := wireMessage.capture.ticks;
                  v.writeEnable       := '1';
                  -- Physical fate survives every logical retirement. A later
                  -- duplicate renews quarantine even for an already retired key.
                  if r.wireSeen(r.index) = '1' or wireMessage.capture.error = '1' or
                     wireMessage.capture.generation /= entry.generation then
                     v.retired(r.index) := '1';
                     rejectedEvents     := rejectedEvents+1;
                  elsif v.retired(r.index) = '0' then
                     entry.timestamp := wireMessage.capture.timestamp;
                     entry.increment := wireMessage.capture.increment;
                     entry.tickPhase := wireMessage.capture.tickPhase;
                     entry.timeValid := wireMessage.capture.timeValid;
                  end if;
               end if;
               if v.responseActive = '1' and v.retired(r.index) = '0' and
                  response.sequenceId = entry.sequenceId and response.domainNumber = entry.domainNumber and
                  ptpRequestingIdentity(response) = entry.identity and response.capture.generation = entry.generation then
                  if response.correction = PTP_CORRECTION_OVERFLOW_C then
                     v.retired(r.index) := '1';
                     rejectedEvents     := rejectedEvents+1;
                  elsif r.responseSeen(r.index) = '1' then
                     if entry.remoteTime /= ptpMessageTimestamp(response) or entry.correction /= response.correction then
                        v.retired(r.index) := '1';
                        rejectedEvents     := rejectedEvents+1;
                     end if;
                  else
                     v.responseSeen(r.index) := '1';
                     v.accepted              := '1';
                     entry.remoteTime        := ptpMessageTimestamp(response);
                     entry.correction        := response.correction;
                     entry.responseTicks     := response.capture.ticks;
                     v.writeEnable           := '1';
                  end if;
               end if;
               if v.retired(r.index) = '0' and v.wireSeen(r.index) = '1' and
                  v.responseSeen(r.index) = '1' and v.sampleValid = '0' and not pendingInput then
                  v.retired(r.index) := '1';
                  if unsigned(entry.responseTicks) >= unsigned(entry.wireTicks) and
                     unsigned(entry.responseTicks)-unsigned(entry.wireTicks) <= PACKET_LIFETIME_G and
                     unsigned(ticks)-unsigned(entry.wireTicks) <= PACKET_LIFETIME_G and entry.generation = generation then
                     v.sample                    := PTP_DELAY_SAMPLE_INIT_C;
                     v.sample.sequenceId         := entry.sequenceId;
                     v.sample.generation         := entry.generation;
                     v.sample.capture.timestamp  := entry.timestamp;
                     v.sample.capture.increment  := entry.increment;
                     v.sample.capture.tickPhase  := entry.tickPhase;
                     v.sample.capture.timeValid  := entry.timeValid;
                     v.sample.capture.ticks      := entry.wireTicks;
                     v.sample.capture.generation := entry.generation;
                     v.sample.remoteTime         := entry.remoteTime;
                     v.sample.correction         := entry.correction;
                     v.sample.responseTicks      := entry.responseTicks;
                     v.sampleValid               := '1';
                  else
                     rejectedEvents := rejectedEvents+1;
                  end if;
               end if;
               -- Reclamation follows wire handling so a coincident duplicate
               -- extends quarantine before any allocator can reuse the slot.
               if v.retired(r.index) = '1' and v.wireSeen(r.index) = '1' and
                  unsigned(ticks)-unsigned(entry.wireTicks) > PACKET_LIFETIME_G and not pendingInput then
                  v.used(r.index) := '0';
               end if;
            end if;
            if v.used(r.index) = '0' then
               v.freeSlot  := r.index;
               v.freeFound := '1';
            elsif entry.sequenceId = slv(resize(r.nextSequence, 16)) then
               v.collision := '1';
            end if;
            v.writeAddress := toSlv(r.index, RAM_ADDR_WIDTH_C);
            v.writeData    := packEntry(entry);
            if r.index = DEPTH_G-1 then
               -- All rows have been checked against the same stable inputs.
               -- Ready is registered; producers transfer on the ADMIT edge.
               v.wireReady     := v.wireActive;
               v.responseReady := v.responseActive;
               if v.collision = '1' then
                  v.nextSequence := r.nextSequence+1;
               elsif v.freeFound = '1' and r.ledgerStatus(STARTUP_BIT_C) = '0' and restart = '0' then
                  v.ready := '1';
               end if;
               v.state := ADMIT_S;
            else
               v.index       := r.index+1;
               v.readAddress := toSlv(r.index+1, RAM_ADDR_WIDTH_C);
               v.readEnable  := '1';
               v.state       := READ_S;
            end if;

         when ADMIT_S =>
            if r.responseReady = '1' and responseValid = '1' then
               v.responseAccepted := r.accepted;
            end if;
            if r.ready = '1' and allocate = '1' and restart = '0' then
               entry                      := ENTRY_INIT_C;
               entry.sequenceId           := slv(resize(r.nextSequence, 16));
               entry.generation           := generation;
               entry.identity             := config.localIdentity;
               entry.domainNumber         := config.domainNumber;
               entry.born                 := ticks;
               v.used(r.freeSlot)         := '1';
               v.retired(r.freeSlot)      := '0';
               v.wireSeen(r.freeSlot)     := '0';
               v.responseSeen(r.freeSlot) := '0';
               v.writeEnable              := '1';
               v.writeAddress             := toSlv(r.freeSlot, RAM_ADDR_WIDTH_C);
               v.writeData                := packEntry(entry);
               v.nextSequence             := r.nextSequence+1;
            end if;
            v.state := START_S;
      end case;
      v.rejectedCount := addEvents(r.rejectedCount, rejectedEvents);

      if r.ledgerStatus(STARTUP_BIT_C) = '1' and r.ledgerStatus(RESET_SEEN_BIT_C) = '1' and
         unsigned(ticks)-unsigned(r.resetTick) > PACKET_LIFETIME_G then
         v.ledgerStatus(STARTUP_BIT_C) := '0';
      end if;
      if restart = '1' then
         v.retired          := (others => '1');
         v.sampleValid      := '0';
         v.ready            := '0';
         v.accepted         := '0';
         v.responseAccepted := '0';
      end if;
      if macResetDone = '1' and r.resetPrevious = '0' then
         -- Reset validity, never the RAM. Stale rows are ignored until a fresh
         -- allocation overwrites their entire payload. Preserve diagnostics.
         v.used                           := (others => '0');
         v.retired                        := (others => '0');
         v.wireSeen                       := (others => '0');
         v.responseSeen                   := (others => '0');
         v.ledgerStatus(STARTUP_BIT_C)    := '1';
         v.ledgerStatus(RESET_SEEN_BIT_C) := '1';
         v.resetTick                      := ticks;
         v.sampleValid                    := '0';
         v.writeEnable                    := '0';
         v.readEnable                     := '0';
         v.ready                          := '0';
         v.wireReady                      := '0';
         v.responseReady                  := '0';
         v.responseAccepted               := '0';
         v.state                          := START_S;
      end if;
      v.ledgerStatus(15 downto 8)  := (others => '0');
      v.ledgerStatus(23 downto 16) := (others => '0');
      for i in 0 to DEPTH_G-1 loop
         if v.used(i) = '1' then
            v.ledgerStatus(15 downto 8) := slv(unsigned(v.ledgerStatus(15 downto 8))+1);
            if v.wireSeen(i) = '0' then
               v.ledgerStatus(23 downto 16) := slv(unsigned(v.ledgerStatus(23 downto 16))+1);
            end if;
         end if;
      end loop;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;
      allocateReady <= r.ready;
      allocateSequence <= slv(resize(r.nextSequence, 16));
      wireReady <= r.wireReady;
      responseReady <= r.responseReady;
      responseAccepted <= r.responseAccepted;
      sample <= r.sample;
      sampleValid <= r.sampleValid;
      ledgerStatus <= r.ledgerStatus;
      timeoutCount <= r.timeoutCount;
      rejectedCount <= r.rejectedCount;
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
