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


# Centralize recurring IPv4/ARP/ICMP/IGMP protocol constants here so the tests
# can describe behavior without repeating low-level packet-literal trivia.
IPV4_RTL_SOURCES = [
    str(path)
    for path in sorted((Path(__file__).resolve().parents[3] / "ethernet" / "IpV4Engine" / "rtl").glob("*.vhd"))
]

ETH_TYPE_IPV4 = 0x0800
ETH_TYPE_ARP = 0x0806
IPV4_VERSION_IHL = 0x45
IPV4_DEFAULT_TTL = 0x20
IPV4_DF_FLAGS = b"\x40\x00"
IP_PROTOCOL_ICMP = 0x01
IP_PROTOCOL_IGMP = 0x02
IP_PROTOCOL_UDP = 0x11
ARP_HTYPE_ETHERNET = 0x0001
ARP_PTYPE_IPV4 = 0x0800
ARP_HLEN_ETHERNET = 0x06
ARP_PLEN_IPV4 = 0x04
ARP_BROADCAST_MAC = 0xFFFFFFFFFFFF
ICMP_ECHO_REPLY = 0x00
ICMP_ECHO_REQUEST = 0x08
IGMP_MEMBERSHIP_QUERY = 0x11
IGMP_V2_MEMBERSHIP_REPORT = 0x16


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
    ttl: int = IPV4_DEFAULT_TTL,
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
        eth_type=ETH_TYPE_IPV4,
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
    ttl: int = IPV4_DEFAULT_TTL,
) -> bytes:
    # IpV4EngineTx leaves the IPv4 total length and checksum fields clear for
    # downstream MAC checksum/length logic to repair.
    ipv4_header = (
        bytes([IPV4_VERSION_IHL, 0x00])
        + b"\x00\x00"
        + identification.to_bytes(2, byteorder="big")
        + IPV4_DF_FLAGS
        + bytes([ttl, protocol, 0x00, 0x00])
        + ipv4_to_bytes(src_ip)
        + ipv4_to_bytes(dst_ip)
    )
    return build_ethernet_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        eth_type=ETH_TYPE_IPV4,
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
        dst_mac = ARP_BROADCAST_MAC if opcode == 1 else target_mac
    if src_mac is None:
        src_mac = sender_mac

    payload = (
        ARP_HTYPE_ETHERNET.to_bytes(2, byteorder="big")
        + ARP_PTYPE_IPV4.to_bytes(2, byteorder="big")
        + bytes([ARP_HLEN_ETHERNET, ARP_PLEN_IPV4])
        + opcode.to_bytes(2, byteorder="big")
        + mac_to_bytes(sender_mac)
        + ipv4_to_bytes(sender_ip)
        + mac_to_bytes(target_mac)
        + ipv4_to_bytes(target_ip)
    )
    return build_ethernet_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        eth_type=ETH_TYPE_ARP,
        payload=payload,
    )


def build_icmp_echo_packet(
    *,
    payload: bytes,
    identifier: int = 0x1234,
    sequence: int = 0x0001,
    icmp_type: int = ICMP_ECHO_REQUEST,
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
        icmp_type=ICMP_ECHO_REPLY,
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
        icmp_type=ICMP_ECHO_REQUEST,
        code=0x00,
    )
    return build_ipv4_frame(
        dst_mac=dst_mac,
        src_mac=src_mac,
        src_ip=src_ip,
        dst_ip=dst_ip,
        protocol=IP_PROTOCOL_ICMP,
        payload=icmp_payload,
    )


def build_igmp_packet(
    *,
    igmp_type: int,
    max_resp_time: int = 0x00,
    group_ip: str = "0.0.0.0",
    checksum_override: int | None = None,
) -> bytes:
    group_ip_bytes = ipv4_to_bytes(group_ip)
    # IGMPv2 packets are always a fixed 8 bytes: type, max-response-time,
    # checksum, and group address.
    header_wo_checksum = bytes([igmp_type & 0xFF, max_resp_time & 0xFF]) + b"\x00\x00" + group_ip_bytes
    checksum = internet_checksum(header_wo_checksum) if checksum_override is None else checksum_override
    return bytes([igmp_type & 0xFF, max_resp_time & 0xFF]) + checksum.to_bytes(2, byteorder="big") + group_ip_bytes


def build_igmp_membership_query_packet(
    *,
    max_resp_time: int,
    group_ip: str = "0.0.0.0",
    checksum_override: int | None = None,
) -> bytes:
    return build_igmp_packet(
        igmp_type=IGMP_MEMBERSHIP_QUERY,
        max_resp_time=max_resp_time,
        group_ip=group_ip,
        checksum_override=checksum_override,
    )


def build_igmp_membership_report_packet(
    *,
    group_ip: str,
    checksum_override: int | None = None,
) -> bytes:
    return build_igmp_packet(
        igmp_type=IGMP_V2_MEMBERSHIP_REPORT,
        max_resp_time=0x00,
        group_ip=group_ip,
        checksum_override=checksum_override,
    )


def igmp_group_mac(group_ip: str) -> int:
    # IPv4 multicast maps onto the Ethernet 01:00:5E prefix with the top bit
    # of the group address dropped.
    group_ip_bytes = ipv4_to_bytes(group_ip)
    return int.from_bytes(b"\x01\x00\x5E" + group_ip_bytes[1:], byteorder="big")


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
