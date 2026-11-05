##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""GMII/XGMII line models, checksum models and frame expectations.

These helpers are independent of the MAC RTL so the EthMacCore regressions
judge the MAC against IEEE 802.3 framing rather than against itself:

- Encoders turn a frame into GMII symbols or XGMII lane bytes, with optional
  error injection (bad FCS, ``RX_ER``, truncated preamble, missing SFD, XGMII
  ``/E/``, nested ``/S/`` and both start lanes).
- Drivers present encoded symbols on a wrapper's receive pins, honouring a
  clock-enable pattern for GMII.
- Monitors decode a wrapper's transmit pins into ``LineFrame`` records with
  preamble, FCS, error and interframe-gap information.
- ``StatusPulseCounter`` counts every one-cycle status pulse so tests can
  assert exact counts rather than only the absence of a pulse.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import random
import zlib

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge

from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETH_TYPE_IPV4,
    IP_PROTOCOL_UDP,
    build_ethernet_frame,
    internet_checksum,
    ipv4_to_bytes,
)


PREAMBLE = b"\x55" * 7
SFD = 0xD5
XGMII_IDLE = 0x07
XGMII_START = 0xFB
XGMII_TERMINATE = 0xFD
XGMII_ERROR = 0xFE
XGMII_IDLE_WORD = 0x0707070707070707
IP_PROTOCOL_TCP = 0x06

# Ethernet sizes without FCS
MIN_FRAME_BYTES = 60
MAX_FRAME_BYTES = 1514
MAX_VLAN_FRAME_BYTES = 1518


def resolved_int(signal, default: int = 0) -> int:
    """Integer value of a signal, or ``default`` while it holds U/X/Z."""
    try:
        return int(signal.value)
    except ValueError:
        return default


def fcs_bytes(frame: bytes) -> bytes:
    """IEEE 802.3 FCS in wire order (least significant byte first)."""
    return zlib.crc32(frame).to_bytes(4, "little")


def corrupt_fcs(frame: bytes) -> bytes:
    fcs = fcs_bytes(frame)
    return bytes([fcs[0] ^ 0x01]) + fcs[1:]


def wire_octets(
    frame: bytes,
    *,
    preamble_bytes: int = 7,
    sfd: bool = True,
    fcs: bytes | None = None,
    bad_fcs: bool = False,
) -> bytes:
    """Preamble, SFD, frame and FCS as transmitted on the line."""
    if fcs is None:
        fcs = corrupt_fcs(frame) if bad_fcs else fcs_bytes(frame)
    return b"\x55" * preamble_bytes + (bytes([SFD]) if sfd else b"") + frame + fcs


def random_payload(rng: random.Random, length: int) -> bytes:
    return bytes(rng.getrandbits(8) for _ in range(length))


def random_frame(
    rng: random.Random,
    length: int,
    *,
    dst_mac: int = 0x001122334455,
    src_mac: int = 0x660102030405,
    eth_type: int = 0x88B5,
) -> bytes:
    """A frame of exactly ``length`` bytes (no FCS) with a random payload."""
    assert length >= 14
    return build_ethernet_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        eth_type=eth_type,
        payload=random_payload(rng, length - 14),
    )


###############################################################################
# GMII
###############################################################################


@dataclass(frozen=True)
class GmiiSymbol:
    dv: int
    er: int
    d: int


GMII_IDLE = GmiiSymbol(0, 0, 0)


def gmii_symbols(
    frame: bytes,
    *,
    preamble_bytes: int = 7,
    sfd: bool = True,
    fcs: bytes | None = None,
    bad_fcs: bool = False,
    er_at: int | None = None,
    truncate_at: int | None = None,
    ifg: int = 12,
) -> list[GmiiSymbol]:
    """Encode one frame as GMII receive symbols followed by ``ifg`` idles.

    ``er_at`` and ``truncate_at`` index the on-wire octet stream, including
    preamble and SFD. ``er_at`` asserts ``RX_ER`` with ``RX_DV`` on that octet;
    ``truncate_at`` drops ``RX_DV`` before that octet.
    """
    octets = wire_octets(frame, preamble_bytes=preamble_bytes, sfd=sfd, fcs=fcs, bad_fcs=bad_fcs)
    if truncate_at is not None:
        octets = octets[:truncate_at]
    symbols = [GmiiSymbol(1, 1 if index == er_at else 0, octet) for index, octet in enumerate(octets)]
    return symbols + [GMII_IDLE] * ifg


def gmii_data_offset(preamble_bytes: int = 7, sfd: bool = True) -> int:
    """Wire-octet index of the first destination-MAC byte."""
    return preamble_bytes + (1 if sfd else 0)


class GmiiDriver:
    """Drive GMII receive pins, one symbol per enabled clock.

    Symbols change on the falling edge, so the DUT samples a stable value on
    the next rising edge. With a clock-enable signal, a symbol is held until a
    rising edge with the enable high consumes it, matching a 10/100 PHY that
    repeats each octet for the enable period.
    """

    MAX_ENABLE_WAIT = 1000

    def __init__(self, dut, *, clk, prefix: str = "gmiiRx", clk_en=None):
        self.clk = clk
        self.dv = getattr(dut, f"{prefix}Dv")
        self.er = getattr(dut, f"{prefix}Er")
        self.d = getattr(dut, f"{prefix}d")
        self.clk_en = clk_en

    def idle(self) -> None:
        self.dv.value = 0
        self.er.value = 0
        self.d.value = 0

    async def send(self, symbols: list[GmiiSymbol]) -> None:
        for symbol in symbols:
            await FallingEdge(self.clk)
            self.dv.value = symbol.dv
            self.er.value = symbol.er
            self.d.value = symbol.d
            for _ in range(self.MAX_ENABLE_WAIT):
                await RisingEdge(self.clk)
                if self.clk_en is None or int(self.clk_en.value) == 1:
                    break
            else:
                raise AssertionError("GMII clock enable stayed low")
        await FallingEdge(self.clk)
        self.idle()


###############################################################################
# XGMII
###############################################################################


def xgmii_lanes(
    frame: bytes,
    *,
    preamble_bytes: int = 6,
    sfd: bool = True,
    fcs: bytes | None = None,
    bad_fcs: bool = False,
    error_at: int | None = None,
    terminate: bool = True,
) -> list[tuple[int, int]]:
    """Encode one frame as (byte, control) lanes starting with ``/S/``.

    ``/S/`` replaces the first preamble octet, so the default carries six
    0x55 octets after it. ``error_at`` replaces that octet of the stream after
    ``/S/`` (preamble included) with ``/E/``. ``terminate=False`` omits
    ``/T/`` so a caller can follow with a nested ``/S/`` or a link drop.
    """
    octets = b"\x55" * preamble_bytes + (bytes([SFD]) if sfd else b"")
    octets += frame + (fcs if fcs is not None else (corrupt_fcs(frame) if bad_fcs else fcs_bytes(frame)))
    lanes = [(XGMII_START, 1)]
    for index, octet in enumerate(octets):
        lanes.append((XGMII_ERROR, 1) if index == error_at else (octet, 0))
    if terminate:
        lanes.append((XGMII_TERMINATE, 1))
    return lanes


def xgmii_words_from_lanes(
    lanes: list[tuple[int, int]],
    *,
    start_lane: int = 0,
    ifg: int = 12,
) -> list[tuple[int, int]]:
    """Pack lanes into 64-bit (data, control) words; ``start_lane`` is 0 or 4."""
    assert start_lane in (0, 4)
    stream = [(XGMII_IDLE, 1)] * start_lane + list(lanes) + [(XGMII_IDLE, 1)] * ifg
    stream += [(XGMII_IDLE, 1)] * (-len(stream) % 8)
    return [
        (
            sum(byte << (8 * index) for index, (byte, _) in enumerate(stream[offset : offset + 8])),
            sum(ctrl << index for index, (_, ctrl) in enumerate(stream[offset : offset + 8])),
        )
        for offset in range(0, len(stream), 8)
    ]


def xgmii_words(frame: bytes, *, start_lane: int = 0, ifg: int = 12, **kwargs) -> list[tuple[int, int]]:
    return xgmii_words_from_lanes(xgmii_lanes(frame, **kwargs), start_lane=start_lane, ifg=ifg)


class XgmiiDriver:
    """Drive XGMII receive pins, one 64-bit word per clock, on the falling edge."""

    def __init__(self, dut, *, clk, data_name: str = "xgmiiRxd", ctrl_name: str = "xgmiiRxc"):
        self.clk = clk
        self.data = getattr(dut, data_name)
        self.ctrl = getattr(dut, ctrl_name)

    def idle(self) -> None:
        self.data.value = XGMII_IDLE_WORD
        self.ctrl.value = 0xFF

    async def send(self, words: list[tuple[int, int]]) -> None:
        for data, ctrl in words:
            await FallingEdge(self.clk)
            self.data.value = data
            self.ctrl.value = ctrl
            await RisingEdge(self.clk)
        await FallingEdge(self.clk)
        self.idle()


###############################################################################
# Transmit-side monitors
###############################################################################


@dataclass
class LineFrame:
    """One frame decoded from transmit pins.

    ``frame`` excludes preamble, SFD and FCS. ``raw`` holds every octet after
    the start delimiter (GMII: after ``TX_EN`` rises; XGMII: after ``/S/``).
    ``ifg`` counts idle octets since the previous frame ended, or ``None`` for
    the first frame.
    """

    raw: bytes
    frame: bytes
    fcs_ok: bool
    preamble_ok: bool
    error: bool
    start_cycle: int
    end_cycle: int
    ifg: int | None
    start_lane: int = 0
    terminated: bool = True


def _split_raw(raw: bytes, preamble: bytes) -> tuple[bytes, bool, bool]:
    preamble_ok = raw[: len(preamble)] == preamble
    body = raw[len(preamble) :] if preamble_ok else raw
    if len(body) < 4:
        return body, preamble_ok, False
    frame, fcs = body[:-4], body[-4:]
    return frame, preamble_ok, fcs == fcs_bytes(frame)


class GmiiMonitor:
    """Decode GMII transmit pins into ``LineFrame`` records.

    Samples on every rising edge with the clock enable high, before the DUT's
    registered ``TPD_G`` update, so each registered symbol is seen once.
    ``er_symbols`` records (cycle, tx_en, txd) for every ``TX_ER`` sample.
    """

    def __init__(self, dut, *, clk, prefix: str = "gmiiTx", clk_en=None):
        self.clk = clk
        self.en = getattr(dut, f"{prefix}En")
        self.er = getattr(dut, f"{prefix}Er")
        self.d = getattr(dut, f"{prefix}d")
        self.clk_en = clk_en
        self.frames: list[LineFrame] = []
        self.er_symbols: list[tuple[int, int, int]] = []
        self.cycle = 0
        self._raw: bytearray | None = None
        self._error = False
        self._start = 0
        self._idle = 0
        self._seen_frame = False
        self.task = cocotb.start_soon(self._run())

    def abort(self) -> None:
        """Discard a partially decoded frame, for example across a reset."""
        self._raw = None

    @property
    def frame_pending(self) -> bool:
        """Whether a start has been observed without a matching end."""
        return self._raw is not None

    async def _run(self) -> None:
        """Lifetime agent: decode GMII transmit symbols until the test ends."""
        while True:
            await RisingEdge(self.clk)
            if self.clk_en is not None and resolved_int(self.clk_en, 1) == 0:
                continue
            self.cycle += 1
            en, er, d = resolved_int(self.en), resolved_int(self.er), resolved_int(self.d)
            if er:
                self.er_symbols.append((self.cycle, en, d))
            if en:
                if self._raw is None:
                    self._raw = bytearray()
                    self._error = False
                    self._start = self.cycle
                self._raw.append(d)
                self._error |= bool(er)
            elif self._raw is not None:
                raw = bytes(self._raw)
                frame, preamble_ok, fcs_ok = _split_raw(raw, PREAMBLE + bytes([SFD]))
                self.frames.append(
                    LineFrame(
                        raw=raw,
                        frame=frame,
                        fcs_ok=fcs_ok,
                        preamble_ok=preamble_ok,
                        error=self._error,
                        start_cycle=self._start,
                        end_cycle=self.cycle - 1,
                        ifg=self._idle if self._seen_frame else None,
                    )
                )
                self._raw = None
                self._seen_frame = True
                self._idle = 1
            else:
                self._idle += 1


class XgmiiMonitor:
    """Decode XGMII transmit pins into ``LineFrame`` records.

    A frame starts at ``/S/`` in lane 0 or 4 and ends at ``/T/``. ``/E/``
    within a frame sets ``error``. A second ``/S/`` before ``/T/`` closes the
    open frame with ``terminated=False``. ``protocol_errors`` lists any other
    control character seen inside a frame or outside idle.
    """

    def __init__(self, dut, *, clk, data_name: str = "xgmiiTxd", ctrl_name: str = "xgmiiTxc"):
        self.clk = clk
        self.data = getattr(dut, data_name)
        self.ctrl = getattr(dut, ctrl_name)
        self.frames: list[LineFrame] = []
        self.protocol_errors: list[tuple[int, int, int]] = []
        self.cycle = 0
        self._raw: bytearray | None = None
        self._error = False
        self._start = 0
        self._lane = 0
        self._idle = 0
        self._seen_frame = False
        self.task = cocotb.start_soon(self._run())

    def _close(self, *, terminated: bool) -> None:
        raw = bytes(self._raw)
        frame, preamble_ok, fcs_ok = _split_raw(raw, b"\x55" * 6 + bytes([SFD]))
        self.frames.append(
            LineFrame(
                raw=raw,
                frame=frame,
                fcs_ok=fcs_ok,
                preamble_ok=preamble_ok,
                error=self._error,
                start_cycle=self._start,
                end_cycle=self.cycle,
                ifg=self._idle if self._seen_frame else None,
                start_lane=self._lane,
                terminated=terminated,
            )
        )
        self._raw = None
        self._seen_frame = True
        self._idle = 0

    def abort(self) -> None:
        """Discard a partially decoded frame, for example across a reset."""
        self._raw = None

    @property
    def frame_pending(self) -> bool:
        """Whether /S/ has been observed without /T/."""
        return self._raw is not None

    async def _run(self) -> None:
        """Lifetime agent: decode XGMII transmit words until the test ends."""
        while True:
            await RisingEdge(self.clk)
            self.cycle += 1
            data, ctrl = resolved_int(self.data, XGMII_IDLE_WORD), resolved_int(self.ctrl, 0xFF)
            for lane in range(8):
                byte, control = (data >> (8 * lane)) & 0xFF, (ctrl >> lane) & 1
                if control and byte == XGMII_START:
                    if self._raw is not None:
                        self._close(terminated=False)
                    if lane not in (0, 4):
                        self.protocol_errors.append((self.cycle, lane, byte))
                    self._raw = bytearray()
                    self._error = False
                    self._start = self.cycle
                    self._lane = lane
                elif self._raw is not None:
                    if not control:
                        self._raw.append(byte)
                    elif byte == XGMII_ERROR:
                        self._error = True
                    elif byte == XGMII_TERMINATE:
                        self._close(terminated=True)
                    else:
                        self.protocol_errors.append((self.cycle, lane, byte))
                        self._error = True
                elif control and byte == XGMII_IDLE:
                    self._idle += 1
                else:
                    self.protocol_errors.append((self.cycle, lane, byte))


###############################################################################
# Status pulses
###############################################################################


class StatusPulseCounter:
    """Count one-cycle status pulses on named signals.

    Samples on every rising edge before the registered update, so each pulse
    held for one clock is counted once. ``counts`` maps name to count and
    ``cycles`` maps name to the sample indexes at which the pulse was high.
    """

    def __init__(self, clk, signals: dict[str, object]):
        self.clk = clk
        self.signals = dict(signals)
        self.counts = {name: 0 for name in self.signals}
        self.cycles: dict[str, list[int]] = {name: [] for name in self.signals}
        self.cycle = 0
        self.task = cocotb.start_soon(self._run())

    async def _run(self) -> None:
        """Lifetime agent: count status pulses until the test ends."""
        while True:
            await RisingEdge(self.clk)
            self.cycle += 1
            for name, signal in self.signals.items():
                if resolved_int(signal):
                    self.counts[name] += 1
                    self.cycles[name].append(self.cycle)

    def snapshot(self) -> dict[str, int]:
        return dict(self.counts)

    def delta(self, before: dict[str, int]) -> dict[str, int]:
        return {name: self.counts[name] - before.get(name, 0) for name in self.counts}


###############################################################################
# Checksum models
###############################################################################


def build_ipv4_packet(
    *,
    src_ip: str,
    dst_ip: str,
    protocol: int,
    l4: bytes,
    identification: int = 0x1234,
    flags_fragment: int = 0x0000,
    ttl: int = 64,
    ip_checksum: int | None = None,
) -> bytes:
    """Minimal IPv4 header (IHL 5) plus ``l4``; checksum computed unless given."""
    header = bytes([0x45, 0x00]) + (20 + len(l4)).to_bytes(2, "big")
    header += identification.to_bytes(2, "big") + flags_fragment.to_bytes(2, "big")
    header += bytes([ttl, protocol]) + b"\x00\x00" + ipv4_to_bytes(src_ip) + ipv4_to_bytes(dst_ip)
    checksum = internet_checksum(header) if ip_checksum is None else ip_checksum
    return header[:10] + checksum.to_bytes(2, "big") + header[12:] + l4


def l4_pseudo_header(src_ip: str, dst_ip: str, protocol: int, length: int) -> bytes:
    return ipv4_to_bytes(src_ip) + ipv4_to_bytes(dst_ip) + bytes([0, protocol]) + length.to_bytes(2, "big")


def build_udp_segment(*, src_ip: str, dst_ip: str, src_port: int, dst_port: int, payload: bytes, checksum: int | None = None) -> bytes:
    header = src_port.to_bytes(2, "big") + dst_port.to_bytes(2, "big") + (8 + len(payload)).to_bytes(2, "big") + b"\x00\x00"
    if checksum is None:
        checksum = internet_checksum(l4_pseudo_header(src_ip, dst_ip, IP_PROTOCOL_UDP, 8 + len(payload)) + header + payload)
        # RFC 768: a computed zero is transmitted as all ones. An explicit
        # checksum=0 still requests the IPv4 UDP "checksum disabled" value.
        checksum = checksum or 0xFFFF
    return header[:6] + checksum.to_bytes(2, "big") + payload


def build_tcp_segment(
    *,
    src_ip: str,
    dst_ip: str,
    src_port: int,
    dst_port: int,
    payload: bytes,
    seq: int = 0x01020304,
    ack: int = 0,
    flags: int = 0x18,
    window: int = 0x2000,
    checksum: int | None = None,
) -> bytes:
    """TCP header with data offset 5 (no options) plus payload."""
    header = src_port.to_bytes(2, "big") + dst_port.to_bytes(2, "big")
    header += seq.to_bytes(4, "big") + ack.to_bytes(4, "big")
    header += bytes([0x50, flags]) + window.to_bytes(2, "big") + b"\x00\x00" + b"\x00\x00"
    if checksum is None:
        checksum = internet_checksum(l4_pseudo_header(src_ip, dst_ip, IP_PROTOCOL_TCP, len(header) + len(payload)) + header + payload)
    return header[:16] + checksum.to_bytes(2, "big") + header[18:] + payload


def build_ipv4_frame(*, dst_mac: int, src_mac: int, packet: bytes) -> bytes:
    return build_ethernet_frame(dst_mac=dst_mac, src_mac=src_mac, eth_type=ETH_TYPE_IPV4, payload=packet)


@dataclass(frozen=True)
class ChecksumCheck:
    """Receive-side verdict for one frame, mirroring the EMAC sideband bits."""

    iperr: int = 0
    tcperr: int = 0
    udperr: int = 0
    frag: int = 0


def verify_frame_checksums(frame: bytes) -> ChecksumCheck:
    """Standard IPv4/UDP/TCP verification of an untagged Ethernet frame.

    Only the IPv4 header checksum is meaningful for fragments; a zero UDP
    checksum means "not computed" and passes. The MAC's own policy for any
    deviation is asserted in the module test, not here.
    """
    if len(frame) < 34 or int.from_bytes(frame[12:14], "big") != ETH_TYPE_IPV4:
        return ChecksumCheck()
    ip = frame[14:]
    ihl = (ip[0] & 0x0F) * 4
    total = int.from_bytes(ip[2:4], "big")
    iperr = int(internet_checksum(ip[:ihl]) != 0)
    flags_fragment = int.from_bytes(ip[6:8], "big")
    frag = int((flags_fragment & 0x2000) != 0 or (flags_fragment & 0x1FFF) != 0)
    protocol = ip[9]
    l4 = ip[ihl:total]
    src_ip = ".".join(str(b) for b in ip[12:16])
    dst_ip = ".".join(str(b) for b in ip[16:20])
    tcperr = udperr = 0
    if not frag and protocol == IP_PROTOCOL_UDP and len(l4) >= 8 and l4[6:8] != b"\x00\x00":
        udperr = int(internet_checksum(l4_pseudo_header(src_ip, dst_ip, protocol, len(l4)) + l4) != 0)
    elif not frag and protocol == IP_PROTOCOL_TCP and len(l4) >= 20:
        tcperr = int(internet_checksum(l4_pseudo_header(src_ip, dst_ip, protocol, len(l4)) + l4) != 0)
    return ChecksumCheck(iperr=iperr, tcperr=tcperr, udperr=udperr, frag=frag)


###############################################################################
# Per-frame expectations
###############################################################################


@dataclass
class FrameExpectation:
    """What a MAC stage should do with one input frame.

    ``payload`` is the expected delivered bytes, or ``None`` when the frame
    must be dropped. ``status`` is the expected count of each named status
    pulse that this frame causes.
    """

    payload: bytes | None
    eofe: int = 0
    frag: int = 0
    iperr: int = 0
    tcperr: int = 0
    udperr: int = 0
    status: dict[str, int] = field(default_factory=dict)
    note: str = ""

    @property
    def delivered(self) -> bool:
        return self.payload is not None


def describe_case(seed: int, index: int, note: str = "") -> str:
    """Failure context: every random check reports its seed and frame index."""
    return f"seed={seed} frame={index}" + (f" ({note})" if note else "")
