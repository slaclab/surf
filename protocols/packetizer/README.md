# Packetizer

This directory contains stream fragmentation/reassembly and byte-packing RTL.
See the parent [protocols overview](../README.md).

- `rtl/`: Packetizer2/Depacketizer2 and their shared field package, legacy
  packetizer/depacketizer modules, and the byte packer.
- `wrappers/`: flat interfaces used by cocotb regressions.
- `tb/`: HDL simulation benches.
- [Packetizer2 working specification](packetizer2-spec.md): initial V2 wire,
  endpoint and compatibility documentation. Open questions remain explicit;
  this is not yet a complete conformance standard.
- [Regression guide](../../tests/protocols/packetizer/README.md): tests and
  supported invocation details.
- [Specification work and findings](../../docs/plans/packetizer2-spec/README.md):
  active review context, coverage gaps and the PGP separation question.

The current specification effort is limited to V2. Legacy protocol behavior is
outside its scope. Source loading remains controlled by [ruckus.tcl](ruckus.tcl).
