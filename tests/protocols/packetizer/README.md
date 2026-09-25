# Packetizer regressions

Follow the shared [test methodology](../../README.md),
[protocol guidance](../README.md), and [runner documentation](../../common/README.md).

`packetizer_test_utils.py` provides packet encoders, an independent CRC oracle,
flat AXI Stream endpoints, and `Depacketizer2TB` for shared clock/reset setup.
Each test module owns its scenario assertions.

- `test_AxiStreamDepacketizer2Recovery.py` checks termination of active
  destinations under backpressure, mixed active/inactive entries, and reset
  during cleanup.
- `test_AxiStreamDepacketizer2Reconnect.py` checks immediate fresh traffic,
  repeated reconnects, link flaps, and sparse/empty sweeps. Its configurations
  include RAM/output/CRC variants, RSSI, and PGP3/PGP4/PGP4 Lite depacketizer
  generics. These are leaf tests; their sink stalls also exercise direct users.
  They do not model PGP link acquisition or the complete RSSI-to-SRP path.
- The remaining modules cover packet generation, depacketization, malformed
  traffic, CRC errors, mid-packet link loss, and packetizer loopback.

Reconnect cases include `SEQ_CNT_SIZE_G` and `INPUT_PIPE_STAGES_G`. Zero
sequence width is tested only with zero destination bits: the no-sequence
implementation has one shared state register, so independent multi-destination
cleanup is unsupported.

From the repository root, run the suite with:

```bash
./.venv/bin/python -m pytest -n 0 -q tests/protocols/packetizer
```

Use `-k pgp` with `test_AxiStreamDepacketizer2Reconnect.py` to select its five
PGP configurations. These link-loss cases have no RSSI known-issue gate.
