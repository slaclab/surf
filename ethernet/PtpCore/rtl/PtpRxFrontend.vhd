-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Bounded PTP frame validation and atomic message/capture queue.
--
-- Consumes normalized destination-MAC-through-FCS bytes every clk cycle with
-- rxMaster.tValid; this physical input has no backpressure. Binds the capture
-- at SOF, streams the CRC and TLV checks, then queues a complete decoded record.
-- A synchronous FWFT FIFO delivers a record to an available head three clocks
-- after completion. Logical capacity includes the write/read pipeline and head.
-- The registered queue head remains stable while messageReady is low.
-- Transfer requires messageValid, messageReady and no rxAbort on the same edge.
-- A full-queue completion discards queued work and registers an abort event;
-- consumers cancel pending work when they sample that event on the next edge.
-- Flush, generation changes and system reset also invalidate pending work.
-- TX observation retains physical completion identity across PHC generations.
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
use surf.CrcPkg.all;
use surf.PtpPkg.all;

entity PtpRxFrontend is
   generic (
      TPD_G          : time                      := 1 ns;
      RST_POLARITY_G : sl                        := '1';
      RST_ASYNC_G    : boolean                   := false;
      TX_OBSERVE_G   : boolean                   := false;
      FIFO_DEPTH_G   : positive                  := 4;
      MAX_FRAME_G    : PtpFrameCapacityType      := PTP_ETH_MAX_FRAME_C);
   port (
      clk           : in  sl;
      rst           : in  sl;
      rxFlush       : in  sl;
      generation    : in  slv(31 downto 0);
      -- Always-consumed normalized bytes: destination MAC through FCS, with
      -- contiguous low-byte TKEEP. The capture sidecar is sampled only at SOF.
      rxMaster      : in  AxiStreamMasterType;
      rxCapture     : in  PtpRxCaptureType;
      -- Transfer requires messageValid AND messageReady AND NOT rxAbort.
      -- Abort/overflow are registered with the queue update. Consumers give
      -- the published abort priority on its consumption edge. A transfer on
      -- the earlier detection edge may enter revocable downstream work.
      message       : out PtpRxMessageType;
      messageValid  : out sl;
      messageReady  : in  sl;
      queueOverflow : out sl;
      rxAbort       : out sl;
      rxEpoch       : out slv(31 downto 0);
      -- Saturating diagnostics: records enqueued, completed frames rejected
      -- by validation, and full-queue completion events. counters.dropped does not
      -- count every frame lost before SOF, during flush, or through overflow.
      counters : out PtpRxCountersType);
end entity PtpRxFrontend;

architecture rtl of PtpRxFrontend is

   constant PREFIX_BYTES_C : positive := PTP_ETH_HEADER_BYTES_C+PTP_ANNOUNCE_BYTES_C;
   -- The portable FIFO has a minimum address width of four and reserves one
   -- RAM slot. Logical occupancy below includes every stage, not just RAM.
   constant FIFO_ADDR_BITS_C : positive := maximum(4, log2(FIFO_DEPTH_G+1));
   -- Good Ethernet FCS residue in CrcPkg's register convention.
   constant ETH_CRC_RESIDUE_C : slv(31 downto 0) := x"C704DD7B";

   -- Only one physical frame is being decoded at a time. The 78-byte prefix
   -- covers Ethernet (14) plus the largest supported fixed PTP message (64).
   -- Longer TLVs are streamed past; count saturates at MAX_FRAME_G+1 so an
   -- unterminated frame cannot wrap the parser back to a plausible short frame.
   -- bad is sticky for this frame and capture never changes after its SOF.
   type FrameType is record
      active       : sl;
      bad          : sl;
      count        : natural range 0 to MAX_FRAME_G+1;
      prefix       : Slv8Array(0 to PREFIX_BYTES_C-1);
      crc          : slv(31 downto 0);
      capture      : PtpRxCaptureType;
      base         : natural range 0 to PTP_ANNOUNCE_BYTES_C;
      messageEnd   : natural range 0 to MAX_FRAME_G;
      tlvBytes     : natural range 0 to PTP_TLV_HEADER_BYTES_C-1;
      tlvLength    : slv(15 downto 0);
      tlvRemaining : natural range 0 to MAX_FRAME_G;
   end record;

   constant FRAME_INIT_C : FrameType := (
      active       => '0',
      bad          => '0',
      count        => 0,
      prefix       => (others => (others => '0')),
      crc          => (others => '1'),
      capture      => PTP_RX_CAPTURE_INIT_C,
      base         => 0,
      messageEnd   => 0,
      tlvBytes     => 0,
      tlvLength    => (others => '0'),
      tlvRemaining => 0);

   -- The small same-clock queue stores complete records, including captures.
   -- No separately lossy packet/timestamp streams remain to be joined by key.
   -- generation belongs to the PHC/configuration owner; epoch belongs to this
   -- RX queue. Logical occupancy includes the registered write, FIFO and head.
   type RegType is record
      -- Registered queue boundary and invalidation events.
      message          : PtpRxMessageType;
      queueOverflow    : sl;
      abortNow         : sl;

      -- Registered FIFO write/reset and recomputed FWFT read acknowledgement.
      fifoWrite        : sl;
      fifoWriteData    : PtpRxStorageType;
      fifoRst          : sl;
      fifoRead         : sl;
      counters         : PtpRxCountersType;
      messageValid     : sl;
      frame            : FrameType;
      fill             : natural range 0 to FIFO_DEPTH_G;
      generation       : slv(31 downto 0);
      epoch            : unsigned(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      message          => PTP_RX_MESSAGE_INIT_C,
      queueOverflow    => '0',
      abortNow         => '0',
      fifoWrite        => '0',
      fifoWriteData    => (others => '0'),
      fifoRst          => '1',
      fifoRead         => '0',
      counters         => PTP_RX_COUNTERS_INIT_C,
      messageValid     => '0',
      frame            => FRAME_INIT_C,
      fill             => 0,
      generation       => (others => '0'),
      epoch            => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoWrite     : sl;
   signal fifoWriteData : PtpRxStorageType;
   signal fifoRst       : sl;
   signal fifoRead      : sl;
   signal fifoReadData  : PtpRxStorageType;
   signal fifoValid     : sl;

   -- Fixed lengths include the 34-byte PTP header: Sync/Follow_Up (44),
   -- Delay_Resp (54), Announce (64). Delay_Req is TX-only for this receiver.
   -- Zero marks unsupported types, disabling both TLV walking and admission.
   function baseLength (kind : slv(3 downto 0)) return natural is
   begin
      if TX_OBSERVE_G then
         if kind = PTP_MSG_DELAY_REQ_C then
            return PTP_TIMESTAMP_MSG_BYTES_C;
         end if;
         return 0;
      end if;
      case kind is
         when PTP_MSG_SYNC_C | PTP_MSG_FOLLOW_UP_C =>
            return PTP_TIMESTAMP_MSG_BYTES_C;
         when PTP_MSG_DELAY_RESP_C =>
            return PTP_DELAY_RESP_BYTES_C;
         when PTP_MSG_ANNOUNCE_C =>
            return PTP_ANNOUNCE_BYTES_C;
         when others =>
            return 0;
      end case;
   end function;

   -- Prefix offsets count from destination-MAC byte zero. Reassemble wire
   -- octets into conventional big-endian fields; AXI lane order is unrelated
   -- to the numerical significance of a multibyte PTP field.
   function networkField (
      bytes : Slv8Array;
      first : natural;
      count : positive) return slv is
      variable retVar : slv(8*count-1 downto 0);
   begin
      for i in 0 to count-1 loop
         retVar(8*(count-i)-1 downto 8*(count-i-1)) := bytes(first+i);
      end loop;
      return retVar;
   end function;

begin

   -- Completion at N registers a write, accepted by the synchronous FIFO at
   -- N+1. Its FWFT read presents data/valid at N+2 for the head to capture at
   -- N+3. Logical fill reserves capacity throughout these stages. This backend
   -- recovers from reset in one clock; parsing a minimum frame takes at least
   -- eight clocks, so a fresh completion cannot overlap reset recovery.
   -- Invalidation clears the head immediately and registers fifoRst for the
   -- following edge. No FIFO data is captured while that reset is pending.
   U_Queue : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         SYNTH_MODE_G    => "inferred",
         MEMORY_TYPE_G   => "distributed",
         PIPE_STAGES_G   => 0,
         DATA_WIDTH_G    => PTP_RX_STORAGE_BITS_C,
         ADDR_WIDTH_G    => FIFO_ADDR_BITS_C)
      port map (
         rst           => fifoRst,        -- [in]
         wr_clk        => clk,            -- [in]
         wr_en         => fifoWrite,      -- [in]
         din           => fifoWriteData,  -- [in]
         wr_data_count => open,           -- [out]
         wr_ack        => open,           -- [out]
         overflow      => open,           -- [out]
         prog_full     => open,           -- [out]
         almost_full   => open,           -- [out]
         full          => open,           -- [out]
         not_full      => open,           -- [out]
         rd_clk        => clk,            -- [in]
         rd_en         => fifoRead,       -- [in]
         dout          => fifoReadData,   -- [out]
         rd_data_count => open,           -- [out]
         valid         => fifoValid,      -- [out]
         underflow     => open,           -- [out]
         prog_empty    => open,           -- [out]
         almost_empty  => open,           -- [out]
         empty         => open);          -- [out]

   comb : process (r, rst, rxFlush, generation, rxMaster, rxCapture, messageReady, fifoReadData, fifoValid) is
      variable v            : RegType;
      variable octet        : slv(7 downto 0);
      variable base         : natural range 0 to PTP_ANNOUNCE_BYTES_C;
      variable length       : natural range 0 to 65535;
      variable offset       : natural range 0 to MAX_FRAME_G+1;
      variable first        : natural range 0 to MAX_FRAME_G+1;
      variable last         : natural range 0 to MAX_FRAME_G+9;
      variable alignedBytes : Slv8Array(0 to 7);

      -- Calculations used only during this evaluation.
      variable completedMessage : PtpRxMessageType;
      variable frameComplete    : boolean;
      variable byteCount        : natural range 0 to 8;
      variable crcData          : slv(63 downto 0);
      variable keepGap          : boolean;
   begin
      v            := r;
      octet        := (others => '0');
      base         := 0;
      length       := 0;
      offset       := 0;
      first        := 0;
      last         := 0;
      alignedBytes := (others => (others => '0'));

      completedMessage := PTP_RX_MESSAGE_INIT_C;
      frameComplete    := false;
      v.abortNow       := '0';
      v.queueOverflow  := '0';
      v.fifoWrite      := '0';
      v.fifoRead       := '0';
      v.fifoRst        := '0';
      byteCount        := 0;
      crcData          := (others => '0');
      keepGap          := false;

      -- Release a consumed head, then capture an available FWFT word. The
      -- read acknowledgement consumes exactly the word captured on this edge;
      -- registering it would require another slot for the delayed consumption.
      if r.messageValid = '1' and messageReady = '1' then
         v.messageValid := '0';
         v.fill         := r.fill-1;
      end if;
      if v.messageValid = '0' and fifoValid = '1' and r.fifoRst = '0' then
         v.message      := ptpUnpackRxMessage(fifoReadData);
         v.messageValid := '1';
         v.fifoRead     := '1';
      end if;

      if rxMaster.tValid = '1' then
         if ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, rxMaster) = '1' then
            -- Start with fresh parser state and bind this frame's capture.
            -- A nested SOF discards both the partial frame and the new candidate;
            -- stale-generation starts are also ignored. Neither can attach a
            -- new timestamp to leftover bytes. PHC timeValid alone is not an
            -- admission requirement: acquisition needs unsynchronized captures.
            v.frame := FRAME_INIT_C;
            if r.frame.active = '0' and (TX_OBSERVE_G or rxCapture.generation = r.generation) then
               v.frame.active  := '1';
               v.frame.capture := rxCapture;
               if not TX_OBSERVE_G then
                  v.frame.bad := rxCapture.error;
               end if;
               -- TX always reports a structurally valid wire completion. Its
               -- capture.error may prohibit measurement, but must not hide that
               -- a previously queued request has finally left the MAC.
            end if;
         end if;
         if v.frame.active = '1' then
            -- Keep errors until EOF, even if a later beat has clean sidebands.
            v.frame.bad := v.frame.bad or ssiGetUserEofe(PTP_RX_AXIS_CONFIG_C, rxMaster);
            for i in 0 to 7 loop
               if rxMaster.tKeep(i) = '1' then
                  if keepGap then
                     -- Sparse keeps violate the normalized physical interface.
                     -- Continue consuming, but never publish this frame.
                     v.frame.bad := '1';
                  end if;
                  byteCount := byteCount+1;
                  octet     := rxMaster.tData(8*i+7 downto 8*i);
                  -- CrcPkg expects the first byte at the high end and reversed
                  -- bit order within each octet. Ethernet arrives low AXI byte
                  -- first; this transpose is separate from networkField decode.
                  for b in 0 to 7 loop
                     crcData(63-8*i-b) := octet(b);
                  end loop;
               else
                  keepGap := true;
               end if;
            end loop;

            -- Rotate once into frame-byte lanes, then give each prefix byte
            -- one write enable. Contiguous keeps make frame offsets distinct;
            -- sparse beats are already bad and can never publish a record.
            first := v.frame.count;
            last  := first+byteCount;
            for i in 0 to 7 loop
               alignedBytes(i) := rxMaster.tData(8*((i+8-(first mod 8)) mod 8)+7 downto 8*((i+8-(first mod 8)) mod 8));
            end loop;
            for i in v.frame.prefix'range loop
               if first <= i and i < last then
                  v.frame.prefix(i) := alignedBytes(i mod 8);
               end if;
            end loop;
            if last > MAX_FRAME_G then
               v.frame.count := MAX_FRAME_G+1;
               v.frame.bad   := '1';
            else
               v.frame.count := last;
            end if;

            -- Decode once when the messageLength field is complete. Even an
            -- eight-byte beat cannot also reach the first TLV (byte 58), so
            -- these bounds are registered before any TLV needs them.
            if first < 18 and last >= 18 then
               v.frame.base := baseLength(v.frame.prefix(14)(3 downto 0));
               length       := to_integer(unsigned(networkField(v.frame.prefix, 16, 2)));
               if v.frame.base = 0 or length < v.frame.base or length > MAX_FRAME_G-PTP_ETH_OVERHEAD_BYTES_C then
                  v.frame.bad := '1';
               else
                  v.frame.messageEnd := PTP_ETH_HEADER_BYTES_C+length;
               end if;
            end if;

            -- Only TLV header transitions need byte ordering. Prefix writes,
            -- byte counting and header bounds no longer feed an eight-stage
            -- chain. Keep the parser able to finish a value and start another
            -- header in the same beat, including zero-length TLVs.
            for i in 0 to 7 loop
               if i < byteCount and v.frame.bad = '0' then
                  offset := first+i;
                  octet  := rxMaster.tData(8*i+7 downto 8*i);
                  if offset >= PTP_ETH_HEADER_BYTES_C+r.frame.base and offset < r.frame.messageEnd then
                     if v.frame.tlvRemaining /= 0 then
                        v.frame.tlvRemaining := v.frame.tlvRemaining-1;
                     else
                        if v.frame.tlvBytes = PTP_TLV_LENGTH_OFFSET_C then
                           v.frame.tlvLength(15 downto 8) := octet;
                        elsif v.frame.tlvBytes = PTP_TLV_LENGTH_OFFSET_C+1 then
                           v.frame.tlvLength(7 downto 0) := octet;
                           -- offset is the last TLV-header byte. A declared
                           -- value may not extend past the PTP message end.
                           -- IEEE 1588-2019 5.3.8 requires even TLV lengths.
                           if v.frame.tlvLength(0) = '1' or
                              to_integer(unsigned(v.frame.tlvLength)) > r.frame.messageEnd-offset-1 then
                              v.frame.bad := '1';
                           else
                              -- Validate all 16 wire bits before narrowing
                              -- the remaining-byte counter to frame capacity.
                              v.frame.tlvRemaining := to_integer(unsigned(v.frame.tlvLength));
                           end if;
                        end if;
                        v.frame.tlvBytes := (v.frame.tlvBytes+1) mod PTP_TLV_HEADER_BYTES_C;
                     end if;
                  end if;
               end if;
            end loop;
            -- One parallel CRC update per physical group. SURF uses the
            -- unreversed register convention; good Ethernet residue is below.
            -- CRC covers the entire frame including padding and FCS. A zero-
            -- byte termination leaves the remainder from the prior beat intact.
            case byteCount is
               when 1 =>
                  v.frame.crc := crc32Parallel1Byte(v.frame.crc, crcData(63 downto 56));
               when 2 =>
                  v.frame.crc := crc32Parallel2Byte(v.frame.crc, crcData(63 downto 48));
               when 3 =>
                  v.frame.crc := crc32Parallel3Byte(v.frame.crc, crcData(63 downto 40));
               when 4 =>
                  v.frame.crc := crc32Parallel4Byte(v.frame.crc, crcData(63 downto 32));
               when 5 =>
                  v.frame.crc := crc32Parallel5Byte(v.frame.crc, crcData(63 downto 24));
               when 6 =>
                  v.frame.crc := crc32Parallel6Byte(v.frame.crc, crcData(63 downto 16));
               when 7 =>
                  v.frame.crc := crc32Parallel7Byte(v.frame.crc, crcData(63 downto 8));
               when 8 =>
                  v.frame.crc := crc32Parallel8Byte(v.frame.crc, crcData);
               when others =>
                  null;
            end case;
            if rxMaster.tLast = '1' then
               -- Decide only after incorporating this beat's bytes and errors.
               -- 18 = 14 Ethernet header bytes + 4 FCS bytes: the length check
               -- proves that the fixed body and TLVs fit before FCS. Thus no
               -- separate trailing-FCS buffer is needed even though prefix may
               -- contain padding/FCS after a short message's meaningful bytes.
               -- Header positions below are Ethernet-frame byte offsets:
               -- EtherType 12..13, type 14, version 15, messageLength 16..17.
               base := v.frame.base;
               -- Validate framing/FCS, protocol identity, then bounded body/TLV
               -- lengths. Keep the rejection order explicit for first-time readers.
               frameComplete := true;
               if v.frame.bad /= '0' then
                  frameComplete := false;
               elsif v.frame.count < PTP_ETH_MIN_FRAME_C or v.frame.count > MAX_FRAME_G then
                  frameComplete := false;
               elsif v.frame.crc /= ETH_CRC_RESIDUE_C then
                  frameComplete := false;

               -- IEEE 1588-2019 19.2 accepts every minor version when the
               -- major version matches. Preserve the minor value in the record.
               elsif networkField(v.frame.prefix, 12, 2) /= PTP_ETH_TYPE_C then
                  frameComplete := false;
               elsif v.frame.prefix(15)(3 downto 0) /= PTP_MAJOR_VERSION_C then
                  frameComplete := false;
               -- Require the fixed body and complete TLVs before the FCS.
               elsif base = 0 then
                  frameComplete := false;
               elsif v.frame.count < PTP_ETH_FCS_BYTES_C+v.frame.messageEnd or v.frame.tlvBytes /= 0 or v.frame.tlvRemaining /= 0 then
                  frameComplete := false;
               end if;
               if frameComplete then
                  -- Publish decoded common fields and only the fixed body;
                  -- candidate initialization zeros unused body bytes. Identity,
                  -- flags, and message-body semantics still need PtpProtocolEngine policy.
                  -- A duplicate key remains a distinct physical record here.
                  -- Explicit wire offsets make the field layout visible here,
                  -- matching the Delay_Req encoder's Ethernet-frame convention.
                  completedMessage.capture            := v.frame.capture;
                  completedMessage.rxEpoch            := slv(r.epoch);
                  completedMessage.destination        := networkField(v.frame.prefix, 0, PTP_ETH_MAC_BYTES_C);
                  completedMessage.sourcePortIdentity := networkField(v.frame.prefix, 34, PTP_PORT_ID_BYTES_C);
                  completedMessage.sequenceId         := networkField(v.frame.prefix, 44, 2);
                  completedMessage.domainNumber       := v.frame.prefix(18);
                  completedMessage.messageType        := v.frame.prefix(14)(3 downto 0);
                  completedMessage.minorVersion       := v.frame.prefix(15)(7 downto 4);
                  completedMessage.transportSpecific  := v.frame.prefix(14)(7 downto 4);
                  completedMessage.messageLength      := networkField(v.frame.prefix, 16, 2);
                  completedMessage.flags              := networkField(v.frame.prefix, 20, 2);
                  completedMessage.correction         := networkField(v.frame.prefix, 22, 8);
                  completedMessage.control            := v.frame.prefix(46);
                  completedMessage.logInterval        := v.frame.prefix(47);
                  -- Fixed body starts at frame byte 48; first octet is bits 239..232.
                  for i in 0 to PTP_ANNOUNCE_BODY_BYTES_C-1 loop
                     if i < base-PTP_HEADER_BYTES_C then
                        completedMessage.messageBody(239-8*i downto 232-8*i) := v.frame.prefix(48+i);
                     end if;
                  end loop;
               else
                  v.counters.dropped := ptpSatInc(r.counters.dropped);
               end if;
               v.frame := FRAME_INIT_C;
            end if;
         end if;
      end if;

      -- Admission deliberately tests pre-edge occupancy. A full queue cannot
      -- rescue this completion through simultaneous ready: discard the candidate
      -- and all queued records, advance the RX epoch, and publish an abort.
      -- Malformed/non-PTP completions never take this overflow path.
      -- A coincident old-head transfer precedes the registered invalidation.
      -- Downstream work remains revocable until that event is consumed next edge.
      if frameComplete and r.fill = FIFO_DEPTH_G then
         v.fill              := 0;
         v.messageValid      := '0';
         v.fifoRead          := '0';
         v.fifoRst           := '1';
         v.epoch             := r.epoch+1;
         v.counters.overflow := ptpSatInc(r.counters.overflow);
         v.queueOverflow     := '1';
         v.abortNow          := '1';
      elsif frameComplete then
         v.fifoWrite         := '1';
         v.fifoWriteData     := ptpPackRxMessage(completedMessage);
         v.fill              := v.fill+1;
         v.counters.accepted := ptpSatInc(r.counters.accepted);
      end if;

      -- Logical invalidation overrides parsing, admission, consumption, and
      -- diagnostic increments above. Hold flush as long as necessary; each
      -- asserted edge advances epoch. No old queue entry or partial frame is
      -- reachable afterward, but downstream consumers must invalidate their
      -- own pending work. This operation neither resets the PHC nor frees TX keys.
      -- An already registered write may commit on this invalidation edge;
      -- the FIFO reset discards it before another head can be published.
      if rxFlush = '1' or (not TX_OBSERVE_G and generation /= r.generation) then
         v := r;

         v.queueOverflow := '0';
         v.frame         := FRAME_INIT_C;
         v.fill          := 0;
         v.messageValid  := '0';
         v.generation    := generation;
         v.epoch         := r.epoch+1;
         v.abortNow      := '1';
         v.fifoWrite     := '0';
         v.fifoRead      := '0';
         v.fifoRst       := '1';
      end if;
      -- Shared system reset excludes transfers. Unlike a logical flush,
      -- it resets epoch/counters; the owner must coordinate reset with consumers
      -- before reusing that epoch space. Async state reset occurs in seq.
      if rst = RST_POLARITY_G then
         v.abortNow  := '1';
         v.fifoRead  := '0';
      end if;
      -- Apply synchronous reset before publishing next state and outputs.
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;

      fifoWrite     <= r.fifoWrite;
      fifoWriteData <= r.fifoWriteData;
      fifoRst       <= r.fifoRst;
      fifoRead      <= v.fifoRead;

      message       <= r.message;
      queueOverflow <= r.queueOverflow;
      messageValid  <= r.messageValid;
      rxAbort       <= r.abortNow;
      rxEpoch       <= slv(r.epoch);
      counters      <= r.counters;
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
