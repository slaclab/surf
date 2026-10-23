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
from pathlib import Path

from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import sample_after_tpd

from tests.axi.utils import axil_read_u32, axil_write_u32, wait_sampled_ready
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    FlatEmacEndpoint,
    cycle,
    keep_mask,
    mac_config_word_from_wire,
    mac_to_bytes,
    pack_bytes,
    setup_flat_emac_testbench,
)

# These helpers model the RawEthFramer private application stream, including
# the two-byte header the DUT inserts between EtherType and payload.
RAWETH_RTL_SOURCES = [
    str(path)
    for path in sorted((Path(__file__).resolve().parents[3] / "ethernet" / "RawEthFramer" / "rtl").glob("*.vhd"))
]


LOCAL_MAC_WIRE = 0x001122334455
LOCAL_MAC_CFG = mac_config_word_from_wire(LOCAL_MAC_WIRE)
REMOTE_MAC_WIRE = 0x0A0B0C0D0E0F
REMOTE_MAC_CFG = mac_config_word_from_wire(REMOTE_MAC_WIRE)
ALT_REMOTE_MAC_WIRE = 0x102132435465
ALT_REMOTE_MAC_CFG = mac_config_word_from_wire(ALT_REMOTE_MAC_WIRE)
# RawEthFramer stores EtherType lane-first at the config boundary, so the wire
# value `0x1000` appears here as `0x0010`.
ETH_TYPE_CFG = 0x0010
# The flattened raw-app wrappers are 64 bits wide.
RAWETH_BEAT_BYTES = 8


@dataclass
class RawAppBeat:
    data: int
    keep: int
    last: int
    dest: int = 0
    sof: int = 0
    bcf: int = 0
    eofe: int = 0


class FlatRawAppEndpoint:
    def __init__(self, dut, *, prefix: str):
        self.dut = dut
        self.prefix = prefix

    def _sig(self, suffix: str):
        return getattr(self.dut, f"{self.prefix}{suffix}")

    def set_idle(self) -> None:
        for suffix, value in (
            ("TValid", 0),
            ("TData", 0),
            ("TKeep", 0),
            ("TLast", 0),
            ("TDest", 0),
            ("Sof", 0),
            ("Bcf", 0),
            ("Eofe", 0),
        ):
            self._sig(suffix).value = value

    def drive(self, beat: RawAppBeat) -> None:
        self._sig("TValid").value = 1
        self._sig("TData").value = beat.data
        self._sig("TKeep").value = beat.keep
        self._sig("TLast").value = beat.last
        self._sig("TDest").value = beat.dest
        self._sig("Sof").value = beat.sof
        self._sig("Bcf").value = beat.bcf
        self._sig("Eofe").value = beat.eofe

    async def wait_ready(self, *, clk) -> None:
        await wait_sampled_ready(
            self._sig("TReady"),
            clk=clk,
        )

    def snapshot(self) -> RawAppBeat:
        return RawAppBeat(
            data=int(self._sig("TData").value),
            keep=int(self._sig("TKeep").value),
            last=int(self._sig("TLast").value),
            dest=int(self._sig("TDest").value),
            sof=int(self._sig("Sof").value),
            bcf=int(self._sig("Bcf").value),
            eofe=int(self._sig("Eofe").value),
        )


@dataclass
class RawEthWrapperBench:
    clk: object
    axil: AxiLiteMaster
    mac_source: FlatEmacEndpoint
    mac_sink: FlatEmacEndpoint
    app_source: FlatRawAppEndpoint
    app_sink: FlatRawAppEndpoint


@dataclass
class RawEthRxBench:
    clk: object
    source: FlatEmacEndpoint
    sink: FlatRawAppEndpoint


@dataclass
class RawEthTxBench:
    clk: object
    source: FlatRawAppEndpoint
    sink: FlatEmacEndpoint


@dataclass
class RawEthPairBench:
    clk: object
    server_source: FlatRawAppEndpoint
    server_sink: FlatRawAppEndpoint
    client_source: FlatRawAppEndpoint
    client_sink: FlatRawAppEndpoint


def raw_app_beats_from_bytes(
    data: bytes,
    *,
    dest: int,
    bcf: int = 0,
    eofe: int = 0,
    beat_bytes: int = RAWETH_BEAT_BYTES,
) -> list[RawAppBeat]:
    beats = []
    offset = 0
    while offset < len(data):
        chunk = data[offset : offset + beat_bytes]
        beats.append(
            RawAppBeat(
                data=pack_bytes(chunk, lane_bytes=beat_bytes),
                keep=keep_mask(len(chunk)),
                last=1 if offset + beat_bytes >= len(data) else 0,
                dest=dest,
                sof=1 if offset == 0 else 0,
                bcf=bcf if offset == 0 else 0,
                eofe=eofe if offset + beat_bytes >= len(data) else 0,
            )
        )
        offset += beat_bytes
    return beats


def payload_from_raw_beats(beats: list[RawAppBeat], *, lane_bytes: int = 8) -> bytes:
    payload = bytearray()
    for beat in beats:
        for index in range(lane_bytes):
            if beat.keep & (1 << index):
                payload.append((beat.data >> (8 * index)) & 0xFF)
    return bytes(payload)


def pad_to_raw_eth_lane_width(payload: bytes, *, lane_bytes: int = RAWETH_BEAT_BYTES) -> bytes:
    return payload + bytes((-len(payload)) % lane_bytes)


def raweth_header_bytes(*, dest: int, bcf: int, min_byte_count: int) -> bytes:
    # Header byte 0 packs the broadcast-copy flag in bit 7 and the low 7 bits
    # of the minimum-byte-count field in bits [6:0]. Byte 1 is the lookup
    # destination index.
    return bytes([((bcf & 0x1) << 7) | (min_byte_count & 0x7F), dest & 0xFF])


def build_raw_eth_wire_frame(
    *,
    dst_mac: int,
    src_mac: int,
    dest: int,
    bcf: int,
    payload: bytes,
    min_byte_count: int,
    eth_type_cfg: int = ETH_TYPE_CFG,
) -> bytes:
    return (
        mac_to_bytes(dst_mac)
        + mac_to_bytes(src_mac)
        + eth_type_cfg.to_bytes(2, byteorder="little")
        + raweth_header_bytes(dest=dest, bcf=bcf, min_byte_count=min_byte_count)
        + payload
    )


def remote_mac_axil_addr(dest: int, *, high: bool = False) -> int:
    # Each destination slot consumes 8 bytes in AXI-Lite space: low word at
    # `dest << 3`, high word four bytes later.
    return (dest << 3) | (4 if high else 0)


async def program_remote_mac(master, *, dest: int, mac_cfg: int) -> None:
    await axil_write_u32(master, remote_mac_axil_addr(dest), mac_cfg & 0xFFFF_FFFF)
    await axil_write_u32(master, remote_mac_axil_addr(dest, high=True), (mac_cfg >> 32) & 0xFFFF)


async def read_remote_mac(master, *, dest: int) -> int:
    low = await axil_read_u32(master, remote_mac_axil_addr(dest))
    high = await axil_read_u32(master, remote_mac_axil_addr(dest, high=True))
    return low | ((high & 0xFFFF) << 32)


async def setup_raw_eth_wrapper_bench(dut) -> RawEthWrapperBench:
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        initial_values={
            "localMac": LOCAL_MAC_CFG,
            "mMacTReady": 0,
            "mAppTReady": 0,
            "S_AXI_AWADDR": 0,
            "S_AXI_AWPROT": 0,
            "S_AXI_AWVALID": 0,
            "S_AXI_WDATA": 0,
            "S_AXI_WSTRB": 0,
            "S_AXI_WVALID": 0,
            "S_AXI_BREADY": 0,
            "S_AXI_ARADDR": 0,
            "S_AXI_ARPROT": 0,
            "S_AXI_ARVALID": 0,
            "S_AXI_RREADY": 0,
        },
    )

    mac_source = FlatEmacEndpoint(dut, prefix="sMac")
    mac_sink = FlatEmacEndpoint(dut, prefix="mMac")
    app_source = FlatRawAppEndpoint(dut, prefix="sApp")
    app_sink = FlatRawAppEndpoint(dut, prefix="mApp")
    mac_source.set_idle()
    app_source.set_idle()

    axil = AxiLiteMaster(
        AxiLiteBus.from_prefix(dut, "S_AXI"),
        dut.clk,
        dut.rst,
        reset_active_level=True,
    )
    await cycle(bench.clk, 2)
    return RawEthWrapperBench(
        clk=bench.clk,
        axil=axil,
        mac_source=mac_source,
        mac_sink=mac_sink,
        app_source=app_source,
        app_sink=app_sink,
    )


async def setup_raw_eth_rx_bench(dut) -> RawEthRxBench:
    await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        initial_values={
            "localMac": LOCAL_MAC_CFG,
            "remoteMac": 0,
            "ack": 0,
            "mAppTReady": 0,
        },
    )

    source = FlatEmacEndpoint(dut, prefix="sMac")
    sink = FlatRawAppEndpoint(dut, prefix="mApp")
    source.set_idle()
    await cycle(dut.clk, 2)
    return RawEthRxBench(clk=dut.clk, source=source, sink=sink)


async def setup_raw_eth_tx_bench(dut) -> RawEthTxBench:
    await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        initial_values={
            "localMac": LOCAL_MAC_CFG,
            "remoteMac": 0,
            "ack": 0,
            "mMacTReady": 0,
        },
    )

    source = FlatRawAppEndpoint(dut, prefix="sApp")
    sink = FlatEmacEndpoint(dut, prefix="mMac")
    source.set_idle()
    await cycle(dut.clk, 2)
    return RawEthTxBench(clk=dut.clk, source=source, sink=sink)


async def setup_raw_eth_pair_bench(dut) -> RawEthPairBench:
    await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        initial_values={
            "serverLocalMac": LOCAL_MAC_CFG,
            "clientLocalMac": REMOTE_MAC_CFG,
            "mServerAppTReady": 0,
            "mClientAppTReady": 0,
        },
    )

    server_source = FlatRawAppEndpoint(dut, prefix="sServerApp")
    server_sink = FlatRawAppEndpoint(dut, prefix="mServerApp")
    client_source = FlatRawAppEndpoint(dut, prefix="sClientApp")
    client_sink = FlatRawAppEndpoint(dut, prefix="mClientApp")
    server_source.set_idle()
    client_source.set_idle()
    await cycle(dut.clk, 2)
    return RawEthPairBench(
        clk=dut.clk,
        server_source=server_source,
        server_sink=server_sink,
        client_source=client_source,
        client_sink=client_sink,
    )


async def wait_lookup_request(
    dut,
    *,
    clk,
    req_name: str = "req",
    dest_name: str = "tDest",
    timeout_cycles: int = 64,
) -> int:
    for _ in range(timeout_cycles):
        await Timer(1, unit="ns")
        if int(getattr(dut, req_name).value) == 1:
            return int(getattr(dut, dest_name).value)
        await RisingEdge(clk)
    raise AssertionError(f"Timed out waiting for {req_name}")


async def pulse_signal(signal, *, clk, cycles: int = 1) -> None:
    signal.value = 1
    for _ in range(cycles):
        await sample_after_tpd(clk)
    signal.value = 0
