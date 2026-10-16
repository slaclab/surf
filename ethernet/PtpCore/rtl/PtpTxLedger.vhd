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
-- Entries use 22 addressed 32-bit words with four ownership flags per slot.
-- A scan compares keys and updates individual words, staging only ages and
-- match flags. The sole full sample register is the held publication boundary.
-- At depth D, scans repeat every 45*D+2 clocks; an accepted allocation adds 22
-- clocks to initialize its words. Producers hold their entire record through
-- ready. Logical restart cancels response eligibility; RAM is never reset.
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
use surf.PtpProtocolPkg.all;
use surf.PtpPkg.all;

entity PtpTxLedger is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      DEPTH_G           : positive               := 4;  -- 1..255; occupancy status uses eight bits.
      SEQUENCE_BITS_G   : positive range 1 to 16 := 16;
      PACKET_LIFETIME_G : positive               := 156250000;
      MEMORY_TYPE_G     : string                 := "block");
   port (
      clk            : in  sl;
      rst            : in  sl;
      restart        : in  sl;
      macResetDone   : in  sl;
      ticks          : in  slv(63 downto 0);
      generation     : in  slv(31 downto 0);
      config         : in  PtpPortConfigType;
      allocate       : in  sl;
      allocation     : out PtpLedgerAllocationType;
      wireMaster     : in  PtpRxMessageMasterType;
      wireReady      : out sl;
      responseMaster : in  PtpRxMessageMasterType;
      responseReady  : out sl;
      -- Registered valid; restart/system reset cancel a coincident transfer.
      -- macResetDone confirms that shared system reset has drained the MAC.
      sampleMaster : out PtpDelaySampleMasterType;
      sampleReady  : in  sl;
      ledgerStatus : out slv(31 downto 0);
      -- Registered completion for the response transferred on the previous edge.
      -- The caller retains that response's metadata until this result arrives.
      responseAccepted : out sl;
      timeoutCount     : out slv(31 downto 0);
      rejectedCount    : out slv(31 downto 0));
end entity PtpTxLedger;

architecture rtl of PtpTxLedger is

   -- Each row has 22 addressed words. Padding is local to a field so a scan
   -- compares keys and updates capture/response fields without a full-row latch.
   constant WORDS_C          : positive := 22;
   constant RAM_ADDR_WIDTH_C : positive := log2(DEPTH_G*WORDS_C);
   constant STARTUP_BIT_C    : natural := 0;
   constant RESET_SEEN_BIT_C : natural := 1;
   type StateType is (START_S, READ_S, CHECK_S, FINISH_S, ADMIT_S, ALLOCATE_S);
   type RegType is record
      state           : StateType;
      used            : slv(DEPTH_G-1 downto 0);
      retired         : slv(DEPTH_G-1 downto 0);
      wireSeen        : slv(DEPTH_G-1 downto 0);
      responseSeen    : slv(DEPTH_G-1 downto 0);
      index           : natural range 0 to DEPTH_G-1;
      field           : natural range 0 to WORDS_C-1;
      sequenceMatch   : sl;
      wireMatch       : sl;
      responseMatch   : sl;
      wireBad         : sl;
      wireUpdate      : sl;
      responseNew     : sl;
      responseCompare : sl;
      responseEqual   : sl;
      publish         : sl;
      lifetimeValid   : sl;
      entryGeneration : slv(31 downto 0);
      scanTicks       : slv(63 downto 0);
      scanWireTicks   : slv(63 downto 0);
      -- Allocation is a public transfer. Freeze its key and birth edge while
      -- the words are written; later configuration changes cannot rename it.
      allocationSequence   : slv(15 downto 0);
      allocationDomain     : slv(7 downto 0);
      allocationIdentity   : slv(79 downto 0);
      allocationGeneration : slv(31 downto 0);
      allocationTicks      : slv(63 downto 0);
      freeSlot             : natural range 0 to DEPTH_G-1;
      freeFound            : sl;
      collision            : sl;
      wireActive           : sl;
      responseActive       : sl;
      accepted             : sl;
      ready                : sl;
      wireReady            : sl;
      responseReady        : sl;
      responseAccepted     : sl;
      ledgerStatus         : slv(31 downto 0);
      nextSequence         : unsigned(SEQUENCE_BITS_G-1 downto 0);
      resetTick            : slv(63 downto 0);
      resetPrevious        : sl;
      sampleMaster         : PtpDelaySampleMasterType;
      writeEnable          : sl;
      writeAddress         : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      writeData            : slv(31 downto 0);
      readEnable           : sl;
      readAddress          : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      timeoutCount         : slv(31 downto 0);
      rejectedCount        : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      state                => START_S,
      used                 => (others => '0'),
      retired              => (others => '0'),
      wireSeen             => (others => '0'),
      responseSeen         => (others => '0'),
      index                => 0,
      field                => 0,
      sequenceMatch        => '0',
      wireMatch            => '0',
      responseMatch        => '0',
      wireBad              => '0',
      wireUpdate           => '0',
      responseNew          => '0',
      responseCompare      => '0',
      responseEqual        => '1',
      publish              => '0',
      lifetimeValid        => '0',
      entryGeneration      => (others => '0'),
      scanTicks            => (others => '0'),
      scanWireTicks        => (others => '0'),
      allocationSequence   => (others => '0'),
      allocationDomain     => (others => '0'),
      allocationIdentity   => (others => '0'),
      allocationGeneration => (others => '0'),
      allocationTicks      => (others => '0'),
      freeSlot             => 0,
      freeFound            => '0',
      collision            => '0',
      wireActive           => '0',
      responseActive       => '0',
      accepted             => '0',
      ready                => '0',
      wireReady            => '0',
      responseReady        => '0',
      responseAccepted     => '0',
      ledgerStatus         => (STARTUP_BIT_C => '1', others => '0'),
      nextSequence         => (others => '0'),
      resetTick            => (others => '0'),
      resetPrevious        => '0',
      sampleMaster         => PTP_DELAY_SAMPLE_MASTER_INIT_C,
      writeEnable          => '0',
      writeAddress         => (others => '0'),
      writeData            => (others => '0'),
      readEnable           => '0',
      readAddress          => (others => '0'),
      timeoutCount         => (others => '0'),
      rejectedCount        => (others => '0'));

   signal r        : RegType := REG_INIT_C;
   signal rin      : RegType;
   signal readData : slv(31 downto 0);
   -- One row can contribute a wire rejection and a response/sample rejection.
   -- Sum local events before the single saturating diagnostic update.
   function addEvents (value : slv(31 downto 0);
   events : natural) return slv is
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
         DATA_WIDTH_G   => 32,
         -- Whole-row writes also keep the unused byte-enable port one bit wide.
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
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
                   wireMaster.data, wireMaster.valid, responseMaster.data, responseMaster.valid, sampleReady, readData) is
      variable v              : RegType;
      variable word           : slv(31 downto 0);
      variable expected       : slv(31 downto 0);
      variable identity       : slv(95 downto 0);
      variable remoteTime     : slv(95 downto 0);
      variable rejectedEvents : natural range 0 to 2;
      variable pendingInput   : boolean;
      variable scanLeft       : unsigned(63 downto 0);
      variable scanRight      : unsigned(63 downto 0);
      variable scanLimit      : unsigned(63 downto 0);
      variable scanDifference : unsigned(64 downto 0);
      variable scanWithin     : boolean;
   begin
      v                  := r;
      word               := readData;
      expected           := (others => '0');
      identity           := x"0000" & ptpRequestingIdentity(responseMaster.data);
      remoteTime         := x"0000" & ptpMessageTimestamp(responseMaster.data);
      rejectedEvents     := 0;
      v.ready            := '0';
      v.wireReady        := '0';
      v.responseReady    := '0';
      v.responseAccepted := '0';
      v.writeEnable      := '0';
      v.readEnable       := '0';
      v.resetPrevious    := macResetDone;

      if r.sampleMaster.valid = '1' and sampleReady = '1' then
         v.sampleMaster.valid := '0';
      end if;

      -- Inputs are held by their producers through the end-of-scan handshake.
      -- A flush may withdraw valid; it cannot substitute a new record halfway
      -- through the scan. Logical restart cancels only response eligibility.
      if wireMaster.valid = '0' then
         v.wireActive := '0';
      end if;

      if responseMaster.valid = '0' or restart = '1' then
         v.responseActive := '0';
         v.accepted       := '0';
      end if;

      -- Do not publish or reclaim past a record that arrived after START.
      -- Its next scan may retire a completed association or renew quarantine.
      pendingInput := (wireMaster.valid = '1' and v.wireActive = '0') or
                      (responseMaster.valid = '1' and v.responseActive = '0');

      -- One age datapath serves mutually exclusive scan phases. Select the
      -- returning high word before subtraction, including a new response word.
      -- Live expiry uses modulo-64 subtraction at its original check edge;
      -- response chronology additionally requires no borrow in bit 64.
      scanLeft  := unsigned(ticks);
      scanRight := unsigned(r.scanWireTicks);
      scanLimit := to_unsigned(PACKET_LIFETIME_G, 64);
      if r.state = CHECK_S and r.field = 6 then
         scanRight := unsigned(slv'(readData & r.scanTicks(31 downto 0)));
         scanLimit := unsigned(config.associationTimeout);
      elsif r.state = CHECK_S and r.field = 10 then
         scanLeft := unsigned(slv'(readData & r.scanTicks(31 downto 0)));
         if r.responseNew = '1' then
            scanLeft(63 downto 32) := unsigned(responseMaster.data.capture.ticks(63 downto 32));
         end if;
      end if;
      scanDifference := resize(scanLeft,65)-resize(scanRight,65);
      scanWithin     := scanDifference(63 downto 0) <= scanLimit;

      case r.state is
         when START_S =>
            v.index          := 0;
            v.field          := 0;
            v.freeFound      := '0';
            v.collision      := '0';
            v.accepted       := '0';
            v.wireActive     := wireMaster.valid;
            v.responseActive := responseMaster.valid and not restart;
            v.publish        := not v.sampleMaster.valid;
            v.readAddress    := (others => '0');
            v.readEnable     := '1';
            v.state          := READ_S;
         when READ_S =>
            v.state := CHECK_S;
         when CHECK_S =>

            if r.used(r.index) = '1' then

               case r.field is
                  when 0 =>
                     v.wireMatch := toSl(v.wireActive = '1' and wireMaster.data.messageType = PTP_MSG_DELAY_REQ_C and
                        wireMaster.data.sequenceId = word(15 downto 0) and wireMaster.data.domainNumber = word(23 downto 16));
                     v.responseMatch := toSl(v.responseActive = '1' and responseMaster.data.sequenceId = word(15 downto 0) and
                        responseMaster.data.domainNumber = word(23 downto 16));
                     v.wireUpdate      := '0';
                     v.responseNew     := '0';
                     v.responseCompare := '0';
                     v.responseEqual   := '1';
                     v.sequenceMatch   := toSl(word(15 downto 0) = slv(resize(r.nextSequence, 16)));
                     if r.publish = '1' then
                        v.sampleMaster.data            := PTP_DELAY_SAMPLE_INIT_C;
                        v.sampleMaster.data.sequenceId := word(15 downto 0);
                     end if;
                  when 1 =>
                     v.entryGeneration := word;
                     v.wireBad         := toSl(wireMaster.data.capture.error = '1' or wireMaster.data.capture.generation /= word);
                     v.responseMatch   := r.responseMatch and toSl(responseMaster.data.capture.generation = word);
                     if r.publish = '1' then
                        v.sampleMaster.data.generation         := word;
                        v.sampleMaster.data.capture.generation := word;
                     end if;
                  when 2 to 4 =>
                     -- The padded high identity word is compared too.
                     identity        := x"0000" & wireMaster.data.sourcePortIdentity;
                     v.wireMatch     := r.wireMatch and toSl(word = identity(32*(r.field-2)+31 downto 32*(r.field-2)));
                     identity        := x"0000" & ptpRequestingIdentity(responseMaster.data);
                     v.responseMatch := r.responseMatch and toSl(word = identity(32*(r.field-2)+31 downto 32*(r.field-2)));
                  when 5 =>
                     v.scanTicks(31 downto 0) := word;
                  when 6 =>
                     v.scanTicks(63 downto 32) := word;
                     if r.retired(r.index) = '0' and
                        not scanWithin then
                        v.retired(r.index) := '1';
                        v.timeoutCount := ptpSatInc(r.timeoutCount);
                     end if;
                  when 7 =>
                     if r.wireMatch = '1' and v.wireActive = '1' then
                        word          := wireMaster.data.capture.ticks(31 downto 0);
                        v.writeEnable := '1';
                        if r.wireSeen(r.index) = '1' or r.wireBad = '1' then
                           v.retired(r.index) := '1';
                           rejectedEvents := rejectedEvents+1;
                        elsif v.retired(r.index) = '0' then
                           v.wireUpdate := '1';
                        end if;
                     end if;
                     v.scanWireTicks(31 downto 0) := word;
                     if r.publish = '1' then
                        v.sampleMaster.data.capture.ticks(31 downto 0) := word;
                     end if;
                  when 8 =>
                     if r.wireMatch = '1' and v.wireActive = '1' then
                        word          := wireMaster.data.capture.ticks(63 downto 32);
                        v.writeEnable := '1';
                        v.wireSeen(r.index) := '1';
                     end if;
                     v.scanWireTicks(63 downto 32) := word;
                     if r.publish = '1' then
                        v.sampleMaster.data.capture.ticks(63 downto 32) := word;
                     end if;
                  when 9 =>
                     if r.responseMatch = '1' and v.responseActive = '1' and v.retired(r.index) = '0' then
                        if responseMaster.data.correction = PTP_CORRECTION_OVERFLOW_C then
                           v.retired(r.index) := '1';
                           rejectedEvents := rejectedEvents+1;
                        elsif r.responseSeen(r.index) = '1' then
                           v.responseCompare := '1';
                        else
                           v.responseNew := '1';
                           word          := responseMaster.data.capture.ticks(31 downto 0);
                           v.writeEnable := '1';
                        end if;
                     end if;
                     v.scanTicks(31 downto 0) := word;
                     if r.publish = '1' then
                        v.sampleMaster.data.responseTicks(31 downto 0) := word;
                     end if;
                  when 10 =>
                     if r.responseNew = '1' then
                        word          := responseMaster.data.capture.ticks(63 downto 32);
                        v.writeEnable := '1';
                     end if;
                     v.scanTicks(63 downto 32) := word;
                     v.lifetimeValid := toSl(scanDifference(64) = '0' and scanWithin);
                     if r.publish = '1' then
                        v.sampleMaster.data.responseTicks(63 downto 32) := word;
                     end if;
                  when 11 to 15 =>
                     if r.field <= 13 then
                        expected := remoteTime(32*(r.field-11)+31 downto 32*(r.field-11));
                     else
                        expected := responseMaster.data.correction(32*(r.field-14)+31 downto 32*(r.field-14));
                     end if;
                     if r.responseNew = '1' then
                        word          := expected;
                        v.writeEnable := '1';
                     elsif r.responseCompare = '1' then
                        v.responseEqual := r.responseEqual and toSl(word = expected);
                     end if;
                     if r.publish = '1' then

                        case r.field is
                           when 11 to 12 =>
                              v.sampleMaster.data.remoteTime(32*(r.field-11)+31 downto 32*(r.field-11)) := word;
                           when 13 =>
                              v.sampleMaster.data.remoteTime(79 downto 64) := word(15 downto 0);
                           when others =>
                              v.sampleMaster.data.correction(32*(r.field-14)+31 downto 32*(r.field-14)) := word;
                        end case;

                     end if;
                  when 16 to 21 =>
                     if r.wireUpdate = '1' then

                        case r.field is
                           when 16 to 18 =>
                              word := wireMaster.data.capture.timestamp(32*(r.field-16)+31 downto 32*(r.field-16));
                           when 19 to 20 =>
                              word := wireMaster.data.capture.increment(32*(r.field-19)+31 downto 32*(r.field-19));
                           when others =>
                              word := (others => '0');
                              word(PTP_TICK_PHASE_BITS_C-1 downto 0) := wireMaster.data.capture.tickPhase;
                              word(PTP_TICK_PHASE_BITS_C) := wireMaster.data.capture.timeValid;
                        end case;

                        v.writeEnable := '1';
                     end if;
                     if r.publish = '1' then

                        case r.field is
                           when 16 to 18 =>
                              v.sampleMaster.data.capture.timestamp(32*(r.field-16)+31 downto 32*(r.field-16)) := word;
                           when 19 to 20 =>
                              v.sampleMaster.data.capture.increment(32*(r.field-19)+31 downto 32*(r.field-19)) := word;
                           when others =>
                              v.sampleMaster.data.capture.tickPhase := word(PTP_TICK_PHASE_BITS_C-1 downto 0);
                              v.sampleMaster.data.capture.timeValid := word(PTP_TICK_PHASE_BITS_C);
                        end case;

                     end if;
               end case;

            end if;

            v.writeAddress := toSlv(WORDS_C*r.index+r.field, RAM_ADDR_WIDTH_C);
            v.writeData    := word;

            if r.field = WORDS_C-1 then
               v.state := FINISH_S;
            else
               v.field       := r.field+1;
               v.readAddress := toSlv(WORDS_C*r.index+r.field+1, RAM_ADDR_WIDTH_C);
               v.readEnable  := '1';
               v.state       := READ_S;
            end if;

         when FINISH_S =>

            if r.used(r.index) = '1' then
               if r.responseNew = '1' and v.responseActive = '1' and v.retired(r.index) = '0' then
                  v.responseSeen(r.index) := '1';
                  v.accepted := '1';
               elsif r.responseCompare = '1' and r.responseEqual = '0' and v.retired(r.index) = '0' then
                  v.retired(r.index) := '1';
                  rejectedEvents := rejectedEvents+1;
               end if;
               if v.retired(r.index) = '0' and v.wireSeen(r.index) = '1' and
                  v.responseSeen(r.index) = '1' and r.publish = '1' and not pendingInput then
                  v.retired(r.index) := '1';
                  if r.lifetimeValid = '1' and scanWithin and
                     r.entryGeneration = generation then
                     v.sampleMaster.valid := '1';
                  else
                     rejectedEvents := rejectedEvents+1;
                  end if;
               end if;
               if v.retired(r.index) = '1' and v.wireSeen(r.index) = '1' and
                  not scanWithin and not pendingInput then
                  v.used(r.index) := '0';
               end if;
            end if;

            if v.used(r.index) = '0' then
               v.freeSlot  := r.index;
               v.freeFound := '1';
            elsif r.sequenceMatch = '1' then
               v.collision := '1';
            end if;

            if r.index = DEPTH_G-1 then
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
               v.field       := 0;
               v.publish     := not v.sampleMaster.valid;
               v.readAddress := toSlv(WORDS_C*(r.index+1), RAM_ADDR_WIDTH_C);
               v.readEnable  := '1';
               v.state       := READ_S;
            end if;

         when ADMIT_S =>

            if r.responseReady = '1' and responseMaster.valid = '1' then
               v.responseAccepted := r.accepted;
            end if;

            v.state := START_S;

            if r.ready = '1' and allocate = '1' and restart = '0' then
               v.allocationSequence   := slv(resize(r.nextSequence, 16));
               v.allocationGeneration := generation;
               v.allocationIdentity   := config.localIdentity;
               v.allocationDomain     := config.domainNumber;
               v.allocationTicks      := ticks;
               v.used(r.freeSlot) := '1';
               v.retired(r.freeSlot) := '0';
               v.wireSeen(r.freeSlot) := '0';
               v.responseSeen(r.freeSlot) := '0';
               v.nextSequence := r.nextSequence+1;
               v.field        := 0;
               v.state        := ALLOCATE_S;
            end if;

         when ALLOCATE_S =>
            word     := (others => '0');
            identity := x"0000" & r.allocationIdentity;

            case r.field is
               when 0 =>
                  word(15 downto 0) := r.allocationSequence;
                  word(23 downto 16) := r.allocationDomain;
               when 1 =>
                  word := r.allocationGeneration;
               when 2 to 4 =>
                  word := identity(32*(r.field-2)+31 downto 32*(r.field-2));
               when 5 to 6 =>
                  word := r.allocationTicks(32*(r.field-5)+31 downto 32*(r.field-5));
               when others =>
                  null;
            end case;

            v.writeEnable  := '1';
            v.writeAddress := toSlv(WORDS_C*r.freeSlot+r.field, RAM_ADDR_WIDTH_C);
            v.writeData    := word;

            if r.field = WORDS_C-1 then
               v.state := START_S;
            else
               v.field := r.field+1;
            end if;

      end case;

      v.rejectedCount := addEvents(r.rejectedCount, rejectedEvents);

      if r.ledgerStatus(STARTUP_BIT_C) = '1' and r.ledgerStatus(RESET_SEEN_BIT_C) = '1' and
         unsigned(ticks)-unsigned(r.resetTick) > PACKET_LIFETIME_G then
         v.ledgerStatus(STARTUP_BIT_C) := '0';
      end if;

      if restart = '1' then
         v.retired            := (others => '1');
         v.sampleMaster.valid := '0';
         v.ready              := '0';
         v.accepted           := '0';
         v.responseAccepted   := '0';
      end if;

      if macResetDone = '1' and r.resetPrevious = '0' then
         -- Reset validity, never the RAM. Stale rows are ignored until a fresh
         -- allocation overwrites their entire payload. Preserve diagnostics.
         v.used         := (others => '0');
         v.retired      := (others => '0');
         v.wireSeen     := (others => '0');
         v.responseSeen := (others => '0');
         v.ledgerStatus(STARTUP_BIT_C)    := '1';
         v.ledgerStatus(RESET_SEEN_BIT_C) := '1';
         v.resetTick          := ticks;
         v.sampleMaster.valid := '0';
         v.writeEnable        := '0';
         v.readEnable         := '0';
         v.ready              := '0';
         v.wireReady          := '0';
         v.responseReady      := '0';
         v.responseAccepted   := '0';
         v.state              := START_S;
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
      -- The offered identifier and registered capacity describe one reservation edge.
      allocation <=
      (
         ready      => r.ready,
         sequenceId => slv(resize(r.nextSequence, 16))
      );
      wireReady        <= r.wireReady;
      responseReady    <= r.responseReady;
      responseAccepted <= r.responseAccepted;
      sampleMaster     <= r.sampleMaster;
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
