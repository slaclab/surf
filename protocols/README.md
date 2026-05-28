# Protocols

This tree contains reusable protocol cores layered above the base, AXI, and Ethernet libraries.

## Layout

- Link/protocol families include `pgp/`, `ssi/`, `srp/`, `rssi/`, `sugoi/`, `salt/`, `glink/`, `htsp/`, and `coaxpress/`.
- Peripheral/control protocols include `i2c/`, `spi/`, `uart/`, `mdio/`, `pmbus/`, and `saci/`.
- Data formatting and protection helpers include `batcher/`, `packetizer/`, `line-codes/`, `hamming-ecc/`, and `event-frame-sequencer/`.
- JESD support lives in `jesd204b/`.

Many protocol folders split portable `core/` or `rtl/` logic from FPGA-family PHY wrappers. Preserve protocol record types and sideband semantics, especially `TKEEP`, `TLAST`, `TUSER`/SOF/EOFE, VC fields, and AXI-Lite status/control register maps. Put Python-facing register models under `python/surf/protocols` when the RTL exposes a PyRogue-visible register space.
