-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-port TX admission, ownership and completions
-------------------------------------------------------------------------------
-- TX half of PtpMacPort (ethernet/PtpCore/timing-port.md, section 4). A
-- request is admitted on its SOF beat only when a table entry is free; the
-- completion FIFO holds one record per entry, so admission also reserves the
-- completion slot. The entry index plus one is the MAC token stamped on
-- every beat. Frames pass through a store-and-forward hold store: a frame
-- that breaks the stream-shape rules (declared length, partial keep before
-- tLast, EOFE on tLast, nested SOF, missing EOF) is terminated with EOFE in
-- the store, whose outbound filter removes it, so no partial or rejected
-- frame reaches the MAC. Stale-generation and out-of-range requests are
-- consumed without storing. Beats with no SOF and no open frame are consumed
-- and counted as rejected; they have no request and no completion.
--
-- The exporter's start fixes the wire capture, evaluated from the registered
-- PHC copy while start is visible (section 2.4). done resolves the entry
-- SENT or WIRE_ERR; captureValid requires a timestamp request, a capture
-- without error, and no PHC generation change or capture abort from start
-- through done. Exporter and checksum retires resolve DISCARDED; releaseAll
-- (forced abort step four) resolves every open entry FLUSHED. Each entry
-- completes exactly once and is freed when its completion is accepted.
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpMacPortTx is
   generic (
      TPD_G              : time                    := 1 ns;
      RST_POLARITY_G     : sl                      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      TABLE_DEPTH_G      : positive range 1 to 255 := 16;
      STORE_ADDR_WIDTH_G : positive range 8 to 16  := 8;
      MEMORY_TYPE_G      : string                  := "block";
      SYNTH_MODE_G       : string                  := "inferred";
      EGRESS_LATENCY_G   : slv(63 downto 0)        := (others => '0'));
   port (
      clk              : in  sl;
      rst              : in  sl;
      -- Lifecycle from PtpMacPort
      admit            : in  sl;
      generation       : in  slv(15 downto 0);
      flush            : in  sl;
      releaseAll       : in  sl;
      idle             : out sl;
      protocolFault    : out sl;
      -- Registered PHC copy: the values standing during the previous cycle
      phcTime          : in  PtpTimeType;
      phcStatus        : in  PtpPhcStatusType;
      captureAbort     : in  sl;
      -- Controller
      txMaster         : in  PtpMacPortTxMasterType;
      txSlave          : out AxiStreamSlaveType;
      completionMaster : out PtpMacPortTxCompletionMasterType;
      completionReady  : in  sl;
      -- MAC
      macTxMaster      : out AxiStreamMasterType;
      macTxSlave       : in  AxiStreamSlaveType;
      txFrameEvent     : in  EthMacFrameEventType;
      txRetire         : in  EthMacTokenRetireArray(EMAC_TX_RETIRE_SOURCES_C-1 downto 0);
      -- One pulse per completion written, by outcome, and per rejected frame
      countSent        : out sl;
      countWireError   : out sl;
      countDiscarded   : out sl;
      countFlushed     : out sl;
      countRejected    : out sl);
end entity PtpMacPortTx;

architecture rtl of PtpMacPortTx is

   constant IN_CONFIG_C    : AxiStreamConfigType := EMAC_AXIS_CONFIG_C;
   constant STORE_CONFIG_C : AxiStreamConfigType := EMAC_TIMING_AXIS_CONFIG_C;
   constant MIN_LENGTH_C   : natural             := 16;
   constant MAX_LENGTH_C   : natural             := EMAC_TIMING_MAX_FRAME_C;
   constant EOF_SLACK_C    : natural             := 64;
   constant FIFO_WIDTH_C   : positive            := EMAC_TOKEN_BITS_C + PTP_MAC_PORT_TX_COMPLETION_BITS_C;
   constant FIFO_ADDR_C    : positive            := maximum(4, bitSize(TABLE_DEPTH_G));
   -- The TX tap applies the egress latency negated, as PtpTxTimestampTap does
   constant TX_LATENCY_C   : slv(63 downto 0)    := slv(-signed(EGRESS_LATENCY_G));

   -- Entry lifecycle: OPEN until resolved, PENDING until its completion is
   -- written, QUEUED until the controller accepts the completion.
   constant FREE_C    : slv(1 downto 0) := "00";
   constant OPEN_C    : slv(1 downto 0) := "01";
   constant PENDING_C : slv(1 downto 0) := "10";
   constant QUEUED_C  : slv(1 downto 0) := "11";

   type EntryType is record
      state      : slv(1 downto 0);
      cookie     : PtpMacPortCookieType;
      generation : slv(15 downto 0);
      timestamp  : sl;
      started    : sl;
      outcome    : slv(1 downto 0);
   end record EntryType;

   constant ENTRY_INIT_C : EntryType := (
      state      => FREE_C,
      cookie     => (others => '0'),
      generation => (others => '0'),
      timestamp  => '0',
      started    => '0',
      outcome    => PTP_MAC_PORT_OUTCOME_DISCARDED_C);

   type EntryArray is array (0 to TABLE_DEPTH_G-1) of EntryType;

   -- IDLE_S expects a SOF; STORE_S writes an admitted frame; CONSUME_S
   -- discards through tLast; DRAIN_S discards up to the next SOF.
   type StateType is (
      IDLE_S,
      STORE_S,
      CONSUME_S,
      DRAIN_S);

   type RegType is record
      state         : StateType;
      entry         : EntryArray;
      current       : natural range 0 to TABLE_DEPTH_G-1;
      declared      : unsigned(15 downto 0);
      bytes         : unsigned(15 downto 0);
      bad           : sl;
      storeMaster   : AxiStreamMasterType;
      wireActive    : sl;
      wireIndex     : natural range 0 to TABLE_DEPTH_G-1;
      wireOk        : sl;
      wireGen       : slv(31 downto 0);
      wireCapture   : PtpRxCaptureType;
      fifoWrite     : sl;
      fifoData      : slv(FIFO_WIDTH_C-1 downto 0);
      protocolFault : sl;
      idle          : sl;
      countSent     : sl;
      countWireErr  : sl;
      countDiscard  : sl;
      countFlushed  : sl;
      countRejected : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state         => IDLE_S,
      entry         => (others => ENTRY_INIT_C),
      current       => 0,
      declared      => (others => '0'),
      bytes         => (others => '0'),
      bad           => '0',
      storeMaster   => AXI_STREAM_MASTER_INIT_C,
      wireActive    => '0',
      wireIndex     => 0,
      wireOk        => '0',
      wireGen       => (others => '0'),
      wireCapture   => PTP_RX_CAPTURE_INIT_C,
      fifoWrite     => '0',
      fifoData      => (others => '0'),
      protocolFault => '0',
      idle          => '1',
      countSent     => '0',
      countWireErr  => '0',
      countDiscard  => '0',
      countFlushed  => '0',
      countRejected => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal storeSlave : AxiStreamSlaveType;
   signal storeRst   : sl;
   signal fifoDout   : slv(FIFO_WIDTH_C-1 downto 0);
   signal fifoValid  : sl;
   signal fifoRead   : sl;

   -- Byte count of a beat's tKeep
   function keepBytes (keep : slv(15 downto 0)) return natural is
      variable count : natural range 0 to 16 := 0;
   begin
      for i in 0 to 15 loop
         if (keep(i) = '1') then
            count := count + 1;
         end if;
      end loop;
      return count;
   end function keepBytes;

   -- Map a 1-based token to its entry index, or -1 when out of range
   function tokenIndex (token : EthMacTokenType) return integer is
      variable value : natural;
   begin
      value := to_integer(unsigned(token));
      if (value >= 1) and (value <= TABLE_DEPTH_G) then
         return value - 1;
      end if;
      return -1;
   end function tokenIndex;

   function tokenOf (index : natural) return EthMacTokenType is
   begin
      return slv(to_unsigned(index+1, EMAC_TOKEN_BITS_C));
   end function tokenOf;

begin

   comb : process (admit, captureAbort, completionReady, fifoDout, fifoValid, generation,
                   phcStatus, phcTime, r, releaseAll, rst, storeSlave, txFrameEvent,
                   txMaster, txRetire) is
      variable v          : RegType;
      variable slave      : AxiStreamSlaveType;
      variable inBeat     : AxiStreamMasterType;
      variable request    : PtpMacPortTxRequestType;
      variable sof        : sl;
      variable free       : integer range -1 to TABLE_DEPTH_G-1;
      variable index      : integer range -1 to TABLE_DEPTH_G-1;
      variable beatBytes  : natural range 0 to 16;
      variable lengthOk   : boolean;
      variable completion : PtpMacPortTxCompletionType;
      variable capture    : PtpRxCaptureType;
      variable pending    : integer range -1 to TABLE_DEPTH_G-1;
      variable anyBusy    : sl;

      -- Resolve an entry; its completion is written by the scan below
      procedure resolve (i : in natural; outcome : in slv(1 downto 0)) is
      begin
         v.entry(i).state   := PENDING_C;
         v.entry(i).outcome := outcome;
      end procedure resolve;

      -- Write one completion record and count it by outcome
      procedure writeCompletion (i : in natural; data : in PtpMacPortTxCompletionType) is
      begin
         v.fifoWrite      := '1';
         v.fifoData       := tokenOf(i) & toSlv(data);
         v.entry(i).state := QUEUED_C;
         case data.outcome is
            when PTP_MAC_PORT_OUTCOME_SENT_C     => v.countSent    := '1';
            when PTP_MAC_PORT_OUTCOME_WIRE_ERR_C => v.countWireErr := '1';
            when PTP_MAC_PORT_OUTCOME_FLUSHED_C  => v.countFlushed := '1';
            when others                          => v.countDiscard := '1';
         end case;
      end procedure writeCompletion;

   begin
      -- Latch the current value
      v := r;

      -- Reset the pulses
      slave           := AXI_STREAM_SLAVE_INIT_C;
      v.fifoWrite     := '0';
      v.protocolFault := '0';
      v.countSent     := '0';
      v.countWireErr  := '0';
      v.countDiscard  := '0';
      v.countFlushed  := '0';
      v.countRejected := '0';
      if (storeSlave.tReady = '1') then
         v.storeMaster.tValid := '0';
      end if;

      -------------------------------------------------------------------------
      -- Completion accepted by the controller: free its entry
      -------------------------------------------------------------------------
      if (fifoValid = '1') and (completionReady = '1') then
         index := tokenIndex(fifoDout(FIFO_WIDTH_C-1 downto PTP_MAC_PORT_TX_COMPLETION_BITS_C));
         if (index >= 0) then
            v.entry(index) := ENTRY_INIT_C;
         end if;
      end if;

      -------------------------------------------------------------------------
      -- Admission and stream shape
      -------------------------------------------------------------------------
      inBeat  := txMaster.frame;
      request := txMaster.request;
      sof     := ssiGetUserSof(IN_CONFIG_C, inBeat);
      free    := -1;
      for i in TABLE_DEPTH_G-1 downto 0 loop
         if (r.entry(i).state = FREE_C) then
            free := i;
         end if;
      end loop;

      if (inBeat.tValid = '1') and (v.storeMaster.tValid = '0') then
         beatBytes := keepBytes(inBeat.tKeep(15 downto 0));
         case r.state is
            -------------------------------------------------------------------
            when IDLE_S =>
               if (sof = '0') then
                  -- No request context: consumed, counted, no completion
                  slave.tReady    := '1';
                  v.countRejected := '1';
                  if (inBeat.tLast = '0') then
                     v.state := CONSUME_S;
                  end if;
               elsif (admit = '1') and (free >= 0) then
                  slave.tReady              := '1';
                  v.current                 := free;
                  v.entry(free)             := ENTRY_INIT_C;
                  v.entry(free).state       := OPEN_C;
                  v.entry(free).cookie      := request.cookie;
                  v.entry(free).generation  := request.transportGeneration;
                  v.entry(free).timestamp   := request.timestamp;
                  v.declared                := unsigned(request.frameLength);
                  v.bytes                   := to_unsigned(beatBytes, 16);
                  v.bad                     := '0';
                  lengthOk                  := (unsigned(request.frameLength) >= MIN_LENGTH_C) and
                                               (unsigned(request.frameLength) <= MAX_LENGTH_C);
                  if (request.transportGeneration /= generation) then
                     -- Built for another lifetime: never reaches the MAC
                     resolve(free, PTP_MAC_PORT_OUTCOME_FLUSHED_C);
                     if (inBeat.tLast = '0') then
                        v.state := CONSUME_S;
                     end if;
                  elsif (not lengthOk) or (inBeat.tKeep(15 downto 0) /= x"FFFF") then
                     resolve(free, PTP_MAC_PORT_OUTCOME_DISCARDED_C);
                     if (inBeat.tLast = '0') then
                        v.state := CONSUME_S;
                     end if;
                  else
                     v.storeMaster                                   := inBeat;
                     v.storeMaster.tId                               := (others => '0');
                     v.storeMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := tokenOf(free);
                     v.storeMaster.tDest                             := (others => '0');
                     ssiSetUserEofe(STORE_CONFIG_C, v.storeMaster, '0');
                     if (inBeat.tLast = '1') then
                        -- Single-beat frame: every check completes now
                        if (v.bytes /= v.declared) or (ssiGetUserEofe(IN_CONFIG_C, inBeat) = '1') then
                           ssiSetUserEofe(STORE_CONFIG_C, v.storeMaster, '1');
                           resolve(free, PTP_MAC_PORT_OUTCOME_DISCARDED_C);
                        end if;
                     else
                        v.state := STORE_S;
                     end if;
                  end if;
               end if;
            -------------------------------------------------------------------
            when STORE_S =>
               v.storeMaster                                   := inBeat;
               v.storeMaster.tId                               := (others => '0');
               v.storeMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := tokenOf(r.current);
               v.storeMaster.tDest                             := (others => '0');
               ssiSetUserEofe(STORE_CONFIG_C, v.storeMaster, '0');
               if (sof = '1') then
                  -- Nested SOF: terminate this frame in the store and take
                  -- the new SOF as a fresh request on a later cycle
                  v.storeMaster.tLast := '1';
                  v.storeMaster.tKeep := (others => '0');
                  ssiSetUserSof(STORE_CONFIG_C, v.storeMaster, '0');
                  ssiSetUserEofe(STORE_CONFIG_C, v.storeMaster, '1');
                  resolve(r.current, PTP_MAC_PORT_OUTCOME_DISCARDED_C);
                  v.state := IDLE_S;
               else
                  slave.tReady := '1';
                  v.bytes      := r.bytes + beatBytes;
                  if (inBeat.tLast = '0') and (inBeat.tKeep(15 downto 0) /= x"FFFF") then
                     v.bad := '1';
                  end if;
                  if (inBeat.tLast = '1') then
                     if (v.bad = '1') or (v.bytes /= r.declared) or (ssiGetUserEofe(IN_CONFIG_C, inBeat) = '1') then
                        ssiSetUserEofe(STORE_CONFIG_C, v.storeMaster, '1');
                        resolve(r.current, PTP_MAC_PORT_OUTCOME_DISCARDED_C);
                     end if;
                     v.state := IDLE_S;
                  elsif (v.bytes > r.declared + EOF_SLACK_C) then
                     -- Missing EOF: end it here and drain to the next SOF
                     v.storeMaster.tLast := '1';
                     ssiSetUserEofe(STORE_CONFIG_C, v.storeMaster, '1');
                     resolve(r.current, PTP_MAC_PORT_OUTCOME_DISCARDED_C);
                     v.state := DRAIN_S;
                  end if;
               end if;
            -------------------------------------------------------------------
            when CONSUME_S =>
               slave.tReady := '1';
               if (inBeat.tLast = '1') then
                  v.state := IDLE_S;
               end if;
            -------------------------------------------------------------------
            when DRAIN_S =>
               if (sof = '1') then
                  v.state := IDLE_S;
               else
                  slave.tReady := '1';
               end if;
         end case;
      end if;

      -------------------------------------------------------------------------
      -- Wire events
      -------------------------------------------------------------------------
      -- Between start and done the capture stays valid only while the PHC
      -- generation is unchanged and no capture abort occurs (done edge included)
      if (r.wireActive = '1') and ((captureAbort = '1') or (phcStatus.generation /= r.wireGen)) then
         v.wireOk := '0';
      end if;

      -- start: the registered PHC copy holds the tuple of the pin cycle
      if (txFrameEvent.start = '1') and (txFrameEvent.startToken /= EMAC_TOKEN_NONE_C) then
         index := tokenIndex(txFrameEvent.startToken);
         if (index >= 0) and (r.entry(index).state = OPEN_C) and (r.wireActive = '0') then
            capture               := ptpRxCapture(phcTime, phcStatus.increment, 0, phcStatus.ticks,
                                                  phcStatus.generation, phcStatus.timeValid, TX_LATENCY_C);
            capture.error         := capture.error or captureAbort;
            v.wireActive          := '1';
            v.wireIndex           := index;
            v.wireOk              := not capture.error;
            v.wireGen             := phcStatus.generation;
            v.wireCapture         := capture;
            v.entry(index).started := '1';
         else
            v.protocolFault := '1';
         end if;
      end if;

      -- done resolves the entry on the pins and writes its completion now
      completion := PTP_MAC_PORT_TX_COMPLETION_INIT_C;
      if (txFrameEvent.done = '1') and (txFrameEvent.doneToken /= EMAC_TOKEN_NONE_C) then
         index := tokenIndex(txFrameEvent.doneToken);
         if (index >= 0) and (r.entry(index).state = OPEN_C) then
            completion.cookie              := r.entry(index).cookie;
            completion.transportGeneration := r.entry(index).generation;
            completion.capture             := PTP_RX_CAPTURE_INIT_C;
            completion.capture.generation  := phcStatus.generation;
            completion.outcome             := PTP_MAC_PORT_OUTCOME_SENT_C;
            if (txFrameEvent.doneError = '1') then
               completion.outcome := PTP_MAC_PORT_OUTCOME_WIRE_ERR_C;
            end if;
            if (r.wireActive = '1') and (r.wireIndex = index) and (v.wireOk = '1') and
               (r.entry(index).timestamp = '1') then
               completion.captureValid := '1';
               completion.capture      := r.wireCapture;
            end if;
            if (r.wireIndex = index) then
               v.wireActive := '0';
            end if;
            writeCompletion(index, completion);
         else
            v.protocolFault := '1';
         end if;
      end if;

      -- MAC retires: consumed before the wire
      for s in 0 to EMAC_TX_RETIRE_SOURCES_C-1 loop
         if (txRetire(s).valid = '1') then
            index := tokenIndex(txRetire(s).token);
            if (index >= 0) and (r.entry(index).state = OPEN_C) and (r.entry(index).started = '0') then
               resolve(index, PTP_MAC_PORT_OUTCOME_DISCARDED_C);
            else
               v.protocolFault := '1';
            end if;
         end if;
      end loop;

      -- Forced abort step four: an entry still open never produced a wire
      -- start (the exporter resolves any frame on the pins before it
      -- acknowledges), so it completes FLUSHED
      if (releaseAll = '1') then
         for i in 0 to TABLE_DEPTH_G-1 loop
            if (v.entry(i).state = OPEN_C) then
               if (v.entry(i).started = '1') then
                  resolve(i, PTP_MAC_PORT_OUTCOME_WIRE_ERR_C);
                  v.protocolFault := '1';
               else
                  resolve(i, PTP_MAC_PORT_OUTCOME_FLUSHED_C);
               end if;
            end if;
         end loop;
         v.wireActive := '0';
      end if;

      -- Write one pending completion per cycle when done did not write
      if (v.fifoWrite = '0') then
         pending := -1;
         for i in TABLE_DEPTH_G-1 downto 0 loop
            if (r.entry(i).state = PENDING_C) then
               pending := i;
            end if;
         end loop;
         if (pending >= 0) then
            completion                     := PTP_MAC_PORT_TX_COMPLETION_INIT_C;
            completion.cookie              := r.entry(pending).cookie;
            completion.transportGeneration := r.entry(pending).generation;
            completion.outcome             := r.entry(pending).outcome;
            completion.capture.generation  := phcStatus.generation;
            writeCompletion(pending, completion);
         end if;
      end if;

      -- Idle when no entry is owned
      anyBusy := '0';
      for i in 0 to TABLE_DEPTH_G-1 loop
         if (v.entry(i).state /= FREE_C) then
            anyBusy := '1';
         end if;
      end loop;
      v.idle := not anyBusy;

      -- Combinatorial outputs before the reset
      txSlave  <= slave;
      fifoRead <= fifoValid and completionReady;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered outputs
      idle           <= r.idle;
      protocolFault  <= r.protocolFault;
      countSent      <= r.countSent;
      countWireError <= r.countWireErr;
      countDiscarded <= r.countDiscard;
      countFlushed   <= r.countFlushed;
      countRejected  <= r.countRejected;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Forced abort step three clears the hold store with the MAC pipeline
   storeRst <= RST_POLARITY_G when (flush = '1') else rst;

   U_Store : entity surf.SsiFifo
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 0,
         PREVENT_LOCKUP_G    => false,
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => STORE_ADDR_WIDTH_G,
         SLAVE_AXI_CONFIG_G  => STORE_CONFIG_C,
         MASTER_AXI_CONFIG_G => STORE_CONFIG_C)
      port map (
         sAxisClk    => clk,
         sAxisRst    => storeRst,
         sAxisMaster => r.storeMaster,
         sAxisSlave  => storeSlave,
         mAxisClk    => clk,
         mAxisRst    => storeRst,
         mAxisMaster => macTxMaster,
         mAxisSlave  => macTxSlave);

   U_Completion : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         SYNTH_MODE_G    => SYNTH_MODE_G,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => FIFO_WIDTH_C,
         ADDR_WIDTH_G    => FIFO_ADDR_C)
      port map (
         rst    => rst,
         wr_clk => clk,
         wr_en  => r.fifoWrite,
         din    => r.fifoData,
         rd_clk => clk,
         rd_en  => fifoRead,
         dout   => fifoDout,
         valid  => fifoValid);

   completionMaster.valid <= fifoValid;
   completionMaster.data  <= toPtpMacPortTxCompletion(fifoDout(PTP_MAC_PORT_TX_COMPLETION_BITS_C-1 downto 0));

end architecture rtl;
