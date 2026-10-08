# PTP endpoint verification

This suite contains independent reference models, leaf RTL scoreboards,
physical protocol tests and autonomous endpoint/MAC regressions. The
[implementation record](../../../docs/plans/ethernet-ptp/autonomous-endpoint.md)
separates simulated behavior from remaining device and interoperability work.

- `test_ptp_mac_association.py` drives real XGMII frames through `EthMacTop`
  using `EthMacPtpExperimentWrapper`, with Python capture/association models.
  It checks CRC-loss ambiguity, byte order, FIFO pressure and recovery, and
  queued TX after logical restart and repeated pause.
- `ptp_wire_utils.py` supplies physical stimulus and independent AXI/wire
  monitors, reusing the existing Ethernet AXI helpers.
- `ptp_reference.py` and `test_ptp_reference.py` define exact arithmetic,
  integer PHC, atomic capture-queue, snapshot-session, and request-ledger
  contracts. Passing these tests is not proof of a PTP RTL or CDC implementation.
- `ptp_rx_reference.py` and `test_ptp_rx_reference.py` model the selected
  bounded RX validator after physical normalization. They verify FCS/length
  checks, atomic message/capture delivery, and same-edge overflow/reset abort.
  The physical GMII/XGMII adapter and protocol policy are outside this model.
- `test_ptp_rx_rtl.py` compares the actual validator against the model each
  cycle, through direct, GMII, and XGMII inputs. It additionally checks whole
  frame acceptance and independent capture timing, signed calibration, reset,
  abort priority, byte phase, and minimum-gap throughput.
  The registered-boundary follow-up also checks output stability between edges.
  Its scoreboard distinguishes a detection-edge head transfer from the abort
  consumed on the following edge, including full-queue consume/overflow.
- `test_ptp_rx_mac.py` runs the RX RTL beside the unchanged MAC under the
  original CRC loss, duplicate, FIFO pressure, and retained-head scenarios.
- `ptp_rx_test_utils.py` supplies independent frame/FCS fixtures and record
  packing for both reference and RTL tests.

**Current gate:** simulation and pytest (including collection and pure reference
cases) remain paused pending maintainer VHDL approval. The commands below are
for use after approval. One-step fixtures are prepared, not behaviorally validated;
see the [one-step acceptance checklist](../../../docs/plans/ethernet-ptp/rtl-review.md#one-step-receive-acceptance).

Run from the repository root after importing HDL sources:

```sh
./.venv/bin/python -m pytest -n 0 -q --log-cli-level=INFO tests/ethernet/PtpCore
```

The counterexample tests pass when they demonstrate the rejected algorithm's
failure. They must not be mistaken for successful timestamp-association RTL.
Large simulator logs stay in `tests/sim_build` or temporary storage; durable
historical results are in the
[Phase 0 record](../../../docs/plans/ethernet-ptp/history/verification.md#phase-0-counterexamples).
Follow the [test guidance](../../README.md) for changes and new regressions.

The [RX design decision](../../../docs/plans/ethernet-ptp/autonomous-endpoint.md#rx-message-and-capture-boundary)
records the selected replacement and its physical producer contract.
Historical RTL results and synthesis limits are in the
[RX evidence record](../../../docs/plans/ethernet-ptp/history/verification.md#rx-rtl-proof).
Run the models alone without starting a simulator:

```sh
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/PtpCore/test_ptp_reference.py tests/ethernet/PtpCore/test_ptp_rx_reference.py
```

## Autonomous endpoint tests

- `test_ptp_math.py`, `test_ptp_phc.py`: checked arithmetic and cycle-by-cycle PHC
  comparison, command/reset ordering, PPS and independent-clock snapshot sessions.
  Math cancellation checks also assert that result-valid stays stable before
  the cancellation edge, including when a completed result is stalled.
- `test_ptp_e2e.py`, `test_ptp_tx_ledger.py`: independent full-width E2E vectors,
  calibration across PHC steering, keyed response/completion reordering, narrow
  sequence wrap, unknown physical fate and reset/quarantine behavior.
  Added checks cover registered result/sample validity during cancellation and
  ledger occupancy alignment with allocation, wire completion and MAC reset.
  These checks await maintainer VHDL approval before execution.
  Ledger capacity and response acceptance now have between-edge stability
  checks; response completion must pulse for the submitted response.
- `ptp_endpoint_reference.py`, `test_ptp_endpoint_reference.py`: rational
  calibration, raw-tick rate estimator and PI models; operating-envelope sweeps.
- `test_ptp_servo.py`: every emitted rate command against the independent PI
  model at varied sample intervals, median startup, backpressure and holdover.
  It also checks registered command/cancellation/expiry stability between edges.
  `test_ptp_phc.py` exercises revocation after admission and expiry priority over
  validity-setting commands. These added timing checks await VHDL review before
  regression execution.
  PHC checks additionally require registered ready/ack/error/capture inhibition;
  cancellation excludes transfer without requiring ready to change mid-cycle.
- `test_ptp_reg.py`: all four development register banks at zero and nonzero bases, SURF
  field-strobe/address-alias/error behavior, immutable commit candidates, cross-bank
  atomicity, coherent snapshot sequences, queued commands and bus-reset recovery.
  Snapshot requests must remain stable between edges; configuration apply is
  observed separately from the registered endpoint restart path.
- `test_ptp_register_map.py`: every PyRogue field start/access mode against its
  local RTL decoder, child offsets, overlap and 4 KiB bank bounds; no PyRogue
  installation is required for these static checks.
- `test_ptp_port_samples.py` / `PtpPortWrapper`: direct production `PtpProtocolEngine` with
  exact independent Q16 forward expectations, one-/two-step correction equivalence,
  signed64 boundaries/widened sums, upper seconds bits, timestamp/flag rejection,
  mixed-mode collisions, capacity/expiry/sequence wrap, rate qualification,
  measurement stalls and lifecycle cancellation. The thin wrapper adds observation
  and backpressure at the port boundary; it contains no alternate protocol model.
- `test_ptp_port.py`: GMII/XGMII reordered/conflicting/foreign messages, bounded
  association replacement, timeout, grandmaster change and Announce metadata,
  plus one-step mode transitions and malformed/FCS-bad/truncated wire traffic.
- `test_ptp_endpoint.py`: independent master time with +100 ppm XGMII and
  −100 ppm GMII oscillators, acquisition with/without phase step, lock, holdover
  expiry and reacquisition in both receive modes. A known total correction is
  split between Sync and Follow_Up for two-step and carried by Sync for one-step;
  independent symmetric-path delay and absolute phase checks apply to each.
  A Python MAC model accelerates these long tests;
  production RX/TX physical timestamp RTL remains in the loop.
- `test_ptp_endpoint_mac.py`: the real `EthMacTop`, both PHY interfaces, primary
  traffic/identity guard, paused TX surviving port restart, late completion and
  fresh transaction recovery in one-step and two-step runs.
  `ptp_endpoint_test_utils.py` supplies shared wire
  stimulus and an independent physical request/FCS observer. One-step frame bodies
  use scheduled physical capture time from the independent simulation clock; the
  driver asserts agreement with the observed edge. Existing builders default to
  two-step, and the source uses `TWO_STEP=0` for one-step cases.

The endpoint tests use accelerated packet timers and fractional correction
fields; the numerical sweeps separately cover realistic default-gain intervals.
Neither is an FPGA timing or hardware accuracy measurement. Long real-MAC tests
can take several minutes on this machine. Use bounded workers, for example:

```sh
make MODULES="$PWD" import
./.venv/bin/python -m pytest -q -n 2 tests/ethernet/PtpCore
./.venv/bin/flake8 tests/ethernet/PtpCore python/surf/ethernet/ptp
```
