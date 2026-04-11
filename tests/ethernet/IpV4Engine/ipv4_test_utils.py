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

import ipaddress
from pathlib import Path

from tests.ethernet.EthMacCore.ethmac_test_utils import (
    build_ethernet_frame,
    build_ipv4_header,
    build_udp_header,
    internet_checksum,
    ipv4_to_bytes,
    mac_to_bytes,
)


IPV4_RTL_SOURCES = [
    str(path)
    for path in sorted((Path(__file__).resolve().parents[3] / "ethernet" / "IpV4Engine" / "rtl").glob("*.vhd"))
]


def ipv4_config_word(address: str) -> int:
    # The flattened cocotb wrappers expose byte-stream traffic lane-first, so
    # config words that are compared directly against stream slices need the
    # same least-significant-lane ordering.
    return int.from_bytes(ipaddress.IPv4Address(address).packed[::-1], byteorder="big")


def build_ipv4_frame(
    *,
    dst_mac: int,
    src_mac: int,
    src_ip: str,
    dst_ip: str,
    protocol: int,
    payload: bytes,
    identification: int = 0x1234,
    ttl: int = 0x20,
    checksum_override: int | None = None,
) -> bytes:
    ipv4_header = build_ipv4_header(
        src_ip=src_ip,
        dst_ip=dst_ip,
        protocol=protocol,
        payload_length=len(payload),
        identification=identification,
        ttl=ttl,
        checksum_override=checksum_override,
    )
    return build_ethernet_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        eth_type=0x0800,
        payload=ipv4_header + payload,
    )


def build_ipv4_protocol_pseudo_frame(
    *,
    mac_address: int,
    first_ip: str,
    second_ip: str,
    protocol: int,
    payload: bytes,
) -> bytes:
    # The IPv4 engines exchange a private pseudo-header format:
    # MAC address, two zero bytes, first IP word, second IP word, then a
    # 4-byte shim of zero/protocol/protocol-length before the protocol payload.
    # The meaning of the two IP words depends on direction:
    # - RX output: source IP then destination IP
    # - TX input: source IP then destination IP
    return (
        mac_to_bytes(mac_address)
        + b"\x00\x00"
        + ipv4_to_bytes(first_ip)
        + ipv4_to_bytes(second_ip)
        + bytes([0x00, protocol & 0xFF])
        + len(payload).to_bytes(2, byteorder="big")
        + payload
    )


def build_ipv4_rx_pseudo_frame(
    *,
    src_mac: int,
    src_ip: str,
    dst_ip: str,
    protocol: int,
    payload: bytes,
) -> bytes:
    return build_ipv4_protocol_pseudo_frame(
        mac_address=src_mac,
        first_ip=src_ip,
        second_ip=dst_ip,
        protocol=protocol,
        payload=payload,
    )


def build_ipv4_tx_pseudo_frame(
    *,
    dst_mac: int,
    src_ip: str,
    dst_ip: str,
    protocol: int,
    payload: bytes,
) -> bytes:
    return build_ipv4_protocol_pseudo_frame(
        mac_address=dst_mac,
        first_ip=src_ip,
        second_ip=dst_ip,
        protocol=protocol,
        payload=payload,
    )


def build_ipv4_tx_wire_frame(
    *,
    dst_mac: int,
    src_mac: int,
    src_ip: str,
    dst_ip: str,
    protocol: int,
    payload: bytes,
    identification: int = 0x0000,
    ttl: int = 0x20,
) -> bytes:
    # IpV4EngineTx leaves the IPv4 total length and checksum fields clear for
    # downstream MAC checksum/length logic to repair.
    ipv4_header = (
        bytes([0x45, 0x00])
        + b"\x00\x00"
        + identification.to_bytes(2, byteorder="big")
        + bytes([0x40, 0x00, ttl, protocol, 0x00, 0x00])
        + ipv4_to_bytes(src_ip)
        + ipv4_to_bytes(dst_ip)
    )
    return build_ethernet_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        eth_type=0x0800,
        payload=ipv4_header + payload,
    )


def build_arp_frame(
    *,
    opcode: int,
    sender_mac: int,
    sender_ip: str,
    target_mac: int,
    target_ip: str,
    dst_mac: int | None = None,
    src_mac: int | None = None,
) -> bytes:
    if dst_mac is None:
        dst_mac = 0xFFFFFFFFFFFF if opcode == 1 else target_mac
    if src_mac is None:
        src_mac = sender_mac

    payload = (
        (0x0001).to_bytes(2, byteorder="big")
        + (0x0800).to_bytes(2, byteorder="big")
        + bytes([0x06, 0x04])
        + opcode.to_bytes(2, byteorder="big")
        + mac_to_bytes(sender_mac)
        + ipv4_to_bytes(sender_ip)
        + mac_to_bytes(target_mac)
        + ipv4_to_bytes(target_ip)
    )
    return build_ethernet_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        eth_type=0x0806,
        payload=payload,
    )


def build_icmp_echo_packet(
    *,
    payload: bytes,
    identifier: int = 0x1234,
    sequence: int = 0x0001,
    icmp_type: int = 0x08,
    code: int = 0x00,
) -> bytes:
    header_wo_checksum = bytes([icmp_type, code]) + b"\x00\x00"
    header_wo_checksum += identifier.to_bytes(2, byteorder="big")
    header_wo_checksum += sequence.to_bytes(2, byteorder="big")
    checksum = internet_checksum(header_wo_checksum + payload)
    return (
        bytes([icmp_type, code])
        + checksum.to_bytes(2, byteorder="big")
        + identifier.to_bytes(2, byteorder="big")
        + sequence.to_bytes(2, byteorder="big")
        + payload
    )


def build_icmp_echo_reply_packet(
    *,
    payload: bytes,
    identifier: int = 0x1234,
    sequence: int = 0x0001,
) -> bytes:
    return build_icmp_echo_packet(
        payload=payload,
        identifier=identifier,
        sequence=sequence,
        icmp_type=0x00,
        code=0x00,
    )


def build_icmp_echo_frame(
    *,
    dst_mac: int,
    src_mac: int,
    src_ip: str,
    dst_ip: str,
    payload: bytes,
    identifier: int = 0x1234,
    sequence: int = 0x0001,
) -> bytes:
    icmp_payload = build_icmp_echo_packet(
        payload=payload,
        identifier=identifier,
        sequence=sequence,
        icmp_type=0x08,
        code=0x00,
    )
    return build_ipv4_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        src_ip=src_ip,
        dst_ip=dst_ip,
        protocol=0x01,
        payload=icmp_payload,
    )


def build_ipv4_udp_payload(
    *,
    src_port: int,
    dst_port: int,
    payload: bytes,
    src_ip: str,
    dst_ip: str,
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
    return udp_header + payload
