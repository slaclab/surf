##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Bounded RX contract model, after physical framing and before protocol policy.

No MAC packet, wire identity, or separate timestamp lookup is an input. The
physical adapter must deliver capture and first frame bytes together. This
model does not implement that adapter, PHC calibration, or a clock crossing.
"""

from collections import Counter, deque
from dataclasses import dataclass
from fractions import Fraction


@dataclass(frozen=True)
class RxStamp:
    time: Fraction
    ticks: int
    generation: int = 0
    time_valid: bool = False
    tick_phase: int = 0  # Eighths of an unsteered cycle at the message point.

    def __post_init__(self):
        if not 0 <= self.tick_phase < 8:
            raise ValueError("invalid unsteered byte phase")


@dataclass(frozen=True)
class RxBeat:
    # Contiguous wire-order bytes, destination MAC through FCS. No preamble.
    data: bytes = b""
    sof: bool = False
    eof: bool = False
    error: bool = False
    stamp: RxStamp | None = None


@dataclass(frozen=True)
class RxMessage:
    stamp: RxStamp
    rx_epoch: int
    destination: bytes
    key: tuple
    minor_version: int
    transport_specific: int
    message_length: int
    flags: int
    correction: int  # Signed Q16 nanoseconds, never converted through float.
    control: int
    log_interval: int
    body: bytes  # Fixed message body only; unknown TLVs are validated then skipped.


def crc_octet(crc, byte):
    """Bit-serial Ethernet residue oracle; stimulus uses zlib independently."""
    crc ^= byte
    for _ in range(8):
        crc = (crc >> 1) ^ (0xedb88320 if crc & 1 else 0)
    return crc


class RxFrontend:
    # Selected TimeReceiver subset. Delay_Req is TX-only at this boundary.
    BASE_LENGTH = {0: 44, 8: 44, 9: 54, 11: 64}
    PREFIX_BYTES = 78  # Ethernet header + largest fixed body (Announce).

    def __init__(self, depth=4, max_frame=1518):
        if depth < 1 or not 82 <= max_frame <= 1518:
            raise ValueError("unsupported bounded RX storage configuration")
        self.depth = depth
        self.max_frame = max_frame  # Includes four FCS bytes, excludes preamble.
        self.generation = 0
        self.rx_epoch = 0
        self.entries = deque()
        self.counters = Counter()
        self.abort = False
        self._idle()

    def _idle(self):
        self.stamp = None
        self.prefix = bytearray()
        self.tail = deque()
        self.count = 0
        self.crc = 0xffffffff
        self.bad = False
        self.tlv_header = bytearray()
        self.tlv_remaining = 0

    def _body_byte(self, byte, offset):
        if len(self.prefix) < self.PREFIX_BYTES:
            self.prefix.append(byte)
        if len(self.prefix) < 18:
            return
        base = self.BASE_LENGTH.get(self.prefix[14] & 15)
        length = int.from_bytes(self.prefix[16:18], "big")
        ptp_offset = offset - 14
        if base is None or not base <= ptp_offset < length:
            return
        if self.tlv_remaining:
            self.tlv_remaining -= 1
        else:
            self.tlv_header.append(byte)
            if len(self.tlv_header) == 4:
                self.tlv_remaining = int.from_bytes(self.tlv_header[2:4], "big")
                if self.tlv_remaining > length - ptp_offset - 1:
                    self.bad = True
                self.tlv_header.clear()

    def _finish(self):
        p = self.prefix
        if self.bad or not 64 <= self.count <= self.max_frame:
            self.counters["framing"] += 1
            return None
        if self.crc != 0xdebb20e3:
            self.counters["crc"] += 1
            return None
        if p[12:14] != b"\x88\xf7":
            self.counters["non_ptp"] += 1
            return None
        kind = p[14] & 15
        base = self.BASE_LENGTH.get(kind)
        length = int.from_bytes(p[16:18], "big")
        if (base is None or p[15] & 15 != 2 or p[15] >> 4 not in (0, 1)):
            self.counters["unsupported"] += 1
            return None
        if (not base <= length <= self.max_frame - 18 or
                self.count - 4 < 14 + length or self.tlv_header or self.tlv_remaining):
            self.counters["length"] += 1
            return None
        # Source/domain/destination/flags and message-specific semantic checks
        # remain PtpPort policy. This is a structurally valid, CRC-checked record.
        return RxMessage(
            self.stamp, self.rx_epoch, bytes(p[:6]),
            (kind, p[18], bytes(p[34:44]), int.from_bytes(p[44:46], "big")),
            p[15] >> 4, p[14] >> 4, length, int.from_bytes(p[20:22], "big"),
            int.from_bytes(p[22:30], "big", signed=True), p[46],
            int.from_bytes(p[47:48], "big", signed=True), bytes(p[48:14+base]),
        )

    def edge(self, beat=None, ready=False, restart=False, generation=None):
        """Return a transferred OLD queue item, or None; expose abort this edge.

        Flush/overflow suppress transfer even if ready was asserted. An RTL
        consumer must qualify valid && ready with !abort on that same edge.
        A new completion never falls through an empty queue on its arrival edge.
        """
        self.abort = False
        next_generation = self.generation if generation is None else generation
        if restart or next_generation != self.generation:
            self.generation = next_generation
            self.rx_epoch += 1
            self.entries.clear()
            self._idle()
            self.abort = True
            return None

        candidate = None
        if beat is not None:
            if len(beat.data) > 8 or (beat.sof and (beat.stamp is None or not beat.data)):
                raise ValueError("invalid normalized physical beat")
            if beat.sof:
                # A nested SOF is an error, not a chance to attach a new time to
                # bytes left from the old frame. A subsequent SOF can recover.
                nested = self.stamp is not None
                self._idle()
                if not nested and beat.stamp.generation == self.generation:
                    self.stamp = beat.stamp
            if self.stamp is not None:
                self.bad |= beat.error
                for byte in beat.data:
                    self.count = min(self.count + 1, self.max_frame + 1)
                    if self.count > self.max_frame:
                        self.bad = True
                        continue
                    self.crc = crc_octet(self.crc, byte)
                    self.tail.append(byte)
                    if len(self.tail) > 4:
                        self._body_byte(self.tail.popleft(), self.count - 5)
                if beat.eof:
                    candidate = self._finish()
                    self._idle()

        # Full means full before the edge. No dependence on consumer readiness
        # in physical admission, and no silent replacement of the visible head.
        if candidate is not None and len(self.entries) == self.depth:
            self.counters["overflow"] += 1
            self.rx_epoch += 1
            self.entries.clear()
            self.abort = True
            return None
        result = self.entries.popleft() if ready and self.entries else None
        if candidate is not None:
            self.entries.append(candidate)
            self.counters["accepted"] += 1
        return result
