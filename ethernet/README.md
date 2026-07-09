# Ethernet

This tree contains Ethernet MAC, framing, IP/UDP, RoCEv2, and high-speed Ethernet cores.

## Layout

- `EthMacCore/`: common Ethernet MAC logic.
- `GigEthCore/`, `TenGigEthCore/`, `XauiCore/`, `XlauiCore/`, and `Caui4Core/`: speed and PHY-family specific Ethernet cores.
- `RawEthFramer/`: raw Ethernet frame transmit/receive support.
- `IpV4Engine/`: ARP, ICMP, IGMP, IPv4 receive/transmit, and demux helpers.
- `UdpEngine/`: UDP protocol support.
- `RoCEv2/`: RDMA over Converged Ethernet v2 support.

High-speed cores commonly split shared `core/` logic from FPGA transceiver-family directories. Use `getFpgaArch` guards in ruckus files for family-specific source selection, and keep protocol-level tests under `tests/ethernet/`.
