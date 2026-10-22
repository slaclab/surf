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
# - Sweep: EthMacRxCsum behind `EthMacRxCsumWrapper` with `JUMBO_G` false and
#   true. Every cocotb entrypoint runs in both cases; the size expectations
#   follow `JUMBO_G`.
# - Stimulus: directed IPv4/UDP/TCP/ICMP frames with good and bad header and
#   transport checksums under all eight `ipCsumEn`/`udpCsumEn`/`tcpCsumEn`
#   settings (zero UDP checksum, sums that fold to zero, UDP/IPv4 length
#   mismatch), fragments (MF, nonzero offset, DF only), non-IPv4 and
#   802.1Q-tagged frames, inbound EOFE, Ethernet padding, frame sizes around
#   the 1500/1520-byte (9000/9024 with JUMBO_G) limit including oversize
#   frames followed by a normal frame, one-byte last beats, and frames two or
#   three idle cycles apart. A seeded random mix (`ETHMAC_CSUM_SEED`, default
#   0xC5A2) of 320 wire-sized frames runs in eight enable batches with random
#   TVALID gaps from the third beat on and random interframe gaps.
#   Back-to-back (0/1 idle cycle) frames are mixed in only while `ipCsumEn` is
#   low, and no gap is placed after the SOF beat (known issues 11 and 12).
# - Checks: every output frame is compared with a reference model: delivered
#   bytes (truncation included), TKEEP, SOF, FRAG on the first beat, and
#   IPERR/TCPERR/UDPERR on the last beat. EOFE is expected to be the OR of the
#   inbound EOFE, the oversize cut and every enabled check's error. For
#   standard traffic the model's verdicts are cross-checked with the
#   independent `verify_frame_checksums()`. RTL policy that differs from RFC
#   practice but is not treated as a defect is asserted explicitly and
#   labelled "current baseline behaviour" with its RTL location.
# - Known issues: with `RUN_KNOWN_ISSUE_TESTS=1` these entrypoints assert the
#   correct behaviour and fail on the current RTL; promote each to the default
#   run with its fix.
#   11. `rx_back_to_back_known_issue_test`: getEthMacCsum (EthMacPkg.vhd)
#      compares a delayed ipCsum with hdrCsum read live from r.ipv4Hdr, which
#      IDLE_S/IPV4_HDR0_S overwrite for the next frame within 0-1 idle cycles
#      (0 after the MOVE_S oversize cut, which enters BLOWOFF_S without
#      setting pipeFlush).
#   12. `rx_frag_after_sof_gap_known_issue_test`: a TVALID gap after SOF while
#      pipeFlush still advances the pipeline for the previous frame puts a
#      bubble behind SOF; the SOF/FRAG update at the pipeline exit reads the
#      bubble's fragDet.
# - Timing: EthMacRxCsum has no backpressure, so the source presents one beat
#   per accepting edge and the monitor samples TVALID on rising edges, before
#   the registered `TPD_G` update. Enables change only while the pipeline is
#   drained, because the RTL samples them as the last beat leaves. Every wait
#   is bounded by a cycle limit scaled to the frame size.
#   Not covered: runt frames of 17..59 bytes. The RX importers DO deliver
#   good-FCS runts without padding (see rx_runts); checksum handling and
#   subsequent-frame recovery on this exposed malformed-input path remain
#   unverified. Also excluded: IPv4 options (IHL > 5), RoCEv2 and async reset.

from __future__ import annotations

from dataclasses import dataclass
import itertools
import os
import random

import cocotb
import pytest
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import (
    env_flag,
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.ethernet.EthMacCore.ethmac_line_models import (
    IP_PROTOCOL_TCP,
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


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxCsumWrapper.vhd"
DEFAULT_SEED = 0xC5A2
KNOWN_ISSUE_SKIP = os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1"
DST_MAC = 0x02AABBCCDDEE
SRC_MAC = 0x021122334455
SRC_IP = "192.168.10.1"
DST_IP = "192.168.10.2"
IP_PROTOCOL_ICMP = 0x01
ETH_TYPE_VLAN = 0x8100
ETH_TYPE_ARP = 0x0806
IPV4_MF = 0x2000
IPV4_DF = 0x4000
MIN_WIRE_FRAME = 60

# EthMacRxCsum.vhd sets MAX_FRAME_SIZE_C to 1500 (9000 with JUMBO_G). MOVE_S
# forces a non-last beat to be last when byteCnt exceeds that limit, so with
# full 16-byte beats a 1520 (9024) byte frame is the largest delivered intact;
# longer frames are cut after that many bytes.
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


def pad(frame: bytes, fill: int = 0) -> bytes:
    return frame + bytes([fill]) * max(0, MIN_WIRE_FRAME - len(frame))


def udp_frame(payload: bytes, *, ip_csum: int | None = None, udp_csum: int | None = None, flags_fragment: int = 0) -> bytes:
    segment = build_udp_segment(src_ip=SRC_IP, dst_ip=DST_IP, src_port=0x1234, dst_port=0x5678, payload=payload, checksum=udp_csum)
    packet = build_ipv4_packet(src_ip=SRC_IP, dst_ip=DST_IP, protocol=IP_PROTOCOL_UDP, l4=segment, flags_fragment=flags_fragment, ip_checksum=ip_csum)
    return build_ipv4_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, packet=packet)


def tcp_frame(payload: bytes, *, ip_csum: int | None = None, tcp_csum: int | None = None, flags_fragment: int = 0) -> bytes:
    segment = build_tcp_segment(src_ip=SRC_IP, dst_ip=DST_IP, src_port=0x2345, dst_port=0x0050, payload=payload, checksum=tcp_csum)
    packet = build_ipv4_packet(src_ip=SRC_IP, dst_ip=DST_IP, protocol=IP_PROTOCOL_TCP, l4=segment, flags_fragment=flags_fragment, ip_checksum=ip_csum)
    return build_ipv4_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, packet=packet)


def icmp_frame(payload: bytes, *, ip_csum: int | None = None, flags_fragment: int = 0) -> bytes:
    packet = build_ipv4_packet(
        src_ip=SRC_IP, dst_ip=DST_IP, protocol=IP_PROTOCOL_ICMP, l4=b"\x08\x00\x00\x00" + payload, flags_fragment=flags_fragment, ip_checksum=ip_csum
    )
    return build_ipv4_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, packet=packet)


def other_frame(length: int, *, eth_type: int = 0x88B5, fill: int | None = None, rng: random.Random | None = None) -> bytes:
    body = random_payload(rng, length - 14) if rng is not None else bytes([fill or 0]) * (length - 14)
    return build_ethernet_frame(dst_mac=DST_MAC, src_mac=SRC_MAC, eth_type=eth_type, payload=body)


def zero_sum_payload(length: int, protocol: int) -> bytes:
    """Payload whose correct UDP/TCP checksum computes to 0x0000."""
    payload = bytearray(b"\x00\x00" + bytes((index * 5 + 1) & 0xFF for index in range(length - 2)))
    if protocol == IP_PROTOCOL_UDP:
        segment = build_udp_segment(src_ip=SRC_IP, dst_ip=DST_IP, src_port=0x1234, dst_port=0x5678, payload=bytes(payload), checksum=0)
    else:
        segment = build_tcp_segment(src_ip=SRC_IP, dst_ip=DST_IP, src_port=0x2345, dst_port=0x0050, payload=bytes(payload), checksum=0)
    payload[0:2] = internet_checksum(l4_pseudo_header(SRC_IP, DST_IP, protocol, len(segment)) + segment).to_bytes(2, "big")
    return bytes(payload)


###############################################################################
# Reference model (from the EthMacRxCsum policy)
###############################################################################


@dataclass
class RxVerdict:
    payload: bytes
    eofe: int
    frag: int
    iperr: int
    tcperr: int
    udperr: int
    truncated: bool


def rx_truncation(length: int, max_size: int) -> int | None:
    """Delivered length when the oversize check fires, else None.

    EthMacRxCsum.vhd initializes byteCnt in IPV4_HDR1_S to 18 + bytes of
    beat 2 (zero-based), then increments it on each MOVE_S beat. A non-last
    beat that takes it past MAX_FRAME_SIZE_C is forced to be the last one.
    """
    beats = (length + 15) // 16
    count = 18 + min(16, max(0, length - 32))
    for beat in range(3, beats - 1):
        count += 16
        if count > max_size:
            return 16 * (beat + 1)
    return None


def rx_udp_checksum(frame: bytes) -> int:
    """UDP checksum as EthMacRxCsum computes it (GetEthMacCsum, EthMacPkg.vhd).

    Pseudo-header length is the UDP length field; every byte after offset 34
    up to the end of the frame is summed, including Ethernet padding.
    """
    segment = bytearray(frame[34:])
    segment[6:8] = b"\x00\x00"
    pseudo = frame[26:34] + bytes([0, IP_PROTOCOL_UDP]) + frame[38:40]
    return internet_checksum(pseudo + bytes(segment)) or 0xFFFF


def rx_tcp_checksum(frame: bytes) -> int:
    """TCP checksum as EthMacRxCsum computes it: length is IPv4 total - 20."""
    segment = bytearray(frame[34:])
    segment[16:18] = b"\x00\x00"
    tcp_len = (get16(frame, 16) - 20) & 0xFFFF
    pseudo = frame[26:34] + bytes([0, IP_PROTOCOL_TCP]) + tcp_len.to_bytes(2, "big")
    return internet_checksum(pseudo + bytes(segment))


def rx_model(frame: bytes, *, eofe: int, enables: dict[str, int], max_size: int) -> RxVerdict:
    """Expected EthMacRxCsum output for a frame of 49+ bytes.

    EOFE is the OR of the inbound EOFE, the oversize cut and every enabled
    check's error.
    """
    assert len(frame) >= 49, "model excludes runt frames"
    cut = rx_truncation(len(frame), max_size)
    data = frame if cut is None else frame[:cut]
    eofe_in = eofe if cut is None else 1
    # FRAG comes from bytes 20-21 for every multi-beat frame, IPv4 or not
    # (the IPV4_HDR0_S fragmentation check has no EtherType qualifier).
    frag = int(bool((data[20] & 0x3F) or data[21]))
    iperr = tcperr = udperr = 0
    if get16(data, 12) == ETH_TYPE_IPV4:
        header = bytearray(data[14:34])
        inbound = get16(header, 10)
        header[10:12] = b"\x00\x00"
        protocol = data[23]
        if enables["ip"]:
            iperr = int(internet_checksum(bytes(header)) != inbound)
        if protocol == IP_PROTOCOL_UDP and enables["udp"] and not frag:
            inbound = get16(data, 40)
            udperr = int(inbound != 0 and inbound != rx_udp_checksum(data))
            if get16(data, 16) != (get16(data, 38) + 20) & 0xFFFF:
                udperr = 1
        if protocol == IP_PROTOCOL_TCP and enables["tcp"] and not frag:
            tcperr = int(get16(data, 50) != rx_tcp_checksum(data))
    eofe_out = int(bool(eofe_in or iperr or udperr or tcperr))
    return RxVerdict(
        payload=data,
        eofe=eofe_out,
        frag=frag,
        iperr=iperr,
        tcperr=tcperr,
        udperr=udperr,
        truncated=cut is not None,
    )


def rfc_standard(frame: bytes, eofe: int) -> bool:
    """True when the RTL's policy should coincide with RFC verification."""
    if eofe or get16(frame, 12) != ETH_TYPE_IPV4:
        return False
    total = get16(frame, 16)
    if total + 14 > len(frame) or any(frame[14 + total :]):
        return False
    if frame[23] == IP_PROTOCOL_UDP and get16(frame, 38) != total - 20:
        return False
    return True


###############################################################################
# Bench
###############################################################################


@dataclass
class RxStimulus:
    frame: bytes
    eofe: int = 0
    frag_in: int = 0
    gap_after: int = 4
    gap_after_sof: int = 0
    note: str = ""


class RxCsumBench:
    """RxCsum source with TVALID gaps, output monitor and scoreboard."""

    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.ethClk
        self.jumbo = env_flag("JUMBO_G", default=False)
        self.max_size = 9000 if self.jumbo else 1500
        self.max_admitted = MAX_ADMITTED_JUMBO if self.jumbo else MAX_ADMITTED_STD
        self.seed = env_int("ETHMAC_CSUM_SEED", default=DEFAULT_SEED)
        self.rng = random.Random(self.seed)
        self.source = FlatEmacEndpoint(dut, prefix="sAxis")
        self.sink = FlatEmacEndpoint(dut, prefix="mAxis")
        self.frames: list[list[EmacBeat]] = []
        self.stray_beats = 0
        self.mid_gap_probability = 0.0
        self.enables = dict(ip=1, udp=1, tcp=1)
        self.monitor_task = None

    async def start(self) -> None:
        # Start the clock, hold reset with every input defined, then run the
        # output monitor for the rest of the test.
        await setup_flat_emac_testbench(
            self.dut,
            source_prefix="sAxis",
            sink_prefix="mAxis",
            initial_values={"ipCsumEn": 1, "udpCsumEn": 1, "tcpCsumEn": 1, "mAxisTReady": 1},
        )
        self.monitor_task = cocotb.start_soon(self._monitor())
        self.dut._log.info(f"JUMBO_G={self.jumbo} seed=0x{self.seed:X}")

    def set_enables(self, *, ip: int, udp: int, tcp: int) -> None:
        # Callers only change the enables while the pipeline is drained.
        self.enables = dict(ip=ip, udp=udp, tcp=tcp)
        self.dut.ipCsumEn.value = ip
        self.dut.udpCsumEn.value = udp
        self.dut.tcpCsumEn.value = tcp

    async def _monitor(self) -> None:
        """Lifetime agent: record output beats into frames until the test ends."""
        beats: list[EmacBeat] = []
        while True:
            await RisingEdge(self.clk)
            # RxCsum has no TREADY: every visible beat is a transfer.
            if resolved_int(self.dut.mAxisTValid):
                beat = self.sink.snapshot()
                beats.append(beat)
                if beat.last:
                    self.frames.append(beats)
                    beats = []

    async def send(self, stimuli: list[RxStimulus]) -> None:
        # One beat per accepting edge, optional mid-frame bubbles, and the
        # requested idle cycles after each frame (0 = back-to-back).
        for stimulus in stimuli:
            for index, beat in enumerate(frame_beats_from_bytes(stimulus.frame, eofe=stimulus.eofe, frag=stimulus.frag_in)):
                if index == 1 and stimulus.gap_after_sof:
                    gap = stimulus.gap_after_sof
                elif index >= 2 and self.mid_gap_probability and self.rng.random() < self.mid_gap_probability:
                    gap = self.rng.randint(1, 3)
                else:
                    gap = 0
                if gap:
                    self.source.set_idle()
                    for _ in range(gap):
                        await RisingEdge(self.clk)
                self.source.drive(beat)
                await RisingEdge(self.clk)
                assert resolved_int(self.dut.sAxisTReady) == 1
            self.source.set_idle()
            for _ in range(stimulus.gap_after):
                await RisingEdge(self.clk)

    async def run(self, stimuli: list[RxStimulus]) -> list[tuple[int, RxStimulus, list[EmacBeat], RxVerdict]]:
        """Send stimuli and check every output frame against the model."""
        start = len(self.frames)
        verdicts = [rx_model(s.frame, eofe=s.eofe, enables=self.enables, max_size=self.max_size) for s in stimuli]
        beats_total = sum((len(s.frame) + 15) // 16 + s.gap_after for s in stimuli)
        send_task = cocotb.start_soon(self.send(stimuli))
        for _ in range(200 + 3 * beats_total):
            if len(self.frames) >= start + len(stimuli):
                break
            await RisingEdge(self.clk)
        else:
            raise AssertionError(f"Timed out: {len(self.frames) - start} of {len(stimuli)} frames")
        await send_task
        # Drain: no extra frame may appear (e.g. the tail of a cut frame).
        for _ in range(32):
            await RisingEdge(self.clk)
        observed = self.frames[start:]
        assert len(observed) == len(stimuli), f"expected {len(stimuli)} frames, saw {len(observed)}"
        results = []
        for index, (stimulus, verdict, beats) in enumerate(zip(stimuli, verdicts, observed)):
            previous = stimuli[index - 1].note if index else "none"
            context = describe_case(self.seed, index, f"{stimulus.note}; previous: {previous}; mid-frame gaps={self.mid_gap_probability}")
            check_rx_frame(beats, verdict, context)
            results.append((index, stimulus, beats, verdict))
        return results


def check_rx_frame(beats: list[EmacBeat], verdict: RxVerdict, context: str) -> None:
    length = len(verdict.payload)
    assert len(beats) == (length + 15) // 16, f"{context}: {len(beats)} beats for {length} bytes"
    payload = payload_from_beats(beats)
    assert payload == verdict.payload, f"{context}: payload differs"
    for index, beat in enumerate(beats):
        last = index == len(beats) - 1
        expected_keep = keep_mask(length - 16 * index) if last else 0xFFFF
        assert beat.keep == expected_keep, f"{context}: beat {index} keep 0x{beat.keep:04X}"
        assert beat.last == int(last), f"{context}: beat {index} last={beat.last}"
        alias = last and index and beat.keep == 0x0001
        # With one valid byte, the wrapper's SOF/FRAG view of the last beat is
        # the same lane-0 tUser bits as IPERR/EOFE.
        assert beat.sof == (verdict.iperr if alias else int(index == 0)), f"{context}: beat {index} sof={beat.sof}"
        if index:
            assert beat.frag == (verdict.eofe if alias else 0), f"{context}: FRAG on beat {index}"
        if not last:
            assert (beat.eofe, beat.iperr, beat.tcperr, beat.udperr) == (0, 0, 0, 0), f"{context}: status on beat {index}"
    observed = (beats[0].frag, beats[-1].iperr, beats[-1].tcperr, beats[-1].udperr)
    expected = (verdict.frag, verdict.iperr, verdict.tcperr, verdict.udperr)
    assert observed == expected, f"{context}: (frag, iperr, tcperr, udperr) {observed} != {expected}"
    assert beats[-1].eofe == verdict.eofe, f"{context}: EOFE {beats[-1].eofe} != {verdict.eofe}"


def status(beats: list[EmacBeat]) -> dict[str, int]:
    return dict(frag=beats[0].frag, eofe=beats[-1].eofe, iperr=beats[-1].iperr, tcperr=beats[-1].tcperr, udperr=beats[-1].udperr)


###############################################################################
# Directed tests
###############################################################################


def verdict_frames() -> dict[str, bytes]:
    udp_payload = b"odd-length-udp-payload-37-bytes-long!"
    good_udp = udp_frame(udp_payload)
    udp_zero = zero_sum_payload(33, IP_PROTOCOL_UDP)
    tcp_zero = zero_sum_payload(41, IP_PROTOCOL_TCP)
    # UDP length two bytes short of the IPv4 length, with the checksum the RTL
    # computes for it, so only the length cross-check can flag it.
    mismatch = patch16(good_udp, 38, get16(good_udp, 38) - 2)
    mismatch = patch16(mismatch, 40, rx_udp_checksum(mismatch))
    return {
        "udp_good": good_udp,
        "udp_bad_ip": udp_frame(udp_payload, ip_csum=0x1111),
        "udp_bad": udp_frame(udp_payload, udp_csum=0x2222),
        "udp_bad_ip_bad_udp": udp_frame(udp_payload, ip_csum=0x1111, udp_csum=0x2222),
        "udp_no_checksum": udp_frame(b"zero-means-no-checksum-computed", udp_csum=0),
        "udp_sum_zero_ffff": udp_frame(udp_zero, udp_csum=0xFFFF),
        "udp_len_mismatch": mismatch,
        "tcp_good": tcp_frame(bytes((3 * i) & 0xFF for i in range(101))),
        "tcp_bad": tcp_frame(bytes((3 * i) & 0xFF for i in range(101)), tcp_csum=0x3333),
        "tcp_bad_ip": tcp_frame(b"tcp-with-a-bad-ipv4-header", ip_csum=0x4444),
        "tcp_sum_zero": tcp_frame(tcp_zero, tcp_csum=0x0000),
        "tcp_sum_zero_ffff": tcp_frame(tcp_zero, tcp_csum=0xFFFF),
        "icmp_good": icmp_frame(b"icmp-echo-request-payload"),
        "icmp_bad_ip": icmp_frame(b"icmp-echo-request-payload", ip_csum=0x5555),
    }


@cocotb.test()
async def rx_checksum_verdicts(dut):
    """IPERR/TCPERR/UDPERR/EOFE for good and bad checksums under every enable setting."""
    bench = RxCsumBench(dut)
    await bench.start()
    frames = verdict_frames()
    for enables in ALL_ENABLES:
        bench.set_enables(**enables)
        label = "ip{ip}_udp{udp}_tcp{tcp}".format(**enables)
        stimuli = [RxStimulus(pad(frame), note=f"{label}:{name}") for name, frame in frames.items()]
        results = {s.note.split(":")[1]: status(beats) for _, s, beats, _ in await bench.run(stimuli)}
        ip, udp, tcp = enables["ip"], enables["udp"], enables["tcp"]
        # Explicit expectations for the policy, independent of the model.
        assert results["udp_good"] == dict(frag=0, eofe=0, iperr=0, tcperr=0, udperr=0)
        assert results["udp_bad"]["udperr"] == udp and results["udp_bad"]["eofe"] == udp
        assert results["udp_bad_ip"]["iperr"] == ip
        assert results["udp_no_checksum"]["udperr"] == 0
        assert results["udp_sum_zero_ffff"]["udperr"] == 0
        assert results["udp_len_mismatch"]["udperr"] == udp and results["udp_len_mismatch"]["eofe"] == udp
        assert results["tcp_good"] == dict(frag=0, eofe=0, iperr=0, tcperr=0, udperr=0)
        assert results["tcp_bad"]["tcperr"] == tcp and results["tcp_bad"]["eofe"] == tcp
        assert results["tcp_sum_zero"]["tcperr"] == 0
        assert results["icmp_bad_ip"] == dict(frag=0, eofe=ip, iperr=ip, tcperr=0, udperr=0)
        # A valid transport checksum must preserve an enabled IPv4 error.
        assert (results["udp_bad_ip"]["iperr"], results["udp_bad_ip"]["udperr"]) == (ip, 0)
        assert (results["tcp_bad_ip"]["iperr"], results["tcp_bad_ip"]["tcperr"]) == (ip, 0)
        assert results["udp_bad_ip"]["eofe"] == ip
        assert results["tcp_bad_ip"]["eofe"] == ip
        assert results["udp_bad_ip_bad_udp"]["eofe"] == int(bool(ip or udp))
        # Current baseline behaviour: the TCP check compares the inbound
        # checksum with the computed one (EthMacPkg.vhd getEthMacCsum), so
        # 0xFFFF, the RFC 1624 equivalent of a computed 0x0000, is an error.
        assert results["tcp_sum_zero_ffff"]["tcperr"] == tcp
        assert verify_frame_checksums(frames["tcp_sum_zero_ffff"]).tcperr == 0


@cocotb.test()
async def rx_fragments_and_non_ipv4(dut):
    """FRAG on the first beat, no transport verdict for fragments, non-IPv4 bypass."""
    bench = RxCsumBench(dut)
    await bench.start()
    inner = udp_frame(b"vlan-tagged-udp-with-bad-checksums!", ip_csum=0x1111, udp_csum=0x2222)
    vlan = inner[:12] + ETH_TYPE_VLAN.to_bytes(2, "big") + (0x0064).to_bytes(2, "big") + inner[12:]
    stimuli = [
        RxStimulus(udp_frame(b"first-fragment-bad-udp-csum", udp_csum=0x2222, flags_fragment=IPV4_MF), note="udp_mf"),
        RxStimulus(udp_frame(b"later-fragment-payload-bytes", udp_csum=0x2222, flags_fragment=0x00B9), note="udp_offset"),
        RxStimulus(udp_frame(b"df-only-is-not-a-fragment!", udp_csum=0x2222, flags_fragment=IPV4_DF), note="udp_df"),
        RxStimulus(udp_frame(b"fragment-with-bad-ip-header", ip_csum=0x1111, flags_fragment=IPV4_MF | 0x0010), note="udp_mf_bad_ip"),
        RxStimulus(tcp_frame(b"tcp-fragment-bad-csum", tcp_csum=0x3333, flags_fragment=IPV4_MF), note="tcp_mf"),
        RxStimulus(pad(icmp_frame(b"icmp-frag", flags_fragment=0x0001)), note="icmp_offset"),
        RxStimulus(udp_frame(b"frag-sideband-in-but-not-a-fragment"), frag_in=1, note="frag_in_ignored"),
        RxStimulus(patch16(other_frame(80, fill=0x00), 20, IPV4_MF), note="nonip_frag_lookalike"),
        RxStimulus(other_frame(80, eth_type=ETH_TYPE_ARP, fill=0x00), note="nonip_zero"),
        RxStimulus(vlan, note="vlan_ipv4"),
    ]
    results = {s.note: status(beats) for _, s, beats, _ in await bench.run(stimuli)}
    assert results["udp_mf"] == dict(frag=1, eofe=0, iperr=0, tcperr=0, udperr=0)
    assert results["udp_offset"] == dict(frag=1, eofe=0, iperr=0, tcperr=0, udperr=0)
    assert results["udp_df"] == dict(frag=0, eofe=1, iperr=0, tcperr=0, udperr=1)
    assert results["udp_mf_bad_ip"] == dict(frag=1, eofe=1, iperr=1, tcperr=0, udperr=0)
    assert results["tcp_mf"] == dict(frag=1, eofe=0, iperr=0, tcperr=0, udperr=0)
    assert results["icmp_offset"]["frag"] == 1
    # The inbound FRAG sideband is replaced by the header-derived verdict.
    assert results["frag_in_ignored"]["frag"] == 0
    assert results["nonip_zero"] == dict(frag=0, eofe=0, iperr=0, tcperr=0, udperr=0)
    # Current baseline behaviour: FRAG is derived from bytes 20-21 of every
    # multi-beat frame without checking the EtherType (the IPV4_HDR0_S
    # fragmentation check), so non-IPv4 frames can carry FRAG; an 802.1Q-tagged
    # frame has its inner IPv4 total length there. Tagged frames get no
    # checksum verdicts.
    assert results["nonip_frag_lookalike"] == dict(frag=1, eofe=0, iperr=0, tcperr=0, udperr=0)
    assert results["vlan_ipv4"] == dict(frag=1, eofe=0, iperr=0, tcperr=0, udperr=0)


@cocotb.test()
async def rx_inbound_eofe_and_padding(dut):
    """Inbound EOFE propagation and checksum treatment of Ethernet padding."""
    bench = RxCsumBench(dut)
    await bench.start()
    stimuli = [
        RxStimulus(other_frame(64, fill=0x00), eofe=1, note="nonip_eofe"),
        RxStimulus(pad(udp_frame(b"good-udp-with-eofe-in")), eofe=1, note="udp_good_eofe"),
        RxStimulus(pad(icmp_frame(b"good-icmp-with-eofe")), eofe=1, note="icmp_good_eofe"),
        RxStimulus(pad(udp_frame(b"pad")), note="udp_zero_pad"),
        RxStimulus(pad(udp_frame(b"pad"), fill=0xA5), note="udp_nonzero_pad"),
        RxStimulus(pad(tcp_frame(b""), fill=0xA5), note="tcp_nonzero_pad"),
        RxStimulus(pad(icmp_frame(b""), fill=0xA5), note="icmp_nonzero_pad"),
    ]
    results = {s.note: status(beats) for _, s, beats, _ in await bench.run(stimuli)}
    assert results["nonip_eofe"]["eofe"] == 1
    assert results["udp_zero_pad"] == dict(frag=0, eofe=0, iperr=0, tcperr=0, udperr=0)
    assert results["icmp_nonzero_pad"] == dict(frag=0, eofe=0, iperr=0, tcperr=0, udperr=0)
    # Successful checks must preserve inbound EOFE.
    for note in ("udp_good_eofe", "icmp_good_eofe"):
        assert results[note] == dict(frag=0, eofe=1, iperr=0, tcperr=0, udperr=0), note
    # Current baseline behaviour: transport checksums sum every byte to the
    # end of the frame, including Ethernet padding beyond the IPv4 total
    # length (MOVE_S copies tData/tKeep without a length cutoff), so nonzero
    # padding is an error.
    assert results["udp_nonzero_pad"]["udperr"] == 1 and results["udp_nonzero_pad"]["eofe"] == 1
    assert results["tcp_nonzero_pad"]["tcperr"] == 1 and results["tcp_nonzero_pad"]["eofe"] == 1
    assert verify_frame_checksums(pad(udp_frame(b"pad"), fill=0xA5)).udperr == 0
    # With every check disabled, the inbound EOFE passes through.
    bench.set_enables(ip=0, udp=0, tcp=0)
    results = {s.note: status(beats) for _, s, beats, _ in await bench.run(stimuli[:3])}
    assert results == {note: dict(frag=0, eofe=1, iperr=0, tcperr=0, udperr=0) for note in ("nonip_eofe", "udp_good_eofe", "icmp_good_eofe")}


@cocotb.test()
async def rx_size_boundary_and_oversize(dut):
    """1514/1520 (9014/9024) frames pass; longer frames are cut with EOFE and the next frame is intact."""
    bench = RxCsumBench(dut)
    await bench.start()
    rng = bench.rng
    canary = pad(udp_frame(b"canary-after-oversize"))
    admitted = [1514, 1515, MAX_ADMITTED_STD]
    if bench.jumbo:
        admitted += [MAX_ADMITTED_STD + 1, 4001, 9014, MAX_ADMITTED_JUMBO]
    stimuli = []
    for size in admitted:
        stimuli.append(RxStimulus(udp_frame(random_payload(rng, size - 42)), note=f"udp_{size}"))
        stimuli.append(RxStimulus(tcp_frame(random_payload(rng, size - 54)), note=f"tcp_{size}"))
    over = bench.max_admitted + 1
    stimuli += [
        RxStimulus(other_frame(over, rng=rng), note=f"nonip_{over}", gap_after=0),
        RxStimulus(canary, note="canary_1"),
        RxStimulus(other_frame(over + 479, rng=rng), note="nonip_long"),
        RxStimulus(canary, note="canary_2"),
        RxStimulus(icmp_frame(random_payload(rng, over + 100 - 38)), note="icmp_oversize"),
        RxStimulus(canary, note="canary_3"),
        RxStimulus(udp_frame(random_payload(rng, over + 100 - 42)), note="udp_oversize"),
        RxStimulus(canary, note="canary_4"),
    ]
    results = {s.note: (beats, verdict) for _, s, beats, verdict in await bench.run(stimuli)}
    for size in admitted:
        for kind in ("udp", "tcp"):
            beats, verdict = results[f"{kind}_{size}"]
            assert not verdict.truncated and len(payload_from_beats(beats)) == size
            assert status(beats) == dict(frag=0, eofe=0, iperr=0, tcperr=0, udperr=0), f"{kind}_{size}"
    for note in (f"nonip_{over}", "nonip_long", "icmp_oversize", "udp_oversize"):
        beats, verdict = results[note]
        assert len(payload_from_beats(beats)) == bench.max_admitted, f"{note}: cut length"
    for note in ("canary_1", "canary_2", "canary_3", "canary_4"):
        assert status(results[note][0]) == dict(frag=0, eofe=0, iperr=0, tcperr=0, udperr=0), note
    assert status(results[f"nonip_{over}"][0])["eofe"] == 1
    assert status(results["nonip_long"][0])["eofe"] == 1
    assert status(results["udp_oversize"][0])["eofe"] == 1
    # A valid IPv4 header must preserve the oversize cut's EOFE.
    assert status(results["icmp_oversize"][0])["iperr"] == 0
    assert status(results["icmp_oversize"][0])["eofe"] == 1
    # With the IPv4 check disabled the cut frame keeps its EOFE.
    bench.set_enables(ip=0, udp=1, tcp=1)
    results = await bench.run([stimuli[-4], stimuli[-3]])
    assert status(results[0][2])["eofe"] == 1


def one_byte_last_beat_stimuli() -> list[RxStimulus]:
    """Frames of 16*n+1 bytes with a bad IPv4 header, plus unaffected controls."""
    return [
        RxStimulus(icmp_frame(bytes(81 - 38), ip_csum=0x1234), note="icmp81_bad_ip"),
        RxStimulus(icmp_frame(bytes(81 - 38), ip_csum=0x1234, flags_fragment=IPV4_MF), eofe=1, note="icmp81_bad_ip_mf_eofe"),
        RxStimulus(udp_frame(bytes(81 - 42), ip_csum=0x1234, udp_csum=0x0001), note="udp81_bad_ip_bad_udp"),
        RxStimulus(tcp_frame(bytes(97 - 54), ip_csum=0x1234, tcp_csum=0x0001), note="tcp97_bad_ip_bad_tcp"),
        RxStimulus(udp_frame(bytes(81 - 42), udp_csum=0x0001), note="udp81_bad_udp"),
        RxStimulus(icmp_frame(bytes(82 - 38), ip_csum=0x1234), note="icmp82_bad_ip"),
    ]


def last_status(beats: list[EmacBeat]) -> tuple[int, int, int, int]:
    beat = beats[-1]
    return beat.eofe, beat.iperr, beat.tcperr, beat.udperr


@cocotb.test()
async def rx_one_byte_last_beat(dut):
    """Error bits of frames whose last beat carries a single byte."""
    bench = RxCsumBench(dut)
    await bench.start()
    results = {s.note: beats for _, s, beats, _ in await bench.run(one_byte_last_beat_stimuli())}
    # IPERR shares the wrapper's SOF view on a one-byte final beat, but
    # must not cause the RTL to replace that beat's EOFE with FRAG.
    assert last_status(results["icmp81_bad_ip"]) == (1, 1, 0, 0)
    assert last_status(results["icmp81_bad_ip_mf_eofe"]) == (1, 1, 0, 0)
    assert last_status(results["udp81_bad_ip_bad_udp"]) == (1, 1, 0, 1)
    assert last_status(results["tcp97_bad_ip_bad_tcp"]) == (1, 1, 1, 0)
    assert last_status(results["udp81_bad_udp"]) == (1, 0, 0, 1)
    assert last_status(results["icmp82_bad_ip"]) == (1, 1, 0, 0)


async def spacing_sequence(bench: RxCsumBench, gap: int) -> dict[str, dict[str, int]]:
    """Frame pairs separated by `gap` idle cycles; returns raw status by note.

    The scoreboard model assumes isolated frames, so callers assert the
    status explicitly.
    """
    first = pad(icmp_frame(b"first-frame-valid-header"))
    second = udp_frame(b"next-frame-other-header-checksum")
    assert get16(first, 24) != get16(second, 24)
    stimuli = [
        RxStimulus(first, gap_after=gap, note="first"),
        RxStimulus(second, gap_after=8, note="second"),
        RxStimulus(icmp_frame(bytes(bench.max_admitted + 60)), gap_after=gap, note="oversize"),
        RxStimulus(pad(udp_frame(b"canary")), gap_after=8, note="canary"),
        # A one-cycle TVALID gap between the first two beats of a fragment
        # that follows a (non-IPv4) frame after `gap` idle cycles.
        RxStimulus(other_frame(64), gap_after=gap, note="nonip"),
        RxStimulus(udp_frame(bytes(60), flags_fragment=IPV4_MF), gap_after_sof=1, gap_after=8, note="fragment"),
    ]
    start = len(bench.frames)
    send_task = cocotb.start_soon(bench.send(stimuli))
    for _ in range(1500):
        if len(bench.frames) >= start + len(stimuli):
            break
        await RisingEdge(bench.clk)
    else:
        raise AssertionError(f"gap={gap}: timed out")
    await send_task
    observed = bench.frames[start:]
    assert len(observed) == len(stimuli), f"gap={gap}: {len(observed)} frames"
    assert len(payload_from_beats(observed[2])) == bench.max_admitted, f"gap={gap}: oversize cut length"
    return {stimulus.note: status(beats) for stimulus, beats in zip(stimuli, observed)}


CLEAN = dict(frag=0, eofe=0, iperr=0, tcperr=0, udperr=0)


@cocotb.test()
async def rx_spaced_frames(dut):
    """Frames separated by two or three idle cycles keep correct verdicts."""
    bench = RxCsumBench(dut)
    await bench.start()
    for gap in (2, 3):
        results = await spacing_sequence(bench, gap)
        assert results["first"] == CLEAN, f"gap={gap}"
        assert results["oversize"]["iperr"] == 0, f"gap={gap}"
        for note in ("second", "canary", "nonip"):
            assert results[note] == CLEAN, f"gap={gap} {note}"
        if gap == 3:
            assert results["fragment"] == dict(CLEAN, frag=1)


@cocotb.test()
async def rx_eofe_preservation_test(dut):
    """Report #1: checks preserve inbound, earlier-check and oversize EOFE."""
    bench = RxCsumBench(dut)
    await bench.start()
    stimuli = [
        RxStimulus(pad(udp_frame(b"bad-header-good-udp", ip_csum=0x1111)), note="udp_bad_ip"),
        RxStimulus(pad(tcp_frame(b"bad-header-good-tcp", ip_csum=0x1111)), note="tcp_bad_ip"),
        RxStimulus(pad(udp_frame(b"good-udp-with-eofe-in")), eofe=1, note="udp_good_eofe_in"),
        RxStimulus(pad(tcp_frame(b"good-tcp-with-eofe-in")), eofe=1, note="tcp_good_eofe_in"),
        RxStimulus(pad(icmp_frame(b"good-icmp-with-eofe")), eofe=1, note="icmp_good_eofe_in"),
        RxStimulus(icmp_frame(bytes(bench.max_admitted + 100)), gap_after=8, note="icmp_oversize"),
    ]
    # Exercise every runtime enable combination. Inbound/oversize errors
    # survive even when checks are disabled; header errors require ipCsumEn.
    # Follow each errored frame with clean traffic to reject sticky EOFE.
    canary = pad(udp_frame(b"clean-after-eofe"))
    sequence = [item for stimulus in stimuli for item in
                (stimulus, RxStimulus(canary, note=f"canary_after_{stimulus.note}"))]
    for enables in ALL_ENABLES:
        bench.set_enables(**enables)
        results = {s.note: status(beats) for _, s, beats, _ in await bench.run(sequence)}
        for stimulus in stimuli:
            expected_eofe = enables["ip"] if stimulus.note in ("udp_bad_ip", "tcp_bad_ip") else 1
            assert results[stimulus.note]["eofe"] == expected_eofe, (enables, stimulus.note, results)
            assert results[f"canary_after_{stimulus.note}"] == CLEAN, (enables, stimulus.note, results)


@cocotb.test()
async def rx_one_byte_last_beat_eofe_test(dut):
    """Report #2: final-beat checksum flags must not trigger a SOF update."""
    bench = RxCsumBench(dut)
    await bench.start()
    stimuli = one_byte_last_beat_stimuli()[:4]
    stimuli.append(RxStimulus(pad(udp_frame(b"clean-after-one-byte-errors")), note="recovery"))
    # bench.run() scoreboards each frame with check_rx_frame() first. On a
    # one-byte final beat FRAG aliases EOFE, so a regression of this fix
    # fails there as "FRAG on beat N" before the EOFE assertion below.
    results = {s.note: beats for _, s, beats, _ in await bench.run(stimuli)}
    for stimulus in stimuli[:-1]:
        assert results[stimulus.note][-1].eofe == 1, (stimulus.note, last_status(results[stimulus.note]))
    assert status(results["recovery"]) == CLEAN


###############################################################################
# Known issues (RUN_KNOWN_ISSUE_TESTS=1; each asserts the correct behaviour)
###############################################################################


@cocotb.test(skip=KNOWN_ISSUE_SKIP)
async def rx_back_to_back_known_issue_test(dut):
    """Known issue 11: the next frame's header corrupts a closely followed IPv4 verdict."""
    bench = RxCsumBench(dut)
    await bench.start()
    wrong = {}
    for gap in (0, 1):
        results = await spacing_sequence(bench, gap)
        if results["first"] != CLEAN:
            wrong[f"first_gap{gap}"] = results["first"]
        if gap == 0 and results["oversize"]["iperr"] != 0:
            wrong["oversize_gap0"] = results["oversize"]
    assert not wrong, (
        "known issue: getEthMacCsum (EthMacPkg.vhd) compares an ipCsum summed "
        "three cycles earlier with hdrCsum read live from r.ipv4Hdr, which "
        "IDLE_S/IPV4_HDR0_S overwrite from the next frame before the final-beat "
        "checksum update samples the verdict (the MOVE_S oversize cut enters "
        f"BLOWOFF_S without setting pipeFlush); valid headers flagged: {wrong}"
    )


@cocotb.test(skip=KNOWN_ISSUE_SKIP)
async def rx_frag_after_sof_gap_known_issue_test(dut):
    """Known issue 12: FRAG lost after a TVALID gap behind SOF during a flush."""
    bench = RxCsumBench(dut)
    await bench.start()
    wrong = {}
    for gap in (0, 2):
        results = await spacing_sequence(bench, gap)
        if results["fragment"]["frag"] != 1:
            wrong[f"fragment_gap{gap}"] = results["fragment"]
    assert not wrong, (
        "known issue: while pipeFlush still advances the pipeline for the "
        "previous frame, a TVALID gap after SOF inserts a bubble behind it "
        "and the SOF/FRAG update at the pipeline exit takes the bubble's "
        f"fragDet; MF fragments delivered without FRAG: {wrong}"
    )


###############################################################################
# Random scoreboard
###############################################################################


def random_rx_stimulus(rng: random.Random, bench: RxCsumBench) -> RxStimulus:
    kind = rng.choices(
        ["udp", "tcp", "icmp", "nonip", "vlan", "udp_frag", "tcp_frag", "udp_len_mismatch", "ip_len_garbage", "oversize"],
        weights=[30, 27, 8, 10, 4, 6, 4, 4, 3, 4],
    )[0]
    size_class = rng.choices(["small", "medium", "boundary", "jumbo"], weights=[55, 33, 9, 3 if bench.jumbo else 0])[0]
    if size_class == "small":
        length = rng.randint(42, 96)
    elif size_class == "medium":
        length = rng.randint(97, 500)
    elif size_class == "boundary":
        length = rng.randint(MAX_ADMITTED_STD - 24, MAX_ADMITTED_STD)
    else:
        length = rng.randint(MAX_ADMITTED_STD + 1, bench.max_admitted)
    if kind == "oversize":
        length = rng.randint(bench.max_admitted + 1, bench.max_admitted + 64)

    def checksum() -> int | None:
        choice = rng.choices(["correct", "zero", "garbage"], weights=[60, 15, 25])[0]
        return None if choice == "correct" else 0 if choice == "zero" else rng.getrandbits(16)

    flags = 0
    if kind in ("udp_frag", "tcp_frag"):
        flags = rng.choice([IPV4_MF, IPV4_MF | rng.randint(1, 0x1FFF), rng.randint(1, 0x1FFF)])
    elif rng.random() < 0.2:
        flags = IPV4_DF
    if kind in ("udp", "udp_frag", "udp_len_mismatch") or (kind == "oversize" and rng.random() < 0.5):
        frame = udp_frame(random_payload(rng, max(0, length - 42)), ip_csum=checksum(), udp_csum=checksum(), flags_fragment=flags)
        if kind == "udp_len_mismatch":
            frame = patch16(frame, 38, rng.getrandbits(16))
    elif kind in ("tcp", "tcp_frag"):
        frame = tcp_frame(random_payload(rng, max(0, length - 54)), ip_csum=checksum(), tcp_csum=checksum(), flags_fragment=flags)
    elif kind in ("icmp", "ip_len_garbage"):
        frame = icmp_frame(random_payload(rng, max(0, length - 38)), ip_csum=checksum(), flags_fragment=flags)
    elif kind == "vlan":
        inner = udp_frame(random_payload(rng, max(0, length - 46)), ip_csum=checksum(), udp_csum=checksum())
        frame = inner[:12] + ETH_TYPE_VLAN.to_bytes(2, "big") + rng.getrandbits(16).to_bytes(2, "big") + inner[12:]
    else:
        frame = other_frame(max(length, 14), eth_type=rng.choice([0x88B5, ETH_TYPE_ARP, 0x86DD]), rng=rng)
    if kind == "ip_len_garbage":
        frame = patch16(frame, 16, rng.getrandbits(16))
        if rng.random() < 0.5:
            frame = patch16(frame, 24, 0)
            frame = patch16(frame, 24, internet_checksum(frame[14:34]))
    frame = pad(frame)
    eofe = int(rng.random() < 0.08)
    # Back-to-back frames corrupt the IPv4 header verdict (known issue 11), so
    # they are only mixed in while the header check is disabled; the
    # transport checks see them either way. The source never gaps between
    # the first two beats (known issue 12).
    gap = rng.choice([0, 0, 1, 2, 4]) if not bench.enables["ip"] else rng.choice([2, 3, 4])
    return RxStimulus(frame, eofe=eofe, gap_after=gap, note=f"{kind} len={len(frame)} eofe={eofe} gap={gap}")


@cocotb.test()
async def rx_random_scoreboard(dut):
    """Seeded random mix in eight enable batches with TVALID gaps."""
    bench = RxCsumBench(dut)
    await bench.start()
    frames_per_batch = 40
    standard = 0
    for batch, enables in enumerate(bench.rng.sample(ALL_ENABLES, len(ALL_ENABLES))):
        bench.set_enables(**enables)
        bench.mid_gap_probability = bench.rng.choice([0.0, 0.2, 0.5])
        dut._log.info(f"batch {batch}: enables={enables} mid-frame gaps={bench.mid_gap_probability}")
        stimuli = []
        for index in range(frames_per_batch):
            stimulus = random_rx_stimulus(bench.rng, bench)
            stimulus.note = f"batch={batch} index={index} {stimulus.note}"
            stimuli.append(stimulus)
        results = await bench.run(stimuli)
        # For standard traffic with every check enabled the RTL policy must
        # agree with RFC verification; this also guards the model itself.
        if enables == dict(ip=1, udp=1, tcp=1):
            for index, stimulus, _, verdict in results:
                if verdict.truncated or not rfc_standard(stimulus.frame, stimulus.eofe):
                    continue
                reference = verify_frame_checksums(stimulus.frame)
                context = describe_case(bench.seed, batch * frames_per_batch + index, stimulus.note)
                assert (verdict.iperr, verdict.tcperr, verdict.udperr, verdict.frag) == (
                    reference.iperr,
                    reference.tcperr,
                    reference.udperr,
                    reference.frag,
                ), f"{context}: RTL policy differs from RFC verification"
                standard += 1
        bench.mid_gap_probability = 0.0
    dut._log.info(f"{standard} standard frames cross-checked against verify_frame_checksums")
    assert standard >= 10


###############################################################################
# Pytest wrapper
###############################################################################


PARAMETER_SWEEP = [
    parameter_case("std", JUMBO_G="false"),
    parameter_case("jumbo", JUMBO_G="true"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacRxCsumDepth(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxcsumwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
