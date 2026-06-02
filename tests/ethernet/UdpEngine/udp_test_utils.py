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

from cocotb.triggers import Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    FlatEmacEndpoint,
    cycle,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    setup_flat_emac_testbench,
)
from tests.ethernet.IpV4Engine.ipv4_test_utils import ipv4_config_word


# Shared UDP-engine helpers centralize the wrapper-specific pseudo-header
# layout and the legacy demo configuration still used by the checked-in RTL.
UDP_RTL_SOURCES = [
    str(path)
    for path in sorted((Path(__file__).resolve().parents[3] / "ethernet" / "UdpEngine" / "rtl").glob("*.vhd"))
]


# The wrappers power up with the original SURF example endpoint table, so the
# benches keep using those MAC/IP tuples instead of inventing a second config.
LEGACY_MAC_WIRES = (
    0x004456000301,
    0x004456000302,
    0x004456000303,
    0x004456000304,
)
LEGACY_MAC_CFGS = tuple(mac_config_word_from_wire(value) for value in LEGACY_MAC_WIRES)
LEGACY_IPS = (
    "192.168.2.10",
    "192.168.2.11",
    "192.168.2.12",
    "192.168.2.13",
)
LEGACY_IP_CFGS = tuple(ipv4_config_word(value) for value in LEGACY_IPS)

UDP_PROTOCOL = 0x11
UDP_SERVER_PORT = 8192
UDP_CLIENT_PORT = 8193
DHCP_CLIENT_PORT = 68
DHCP_SERVER_PORT = 67
DHCP_DISCOVER = 1
DHCP_OFFER = 2
DHCP_REQUEST = 3
DHCP_ACK = 5
DHCP_BOOT_REPLY_OP = 0x02
DHCP_HTYPE_ETHERNET = 0x01
DHCP_HLEN_ETHERNET = 0x06
DHCP_FIXED_HEADER_BYTES = 240
DHCP_MAGIC_COOKIE = bytes.fromhex("63825363")
DHCP_OPT_MESSAGE_TYPE = 53
DHCP_OPT_REQUESTED_IP = 50
DHCP_OPT_LEASE_TIME = 51
DHCP_OPT_SERVER_IDENTIFIER = 54
DHCP_OPT_END = 255


@dataclass
class UdpRxBench:
    clk: object
    source: FlatEmacEndpoint
    server_sink: FlatEmacEndpoint
    client_sink: FlatEmacEndpoint
    dhcp_sink: FlatEmacEndpoint


@dataclass
class UdpTxBench:
    clk: object
    source: FlatEmacEndpoint
    sink: FlatEmacEndpoint
    dhcp_source: FlatEmacEndpoint


@dataclass
class UdpTopBench:
    clk: object
    udp_source: FlatEmacEndpoint
    udp_sink: FlatEmacEndpoint
    server_source: FlatEmacEndpoint
    server_sink: FlatEmacEndpoint
    client_source: FlatEmacEndpoint
    client_sink: FlatEmacEndpoint
    arp_req_sink: FlatEmacEndpoint
    arp_ack_source: FlatEmacEndpoint


@dataclass
class UdpWrapperBench:
    clk: object
    axil: AxiLiteMaster
    mac_source: FlatEmacEndpoint
    mac_sink: FlatEmacEndpoint
    server_source: FlatEmacEndpoint
    server_sink: FlatEmacEndpoint
    client_source: FlatEmacEndpoint
    client_sink: FlatEmacEndpoint


@dataclass
class UdpArpBench:
    clk: object
    arp_req_sink: FlatEmacEndpoint
    arp_ack_source: FlatEmacEndpoint


@dataclass
class UdpDhcpBench:
    clk: object
    source: FlatEmacEndpoint
    sink: FlatEmacEndpoint


@dataclass
class ArpIpTableBench:
    clk: object


def ipv4_to_bytes(address: str) -> bytes:
    return ipaddress.IPv4Address(address).packed


def port_config_word(port: int) -> int:
    # The flattened wrappers expose 16-bit ports lane-first, so reverse the
    # normal big-endian wire view before comparing against DUT config words.
    return int.from_bytes(port.to_bytes(2, byteorder="big")[::-1], byteorder="big")


def pack_udp_app_payload(payload: bytes) -> list:
    return frame_beats_from_bytes(payload)


def build_udp_rx_pseudo_frame(
    *,
    remote_mac: int,
    remote_ip: str,
    local_ip: str,
    remote_port: int,
    local_port: int,
    payload: bytes,
    udp_checksum: int = 0,
    extra_trailer: bytes = b"",
) -> bytes:
    udp_length = 8 + len(payload) + len(extra_trailer)
    # The RX pseudo-header is remote MAC, two pad bytes, remote/local IP, then
    # zero/protocol/UDP metadata before the payload bytes.
    header0 = remote_mac.to_bytes(6, byteorder="big") + b"\x00\x00" + ipv4_to_bytes(remote_ip) + ipv4_to_bytes(local_ip)
    header1 = (
        bytes([0x00, UDP_PROTOCOL])
        + b"\x00\x00"
        + remote_port.to_bytes(2, byteorder="big")
        + local_port.to_bytes(2, byteorder="big")
        + udp_length.to_bytes(2, byteorder="big")
        + udp_checksum.to_bytes(2, byteorder="big")
        + payload[:4].ljust(4, b"\x00")
    )
    return header0 + header1 + payload[4:] + extra_trailer


def build_udp_tx_pseudo_frame(
    *,
    dst_mac: int,
    src_ip: str,
    dst_ip: str,
    src_port: int,
    dst_port: int,
    payload: bytes,
) -> bytes:
    # The TX pseudo-header keeps the same private layout but uses the outgoing
    # destination MAC and source/destination IP tuple.
    header0 = dst_mac.to_bytes(6, byteorder="big") + b"\x00\x00" + ipv4_to_bytes(src_ip) + ipv4_to_bytes(dst_ip)
    header1 = (
        bytes([0x00, UDP_PROTOCOL])
        + b"\x00\x00"
        + src_port.to_bytes(2, byteorder="big")
        + dst_port.to_bytes(2, byteorder="big")
        + b"\x00\x00"
        + b"\x00\x00"
        + payload[:4].ljust(4, b"\x00")
    )
    return header0 + header1 + payload[4:]


def build_dhcp_reply_payload(
    *,
    message_type: int,
    xid: int,
    client_mac: int,
    yiaddr: str,
    siaddr: str,
    lease_time: int = 120,
) -> bytes:
    # DHCP options start after the 240-byte BOOTP fixed header.
    payload = bytearray(DHCP_FIXED_HEADER_BYTES)
    payload[0] = DHCP_BOOT_REPLY_OP
    payload[1] = DHCP_HTYPE_ETHERNET
    payload[2] = DHCP_HLEN_ETHERNET
    payload[3] = 0x00
    payload[4:8] = xid.to_bytes(4, byteorder="big")
    payload[16:20] = ipv4_to_bytes(yiaddr)
    payload[20:24] = ipv4_to_bytes(siaddr)
    payload[28:34] = client_mac.to_bytes(6, byteorder="big")
    payload[236:240] = DHCP_MAGIC_COOKIE
    payload.extend(
        bytes(
            [
                DHCP_OPT_MESSAGE_TYPE,
                1,
                message_type & 0xFF,
                DHCP_OPT_LEASE_TIME,
                4,
            ]
        )
    )
    payload.extend(lease_time.to_bytes(4, byteorder="big"))
    payload.extend(bytes([DHCP_OPT_END]))
    return bytes(payload)


def extract_dhcp_xid(payload: bytes) -> int:
    return int.from_bytes(payload[4:8], byteorder="big")


def extract_dhcp_message_type(payload: bytes) -> int | None:
    index = DHCP_FIXED_HEADER_BYTES
    while index < len(payload):
        code = payload[index]
        if code == 0:
            index += 1
            continue
        if code == DHCP_OPT_END:
            return None
        if index + 1 >= len(payload):
            return None
        length = payload[index + 1]
        data_start = index + 2
        data_stop = data_start + length
        if data_stop > len(payload):
            return None
        if code == DHCP_OPT_MESSAGE_TYPE and length == 1:
            return payload[data_start]
        index = data_stop
    return None


def extract_dhcp_requested_ip(payload: bytes) -> str | None:
    index = DHCP_FIXED_HEADER_BYTES
    while index < len(payload):
        code = payload[index]
        if code == 0:
            index += 1
            continue
        if code == DHCP_OPT_END:
            return None
        length = payload[index + 1]
        data_start = index + 2
        data_stop = data_start + length
        if code == DHCP_OPT_REQUESTED_IP and length == 4:
            return str(ipaddress.IPv4Address(payload[data_start:data_stop]))
        index = data_stop
    return None


def extract_dhcp_server_identifier(payload: bytes) -> str | None:
    index = DHCP_FIXED_HEADER_BYTES
    while index < len(payload):
        code = payload[index]
        if code == 0:
            index += 1
            continue
        if code == DHCP_OPT_END:
            return None
        length = payload[index + 1]
        data_start = index + 2
        data_stop = data_start + length
        if code == DHCP_OPT_SERVER_IDENTIFIER and length == 4:
            return str(ipaddress.IPv4Address(payload[data_start:data_stop]))
        index = data_stop
    return None


async def axil_read_u48(master, address: int) -> int:
    low = await axil_read_u32(master, address)
    high = await axil_read_u32(master, address + 4)
    return low | ((high & 0xFFFF) << 32)


async def axil_write_u48(master, address: int, value: int) -> None:
    await axil_write_u32(master, address, value & 0xFFFF_FFFF)
    await axil_write_u32(master, address + 4, (value >> 32) & 0xFFFF)


async def wait_for_link_up(signal, *, clk, timeout_cycles: int = 64) -> None:
    # The TX wrapper only becomes usable once the remote endpoint information
    # has propagated through the DUT and `linkUp` rises.
    for _ in range(timeout_cycles):
        await Timer(1, unit="ns")
        if int(signal.value) != 0:
            return
        await cycle(clk, 1)
    raise AssertionError("Timed out waiting for link-up")


async def pulse_signal(signal, *, clk, idle_cycles: int = 1) -> None:
    # Several UdpEngine leaves use one-cycle write enables or acknowledge
    # strobes. Model those as clean pulses instead of open-coded toggles.
    signal.value = 1
    await cycle(clk, 1)
    signal.value = 0
    await cycle(clk, idle_cycles)


async def setup_arp_ip_table_bench(dut) -> ArpIpTableBench:
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        initial_values={
            "ipAddrIn": 0,
            "pos": 0,
            "clientRemoteDetIp": 0,
            "clientRemoteDetValid": 0,
            "ipWrEn": 0,
            "ipWrAddr": 0,
            "macWrEn": 0,
            "macWrAddr": 0,
        },
    )
    return ArpIpTableBench(clk=bench.clk)


async def setup_udp_arp_bench(dut) -> UdpArpBench:
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        initial_values={
            "localIp": LEGACY_IP_CFGS[0],
            "arpTabFound": 0,
            "arpTabMacAddr": 0,
            "clientRemoteDetValid": 0,
            "clientRemoteDetIp": 0,
            "clientRemoteIp": 0,
            "arpReqTReady": 0,
            "arpAckTValid": 0,
            "arpAckTData": 0,
            "arpAckTKeep": 0,
            "arpAckTLast": 0,
            "arpAckSof": 0,
            "arpAckEofe": 0,
        },
    )
    arp_ack_source = FlatEmacEndpoint(dut, prefix="arpAck")
    arp_ack_source.set_idle()
    return UdpArpBench(
        clk=bench.clk,
        arp_req_sink=FlatEmacEndpoint(dut, prefix="arpReq"),
        arp_ack_source=arp_ack_source,
    )


async def setup_udp_dhcp_bench(dut) -> UdpDhcpBench:
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sDhcp",
        initial_values={
            "localMac": LEGACY_MAC_CFGS[0],
            "localIp": 0,
            "mDhcpTReady": 0,
        },
    )
    assert bench.source is not None
    return UdpDhcpBench(
        clk=bench.clk,
        source=bench.source,
        sink=FlatEmacEndpoint(dut, prefix="mDhcp"),
    )


async def setup_udp_rx_bench(dut) -> UdpRxBench:
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sUdp",
        initial_values={
            "localIp": LEGACY_IP_CFGS[0],
            "broadcastIp": ipv4_config_word("255.255.255.255"),
            "igmpIp": 0,
            "mServerTReady": 0,
            "mClientTReady": 0,
            "mDhcpTReady": 0,
        },
    )
    assert bench.source is not None
    return UdpRxBench(
        clk=bench.clk,
        source=bench.source,
        server_sink=FlatEmacEndpoint(dut, prefix="mServer"),
        client_sink=FlatEmacEndpoint(dut, prefix="mClient"),
        dhcp_sink=FlatEmacEndpoint(dut, prefix="mDhcp"),
    )


async def setup_udp_tx_bench(dut) -> UdpTxBench:
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        initial_values={
            "localMac": LEGACY_MAC_CFGS[0],
            "localIp": LEGACY_IP_CFGS[0],
            "remotePort": 0x0020,
            "remoteIp": LEGACY_IP_CFGS[1],
            "remoteMac": LEGACY_MAC_CFGS[1],
            "arpTabFound": 0,
            "arpTabIpAddr": 0,
            "arpTabMacAddr": 0,
            "mUdpTReady": 0,
            "sDhcpTValid": 0,
            "sDhcpTData": 0,
            "sDhcpTKeep": 0,
            "sDhcpTLast": 0,
            "sDhcpSof": 0,
            "sDhcpEofe": 0,
        },
    )
    source = FlatEmacEndpoint(dut, prefix="sApp")
    dhcp_source = FlatEmacEndpoint(dut, prefix="sDhcp")
    sink = FlatEmacEndpoint(dut, prefix="mUdp")
    source.set_idle()
    dhcp_source.set_idle()
    return UdpTxBench(clk=bench.clk, source=source, sink=sink, dhcp_source=dhcp_source)


async def setup_udp_top_bench(dut) -> UdpTopBench:
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sUdp",
        initial_values={
            "localMac": LEGACY_MAC_CFGS[0],
            "localIp": LEGACY_IP_CFGS[0],
            "broadcastIp": ipv4_config_word("255.255.255.255"),
            "clientRemotePort": 0x0020,
            "clientRemoteIp": LEGACY_IP_CFGS[1],
            "mUdpTReady": 0,
            "mServerTReady": 0,
            "mClientTReady": 0,
            "arpReqTReady": 0,
        },
    )
    assert bench.source is not None
    server_source = FlatEmacEndpoint(dut, prefix="sServer")
    client_source = FlatEmacEndpoint(dut, prefix="sClient")
    arp_ack_source = FlatEmacEndpoint(dut, prefix="arpAck")
    server_source.set_idle()
    client_source.set_idle()
    arp_ack_source.set_idle()
    return UdpTopBench(
        clk=bench.clk,
        udp_source=bench.source,
        udp_sink=FlatEmacEndpoint(dut, prefix="mUdp"),
        server_source=server_source,
        server_sink=FlatEmacEndpoint(dut, prefix="mServer"),
        client_source=client_source,
        client_sink=FlatEmacEndpoint(dut, prefix="mClient"),
        arp_req_sink=FlatEmacEndpoint(dut, prefix="arpReq"),
        arp_ack_source=arp_ack_source,
    )


async def setup_udp_wrapper_bench(dut) -> UdpWrapperBench:
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sMac",
        initial_values={
            "localMac": LEGACY_MAC_CFGS[0],
            "localIp": LEGACY_IP_CFGS[0],
            "mMacTReady": 0,
            "mServerTReady": 0,
            "mClientTReady": 0,
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
    assert bench.source is not None
    server_source = FlatEmacEndpoint(dut, prefix="sServer")
    client_source = FlatEmacEndpoint(dut, prefix="sClient")
    server_source.set_idle()
    client_source.set_idle()
    axil = AxiLiteMaster(
        AxiLiteBus.from_prefix(dut, "S_AXI"),
        dut.clk,
        dut.rst,
        reset_active_level=True,
    )
    await cycle(bench.clk, 2)
    return UdpWrapperBench(
        clk=bench.clk,
        axil=axil,
        mac_source=bench.source,
        mac_sink=FlatEmacEndpoint(dut, prefix="mMac"),
        server_source=server_source,
        server_sink=FlatEmacEndpoint(dut, prefix="mServer"),
        client_source=client_source,
        client_sink=FlatEmacEndpoint(dut, prefix="mClient"),
    )
