-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-port RX token ownership, captures and delivery
-------------------------------------------------------------------------------
-- RX half of PtpMacPort (ethernet/PtpCore/timing-port.md, sections 2.3 and
-- 3). The registered nextToken offers the lowest free table entry (index
-- plus one) to the import leaf, or EMAC_TOKEN_NONE_C while admission is
-- closed or the table is full. The leaf samples the offer on its sampling
-- edge and echoes it in start one cycle later, by which time a release may
-- have lowered the offer; start is checked against the offer it sampled and
-- allocates that entry. Its capture is evaluated from the registered PHC
-- copy while start is visible, with the leaf's start lane (section 2.4).
-- done records the frame length,
-- rejects wire errors and frames outside 60..1518 bytes, and flags a PHC generation
-- change since the capture. MAC-stage retires release entries (rxDropped;
-- the import leaf's own retire counts as rxLost). Done with token zero is a
-- frame suppressed at the importer and counts as rxDropped.
--
-- The output stage delivers stored frames with their metadata and tId
-- cleared, releasing the entry when the controller accepts the last beat; a
-- rejected frame is consumed and released at its last beat. On cancel
-- (forced abort step two) a partially delivered frame is ended with one
-- tLast+EOFE beat and every later MAC beat is discarded without release
-- until releaseAll frees the whole table.
--
-- Storage: each entry's wide payload (capture and transport generation) is
-- written once, at start, into a LUT RAM indexed by token and read
-- asynchronously once, at the output SOF; an entry cannot be reused before
-- release, so the two never address the same entry in one cycle. Only narrow
-- control state (state, length, rejected, stale) stays in registers with the
-- same-cycle update order. A PHC generation change marks every allocated
-- entry stale, which done then reports as capture.error; generations only
-- advance, so this equals comparing the generation at done with the
-- captured one.
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

entity PtpMacPortRx is
   generic (
      TPD_G             : time                    := 1 ns;
      RST_POLARITY_G    : sl                      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      TABLE_DEPTH_G     : positive range 1 to 255 := 16;
      INGRESS_LATENCY_G : slv(63 downto 0)        := (others => '0'));
   port (
      clk           : in  sl;
      rst           : in  sl;
      -- Lifecycle from PtpMacPort
      offer         : in  sl;
      generation    : in  slv(15 downto 0);
      cancel        : in  sl;
      releaseAll    : in  sl;
      cancelDone    : out sl;
      idle          : out sl;
      occupancy     : out slv(7 downto 0);
      protocolFault : out sl;
      -- Registered PHC copy: the values standing during the previous cycle
      phcTime       : in  PtpTimeType;
      phcStatus     : in  PtpPhcStatusType;
      captureAbort  : in  sl;
      -- MAC
      rxNextToken   : out EthMacTokenType;
      rxFrameEvent  : in  EthMacFrameEventType;
      rxRetire      : in  EthMacTokenRetireArray(EMAC_RX_RETIRE_SOURCES_C-1 downto 0);
      macRxMaster   : in  AxiStreamMasterType;
      macRxSlave    : out AxiStreamSlaveType;
      -- Controller
      rxMaster      : out PtpMacPortRxMasterType;
      rxReady       : in  sl;
      -- Counter increments this cycle
      incDelivered  : out slv(0 downto 0);
      incDropped    : out slv(8 downto 0);
      incLost       : out slv(1 downto 0));
end entity PtpMacPortRx;

architecture rtl of PtpMacPortRx is

   constant CONFIG_C     : AxiStreamConfigType := EMAC_TIMING_AXIS_CONFIG_C;
   constant MIN_LENGTH_C : natural             := EMAC_TIMING_MIN_FRAME_C;
   constant MAX_LENGTH_C : natural             := EMAC_TIMING_MAX_FRAME_C;

   -- Entry lifecycle: ALLOC from start to done, DONE until released
   constant FREE_C  : slv(1 downto 0) := "00";
   constant ALLOC_C : slv(1 downto 0) := "01";
   constant DONE_C  : slv(1 downto 0) := "10";

   type EntryType is record
      state    : slv(1 downto 0);
      length   : slv(15 downto 0);
      rejected : sl;
      -- The PHC generation changed while the entry was allocated.
      stale    : sl;
   end record EntryType;

   constant ENTRY_INIT_C : EntryType := (
      state    => FREE_C,
      length   => (others => '0'),
      rejected => '0',
      stale    => '0');

   -- Payload RAM word: capture, then transport generation in the low bits.
   constant RAM_ADDR_BITS_C : positive := maximum(1, bitSize(TABLE_DEPTH_G-1));
   constant RAM_DATA_BITS_C : positive := PTP_RX_CAPTURE_BITS_C+16;

   type EntryArray is array (0 to TABLE_DEPTH_G-1) of EntryType;

   -- IDLE_S waits for a SOF beat; DELIVER_S forwards a frame; CONSUME_S
   -- swallows a rejected frame; TERM_S ends a partial frame on cancel;
   -- DISCARD_S drops everything until the abort completes.
   type StateType is (
      IDLE_S,
      DELIVER_S,
      CONSUME_S,
      TERM_S,
      DISCARD_S);

   type RegType is record
      state         : StateType;
      entry         : EntryArray;
      outIndex      : natural range 0 to TABLE_DEPTH_G-1;
      slotFinal     : sl;
      consumeOwned  : sl;
      nextToken     : EthMacTokenType;
      offered       : EthMacTokenType;
      generation    : slv(31 downto 0);
      rxMaster      : PtpMacPortRxMasterType;
      cancelDone    : sl;
      idle          : sl;
      occupancy     : natural range 0 to TABLE_DEPTH_G;
      protocolFault : sl;
      incDelivered  : unsigned(0 downto 0);
      incDropped    : unsigned(8 downto 0);
      incLost       : unsigned(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state         => IDLE_S,
      entry         => (others => ENTRY_INIT_C),
      outIndex      => 0,
      slotFinal     => '0',
      consumeOwned  => '0',
      nextToken     => EMAC_TOKEN_NONE_C,
      offered       => EMAC_TOKEN_NONE_C,
      generation    => (others => '0'),
      rxMaster      => PTP_MAC_PORT_RX_MASTER_INIT_C,
      cancelDone    => '0',
      idle          => '1',
      occupancy     => 0,
      protocolFault => '0',
      incDelivered  => (others => '0'),
      incDropped    => (others => '0'),
      incLost       => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramWrite     : sl;
   signal ramWriteAddr : slv(RAM_ADDR_BITS_C-1 downto 0);
   signal ramWriteData : slv(RAM_DATA_BITS_C-1 downto 0);
   signal ramReadAddr  : slv(RAM_ADDR_BITS_C-1 downto 0);
   signal ramReadData  : slv(RAM_DATA_BITS_C-1 downto 0);

   function tokenIndex (token : EthMacTokenType) return integer is
      variable value : natural;
   begin
      value := to_integer(unsigned(token));
      if (value >= 1) and (value <= TABLE_DEPTH_G) then
         return value - 1;
      end if;
      return -1;
   end function tokenIndex;

begin

   -- The output stage reads the payload of the token on the MAC beat.
   readAddr : process (macRxMaster) is
      variable index : integer range -1 to TABLE_DEPTH_G-1;
   begin
      index := tokenIndex(macRxMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0));
      if index < 0 then
         index := 0;
      end if;
      ramReadAddr <= slv(to_unsigned(index, RAM_ADDR_BITS_C));
   end process readAddr;

   U_Payload : entity surf.LutRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         REG_EN_G       => false,
         DATA_WIDTH_G   => RAM_DATA_BITS_C,
         ADDR_WIDTH_G   => RAM_ADDR_BITS_C,
         NUM_PORTS_G    => 2)
      port map (
         clka  => clk,           -- [in]
         wea   => ramWrite,      -- [in]
         addra => ramWriteAddr,  -- [in]
         dina  => ramWriteData,  -- [in]
         douta => open,          -- [out]
         clkb  => clk,           -- [in]
         addrb => ramReadAddr,   -- [in]
         doutb => ramReadData);  -- [out]

   comb : process (cancel, captureAbort, generation, macRxMaster, offer, phcStatus, phcTime,
                   r, ramReadData, releaseAll, rst, rxFrameEvent, rxReady, rxRetire) is
      variable v       : RegType;
      variable slave   : AxiStreamSlaveType;
      variable beat    : AxiStreamMasterType;
      variable index   : integer range -1 to TABLE_DEPTH_G-1;
      variable free    : integer range -1 to TABLE_DEPTH_G-1;
      variable capture : PtpRxCaptureType;
      variable meta    : PtpMacPortRxMetaType;
      variable anyBusy : sl;
      variable write   : sl;
      variable wrIndex : natural range 0 to TABLE_DEPTH_G-1;
      variable ramCap  : slv(PTP_RX_CAPTURE_BITS_C-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the pulses
      slave           := AXI_STREAM_SLAVE_INIT_C;
      write           := '0';
      wrIndex         := 0;
      capture         := PTP_RX_CAPTURE_INIT_C;
      v.protocolFault := '0';
      v.incDelivered  := (others => '0');
      v.incDropped    := (others => '0');
      v.incLost       := (others => '0');

      -------------------------------------------------------------------------
      -- Controller acceptance: the last delivered beat releases its entry
      -------------------------------------------------------------------------
      if (rxReady = '1') and (r.rxMaster.frame.tValid = '1') then
         v.rxMaster.frame.tValid := '0';
         v.slotFinal             := '0';
         if (r.slotFinal = '1') then
            v.entry(r.outIndex) := ENTRY_INIT_C;
            v.incDelivered      := "1";
         end if;
      end if;

      -------------------------------------------------------------------------
      -- PHC generation change: invalidates every capture taken before it
      -------------------------------------------------------------------------
      -- Marked before this cycle's start, whose capture already uses the new
      -- generation, and before done, which then reports it.
      v.generation := phcStatus.generation;
      if (phcStatus.generation /= r.generation) then
         for i in 0 to TABLE_DEPTH_G-1 loop
            if (v.entry(i).state = ALLOC_C) then
               v.entry(i).stale := '1';
            end if;
         end loop;
      end if;

      -------------------------------------------------------------------------
      -- Wire events
      -------------------------------------------------------------------------
      -- start allocates the entry offered on the leaf's sampling edge; the
      -- capture uses the leaf's lane
      v.offered := r.nextToken;
      if (rxFrameEvent.start = '1') and (rxFrameEvent.startToken /= EMAC_TOKEN_NONE_C) then
         index := tokenIndex(rxFrameEvent.startToken);
         if (index >= 0) and (r.entry(index).state = FREE_C) and (rxFrameEvent.startToken = r.offered) then
            capture                   := ptpRxCapture(phcTime, phcStatus.increment,
                                                      to_integer(unsigned(rxFrameEvent.startLane)), phcStatus.ticks,
                                                      phcStatus.generation, phcStatus.timeValid, INGRESS_LATENCY_G);
            capture.error        := capture.error or captureAbort;
            v.entry(index)       := ENTRY_INIT_C;
            v.entry(index).state := ALLOC_C;
            -- The payload is written once here and read at the output SOF.
            write                := '1';
            wrIndex              := index;
         else
            v.protocolFault := '1';
         end if;
      end if;

      -- done: wire/length verdict and PHC generation change since the capture
      if (rxFrameEvent.done = '1') then
         if (rxFrameEvent.doneToken = EMAC_TOKEN_NONE_C) then
            v.incDropped := v.incDropped + 1;
         else
            index := tokenIndex(rxFrameEvent.doneToken);
            if (index >= 0) and (v.entry(index).state = ALLOC_C) then
               v.entry(index).state  := DONE_C;
               v.entry(index).length := rxFrameEvent.doneLength;
               -- Preserve the physical verdict independently of the stream's
               -- EOFE: the legacy checksum stage can overwrite that sideband.
               -- Keep ownership until a MAC retire or output consumption.
               if (rxFrameEvent.doneError = '1') or
                  (unsigned(rxFrameEvent.doneLength) < MIN_LENGTH_C) or
                  (unsigned(rxFrameEvent.doneLength) > MAX_LENGTH_C) then
                  v.entry(index).rejected := '1';
               end if;
               -- A generation change since start marked the entry stale.
            else
               v.protocolFault := '1';
            end if;
         end if;
      end if;

      -- Retires release entries; none may name the frame being delivered
      for s in 0 to EMAC_RX_RETIRE_SOURCES_C-1 loop
         if (rxRetire(s).valid = '1') then
            index := tokenIndex(rxRetire(s).token);
            if (index >= 0) and (v.entry(index).state /= FREE_C) and
               not ((r.state = DELIVER_S or r.rxMaster.frame.tValid = '1') and (r.outIndex = index)) then
               v.entry(index) := ENTRY_INIT_C;
               if (s = EMAC_RX_RETIRE_IMPORT_C) then
                  v.incLost := v.incLost + 1;
               else
                  v.incDropped := v.incDropped + 1;
               end if;
            else
               v.protocolFault := '1';
            end if;
         end if;
      end loop;

      if (rxFrameEvent.lost = '1') then
         v.incLost := v.incLost + 1;
      end if;

      -------------------------------------------------------------------------
      -- Output stage
      -------------------------------------------------------------------------
      beat := macRxMaster;
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if (cancel = '1') then
               v.state := DISCARD_S;
            elsif (beat.tValid = '1') and (v.rxMaster.frame.tValid = '0') then
               index := tokenIndex(beat.tId(EMAC_TOKEN_BITS_C-1 downto 0));
               slave.tReady := '1';
               if (index < 0) or (v.entry(index).state /= DONE_C) then
                  -- No resolved owner: a token protocol fault; swallow it
                  v.protocolFault := '1';
                  v.consumeOwned  := '0';
                  if (beat.tLast = '0') then
                     v.state := CONSUME_S;
                  end if;
               elsif (v.entry(index).rejected = '1') then
                  v.outIndex     := index;
                  v.consumeOwned := '1';
                  if (beat.tLast = '1') then
                     v.entry(index) := ENTRY_INIT_C;
                     v.incDropped   := v.incDropped + 1;
                  else
                     v.state := CONSUME_S;
                  end if;
               else
                  v.outIndex                           := index;
                  ramCap                               := ramReadData(RAM_DATA_BITS_C-1 downto 16);
                  meta.capture                         := toPtpRxCapture(ramCap);
                  meta.capture.error                   := meta.capture.error or v.entry(index).stale;
                  meta.frameLength                     := v.entry(index).length;
                  meta.transportGeneration             := ramReadData(15 downto 0);
                  v.rxMaster.meta                      := meta;
                  v.rxMaster.frame                     := beat;
                  v.rxMaster.frame.tId                 := (others => '0');
                  v.rxMaster.frame.tDest               := (others => '0');
                  v.slotFinal                          := beat.tLast;
                  if (beat.tLast = '0') then
                     v.state := DELIVER_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DELIVER_S =>
            if (cancel = '1') then
               v.state := TERM_S;
            elsif (beat.tValid = '1') and (v.rxMaster.frame.tValid = '0') then
               slave.tReady           := '1';
               v.rxMaster.frame       := beat;
               v.rxMaster.frame.tId   := (others => '0');
               v.rxMaster.frame.tDest := (others => '0');
               v.slotFinal            := beat.tLast;
               if (beat.tLast = '1') then
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CONSUME_S =>
            if (beat.tValid = '1') then
               slave.tReady := '1';
               if (beat.tLast = '1') then
                  if (r.consumeOwned = '1') then
                     v.entry(r.outIndex) := ENTRY_INIT_C;
                     v.incDropped        := v.incDropped + 1;
                  end if;
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when TERM_S =>
            -- The consumer discards a frame whose last beat carries EOFE
            if (v.rxMaster.frame.tValid = '0') then
               v.rxMaster.frame        := AXI_STREAM_MASTER_INIT_C;
               v.rxMaster.frame.tValid := '1';
               v.rxMaster.frame.tLast  := '1';
               v.rxMaster.frame.tKeep  := (others => '0');
               ssiSetUserEofe(CONFIG_C, v.rxMaster.frame, '1');
               v.state                 := DISCARD_S;
            end if;
         ----------------------------------------------------------------------
         when DISCARD_S =>
            slave.tReady := '1';
            if (cancel = '0') then
               v.state := IDLE_S;
            end if;
      end case;

      -- Cancel is complete once nothing of a partial frame remains at the
      -- controller boundary
      v.cancelDone := '0';
      if (v.state = DISCARD_S) and (v.rxMaster.frame.tValid = '0') then
         v.cancelDone := '1';
      end if;

      -- Forced abort step four
      if (releaseAll = '1') then
         for i in 0 to TABLE_DEPTH_G-1 loop
            if (v.entry(i).state /= FREE_C) then
               v.entry(i)   := ENTRY_INIT_C;
               v.incDropped := v.incDropped + 1;
            end if;
         end loop;
      end if;

      -- Offer the lowest free entry for the next start
      free := -1;
      for i in TABLE_DEPTH_G-1 downto 0 loop
         if (v.entry(i).state = FREE_C) then
            free := i;
         end if;
      end loop;
      v.nextToken := EMAC_TOKEN_NONE_C;
      if (offer = '1') and (cancel = '0') and (free >= 0) then
         v.nextToken := slv(to_unsigned(free+1, EMAC_TOKEN_BITS_C));
      end if;

      anyBusy     := '0';
      v.occupancy := 0;
      for i in 0 to TABLE_DEPTH_G-1 loop
         if (v.entry(i).state /= FREE_C) then
            anyBusy     := '1';
            v.occupancy := v.occupancy+1;
         end if;
      end loop;
      v.idle := not anyBusy;

      -- Combinatorial outputs before the reset; reset excludes the RAM write.
      macRxSlave   <= slave;
      ramWrite     <= write and toSl(rst /= RST_POLARITY_G);
      ramWriteAddr <= slv(to_unsigned(wrIndex, RAM_ADDR_BITS_C));
      ramWriteData <= toSlv(capture) & generation;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered outputs
      rxNextToken   <= r.nextToken;
      rxMaster      <= r.rxMaster;
      cancelDone    <= r.cancelDone;
      idle          <= r.idle;
      occupancy     <= toSlv(r.occupancy, 8);
      protocolFault <= r.protocolFault;
      incDelivered  <= slv(r.incDelivered);
      incDropped    <= slv(r.incDropped);
      incLost       <= slv(r.incLost);

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
