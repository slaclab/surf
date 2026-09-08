-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Bounded atomic PTP RX validation and record queue
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
      FIFO_DEPTH_G   : positive                  := 4;
      MAX_FRAME_G    : positive range 82 to 1518 := 1518);
   port (
      clk           : in sl;
      rst           : in sl;
      rxFlush       : in sl;
      generation    : in slv(31 downto 0);
      -- Always-consumed normalized bytes: destination MAC through FCS, with
      -- contiguous low-byte TKEEP. The capture sidecar is sampled only at SOF.
      rxMaster      : in AxiStreamMasterType;
      rxCapture     : in PtpRxCaptureType;
      -- Transfer requires messageValid AND messageReady AND NOT rxAbort.
      -- Abort is a same-edge invalidation, including of the visible old head;
      -- consumers must give it priority over all protocol/measurement commits.
      message       : out PtpRxMessageType;
      messageValid  : out sl;
      messageReady  : in sl;
      rxAbort       : out sl;
      rxEpoch       : out slv(31 downto 0);
      -- Saturating diagnostics: records enqueued, completed frames rejected
      -- by validation, and full-queue completion events. droppedCount does not
      -- count every frame lost before SOF, during flush, or through overflow.
      acceptedCount : out slv(31 downto 0);
      droppedCount  : out slv(31 downto 0);
      overflowCount : out slv(31 downto 0));
end entity PtpRxFrontend;

architecture rtl of PtpRxFrontend is

   -- Only one physical frame is being decoded at a time. The 78-byte prefix
   -- covers Ethernet (14) plus the largest supported fixed PTP message (64).
   -- Longer TLVs are streamed past; count saturates at MAX_FRAME_G+1 so an
   -- unterminated frame cannot wrap the parser back to a plausible short frame.
   -- bad is sticky for this frame and capture never changes after its SOF.
   type FrameType is record
      active : sl;
      bad : sl;
      count : natural range 0 to MAX_FRAME_G+1;
      prefix : Slv8Array(0 to 77);
      crc : slv(31 downto 0);
      capture : PtpRxCaptureType;
      tlvBytes : natural range 0 to 3;
      tlvLength : slv(15 downto 0);
      tlvRemaining : natural range 0 to 65535;
   end record;
   constant FRAME_INIT_C : FrameType := (
      active => '0', bad => '0', count => 0, prefix => (others => (others => '0')),
      crc => (others => '1'), capture => PTP_RX_CAPTURE_INIT_C,
      tlvBytes => 0, tlvLength => (others => '0'), tlvRemaining => 0);

   -- The small same-clock queue stores complete records, including captures.
   -- No separately lossy packet/timestamp streams remain to be joined by key.
   -- generation belongs to the PHC/configuration owner; epoch belongs to this
   -- RX queue. Clearing live pointers suffices to invalidate stored queue data.
   type RegType is record
      frame : FrameType;
      queue : PtpRxMessageArray(0 to FIFO_DEPTH_G-1);
      wrPtr : natural range 0 to FIFO_DEPTH_G-1;
      rdPtr : natural range 0 to FIFO_DEPTH_G-1;
      fill : natural range 0 to FIFO_DEPTH_G;
      generation : slv(31 downto 0);
      epoch : unsigned(31 downto 0);
      accepted : unsigned(31 downto 0);
      dropped : unsigned(31 downto 0);
      overflow : unsigned(31 downto 0);
   end record;
   constant REG_INIT_C : RegType := (
      frame => FRAME_INIT_C, queue => (others => PTP_RX_MESSAGE_INIT_C),
      wrPtr => 0, rdPtr => 0, fill => 0, generation => (others => '0'), epoch => (others => '0'),
      accepted => (others => '0'), dropped => (others => '0'), overflow => (others => '0'));
   signal r : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Explicit wrapping also supports depth one and non-power-of-two depths.
   function advance (ptr : natural) return natural is
   begin
      if ptr = FIFO_DEPTH_G-1 then
         return 0;
      end if;
      return ptr+1;
   end function;

   function satInc (value : unsigned) return unsigned is
   begin
      if value = (value'range => '1') then
         return value;
      end if;
      return value+1;
   end function;

   -- Fixed lengths include the 34-byte PTP header: Sync/Follow_Up (44),
   -- Delay_Resp (54), Announce (64). Delay_Req is TX-only for this receiver.
   -- Zero marks unsupported types, disabling both TLV walking and admission.
   function baseLength (kind : slv(3 downto 0)) return natural is
   begin
      case kind is
         when x"0" | x"8" => return 44;
         when x"9" => return 54;
         when x"B" => return 64;
         when others => return 0;
      end case;
   end function;

   -- Prefix offsets count from destination-MAC byte zero. Reassemble wire
   -- octets into conventional big-endian fields; AXI lane order is unrelated
   -- to the numerical significance of a multibyte PTP field.
   function networkField (bytes : Slv8Array; first : natural; count : positive) return slv is
      variable retVar : slv(8*count-1 downto 0);
   begin
      for i in 0 to count-1 loop
         retVar(8*(count-i)-1 downto 8*(count-i-1)) := bytes(first+i);
      end loop;
      return retVar;
   end function;

begin

   comb : process (r, rst, rxFlush, generation, rxMaster, rxCapture, messageReady) is
      variable v         : RegType;
      variable candidate : PtpRxMessageType;
      variable complete  : boolean;
      variable abortNow  : sl;
      variable byteCount : natural range 0 to 8;
      variable crcData   : slv(63 downto 0);
      variable octet     : slv(7 downto 0);
      variable base      : natural range 0 to 64;
      variable length    : natural range 0 to 65535;
      variable offset    : natural range 0 to MAX_FRAME_G+1;
      variable gap       : boolean;
   begin
      v := r;
      candidate := PTP_RX_MESSAGE_INIT_C;
      complete := false;
      abortNow := '0';
      byteCount := 0;
      crcData := (others => '0');
      gap := false;

      if rxMaster.tValid = '1' then
         if ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, rxMaster) = '1' then
            -- Start with fresh parser state and bind this frame's capture.
            -- A nested SOF discards both the partial frame and the new candidate;
            -- stale-generation starts are also ignored. Neither can attach a
            -- new timestamp to leftover bytes. PHC timeValid alone is not an
            -- admission requirement: acquisition needs unsynchronized captures.
            v.frame := FRAME_INIT_C;
            if r.frame.active = '0' and rxCapture.generation = r.generation then
               v.frame.active := '1';
               v.frame.capture := rxCapture;
               v.frame.bad := rxCapture.error;
            end if;
         end if;
         if v.frame.active = '1' then
            -- Keep errors until EOF, even if a later beat has clean sidebands.
            v.frame.bad := v.frame.bad or ssiGetUserEofe(PTP_RX_AXIS_CONFIG_C, rxMaster);
            for i in 0 to 7 loop
               if rxMaster.tKeep(i) = '1' then
                  if gap then
                     -- Sparse keeps violate the normalized physical interface.
                     -- Continue consuming, but never publish this frame.
                     v.frame.bad := '1';
                  end if;
                  byteCount := byteCount+1;
                  octet := rxMaster.tData(8*i+7 downto 8*i);
                  -- CrcPkg expects the first byte at the high end and reversed
                  -- bit order within each octet. Ethernet arrives low AXI byte
                  -- first; this transpose is separate from networkField decode.
                  for b in 0 to 7 loop
                     crcData(63-8*i-b) := octet(b);
                  end loop;
                  offset := v.frame.count;
                  if offset < MAX_FRAME_G then
                     v.frame.count := offset+1;
                     if offset < 78 then
                        v.frame.prefix(offset) := octet;
                     end if;
                     base := baseLength(v.frame.prefix(14)(3 downto 0));
                     length := to_integer(unsigned(networkField(v.frame.prefix, 16, 2)));
                     -- TLVs occupy [14+base, 14+messageLength). Their four-byte
                     -- header is type then value length; only length is needed
                     -- to skip unknown values. Padding lies outside this span.
                     -- Updating v within the loop handles headers split across
                     -- beats and a value ending partway through the same beat.
                     if base /= 0 and offset >= 14+base and offset < 14+length then
                        if v.frame.tlvRemaining /= 0 then
                           v.frame.tlvRemaining := v.frame.tlvRemaining-1;
                        else
                           if v.frame.tlvBytes = 2 then
                              v.frame.tlvLength(15 downto 8) := octet;
                           elsif v.frame.tlvBytes = 3 then
                              v.frame.tlvLength(7 downto 0) := octet;
                              v.frame.tlvRemaining := to_integer(unsigned(v.frame.tlvLength));
                              -- offset is the last TLV-header byte. A declared
                              -- value may not extend past the PTP message end.
                              if v.frame.tlvRemaining > 14+length-offset-1 then
                                 v.frame.bad := '1';
                              end if;
                           end if;
                           v.frame.tlvBytes := (v.frame.tlvBytes+1) mod 4;
                        end if;
                     end if;
                  else
                     v.frame.count := MAX_FRAME_G+1;
                     v.frame.bad := '1';
                  end if;
               else
                  gap := true;
               end if;
            end loop;
            -- One parallel CRC update per physical group. SURF uses the
            -- unreversed register convention; good Ethernet residue is below.
            -- CRC covers the entire frame including padding and FCS. A zero-
            -- byte termination leaves the remainder from the prior beat intact.
            case byteCount is
               when 1 => v.frame.crc := crc32Parallel1Byte(v.frame.crc, crcData(63 downto 56));
               when 2 => v.frame.crc := crc32Parallel2Byte(v.frame.crc, crcData(63 downto 48));
               when 3 => v.frame.crc := crc32Parallel3Byte(v.frame.crc, crcData(63 downto 40));
               when 4 => v.frame.crc := crc32Parallel4Byte(v.frame.crc, crcData(63 downto 32));
               when 5 => v.frame.crc := crc32Parallel5Byte(v.frame.crc, crcData(63 downto 24));
               when 6 => v.frame.crc := crc32Parallel6Byte(v.frame.crc, crcData(63 downto 16));
               when 7 => v.frame.crc := crc32Parallel7Byte(v.frame.crc, crcData(63 downto 8));
               when 8 => v.frame.crc := crc32Parallel8Byte(v.frame.crc, crcData);
               when others => null;
            end case;
            if rxMaster.tLast = '1' then
               -- Decide only after incorporating this beat's bytes and errors.
               -- 18 = 14 Ethernet header bytes + 4 FCS bytes: the length check
               -- proves that the fixed body and TLVs fit before FCS. Thus no
               -- separate trailing-FCS buffer is needed even though prefix may
               -- contain padding/FCS after a short message's meaningful bytes.
               -- C704DD7B is the good residue in CrcPkg's register convention.
               base := baseLength(v.frame.prefix(14)(3 downto 0));
               length := to_integer(unsigned(networkField(v.frame.prefix, 16, 2)));
               complete := v.frame.bad = '0' and v.frame.count >= 64 and v.frame.count <= MAX_FRAME_G and
                  v.frame.crc = x"C704DD7B" and networkField(v.frame.prefix, 12, 2) = x"88F7" and
                  v.frame.prefix(15)(3 downto 0) = x"2" and
                  (v.frame.prefix(15)(7 downto 4) = x"0" or v.frame.prefix(15)(7 downto 4) = x"1") and
                  base /= 0 and length >= base and length <= MAX_FRAME_G-18 and
                  v.frame.count >= 18+length and v.frame.tlvBytes = 0 and v.frame.tlvRemaining = 0;
               if complete then
                  -- Publish decoded common fields and only the fixed body;
                  -- candidate initialization zeros unused body bytes. Identity,
                  -- flags, and message-body semantics still need PtpPort policy.
                  -- A duplicate key remains a distinct physical record here.
                  candidate.capture := v.frame.capture;
                  candidate.rxEpoch := slv(r.epoch);
                  candidate.destination := networkField(v.frame.prefix, 0, 6);
                  candidate.sourcePortIdentity := networkField(v.frame.prefix, 34, 10);
                  candidate.sequenceId := networkField(v.frame.prefix, 44, 2);
                  candidate.domainNumber := v.frame.prefix(18);
                  candidate.messageType := v.frame.prefix(14)(3 downto 0);
                  candidate.minorVersion := v.frame.prefix(15)(7 downto 4);
                  candidate.transportSpecific := v.frame.prefix(14)(7 downto 4);
                  candidate.messageLength := networkField(v.frame.prefix, 16, 2);
                  candidate.flags := networkField(v.frame.prefix, 20, 2);
                  candidate.correction := networkField(v.frame.prefix, 22, 8);
                  candidate.control := v.frame.prefix(46);
                  candidate.logInterval := v.frame.prefix(47);
                  for i in 0 to 29 loop
                     if i < base-34 then
                        candidate.messageBody(239-8*i downto 232-8*i) := v.frame.prefix(48+i);
                     end if;
                  end loop;
               else
                  v.dropped := satInc(r.dropped);
               end if;
               v.frame := FRAME_INIT_C;
            end if;
         end if;
      end if;

      -- Admission deliberately tests pre-edge occupancy. A full queue cannot
      -- rescue this completion through simultaneous ready: discard the candidate
      -- and all queued records, advance the RX epoch, and cancel this edge's
      -- transfer. Malformed/non-PTP completions never take this overflow path.
      if complete and r.fill = FIFO_DEPTH_G then
         v.fill := 0;
         v.wrPtr := 0;
         v.rdPtr := 0;
         v.epoch := r.epoch+1;
         v.overflow := satInc(r.overflow);
         abortNow := '1';
      else
         -- Ordinary edge: remove the old head, then append a new completion.
         -- Outputs still come from r, so an arrival cannot fall through an empty
         -- queue and a stalled head stays stable unless explicitly aborted.
         if r.fill /= 0 and messageReady = '1' then
            v.rdPtr := advance(r.rdPtr);
            v.fill := r.fill-1;
         end if;
         if complete then
            v.queue(r.wrPtr) := candidate;
            v.wrPtr := advance(r.wrPtr);
            v.fill := v.fill+1;
            v.accepted := satInc(r.accepted);
         end if;
      end if;

      -- Logical invalidation overrides parsing, admission, consumption, and
      -- diagnostic increments above. Hold flush as long as necessary; each
      -- asserted edge advances epoch. No old queue entry or partial frame is
      -- reachable afterward, but downstream consumers must invalidate their
      -- own pending work. This operation neither resets the PHC nor frees TX keys.
      if rxFlush = '1' or generation /= r.generation then
         v := r;
         v.frame := FRAME_INIT_C;
         v.fill := 0;
         v.rdPtr := 0;
         v.wrPtr := 0;
         v.generation := generation;
         v.epoch := r.epoch+1;
         abortNow := '1';
      end if;
      -- System reset also cancels transfer immediately. Unlike a logical flush,
      -- it resets epoch/counters; the owner must coordinate reset with consumers
      -- before reusing that epoch space. Async state reset occurs in seq.
      if rst = RST_POLARITY_G then
         abortNow := '1';
         if not RST_ASYNC_G then
            v := REG_INIT_C;
         end if;
      end if;
      rin <= v;
      -- Keep the old head visible while stalled. rxAbort is combinational from
      -- this edge's decision, so messageValid alone is never proof of transfer.
      -- Epoch and counters below describe registered state, changing after TPD.
      message <= r.queue(r.rdPtr);
      messageValid <= '0';
      if r.fill /= 0 then
         messageValid <= '1';
      end if;
      rxAbort <= abortNow;
      rxEpoch <= slv(r.epoch);
      acceptedCount <= slv(r.accepted);
      droppedCount <= slv(r.dropped);
      overflowCount <= slv(r.overflow);
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
