##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from __future__ import annotations

from dataclasses import dataclass
import ipaddress
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


ETHMAC_RTL_SOURCES = [
    str(path)
    for path in sorted((Path(__file__).resolve().parents[3] / "ethernet" / "EthMacCore" / "rtl").glob("*.vhd"))
    if path.name != "EthMacPkg.vhd"
]
ETHMAC_RTL_SOURCES.append(str(Path(__file__).resolve().parents[3] / "dsp" / "xilinx" / "logic" / "DspXor.vhd"))


@dataclass
class EmacBeat:
    """One flattened EMAC transfer beat as exposed by the cocotb wrappers."""

    data: int
    keep: int
    last: int
    dest: int = 0
    sof: int = 0
    frag: int = 0
    eofe: int = 0
    iperr: int = 0
    tcperr: int = 0
    udperr: int = 0


class FlatEmacEndpoint:
    def __init__(self, dut, *, prefix: str):
        self.dut = dut
        self.prefix = prefix

    def _sig(self, suffix: str):
        return getattr(self.dut, f"{self.prefix}{suffix}")

    def _has(self, suffix: str) -> bool:
        return hasattr(self.dut, f"{self.prefix}{suffix}")

    def set_idle(self) -> None:
        # Model an idle source by dropping `TVALID` and clearing the payload
        # signals so stale values do not confuse waveform inspection.
        for suffix, value in (
            ("TValid", 0),
            ("TData", 0),
            ("TKeep", 0),
            ("TLast", 0),
            ("TDest", 0),
            ("Sof", 0),
            ("Frag", 0),
            ("Eofe", 0),
            ("IpErr", 0),
            ("TcpErr", 0),
            ("UdpErr", 0),
        ):
            if self._has(suffix):
                self._sig(suffix).value = value

    def drive(self, beat: EmacBeat) -> None:
        # Present one visible beat. The helper keeps this beat stable until the
        # DUT accepts it with `TREADY`.
        self._sig("TValid").value = 1
        self._sig("TData").value = beat.data
        self._sig("TKeep").value = beat.keep
        self._sig("TLast").value = beat.last
        if self._has("TDest"):
            self._sig("TDest").value = beat.dest
        if self._has("Sof"):
            self._sig("Sof").value = beat.sof
        if self._has("Frag"):
            self._sig("Frag").value = beat.frag
        if self._has("Eofe"):
            self._sig("Eofe").value = beat.eofe
        if self._has("IpErr"):
            self._sig("IpErr").value = beat.iperr
        if self._has("TcpErr"):
            self._sig("TcpErr").value = beat.tcperr
        if self._has("UdpErr"):
            self._sig("UdpErr").value = beat.udperr

    async def wait_ready(self, *, clk) -> None:
        # A source-side driver must hold the current beat until the DUT raises
        # `TREADY`, even when that takes multiple cycles.
        while True:
            await RisingEdge(clk)
            await Timer(1, unit="ns")
            if int(self._sig("TReady").value) == 1:
                return

    async def send(self, beat: EmacBeat, *, clk) -> None:
        # `send()` is the simple one-beat helper: drive, wait for acceptance,
        # then return the bus to idle.
        self.drive(beat)
        await self.wait_ready(clk=clk)
        self.set_idle()

    def snapshot(self) -> EmacBeat:
        return EmacBeat(
            data=int(self._sig("TData").value),
            keep=int(self._sig("TKeep").value),
            last=int(self._sig("TLast").value),
            dest=0 if not self._has("TDest") else int(self._sig("TDest").value),
            sof=0 if not self._has("Sof") else int(self._sig("Sof").value),
            frag=0 if not self._has("Frag") else int(self._sig("Frag").value),
            eofe=0 if not self._has("Eofe") else int(self._sig("Eofe").value),
            iperr=0 if not self._has("IpErr") else int(self._sig("IpErr").value),
            tcperr=0 if not self._has("TcpErr") else int(self._sig("TcpErr").value),
            udperr=0 if not self._has("UdpErr") else int(self._sig("UdpErr").value),
        )

    async def wait_valid(self, *, clk, timeout_cycles: int = 64) -> EmacBeat:
        # Sink-side tests often want to notice a beat before deciding whether
        # to consume it, so this helper only waits for visibility.
        for _ in range(timeout_cycles):
            await Timer(1, unit="ns")
            if int(self._sig("TValid").value) == 1:
                return self.snapshot()
            await RisingEdge(clk)
        raise AssertionError(f"Timed out waiting for {self.prefix} valid")

    async def recv(self, *, clk, ready_signal=None, keep_ready: bool = False) -> EmacBeat:
        # Raise `TREADY` when needed, capture the visible beat, then consume it
        # on the next rising edge.
        if ready_signal is not None:
            ready_signal.value = 1
        beat = await self.wait_valid(clk=clk)
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if ready_signal is not None and not keep_ready:
            ready_signal.value = 0
        return beat


@dataclass
class FlatEmacBench:
    """Common cocotb bench wiring for flattened EMAC wrappers."""

    clk: object
    source: FlatEmacEndpoint | None = None
    sink: FlatEmacEndpoint | None = None


def keep_mask(data_bytes: int) -> int:
    return (1 << data_bytes) - 1


def pack_bytes(data: bytes, *, lane_bytes: int = 16) -> int:
    # SURF's EMAC stream places the first byte of the packet in the least
    # significant byte lane of the flattened data word.
    value = 0
    for index, byte_value in enumerate(data[:lane_bytes]):
        value |= (byte_value & 0xFF) << (8 * index)
    return value


def payload_from_beat(beat: EmacBeat, *, lane_bytes: int = 16) -> bytes:
    payload = bytearray()
    for index in range(lane_bytes):
        if beat.keep & (1 << index):
            payload.append((beat.data >> (8 * index)) & 0xFF)
    return bytes(payload)


def payload_from_beats(beats: list[EmacBeat], *, lane_bytes: int = 16) -> bytes:
    payload = bytearray()
    for beat in beats:
        payload.extend(payload_from_beat(beat, lane_bytes=lane_bytes))
    return bytes(payload)


def frame_beats_from_bytes(
    data: bytes,
    *,
    beat_bytes: int = 16,
    dest: int = 0,
    eofe: int = 0,
    frag: int = 0,
) -> list[EmacBeat]:
    beats = []
    offset = 0
    while offset < len(data):
        chunk = data[offset : offset + beat_bytes]
        beats.append(
            EmacBeat(
                data=pack_bytes(chunk, lane_bytes=beat_bytes),
                keep=keep_mask(len(chunk)),
                last=1 if offset + beat_bytes >= len(data) else 0,
                dest=dest,
                sof=1 if offset == 0 else 0,
                frag=frag if offset == 0 else 0,
                eofe=eofe if offset + beat_bytes >= len(data) else 0,
            )
        )
        offset += beat_bytes
    return beats


def assert_beat_list(observed: list[EmacBeat], expected: list[EmacBeat]) -> None:
    assert len(observed) == len(expected)
    for index, (obs, exp) in enumerate(zip(observed, expected, strict=True)):
        assert obs == exp, f"Mismatch at beat {index}: observed={obs} expected={exp}"


def mac_to_bytes(mac: int) -> bytes:
    return mac.to_bytes(6, byteorder="big")


def mac_config_word_from_wire(mac: int) -> int:
    # EthMac config registers store MAC bytes in the same least-significant-
    # lane-first order used by the flattened EMAC datapath, so reverse the
    # normal wire-order MAC before driving config ports such as `localMac`.
    return int.from_bytes(mac_to_bytes(mac)[::-1], byteorder="big")


def ipv4_to_bytes(address: str) -> bytes:
    return ipaddress.IPv4Address(address).packed


def internet_checksum(data: bytes) -> int:
    # The IPv4, UDP, and TCP checksum blocks all use the standard one's-
    # complement fold over 16-bit words, with a zero pad on odd byte counts.
    if len(data) % 2 != 0:
        data += b"\x00"

    checksum = 0
    for offset in range(0, len(data), 2):
        checksum += int.from_bytes(data[offset : offset + 2], byteorder="big")
        checksum = (checksum & 0xFFFF) + (checksum >> 16)

    return (~checksum) & 0xFFFF


def build_ethernet_frame(*, dst_mac: int, src_mac: int, eth_type: int, payload: bytes) -> bytes:
    return mac_to_bytes(dst_mac) + mac_to_bytes(src_mac) + eth_type.to_bytes(2, byteorder="big") + payload


def pad_ethernet_frame_to_min_size(frame: bytes) -> bytes:
    # Ethernet transmits at least 60 bytes before FCS, so short frames that
    # traverse the TX path emerge padded with zeros on the wire.
    return frame if len(frame) >= 60 else frame + bytes(60 - len(frame))


def build_ipv4_header(
    *,
    src_ip: str,
    dst_ip: str,
    protocol: int,
    payload_length: int,
    identification: int = 0x1234,
    ttl: int = 64,
    checksum_override: int | None = None,
) -> bytes:
    total_length = 20 + payload_length
    header_wo_checksum = bytes([0x45, 0x00]) + total_length.to_bytes(2, byteorder="big")
    header_wo_checksum += identification.to_bytes(2, byteorder="big")
    header_wo_checksum += b"\x00\x00"
    header_wo_checksum += bytes([ttl, protocol])
    header_wo_checksum += b"\x00\x00"
    header_wo_checksum += ipv4_to_bytes(src_ip) + ipv4_to_bytes(dst_ip)

    checksum = internet_checksum(header_wo_checksum) if checksum_override is None else checksum_override
    return header_wo_checksum[:10] + checksum.to_bytes(2, byteorder="big") + header_wo_checksum[12:]


def build_udp_header(
    *,
    src_port: int,
    dst_port: int,
    payload: bytes,
    src_ip: str,
    dst_ip: str,
    checksum_override: int | None = None,
) -> bytes:
    udp_length = 8 + len(payload)
    header_wo_checksum = (
        src_port.to_bytes(2, byteorder="big")
        + dst_port.to_bytes(2, byteorder="big")
        + udp_length.to_bytes(2, byteorder="big")
        + b"\x00\x00"
    )

    pseudo_header = (
        ipv4_to_bytes(src_ip)
        + ipv4_to_bytes(dst_ip)
        + bytes([0x00, 0x11])
        + udp_length.to_bytes(2, byteorder="big")
    )
    checksum = internet_checksum(pseudo_header + header_wo_checksum + payload) if checksum_override is None else checksum_override
    return header_wo_checksum[:6] + checksum.to_bytes(2, byteorder="big")


def build_ipv4_udp_frame(
    *,
    dst_mac: int,
    src_mac: int,
    src_ip: str,
    dst_ip: str,
    src_port: int,
    dst_port: int,
    payload: bytes,
    ip_checksum_override: int | None = None,
    udp_checksum_override: int | None = None,
) -> bytes:
    udp_header = build_udp_header(
        src_port=src_port,
        dst_port=dst_port,
        payload=payload,
        src_ip=src_ip,
        dst_ip=dst_ip,
        checksum_override=udp_checksum_override,
    )
    ipv4_header = build_ipv4_header(
        src_ip=src_ip,
        dst_ip=dst_ip,
        protocol=0x11,
        payload_length=len(udp_header) + len(payload),
        checksum_override=ip_checksum_override,
    )
    return build_ethernet_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        eth_type=0x0800,
        payload=ipv4_header + udp_header + payload,
    )


def build_pause_frame(pause_value: int) -> bytes:
    # The pause opcode and pause quanta are part of the MAC control payload,
    # which the TxPause block pads to Ethernet's 46-byte minimum payload.
    payload = b"\x00\x01" + pause_value.to_bytes(2, byteorder="big") + bytes(42)
    return build_ethernet_frame(
        dst_mac=0x0180C2000001,
        src_mac=0x000000000000,
        eth_type=0x8808,
        payload=payload,
    )


def start_clock(signal, *, period_ns: float = 5.0) -> None:
    cocotb.start_soon(Clock(signal, period_ns, unit="ns").start())


async def cycle(clk, count: int = 1) -> None:
    for _ in range(count):
        await RisingEdge(clk)
        await Timer(1, unit="ns")


async def reset_dut(dut, *, clk_name: str = "ethClk", rst_name: str = "ethRst") -> None:
    clk = getattr(dut, clk_name)
    rst = getattr(dut, rst_name)
    rst.value = 1
    await cycle(clk, 4)
    rst.value = 0
    await cycle(clk, 2)


async def setup_flat_emac_testbench(
    dut,
    *,
    clk_name: str = "ethClk",
    rst_name: str = "ethRst",
    period_ns: float = 5.0,
    source_prefix: str | None = None,
    sink_prefix: str | None = None,
    initial_values: dict[str, int] | None = None,
) -> FlatEmacBench:
    # Most EMAC wrapper benches share the same pattern: start one clock, drive
    # reset high immediately, optionally create flat source/sink endpoints,
    # seed a few sideband controls, then release reset.
    clk = getattr(dut, clk_name)
    rst = getattr(dut, rst_name)
    start_clock(clk, period_ns=period_ns)
    rst.setimmediatevalue(1)

    source = None if source_prefix is None else FlatEmacEndpoint(dut, prefix=source_prefix)
    sink = None if sink_prefix is None else FlatEmacEndpoint(dut, prefix=sink_prefix)

    if source is not None:
        source.set_idle()

    if initial_values is not None:
        for signal_name, value in initial_values.items():
            getattr(dut, signal_name).setimmediatevalue(value)

    await reset_dut(dut, clk_name=clk_name, rst_name=rst_name)
    return FlatEmacBench(clk=clk, source=source, sink=sink)


async def send_contiguous_frame(endpoint: FlatEmacEndpoint, beats: list[EmacBeat], *, clk) -> None:
    # Some EMAC stages inspect packet continuity, so this helper keeps `TVALID`
    # asserted across the entire frame instead of idling between beats.
    for beat in beats:
        endpoint.drive(beat)
        await endpoint.wait_ready(clk=clk)
    endpoint.set_idle()


async def send_frame_burst(
    endpoint: FlatEmacEndpoint,
    frames: list[list[EmacBeat]],
    *,
    clk,
    inter_frame_gap_cycles: int = 0,
) -> None:
    # Burst-style top-level tests need consecutive frames without rebuilding a
    # new source coroutine for each packet. This helper keeps frame boundaries
    # explicit while allowing zero-gap or small-gap sequencing.
    for index, frame in enumerate(frames):
        await send_contiguous_frame(endpoint, frame, clk=clk)
        if index != len(frames) - 1:
            for _ in range(inter_frame_gap_cycles):
                await RisingEdge(clk)
                await Timer(1, unit="ns")


async def recv_frame(endpoint: FlatEmacEndpoint, *, clk, ready_signal=None, timeout_cycles: int = 64) -> list[EmacBeat]:
    beats = []
    if ready_signal is not None:
        ready_signal.value = 1
    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if int(endpoint._sig("TValid").value) == 1:
            beat = endpoint.snapshot()
            beats.append(beat)
            if beat.last == 1:
                if ready_signal is not None:
                    ready_signal.value = 0
                return beats
    if ready_signal is not None:
        ready_signal.value = 0
    raise AssertionError("Timed out waiting for end of EMAC frame")


async def expect_no_output(endpoint: FlatEmacEndpoint, *, clk, cycles: int = 8) -> None:
    for _ in range(cycles):
        await Timer(1, unit="ns")
        assert int(endpoint._sig("TValid").value) == 0
        await RisingEdge(clk)


async def wait_signal_pulse(signal, *, clk, timeout_cycles: int = 64) -> None:
    # Many MAC status outputs are one-cycle pulses, so a dedicated helper keeps
    # tests from relying on fragile fixed delays.
    for _ in range(timeout_cycles):
        await Timer(1, unit="ns")
        if int(signal.value) == 1:
            return
        await RisingEdge(clk)
    raise AssertionError(f"Timed out waiting for pulse on {signal._name}")
