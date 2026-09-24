# RSSI RX and keepalive integration

## Goal and source

Prepare a candidate for the Warm-TDM column SRP failures without adding an
instrumented datapath. Branch: `fix/rssi-rx-keepalive-integration`.

- Base: `8d256ca84`, the keepalive branch with additional regression coverage.
  Its production monitor includes `6b6771a9f`, the fix loaded in Warm-TDM image
  `0b73019`: valid ACK/BUSY traffic refreshes server receive liveness.
- Incoming: [SURF PR #1456](https://github.com/slaclab/surf/pull/1456), reviewed
  head `5641e673f9d4d4481a79b945b476331d66d094a3`.
- Applied the PR changes relative to common ancestor `9248a10e6` as a source
  integration on the keepalive branch, without recording a Git merge of the
  PR branch. Warm-TDM pins the combined candidate through its SURF gitlink.

## Implementation

`RssiRxFsm.vhd` now aligns payload RAM writes/reads, prevents duplicate DATA
from modifying buffers, validates complete SYN headers, preserves payload
sidebands and final-beat pause, and cancels delivery when a connection closes.
The production-RAM/checksum RX wrapper, PyRogue READ-state enum and directed RX,
core-RX and connection-timeout tests accompany the change.

The keepalive monitor RTL and both its unit and core tests remain unchanged
from the base. `RssiConnFsm.vhd` already matches the PR's prerequisite, so no
additional connection-FSM RTL change was needed. Documentation combines both
coverage descriptions. Production interfaces, buffer/window settings, clocks
and the Warm-TDM datapath are unchanged.

## Validation

The source import and VSG checks on both edited VHDL files passed (zero
violations). Flake8 on the changed Python files and the RSSI test compliance
audit passed (zero findings). With GHDL 6.0.0 and cocotb 2.1.0, all 10 focused
pytest cases passed: RX, core-RX, monitor, core-keepalive and connection-FSM.
The remaining checksum, header-register and TX leaf tests also passed (three
pytest cases). The AXI-Lite register-interface case was skipped by its existing
`RUN_RSSI_KNOWN_ISSUE_TESTS` gate; it is not included in passing coverage.

An isolated comparison kept the keepalive fix and new tests but restored the
original RX RTL from `8d256ca84`. Both selected RX cocotb cases failed:

- `data_busy_payload_and_partial_keep_test`: extra zero payload words preceded
  the expected final word, which lost its SOF marker.
- `close_at_each_payload_stage_cancels_old_connection_test`: old payload words
  appeared after reconnect, preceding the new payload without its SOF marker.

Both cases pass in the integrated focused run. This demonstrates that the tests
detect the original RX defects; it does not establish the bench root cause.

Local tooling uses `/Users/bareese/surf/.venv/bin/python` and sibling ruckus:

```bash
make MODULES=/Users/bareese/warm-tdm/firmware/submodules import
/Users/bareese/surf/.venv/bin/python -m pytest -n 0 -q \
  tests/protocols/rssi/test_RssiRxFsm.py \
  tests/protocols/rssi/test_RssiCoreRx.py \
  tests/protocols/rssi/test_RssiMonitor.py \
  tests/protocols/rssi/test_RssiCoreKeepalive.py \
  tests/protocols/rssi/test_RssiConnFsm.py
/Users/bareese/surf/.venv/bin/python -m pytest -n 0 -q \
  tests/protocols/rssi/test_RssiChksum.py \
  tests/protocols/rssi/test_RssiHeaderReg.py \
  tests/protocols/rssi/test_RssiTxFsm.py \
  tests/protocols/rssi/test_RssiAxiLiteRegItf.py
```

Generated outputs stay outside this handoff. Local import/lint/test logs are
`/private/tmp/rssi-integration-{import,vsg,audit,focused,knownbad,leaf}.log`.

## Remaining acceptance

The PR reports a separate broad bidirectional integration failure; gated tests
are not passing-coverage claims. No Vivado synthesis, resource comparison,
implementation timing, image programming or physical hardware run has been
performed for this integration.

After synchronization, build the same column target using
Vivado 2024.1, record the new source/image identities, and compare with the
loaded `0b73019` image. Follow Warm-TDM's
`docs/plans/register-timeout/hardware-handoff/README.md`: idle keepalive,
SAFb/AxiVersion batched versus sequential reads, full-column reads, and first
reads after clean close versus after a batched-read reset. Keep raw evidence
outside Git. Preserve the keepalive fix in every candidate; do not replace the
base with the older PR head wholesale. Bench root cause remains unproven.
