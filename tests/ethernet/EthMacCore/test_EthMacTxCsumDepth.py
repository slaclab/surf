##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: EthMacTxCsum behind `EthMacTxCsumWrapper` (direct output, no RX
#   checker). `drop_err` (DROP_ERR_PKT_G=true, JUMBO_G=false) runs every
#   entrypoint. `pass_err` (DROP_ERR_PKT_G=false) runs the two entrypoints
#   whose expectations depend on that generic: the EOFE policy and the random
#   mix. `drop_err_jumbo` (JUMBO_G=true) runs the size boundary and the random
#   mix with jumbo lengths. The other entrypoints do not depend on these
#   generics, and the simulation is slow enough (~300 cycles/s) that repeating
#   them would exceed the runtime budget.
# - Stimulus: directed frames for the EOFE policy (inbound EOFE, IPv4 frames
#   too short to hold a header, single-beat frames), IPv4/UDP/TCP checksum
#   insertion across all eight `ipCsumEn`/`udpCsumEn`/`tcpCsumEn` settings
#   (odd payloads, zeroed and garbage checksums and lengths, sums that fold to
#   zero), IPv4 fragments, non-IPv4 and 802.1Q-tagged frames, and the frame
#   size boundary. A seeded random mix (`ETHMAC_CSUM_SEED`, default 0xC5A1)
#   of 200 frames runs in eight batches, one per enable setting, with random
#   source gaps and sink backpressure.
# - Checks: every delivered frame is compared byte-for-byte with a reference
#   model written from the RTL policy, together with TKEEP packing, SOF, FRAG
#   pass-through and EOFE. Inserted checksums are cross-checked with the
#   independent `verify_frame_checksums()`. Dropped frames must not appear and
#   the following frame must be intact. Behaviour that differs from what a
#   reader would expect is asserted explicitly and labelled "current baseline
#   behaviour" with its RTL location.
# - Timing: the output monitor and the source sample TVALID/TREADY on rising
#   edges, before the registered `TPD_G` update, so every accepted handshake is
#   seen exactly once. Enables are changed only while the DUT is drained,
#   because the RTL samples them as each frame leaves its cache FIFO. Every
#   wait is bounded by a cycle limit scaled to the frame size.
#   Oversize TX frames are not sent: the RTL truncates any frame whose byte
#   count reaches beyond the limit before its last beat (1521+ bytes, or
#   9025+ bytes with JUMBO_G), and that branch is in the known-issue set
#   (missing tLast in Fifo_Cache, following frame lost, Fifo_Trans
#   misaligned). The admitted maxima of 1520 and 9024 bytes are covered.
#   IPv4 options (IHL > 5) and RoCEv2 (`ROCEV2_EN_G`) are not covered.

from __future__ import annotations

from dataclasses import dataclass
import itertools
import random

import cocotb
import pytest
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import (
    cocotb_filtered_env,
    cocotb_test_filter,
    env_flag,
    env_int,
    hdl_parameters_from,
    run_surf_vhdl_test,
)
from tests.ethernet.EthMacCore.ethmac_line_models import (
    IP_PROTOCOL_TCP,
    FrameExpectation,
    build_ipv4_frame,
    build_ipv4_packet,
    build_tcp_segment,
    build_udp_segment,
    describe_case,
    l4_pseudo_header,
    random_payload,
    resolved_int,
    verify_frame_checksums,
)
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETH_TYPE_IPV4,
    ETHMAC_RTL_SOURCES,
    IP_PROTOCOL_UDP,
    EmacBeat,
    FlatEmacEndpoint,
    build_ethernet_frame,
    frame_beats_from_bytes,
    internet_checksum,
    keep_mask,
    payload_from_beats,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxCsumWrapper.vhd"
DEFAULT_SEED = 0xC5A1
DST_MAC = 0x02AABBCCDDEE
SRC_MAC = 0x021122334455
SRC_IP = "10.0.0.1"
DST_IP = "10.0.0.2"
IP_PROTOCOL_ICMP = 0x01
ETH_TYPE_VLAN = 0x8100
ETH_TYPE_ARP = 0x0806
ETH_TYPE_IPV6 = 0x86DD
IPV4_MF = 0x2000

# EthMacTxCsum.vhd:51 sets MAX_FRAME_SIZE_C to 1500 (9000 with JUMBO_G) and
# :382-385 compares the running count of bytes after the Ethernet header with
# it only on non-last beats. With full 16-byte beats the largest frame that
# never trips the oversize branch is therefore 1520 (9024) bytes.
MAX_ADMITTED_STD = 1520
MAX_ADMITTED_JUMBO = 9024
ALL_ENABLES = [dict(zip(("ip", "udp", "tcp"), bits)) for bits in itertools.product((1, 0), repeat=3)]


###############################################################################
# Frame construction
###############################################################################


def patch16(frame: bytes, offset: int, value: int) -> bytes:
    return frame[:offset] + value.to_bytes(2, "big") + frame[offset + 2 :]


def get16(frame: bytes, offset: int) -> int:
    return int.from_bytes(frame[offset : offset + 2], "big")


def udp_frame(
    payload: bytes,
    *,
    ip_csum: int | None = None,
    udp_csum: int | None = None,
    flags_fragment: int = 0,
    src_port: int = 0x1234,
    dst_port: int = 0x5678,
) -> bytes:
    segment = build_udp_segment(src_ip=SRC_IP, dst_ip=DST_IP, src_port=src_port, dst_port=dst_port, payload=payload, checksum=udp_csum)
    packet = build_ipv4_packet(src_ip=SRC_IP, dst_ip=DST_IP, protocol=IP_PROTOCOL_UDP, l4=segment, flags_fragment=flags_fragment, ip_checksum=ip_csum)
    return build_ipv4_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, packet=packet)


def tcp_frame(payload: bytes, *, ip_csum: int | None = None, tcp_csum: int | None = None, flags_fragment: int = 0) -> bytes:
    segment = build_tcp_segment(src_ip=SRC_IP, dst_ip=DST_IP, src_port=0x2345, dst_port=0x0050, payload=payload, checksum=tcp_csum)
    packet = build_ipv4_packet(src_ip=SRC_IP, dst_ip=DST_IP, protocol=IP_PROTOCOL_TCP, l4=segment, flags_fragment=flags_fragment, ip_checksum=ip_csum)
    return build_ipv4_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, packet=packet)


def icmp_frame(payload: bytes, *, ip_csum: int | None = None) -> bytes:
    packet = build_ipv4_packet(src_ip=SRC_IP, dst_ip=DST_IP, protocol=IP_PROTOCOL_ICMP, l4=b"\x08\x00\x00\x00" + payload, ip_checksum=ip_csum)
    return build_ipv4_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, packet=packet)


def zero_sum_payload(length: int, protocol: int) -> bytes:
    """Payload whose correct UDP/TCP checksum computes to 0x0000.

    The first payload word is chosen as the one's-complement of the remaining
    sum, so the folded sum becomes 0xFFFF and its complement 0x0000.
    """
    payload = bytearray(b"\x00\x00" + bytes((index * 7 + 3) & 0xFF for index in range(length - 2)))
    if protocol == IP_PROTOCOL_UDP:
        segment = build_udp_segment(src_ip=SRC_IP, dst_ip=DST_IP, src_port=0x1234, dst_port=0x5678, payload=bytes(payload), checksum=0)
        header_len = 8
    else:
        segment = build_tcp_segment(src_ip=SRC_IP, dst_ip=DST_IP, src_port=0x2345, dst_port=0x0050, payload=bytes(payload), checksum=0)
        header_len = 20
    adjust = internet_checksum(l4_pseudo_header(SRC_IP, DST_IP, protocol, len(segment)) + segment)
    payload[0:2] = adjust.to_bytes(2, "big")
    assert len(payload) == len(segment) - header_len
    return bytes(payload)


###############################################################################
# Reference model (from the EthMacTxCsum policy)
###############################################################################


def is_ipv4(frame: bytes) -> bool:
    # EthMacTxCsum.vhd:244-262 only marks IPv4 on a multi-beat frame whose
    # EtherType at bytes 12-13 is 0x0800; 802.1Q tags are not parsed.
    return len(frame) > 16 and get16(frame, 12) == ETH_TYPE_IPV4


def tx_short_ipv4(frame: bytes) -> bool:
    # A frame that ends on the second beat cannot hold an IPv4 header; the RTL
    # forces EOFE for it (EthMacTxCsum.vhd:279-283).
    return is_ipv4(frame) and len(frame) <= 32


def tx_model_frame(frame: bytes, *, frag: int, ip: int, udp: int, tcp: int) -> bytes:
    """Bytes EthMacTxCsum emits for an untruncated frame of 34+ bytes.

    - IPv4 length is derived from the AXI frame length (bytes after the
      Ethernet header), not from the inbound header, and is inserted together
      with the header checksum when `ipCsumEn` is set (:420-421, :447-455).
    - UDP length and checksum (0x0000 folded to 0xFFFF) are inserted when
      `udpCsumEn` is set and the FRAG sideband is clear (:468-481).
    - The TCP checksum is inserted when `tcpCsumEn` is set and FRAG is clear
      (:494-500). The FRAG sideband, not the IPv4 MF/offset field, gates both.
    """
    out = bytearray(frame)
    if not is_ipv4(frame):
        return bytes(out)
    assert len(frame) >= 34, "model requires a complete IPv4 header"
    ipv4_len = len(frame) - 14
    header = bytearray(frame[14:34])
    header[2:4] = ipv4_len.to_bytes(2, "big")
    header[10:12] = b"\x00\x00"
    if ip:
        out[16:18] = ipv4_len.to_bytes(2, "big")
        out[24:26] = internet_checksum(bytes(header)).to_bytes(2, "big")
    protocol = frame[23]
    prot_len = len(frame) - 34
    pseudo = bytes(header[12:20]) + bytes([0, protocol]) + prot_len.to_bytes(2, "big")
    if protocol == IP_PROTOCOL_UDP and not frag and udp:
        assert len(frame) >= 42
        segment = bytearray(frame[34:])
        segment[4:6] = prot_len.to_bytes(2, "big")
        segment[6:8] = b"\x00\x00"
        checksum = internet_checksum(pseudo + bytes(segment)) or 0xFFFF
        out[38:40] = prot_len.to_bytes(2, "big")
        out[40:42] = checksum.to_bytes(2, "big")
    if protocol == IP_PROTOCOL_TCP and not frag and tcp:
        assert len(frame) >= 54
        segment = bytearray(frame[34:])
        segment[16:18] = b"\x00\x00"
        out[50:52] = internet_checksum(pseudo + bytes(segment)).to_bytes(2, "big")
    return bytes(out)


def tx_expectation(frame: bytes, *, frag: int, eofe: int, enables: dict[str, int], drop: bool, note: str = "") -> FrameExpectation:
    eofe_out = 1 if tx_short_ipv4(frame) else eofe
    if drop and eofe_out:
        # EthMacTxCsum.vhd:437-440 suppresses every beat of an EOFE frame.
        return FrameExpectation(payload=None, note=note)
    assert not tx_short_ipv4(frame), "short IPv4 output bytes depend on stale header state"
    return FrameExpectation(payload=tx_model_frame(frame, frag=frag, **enables), eofe=eofe_out, frag=frag, note=note)


###############################################################################
# Bench
###############################################################################


@dataclass
class TxStimulus:
    frame: bytes
    frag: int = 0
    eofe: int = 0
    note: str = ""


class TxCsumBench:
    """Direct TxCsum source, backpressuring output monitor and scoreboard."""

    SOURCE_TIMEOUT_CYCLES = 4096

    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.ethClk
        self.drop = env_flag("DROP_ERR_PKT_G", default=True)
        self.jumbo = env_flag("JUMBO_G", default=False)
        self.max_admitted = MAX_ADMITTED_JUMBO if self.jumbo else MAX_ADMITTED_STD
        self.seed = env_int("ETHMAC_CSUM_SEED", default=DEFAULT_SEED)
        self.rng = random.Random(self.seed)
        self.source = FlatEmacEndpoint(dut, prefix="sAxis")
        self.sink = FlatEmacEndpoint(dut, prefix="mAxis")
        self.frames: list[list[EmacBeat]] = []
        self.ready_probability = 1.0
        self.source_gap_probability = 0.0
        self.enables = dict(ip=1, udp=1, tcp=1)
        self.monitor_task = None

    async def start(self, **enables: int) -> None:
        # Start the clock, hold reset, and seed every driven input before the
        # first edge; the output monitor then runs for the whole test.
        self.enables = dict(ip=1, udp=1, tcp=1, **enables)
        await setup_flat_emac_testbench(
            self.dut,
            source_prefix="sAxis",
            sink_prefix="mAxis",
            initial_values={
                "ipCsumEn": self.enables["ip"],
                "udpCsumEn": self.enables["udp"],
                "tcpCsumEn": self.enables["tcp"],
                "mAxisTReady": 1,
            },
        )
        self.monitor_task = cocotb.start_soon(self._monitor())
        self.dut._log.info(f"DROP_ERR_PKT_G={self.drop} JUMBO_G={self.jumbo} seed=0x{self.seed:X}")

    def set_enables(self, *, ip: int, udp: int, tcp: int) -> None:
        # Callers only change the enables while the DUT is drained.
        self.enables = dict(ip=ip, udp=udp, tcp=tcp)
        self.dut.ipCsumEn.value = ip
        self.dut.udpCsumEn.value = udp
        self.dut.tcpCsumEn.value = tcp

    async def _monitor(self) -> None:
        """Lifetime agent: record accepted output beats and drive random TREADY until the test ends."""
        beats: list[EmacBeat] = []
        while True:
            await RisingEdge(self.clk)
            # Values read at the edge are the ones the DUT registered on it.
            if resolved_int(self.dut.mAxisTValid) and resolved_int(self.dut.mAxisTReady):
                beat = self.sink.snapshot()
                beats.append(beat)
                if beat.last:
                    self.frames.append(beats)
                    beats = []
            ready = 1 if self.ready_probability >= 1.0 else int(self.rng.random() < self.ready_probability)
            self.dut.mAxisTReady.value = ready

    async def send(self, stimuli: list[TxStimulus]) -> None:
        # Hold each beat until an edge samples TREADY high; optional bubbles
        # drop TVALID between beats to exercise the input handshake.
        for stimulus in stimuli:
            for beat in frame_beats_from_bytes(stimulus.frame, eofe=stimulus.eofe, frag=stimulus.frag):
                if self.source_gap_probability and self.rng.random() < self.source_gap_probability:
                    self.source.set_idle()
                    for _ in range(self.rng.randint(1, 3)):
                        await RisingEdge(self.clk)
                self.source.drive(beat)
                for _ in range(self.SOURCE_TIMEOUT_CYCLES):
                    await RisingEdge(self.clk)
                    if resolved_int(self.dut.sAxisTReady):
                        break
                else:
                    raise AssertionError(f"TxCsum input stalled ({stimulus.note})")
            self.source.set_idle()

    async def wait_frames(self, count: int, *, timeout_cycles: int) -> None:
        for _ in range(timeout_cycles):
            if len(self.frames) >= count:
                return
            await RisingEdge(self.clk)
        raise AssertionError(f"Timed out waiting for {count} frames; saw {len(self.frames)}")

    async def run(self, stimuli: list[TxStimulus], *, drain_cycles: int = 32) -> list[tuple[int, TxStimulus, list[EmacBeat]]]:
        """Send stimuli, check the output against the model and return the delivered frames."""
        start = len(self.frames)
        expectations = [
            tx_expectation(s.frame, frag=s.frag, eofe=s.eofe, enables=self.enables, drop=self.drop, note=s.note)
            for s in stimuli
        ]
        delivered = [(index, s, e) for index, (s, e) in enumerate(zip(stimuli, expectations)) if e.delivered]
        beats_total = sum((len(s.frame) + 15) // 16 for s in stimuli)
        limit = 400 + int(beats_total * 4 / max(self.ready_probability, 0.25)) + 8 * len(stimuli)
        send_task = cocotb.start_soon(self.send(stimuli))
        await self.wait_frames(start + len(delivered), timeout_cycles=limit)
        await send_task
        # Drain: nothing beyond the expected frames may appear, including a
        # trailing frame that should have been dropped.
        last_beats = (len(stimuli[-1].frame) + 15) // 16
        for _ in range(drain_cycles + int(2 * last_beats / max(self.ready_probability, 0.25))):
            await RisingEdge(self.clk)
        observed = self.frames[start:]
        assert len(observed) == len(delivered), (
            f"expected {len(delivered)} frames, saw {len(observed)}; "
            f"dropped={[s.note for s, e in zip(stimuli, expectations) if not e.delivered]}"
        )
        results = []
        for (index, stimulus, expectation), beats in zip(delivered, observed):
            context = describe_case(self.seed, index, stimulus.note)
            check_frame_shape(beats, len(expectation.payload), context)
            payload = payload_from_beats(beats)
            assert payload == expectation.payload, f"{context}: payload mismatch at bytes {byte_diffs(payload, expectation.payload)}"
            assert beats[-1].eofe == expectation.eofe, f"{context}: EOFE {beats[-1].eofe} != {expectation.eofe}"
            assert beats[0].frag == expectation.frag, f"{context}: FRAG {beats[0].frag} != {expectation.frag}"
            results.append((index, stimulus, beats))
        return results


def check_frame_shape(beats: list[EmacBeat], length: int, context: str) -> None:
    # Contiguous TKEEP on every beat, SOF only on the first, EOFE only on the
    # last: TxCsum must not re-pack the frame.
    assert len(beats) == (length + 15) // 16, f"{context}: {len(beats)} beats for {length} bytes"
    for index, beat in enumerate(beats):
        last = index == len(beats) - 1
        expected_keep = keep_mask(length - 16 * index) if last else 0xFFFF
        assert beat.keep == expected_keep, f"{context}: beat {index} keep 0x{beat.keep:04X} != 0x{expected_keep:04X}"
        assert beat.last == int(last), f"{context}: beat {index} last={beat.last}"
        assert beat.sof == int(index == 0), f"{context}: beat {index} sof={beat.sof}"
        if not last:
            assert beat.eofe == 0, f"{context}: EOFE on non-final beat {index}"


def byte_diffs(observed: bytes, expected: bytes) -> list[int]:
    diffs = [index for index, (a, b) in enumerate(zip(observed, expected)) if a != b]
    if len(observed) != len(expected):
        diffs.append(min(len(observed), len(expected)))
    return diffs[:16]


def assert_standard_checksums(frame: bytes, *, frag: int, enables: dict[str, int], context: str) -> None:
    """Cross-check inserted checksums with the independent RFC verifier."""
    if not is_ipv4(frame):
        return
    verdict = verify_frame_checksums(frame)
    if enables["ip"]:
        assert verdict.iperr == 0, f"{context}: inserted IPv4 header checksum is wrong"
    # L4 verification needs the IPv4 total length to describe the frame.
    if get16(frame, 16) != len(frame) - 14 or frag or verdict.frag:
        return
    if frame[23] == IP_PROTOCOL_UDP and enables["udp"]:
        assert verdict.udperr == 0 and get16(frame, 40) != 0, f"{context}: inserted UDP checksum is wrong"
    if frame[23] == IP_PROTOCOL_TCP and enables["tcp"]:
        assert verdict.tcperr == 0, f"{context}: inserted TCP checksum is wrong"


###############################################################################
# Directed tests
###############################################################################


@cocotb.test()
async def tx_eofe_policy(dut):
    """Inbound EOFE and too-short IPv4 frames: dropped or passed with EOFE."""
    bench = TxCsumBench(dut)
    await bench.start()
    canary = udp_frame(b"canary-frame-after-error", ip_csum=0, udp_csum=0)
    short_ipv4 = udp_frame(b"x" * 20)[:30]
    stimuli = [
        TxStimulus(udp_frame(b"eofe-udp-frame-payload!", ip_csum=0, udp_csum=0), eofe=1, note="udp_eofe"),
        TxStimulus(canary, note="canary_1"),
        TxStimulus(build_ethernet_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, eth_type=0x88B5, payload=bytes(range(50))), eofe=1, note="nonip_eofe"),
        TxStimulus(canary, note="canary_2"),
        TxStimulus(build_ethernet_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, eth_type=0x88B5, payload=b"\x01\x02"), eofe=1, note="single_beat_eofe"),
        TxStimulus(canary, note="canary_3"),
        # 30 bytes with EtherType 0x0800 and no EOFE in: EOFE is forced.
        TxStimulus(short_ipv4, note="short_ipv4"),
        TxStimulus(canary, note="canary_4"),
        # The same length with another EtherType is not forced.
        TxStimulus(patch16(short_ipv4, 12, 0x88B5), note="short_nonip"),
        TxStimulus(canary, note="canary_5"),
    ]
    if bench.drop:
        # Every EOFE frame, including the forced short IPv4 frame, vanishes
        # and the canary after it is delivered intact.
        results = await bench.run([s for s in stimuli if s.note != "short_ipv4"])
        assert [s.note for _, s, _ in results] == ["canary_1", "canary_2", "canary_3", "canary_4", "short_nonip", "canary_5"]
        await bench.run([stimuli[6], stimuli[7]])
    else:
        results = await bench.run([s for s in stimuli if s.note != "short_ipv4"])
        notes = [s.note for _, s, _ in results]
        assert notes == ["udp_eofe", "canary_1", "nonip_eofe", "canary_2", "single_beat_eofe", "canary_3", "canary_4", "short_nonip", "canary_5"]
        # A passed EOFE frame still has its checksums repaired.
        eofe_frame = payload_from_beats(results[0][2])
        assert_standard_checksums(eofe_frame, frag=0, enables=bench.enables, context="udp_eofe")
        # The short IPv4 frame's IPv4 length/checksum lanes depend on header
        # bytes left from the previous frame (EthMacTxCsum.vhd:279-291 skips
        # the header capture), so only its other bytes and the forced EOFE
        # are checked.
        send_task = cocotb.start_soon(bench.send([stimuli[6]]))
        start = len(bench.frames)
        await bench.wait_frames(start + 1, timeout_cycles=400)
        await send_task
        beats = bench.frames[start]
        check_frame_shape(beats, len(short_ipv4), "short_ipv4")
        observed = payload_from_beats(beats)
        unchecked = {16, 17, 24, 25}
        assert [b for i, b in enumerate(observed) if i not in unchecked] == [b for i, b in enumerate(short_ipv4) if i not in unchecked]
        assert beats[-1].eofe == 1, "short IPv4 frame must leave with forced EOFE"
        await bench.run([stimuli[7]])


@cocotb.test()
async def tx_checksum_insertion(dut):
    """IPv4/UDP/TCP insertion for all eight enable settings."""
    bench = TxCsumBench(dut)
    await bench.start()
    udp_zero = zero_sum_payload(33, IP_PROTOCOL_UDP)
    tcp_zero = zero_sum_payload(41, IP_PROTOCOL_TCP)
    garbage_udp = patch16(patch16(udp_frame(bytes(range(64)), ip_csum=0xDEAD, udp_csum=0xBEEF), 16, 0x0BAD), 38, 0x0F0F)
    for enables in ALL_ENABLES:
        bench.set_enables(**enables)
        label = "ip{ip}_udp{udp}_tcp{tcp}".format(**enables)
        stimuli = [
            TxStimulus(udp_frame(b"odd-length-udp-payload-of-37-bytes!!!", ip_csum=0, udp_csum=0), note=f"{label}:udp_odd_zeroed"),
            TxStimulus(garbage_udp, note=f"{label}:udp_garbage_csum_len"),
            TxStimulus(udp_frame(b"", ip_csum=0, udp_csum=0), note=f"{label}:udp_empty"),
            TxStimulus(udp_frame(b"\x5a", ip_csum=0, udp_csum=0x1111), note=f"{label}:udp_one_byte"),
            TxStimulus(udp_frame(udp_zero, ip_csum=0, udp_csum=0x4321), note=f"{label}:udp_sum_zero"),
            TxStimulus(udp_frame(bytes(range(256)) * 2 + b"\x77", ip_csum=0x0001, udp_csum=0), note=f"{label}:udp_513"),
            TxStimulus(tcp_frame(bytes((7 * i) & 0xFF for i in range(101)), ip_csum=0, tcp_csum=0), note=f"{label}:tcp_odd_zeroed"),
            TxStimulus(tcp_frame(b"garbage-checksum-tcp", ip_csum=0xFFFF, tcp_csum=0xA5A5), note=f"{label}:tcp_garbage"),
            TxStimulus(tcp_frame(b"", ip_csum=0, tcp_csum=0x1234), note=f"{label}:tcp_header_only"),
            TxStimulus(tcp_frame(tcp_zero, ip_csum=0, tcp_csum=0x5555), note=f"{label}:tcp_sum_zero"),
            TxStimulus(icmp_frame(b"ping-payload", ip_csum=0x0000), note=f"{label}:icmp"),
        ]
        results = await bench.run(stimuli)
        for _, stimulus, beats in results:
            frame = payload_from_beats(beats)
            assert_standard_checksums(frame, frag=0, enables=enables, context=stimulus.note)
            name = stimulus.note.split(":")[1]
            if name == "udp_sum_zero":
                # A UDP checksum that computes to 0x0000 is sent as 0xFFFF.
                assert get16(frame, 40) == (0xFFFF if enables["udp"] else 0x4321), stimulus.note
            if name == "tcp_sum_zero":
                # TCP has no zero-checksum convention: 0x0000 is inserted.
                assert get16(frame, 50) == (0x0000 if enables["tcp"] else 0x5555), stimulus.note
            if name == "udp_garbage_csum_len":
                # Lengths come from the AXI frame length, not the header.
                assert get16(frame, 16) == (len(frame) - 14 if enables["ip"] else 0x0BAD), stimulus.note
                assert get16(frame, 38) == (len(frame) - 34 if enables["udp"] else 0x0F0F), stimulus.note
            if name == "icmp":
                assert frame[34:] == stimulus.frame[34:], stimulus.note


@cocotb.test()
async def tx_fragments(dut):
    """FRAG sideband suppresses L4 insertion; the IPv4 header is still repaired."""
    bench = TxCsumBench(dut)
    await bench.start()
    first_udp = patch16(udp_frame(b"first-fragment-of-a-longer-udp-datagram", ip_csum=0, udp_csum=0xBEEF, flags_fragment=IPV4_MF), 38, 0x05DC)
    later_udp = udp_frame(b"later-fragment-bytes-at-offset", ip_csum=0, udp_csum=0xCAFE, flags_fragment=0x00B9)
    first_tcp = tcp_frame(b"first-fragment-of-a-tcp-segment", ip_csum=0, tcp_csum=0xF00D, flags_fragment=IPV4_MF)
    header_only_mf = udp_frame(b"mf-in-header-but-no-sideband", ip_csum=0, udp_csum=0x0BAD, flags_fragment=IPV4_MF)
    sideband_only = udp_frame(b"sideband-frag-unfragmented-hdr", ip_csum=0, udp_csum=0x0BAD)
    stimuli = [
        TxStimulus(first_udp, frag=1, note="udp_first_fragment"),
        TxStimulus(later_udp, frag=1, note="udp_later_fragment"),
        TxStimulus(first_tcp, frag=1, note="tcp_first_fragment"),
        TxStimulus(header_only_mf, frag=0, note="header_mf_no_sideband"),
        TxStimulus(sideband_only, frag=1, note="sideband_frag_unfragmented"),
    ]
    results = {s.note: payload_from_beats(beats) for _, s, beats in await bench.run(stimuli)}
    for stimulus in stimuli:
        frame = results[stimulus.note]
        assert verify_frame_checksums(frame).iperr == 0, f"{stimulus.note}: IPv4 header not repaired"
    # Fragmented L4 headers/payload bytes are left exactly as supplied.
    assert results["udp_first_fragment"][34:] == first_udp[34:]
    assert results["udp_later_fragment"][34:] == later_udp[34:]
    assert results["tcp_first_fragment"][34:] == first_tcp[34:]
    # Current baseline behaviour: the TX checksum stage keys on the FRAG
    # sideband, not the IPv4 MF/offset field (EthMacTxCsum.vhd:250, :468,
    # :494). A header-only fragment still gets a UDP checksum over this
    # fragment's bytes, and a sideband-only FRAG suppresses insertion.
    assert get16(results["header_mf_no_sideband"], 40) == get16(tx_model_frame(header_only_mf, frag=0, ip=1, udp=1, tcp=1), 40)
    assert get16(results["header_mf_no_sideband"], 40) != 0x0BAD
    assert get16(results["sideband_frag_unfragmented"], 40) == 0x0BAD
    assert verify_frame_checksums(results["sideband_frag_unfragmented"]).udperr == 1


@cocotb.test()
async def tx_non_ipv4_untouched(dut):
    """Non-IPv4 and 802.1Q-tagged frames leave unchanged."""
    bench = TxCsumBench(dut)
    await bench.start()
    lookalike = bytearray(udp_frame(bytes(range(40)), ip_csum=0, udp_csum=0))
    arp = patch16(bytes(lookalike), 12, ETH_TYPE_ARP)
    ipv6 = patch16(bytes(lookalike), 12, ETH_TYPE_IPV6)
    inner = udp_frame(b"vlan-tagged-udp-with-zero-checksums", ip_csum=0, udp_csum=0)
    vlan = inner[:12] + ETH_TYPE_VLAN.to_bytes(2, "big") + (0x0064).to_bytes(2, "big") + inner[12:]
    stimuli = [
        TxStimulus(arp, note="arp_lookalike"),
        TxStimulus(ipv6, note="ipv6_lookalike"),
        TxStimulus(vlan, note="vlan_ipv4_udp"),
        TxStimulus(bytes(range(14)), note="header_only_frame"),
    ]
    results = await bench.run(stimuli)
    for _, stimulus, beats in results:
        assert payload_from_beats(beats) == stimulus.frame, stimulus.note
    # Current baseline behaviour: 802.1Q tags are not parsed, so the inner
    # IPv4/UDP checksums of a tagged frame stay zero (EthMacTxCsum.vhd:259).
    tagged = payload_from_beats(results[2][2])
    assert get16(tagged, 28) == 0 and get16(tagged, 44) == 0


@cocotb.test()
async def tx_size_boundary(dut):
    """Frames at the 1500-byte payload boundary, the admitted maximum and jumbo sizes."""
    bench = TxCsumBench(dut)
    await bench.start()
    sizes = [("udp", 1514), ("tcp", 1514), ("udp", 1515), ("tcp", 1515)]
    sizes += [("udp", MAX_ADMITTED_STD - 1), ("tcp", MAX_ADMITTED_STD - 1), ("udp", MAX_ADMITTED_STD), ("tcp", MAX_ADMITTED_STD)]
    if bench.jumbo:
        # Jumbo lengths are slow to simulate, so each appears once.
        sizes += [("udp", MAX_ADMITTED_STD + 1), ("tcp", 4097), ("udp", 9014), ("udp", 9015), ("tcp", MAX_ADMITTED_JUMBO)]
    assert max(size for _, size in sizes) <= bench.max_admitted, "oversize TX frames belong to the known-issue set"
    stimuli = []
    for kind, size in sizes:
        if kind == "udp":
            frame = udp_frame(random_payload(bench.rng, size - 42), ip_csum=0, udp_csum=0)
        else:
            frame = tcp_frame(random_payload(bench.rng, size - 54), ip_csum=0, tcp_csum=0)
        stimuli.append(TxStimulus(frame, note=f"{kind}_{size}"))
    stimuli.append(TxStimulus(build_ethernet_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, eth_type=0x88B5, payload=bytes(bench.max_admitted - 14)), note="nonip_max"))
    stimuli.append(TxStimulus(udp_frame(b"canary-after-boundary", ip_csum=0, udp_csum=0), note="canary"))
    results = await bench.run(stimuli)
    for _, stimulus, beats in results:
        frame = payload_from_beats(beats)
        assert_standard_checksums(frame, frag=0, enables=bench.enables, context=stimulus.note)
    # Current baseline behaviour: the 1520-byte frame is admitted and its
    # inserted IPv4 total length is 1506, above the 1500-byte MTU
    # (EthMacTxCsum.vhd:385 checks the limit only on non-last beats).
    by_note = {s.note: payload_from_beats(beats) for _, s, beats in results}
    assert get16(by_note[f"udp_{MAX_ADMITTED_STD}"], 16) == MAX_ADMITTED_STD - 14


###############################################################################
# Random scoreboard
###############################################################################


def random_tx_stimulus(rng: random.Random, max_len: int, jumbo: bool) -> TxStimulus:
    """One random frame drawn from the mix described in the methodology."""
    kind = rng.choices(
        ["udp", "tcp", "icmp", "nonip", "vlan", "udp_frag", "tcp_frag", "mf_no_sideband"],
        weights=[34, 30, 8, 10, 5, 5, 4, 4],
    )[0]
    min_len = {"udp": 42, "udp_frag": 42, "mf_no_sideband": 42, "tcp": 54, "tcp_frag": 54, "icmp": 42, "nonip": 14, "vlan": 46}[kind]
    size_class = rng.choices(["small", "medium", "boundary", "jumbo"], weights=[60, 31, 7, 2 if jumbo else 0])[0]
    if size_class == "small":
        length = rng.randint(min_len, 96)
    elif size_class == "medium":
        length = rng.randint(97, 400)
    elif size_class == "boundary":
        length = rng.randint(MAX_ADMITTED_STD - 24, MAX_ADMITTED_STD)
    else:
        length = rng.randint(MAX_ADMITTED_STD + 1, max_len)
    length = max(min(length, max_len), min_len)

    def field(width_bits: int = 16) -> int | None:
        # Inbound checksum: correct (None), zero, or garbage.
        choice = rng.choices(["correct", "zero", "garbage"], weights=[40, 30, 30])[0]
        return None if choice == "correct" else 0 if choice == "zero" else rng.getrandbits(width_bits)

    frag = 0
    flags_fragment = 0
    if kind in ("udp_frag", "tcp_frag"):
        frag = 1
        flags_fragment = rng.choice([IPV4_MF, IPV4_MF | rng.randint(1, 0x1FFF), rng.randint(1, 0x1FFF)])
    elif kind == "mf_no_sideband":
        flags_fragment = IPV4_MF
    if kind in ("udp", "udp_frag", "mf_no_sideband"):
        frame = udp_frame(random_payload(rng, length - 42), ip_csum=field(), udp_csum=field(), flags_fragment=flags_fragment)
        if rng.random() < 0.15:
            frame = patch16(frame, 38, rng.getrandbits(16))
    elif kind in ("tcp", "tcp_frag"):
        frame = tcp_frame(random_payload(rng, length - 54), ip_csum=field(), tcp_csum=field(), flags_fragment=flags_fragment)
    elif kind == "icmp":
        frame = icmp_frame(random_payload(rng, length - 38), ip_csum=field())
    elif kind == "nonip":
        frame = build_ethernet_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, eth_type=rng.choice([0x88B5, ETH_TYPE_ARP, ETH_TYPE_IPV6]), payload=random_payload(rng, length - 14))
    else:
        inner = udp_frame(random_payload(rng, length - 46), ip_csum=field(), udp_csum=field())
        frame = inner[:12] + ETH_TYPE_VLAN.to_bytes(2, "big") + rng.getrandbits(16).to_bytes(2, "big") + inner[12:]
    if is_ipv4(frame) and rng.random() < 0.15:
        frame = patch16(frame, 16, rng.getrandbits(16))
    eofe = int(rng.random() < 0.08)
    return TxStimulus(frame, frag=frag, eofe=eofe, note=f"{kind} len={len(frame)} frag={frag} eofe={eofe}")


@cocotb.test()
async def tx_random_scoreboard(dut):
    """Seeded random mix in eight enable batches with gaps and backpressure."""
    bench = TxCsumBench(dut)
    await bench.start()
    frames_per_batch = 25
    index = 0
    for batch, enables in enumerate(bench.rng.sample(ALL_ENABLES, len(ALL_ENABLES))):
        bench.set_enables(**enables)
        bench.ready_probability = bench.rng.choice([1.0, 0.8, 0.5])
        bench.source_gap_probability = bench.rng.choice([0.0, 0.1, 0.3])
        dut._log.info(
            f"batch {batch}: enables={enables} ready={bench.ready_probability} gaps={bench.source_gap_probability}"
        )
        stimuli = []
        for _ in range(frames_per_batch):
            stimulus = random_tx_stimulus(bench.rng, bench.max_admitted, bench.jumbo)
            stimulus.note = f"batch={batch} {stimulus.note}"
            stimuli.append(stimulus)
            index += 1
        results = await bench.run(stimuli)
        # The model has already matched every byte; also confirm with the
        # independent verifier that the inserted fields are RFC-correct.
        for frame_index, stimulus, beats in results:
            context = describe_case(bench.seed, batch * frames_per_batch + frame_index, stimulus.note)
            assert_standard_checksums(payload_from_beats(beats), frag=stimulus.frag, enables=enables, context=context)
        bench.ready_probability = 1.0
        bench.source_gap_probability = 0.0


###############################################################################
# Pytest wrapper
###############################################################################


ALL_TESTS = (
    "tx_eofe_policy",
    "tx_checksum_insertion",
    "tx_fragments",
    "tx_non_ipv4_untouched",
    "tx_size_boundary",
    "tx_random_scoreboard",
)
PARAMETER_SWEEP = [
    pytest.param({"DROP_ERR_PKT_G": "true", "JUMBO_G": "false"}, ALL_TESTS, id="drop_err"),
    pytest.param({"DROP_ERR_PKT_G": "false", "JUMBO_G": "false"}, ("tx_eofe_policy", "tx_random_scoreboard"), id="pass_err"),
    pytest.param({"DROP_ERR_PKT_G": "true", "JUMBO_G": "true"}, ("tx_size_boundary", "tx_random_scoreboard"), id="drop_err_jumbo"),
]


@pytest.mark.parametrize(("parameters", "tests"), PARAMETER_SWEEP)
def test_EthMacTxCsumDepth(parameters, tests):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxcsumwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=cocotb_filtered_env(parameters, cocotb_test_filter(*tests)),
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
