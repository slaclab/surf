-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Dedicated passive Delay_Req wire validator and two-entry queue.
-- Stores only domain, requester identity and sequence (13 bytes), alongside the
-- complete physical capture. Unsupported message types never allocate a record.
-- Ethernet framing, FCS, length and streamed TLVs are checked through EOF.
-- Logical restart and PHC generation changes cannot erase physical wire fate.
--
-- Consumes normalized destination-MAC-through-FCS bytes every clk cycle with
-- rxMaster.tValid; this physical input has no backpressure. Binds the capture
-- at SOF, streams the CRC and TLV checks, then queues a complete decoded record.
-- A synchronous FWFT FIFO carries validated frame descriptors; the decoder
-- streams compact RAM fields into one held public head. Logical capacity
-- includes the descriptor pipeline, decoder and head.
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

entity PtpDelayReqObserver is
   generic (
      TPD_G          : time                      := 1 ns;
      RST_POLARITY_G : sl                        := '1';
      RST_ASYNC_G    : boolean                   := false;
      MAX_FRAME_G    : PtpFrameCapacityType      := PTP_ETH_MAX_FRAME_C);
   port (
      clk        : in  sl;
      rst        : in  sl;
      rxFlush    : in  sl;
      generation : in  slv(31 downto 0);
      -- Always-consumed normalized bytes: destination MAC through FCS, with
      -- contiguous low-byte TKEEP. The capture sidecar is sampled only at SOF.
      rxMaster  : in  AxiStreamMasterType;
      rxCapture : in  PtpRxCaptureType;
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
end entity PtpDelayReqObserver;

architecture rtl of PtpDelayReqObserver is

   constant FIFO_DEPTH_G : positive := 2;
   -- Compact fixed fields omit Ethernet source/reserved octets. Eight lane
   -- banks accept any normalized physical beat without compute-port arbitration.
   constant STORE_BYTES_C  : positive := 13;
   constant STORE_GROUPS_C : positive := (STORE_BYTES_C+7)/8;
   constant BANKS_C        : positive := FIFO_DEPTH_G+1;
   constant BANK_BITS_C    : positive := log2(BANKS_C);

   constant STORE_ADDR_BITS_C : positive := log2(BANKS_C*STORE_GROUPS_C);

   constant DESCRIPTOR_BITS_C : positive := BANK_BITS_C+7;
   constant CAPTURE_BITS_C    : positive := 96+64+PTP_TICK_PHASE_BITS_C+32+64+2+32;
   type AddressArray is array (0 to 7) of slv(STORE_ADDR_BITS_C-1 downto 0);
   -- The portable FIFO has a minimum address width of four and reserves one
   -- RAM slot. Logical occupancy below includes every stage, not just RAM.
   constant FIFO_ADDR_BITS_C : positive := maximum(4, log2(FIFO_DEPTH_G+1));
   -- Good Ethernet FCS residue in CrcPkg's register convention.
   constant ETH_CRC_RESIDUE_C : slv(31 downto 0) := x"C704DD7B";
   -- One physical frame owns the current capture bank. Fixed fields stream
   -- into byte lanes; only validation metadata remains in this record.
   -- Longer TLVs are streamed past; count saturates at MAX_FRAME_G+1 so an
   -- unterminated frame cannot wrap the parser back to a plausible short frame.
   -- bad is sticky for this frame and capture never changes after its SOF.

   type FrameType is record
      active       : sl;
      bad          : sl;
      count        : natural range 0 to MAX_FRAME_G+1;
      etherType    : slv(15 downto 0);
      kind         : slv(3 downto 0);
      version      : slv(3 downto 0);
      length       : slv(15 downto 0);
      crc          : slv(31 downto 0);
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
      etherType    => (others => '0'),
      kind         => (others => '0'),
      version      => (others => '0'),
      length       => (others => '0'),
      crc          => (others => '1'),
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
      message       : PtpRxMessageType;
      queueOverflow : sl;
      abortNow      : sl;
      -- Registered FIFO write/reset and recomputed FWFT read acknowledgement.
      fifoWrite          : sl;
      fifoWriteData      : slv(DESCRIPTOR_BITS_C-1 downto 0);
      fifoRst            : sl;
      fifoRead           : sl;
      counters           : PtpRxCountersType;
      messageValid       : sl;
      frame              : FrameType;
      fill               : natural range 0 to FIFO_DEPTH_G;
      tail               : natural range 0 to BANKS_C-1;
      storeWrite         : slv(7 downto 0);
      storeAddress       : AddressArray;
      storeData          : Slv8Array(0 to 7);
      captureWrite       : sl;
      captureAddress     : slv(BANK_BITS_C-1 downto 0);
      captureData        : slv(CAPTURE_BITS_C-1 downto 0);
      decoding           : sl;
      decodeBank         : natural range 0 to BANKS_C-1;
      decodeBytes        : natural range 0 to STORE_BYTES_C;
      issueGroup         : natural range 0 to STORE_GROUPS_C;
      readEnable         : sl;
      readAddress        : slv(STORE_ADDR_BITS_C-1 downto 0);
      captureReadAddress : slv(BANK_BITS_C-1 downto 0);
      returnValid        : sl;
      returnGroup        : natural range 0 to STORE_GROUPS_C-1;
      generation         : slv(31 downto 0);
      epoch              : unsigned(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      message            => PTP_RX_MESSAGE_INIT_C,
      queueOverflow      => '0',
      abortNow           => '0',
      fifoWrite          => '0',
      fifoWriteData      => (others => '0'),
      fifoRst            => '1',
      fifoRead           => '0',
      counters           => PTP_RX_COUNTERS_INIT_C,
      messageValid       => '0',
      frame              => FRAME_INIT_C,
      fill               => 0,
      tail               => 0,
      storeWrite         => (others => '0'),
      storeAddress       => (others => (others => '0')),
      storeData          => (others => (others => '0')),
      captureWrite       => '0',
      captureAddress     => (others => '0'),
      captureData        => (others => '0'),
      decoding           => '0',
      decodeBank         => 0,
      decodeBytes        => 0,
      issueGroup         => 0,
      readEnable         => '0',
      readAddress        => (others => '0'),
      captureReadAddress => (others => '0'),
      returnValid        => '0',
      returnGroup        => 0,
      generation         => (others => '0'),
      epoch              => (others => '0'));

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal fifoWrite     : sl;
   signal fifoWriteData : slv(DESCRIPTOR_BITS_C-1 downto 0);

   signal fifoRst      : sl;
   signal fifoRead     : sl;
   signal fifoReadData : slv(DESCRIPTOR_BITS_C-1 downto 0);

   signal fifoValid     : sl;
   signal storeReadData : Slv8Array(0 to 7);

   signal captureReadData : slv(CAPTURE_BITS_C-1 downto 0);
   -- Fixed lengths include the 34-byte PTP header: Sync/Follow_Up (44),
   -- Delay_Resp (54), Announce (64). Delay_Req is TX-only for this receiver.
   -- Zero marks unsupported types, disabling both TLV walking and admission.

   function baseLength (kind : slv(3 downto 0)) return natural is
   begin

      if kind = PTP_MSG_DELAY_REQ_C then
         return PTP_TIMESTAMP_MSG_BYTES_C;
      end if;

      return 0;
   end function;

   -- Monotone compaction guarantees at most one write per lane in an
   -- eight-byte physical group, even when that group straddles a RAM row.

   function compactIndex(offset : natural) return integer is
   begin

      case offset is
         when 18 =>
            return 12;
         when 34 to 45 =>
            return offset-34;
         when others =>
            return -1;
      end case;

   end function;

   procedure takeByte(variable item : inout PtpRxMessageType;
   constant index : natural;
   constant octet : slv(7 downto 0)) is
   begin

      case index is
         when 0 to 9 =>
            item.sourcePortIdentity(79-8*index downto 72-8*index) := octet;
         when 10 to 11 =>
            item.sequenceId(15-8*(index-10) downto 8-8*(index-10)) := octet;
         when 12 =>
            item.domainNumber := octet;
         when others =>
            null;
      end case;

   end procedure;

begin

   -- The extra bank belongs exclusively to the frame in flight. Logical
   -- queue capacity still includes the decoder and held head. No RAM is reset;
   -- the descriptor FIFO and scalar ownership invalidate all old contents.
   GEN_LANE : for i in 0 to 7 generate

      U_Store : entity surf.SimpleDualPortRam
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            DATA_WIDTH_G   => 8,
            BYTE_WR_EN_G   => false,
            BYTE_WIDTH_G   => 8,
            ADDR_WIDTH_G   => STORE_ADDR_BITS_C,
            COMMON_CLK_G   => true,
            MEMORY_TYPE_G  => "distributed",
            READ_LATENCY_G => 1)
         port map (
            clka  => clk,
            ena   => r.storeWrite(i),
            wea   => r.storeWrite(i),
            addra => r.storeAddress(i),
            dina  => r.storeData(i),
            clkb  => clk,
            rstb  => rst,
            enb   => r.readEnable,
            addrb => r.readAddress,
            doutb => storeReadData(i));

   end generate;
   -- One physical SOF capture is a necessary parallel boundary. Store it once
   -- independently of the eight streaming payload ports, then read it with the
   -- descriptor's first group. There is no decoded-record FIFO/write staging.
   U_Capture : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DATA_WIDTH_G   => CAPTURE_BITS_C,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => CAPTURE_BITS_C,
         ADDR_WIDTH_G   => BANK_BITS_C,
         COMMON_CLK_G   => true,
         MEMORY_TYPE_G  => "distributed",
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,
         ena   => r.captureWrite,
         wea   => r.captureWrite,
         addra => r.captureAddress,
         dina  => r.captureData,
         clkb  => clk,
         rstb  => rst,
         enb   => r.readEnable,
         addrb => r.captureReadAddress,
         doutb => captureReadData);

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
         DATA_WIDTH_G    => DESCRIPTOR_BITS_C,
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

   comb : process (r, rst, rxFlush, generation, rxMaster, rxCapture, messageReady, fifoReadData, fifoValid, storeReadData, captureReadData) is
      variable v               : RegType;
      variable octet           : slv(7 downto 0);
      variable base            : natural range 0 to PTP_ANNOUNCE_BYTES_C;
      variable length          : natural range 0 to 65535;
      variable offset          : natural range 0 to MAX_FRAME_G+9;
      variable first           : natural range 0 to MAX_FRAME_G+1;
      variable last            : natural range 0 to MAX_FRAME_G+9;
      variable compact         : integer range -1 to STORE_BYTES_C-1;
      variable captureIndex    : natural;
      variable descriptorBank  : natural range 0 to BANKS_C-1;
      variable descriptorBytes : natural range 0 to STORE_BYTES_C;
      -- Calculations used only during this evaluation.
      variable frameComplete : boolean;
      variable byteCount     : natural range 0 to 8;
      variable crcData       : slv(63 downto 0);
      variable keepGap       : boolean;
   begin
      v               := r;
      octet           := (others => '0');
      base            := 0;
      length          := 0;
      offset          := 0;
      first           := 0;
      last            := 0;
      compact         := -1;
      captureIndex    := 0;
      descriptorBank  := 0;
      descriptorBytes := 0;
      frameComplete   := false;
      v.abortNow       := '0';
      v.queueOverflow  := '0';
      v.fifoWrite      := '0';
      v.fifoRead       := '0';
      v.fifoRst        := '0';
      byteCount := 0;
      crcData   := (others => '0');
      keepGap   := false;
      v.storeWrite := (others => '0');
      v.captureWrite := '0';
      v.readEnable := '0';
      v.returnValid := r.readEnable;
      v.returnGroup := to_integer(unsigned(r.readAddress)) mod STORE_GROUPS_C;

      if r.messageValid = '1' and messageReady = '1' then
         v.messageValid := '0';
         v.fill := r.fill-1;
      end if;

      -- Issue one group every clock; the registered request and synchronous
      -- RAM contribute two edges before a returned group updates the head.
      if r.decoding = '1' then
         if r.issueGroup < (r.decodeBytes+7)/8 then
            v.readEnable := '1';
            v.readAddress := toSlv(r.decodeBank*STORE_GROUPS_C+r.issueGroup, STORE_ADDR_BITS_C);
            v.issueGroup := r.issueGroup+1;
         end if;
         if r.returnValid = '1' then
            if r.returnGroup = 0 then
               captureIndex := 0;
               assignRecord(captureIndex, captureReadData, v.message.rxEpoch);
               assignRecord(captureIndex, captureReadData, v.message.capture.error);
               assignRecord(captureIndex, captureReadData, v.message.capture.timeValid);
               assignRecord(captureIndex, captureReadData, v.message.capture.increment);
               assignRecord(captureIndex, captureReadData, v.message.capture.generation);
               assignRecord(captureIndex, captureReadData, v.message.capture.tickPhase);
               assignRecord(captureIndex, captureReadData, v.message.capture.ticks);
               assignRecord(captureIndex, captureReadData, v.message.capture.timestamp);
            end if;
            for i in 0 to 7 loop
               if 8*r.returnGroup+i < r.decodeBytes then
                  takeByte(v.message, 8*r.returnGroup+i, storeReadData(i));
               end if;
            end loop;
            if 8*(r.returnGroup+1) >= r.decodeBytes then
               v.messageValid := '1';
               v.decoding := '0';
            end if;
         end if;
      elsif v.messageValid = '0' and fifoValid = '1' and r.fifoRst = '0' then
         descriptorBank  := to_integer(unsigned(fifoReadData(BANK_BITS_C-1 downto 0)));
         descriptorBytes := to_integer(unsigned(fifoReadData(DESCRIPTOR_BITS_C-1 downto BANK_BITS_C)));
         v.message := PTP_RX_MESSAGE_INIT_C;
         v.message.messageType := PTP_MSG_DELAY_REQ_C;
         v.decoding := '1';
         v.decodeBank := descriptorBank;
         v.decodeBytes := descriptorBytes;
         v.issueGroup := 1;
         v.readEnable := '1';
         v.readAddress := toSlv(descriptorBank*STORE_GROUPS_C, STORE_ADDR_BITS_C);
         v.captureReadAddress := toSlv(descriptorBank, BANK_BITS_C);
         v.fifoRead := '1';
      end if;

      if rxMaster.tValid = '1' then
         if ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, rxMaster) = '1' then
            -- Start with fresh parser state and bind this frame's capture.
            -- A nested SOF discards both the partial frame and the new candidate
            -- so no new timestamp can attach to leftover bytes. Generation and
            -- capture validity cannot suppress observation of physical TX fate.
            v.frame := FRAME_INIT_C;
            if r.frame.active = '0' then
               v.frame.active  := '1';
               v.captureWrite := '1';
               v.captureAddress := toSlv(r.tail, BANK_BITS_C);
               v.captureData := rxCapture.timestamp & rxCapture.ticks & rxCapture.tickPhase &
                  rxCapture.generation & rxCapture.increment & rxCapture.timeValid & rxCapture.error & slv(r.epoch);
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
            first := v.frame.count;
            last  := first+byteCount;
            for i in 0 to 7 loop
               if i < byteCount then
                  offset := first+i;
                  octet  := rxMaster.tData(8*i+7 downto 8*i);

                  case offset is
                     when 12 =>
                        v.frame.etherType(15 downto 8) := octet;
                     when 13 =>
                        v.frame.etherType(7 downto 0) := octet;
                     when 14 =>
                        v.frame.kind := octet(3 downto 0);
                     when 15 =>
                        v.frame.version := octet(3 downto 0);
                     when 16 =>
                        v.frame.length(15 downto 8) := octet;
                     when 17 =>
                        v.frame.length(7 downto 0) := octet;
                        v.frame.base := baseLength(v.frame.kind);
                        length := to_integer(unsigned(v.frame.length));
                        if v.frame.base = 0 or length < v.frame.base or length > MAX_FRAME_G-PTP_ETH_OVERHEAD_BYTES_C then
                           v.frame.bad := '1';
                        else
                           v.frame.messageEnd := PTP_ETH_HEADER_BYTES_C+length;
                        end if;
                     when others =>
                        null;
                  end case;

                  compact := compactIndex(offset);
                  if compact >= 0 and (offset < 48 or offset < PTP_ETH_HEADER_BYTES_C+v.frame.base) then
                     v.storeWrite(compact mod 8) := '1';
                     v.storeAddress(compact mod 8) := toSlv(r.tail*STORE_GROUPS_C+compact/8, STORE_ADDR_BITS_C);
                     v.storeData(compact mod 8) := octet;
                  end if;
               end if;
            end loop;
            if last > MAX_FRAME_G then
               v.frame.count := MAX_FRAME_G+1;
               v.frame.bad := '1';
            else
               v.frame.count := last;
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
               -- major version matches. Minor version is not part of a wire key.
               elsif v.frame.etherType /= PTP_ETH_TYPE_C then
                  frameComplete := false;
               elsif v.frame.version /= PTP_MAJOR_VERSION_C then
                  frameComplete := false;
               -- Require the fixed body and complete TLVs before the FCS.
               elsif base = 0 then
                  frameComplete := false;
               elsif v.frame.count < PTP_ETH_FCS_BYTES_C+v.frame.messageEnd or v.frame.tlvBytes /= 0 or v.frame.tlvRemaining /= 0 then
                  frameComplete := false;
               end if;
               if not frameComplete then
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
         v.tail := 0;
         v.decoding := '0';
         v.readEnable := '0';
         v.returnValid := '0';
         v.epoch             := r.epoch+1;
         v.counters.overflow := ptpSatInc(r.counters.overflow);
         v.queueOverflow     := '1';
         v.abortNow          := '1';
      elsif frameComplete then
         v.fifoWrite         := '1';
         v.fifoWriteData := toSlv(STORE_BYTES_C, 7) & toSlv(r.tail, BANK_BITS_C);
         v.tail := (r.tail+1) mod BANKS_C;
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
      if rxFlush = '1' then
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
         v.tail := 0;
         v.decoding := '0';
         v.readEnable := '0';
         v.returnValid := '0';
         v.storeWrite := (others => '0');
         v.captureWrite := '0';
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
