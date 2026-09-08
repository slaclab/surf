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
- `test_ptp_rx_mac.py` runs the RX RTL beside the unchanged MAC under the
  original CRC loss, duplicate, FIFO pressure, and retained-head scenarios.
- `ptp_rx_test_utils.py` supplies independent frame/FCS fixtures and record
  packing for both reference and RTL tests.

Run from the repository root after importing HDL sources:

```sh
./.venv/bin/python -m pytest -n 0 -q --log-cli-level=INFO tests/ethernet/PtpCore
```

The counterexample tests pass when they demonstrate the rejected algorithm's
failure. They must not be mistaken for successful timestamp-association RTL.
Large simulator logs stay in `tests/sim_build` or temporary storage; durable
results and remaining gates are in the
[Phase 0 record](../../../docs/plans/ethernet-ptp/phase-0-experiments.md).
Follow the [test guidance](../../README.md) for changes and new regressions.

The [RX design decision](../../../docs/plans/ethernet-ptp/rx-frontend-design.md)
records the selected replacement and its physical producer contract.
Current RTL results and synthesis limits are in the
[RX implementation record](../../../docs/plans/ethernet-ptp/rx-rtl-proof.md).
Run the models alone without starting a simulator:

```sh
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/PtpCore/test_ptp_reference.py tests/ethernet/PtpCore/test_ptp_rx_reference.py
```

## Autonomous endpoint tests

- `test_ptp_math.py`, `test_ptp_phc.py`: checked arithmetic and cycle-by-cycle PHC
  comparison, command/reset ordering, PPS and independent-clock snapshot sessions.
- `test_ptp_e2e.py`, `test_ptp_tx_ledger.py`: independent full-width E2E vectors,
  calibration across PHC steering, keyed response/completion reordering, narrow
  sequence wrap, unknown physical fate and reset/quarantine behavior.
- `ptp_endpoint_reference.py`, `test_ptp_endpoint_reference.py`: rational
  calibration, raw-tick rate estimator and PI models; operating-envelope sweeps.
- `test_ptp_servo.py`: every emitted rate command against the independent PI
  model at varied sample intervals, median startup, backpressure and holdover.
- `test_ptp_reg.py`: raw AXI-Lite alignment/strobes, atomic shadows, coherent
  snapshots, immutable queued commands, bus-only reset and MAC identity changes.
- `test_ptp_port.py`: physical reordered/conflicting/foreign messages, bounded
  association replacement, timeout, grandmaster change and Announce metadata.
- `test_ptp_endpoint.py`: independent master time with +100 ppm XGMII and
  −100 ppm GMII oscillators, acquisition with/without phase step, lock, holdover
  expiry and reacquisition. A Python MAC model accelerates these long tests;
  production RX/TX physical timestamp RTL remains in the loop.
- `test_ptp_endpoint_mac.py`: the real `EthMacTop`, both PHY interfaces, primary
  traffic/identity guard, paused TX surviving port restart, late completion and
  fresh transaction recovery. `ptp_endpoint_test_utils.py` supplies shared wire
  stimulus and an independent physical request/FCS observer.

The endpoint tests use accelerated packet timers and fractional correction
fields; the numerical sweeps separately cover realistic default-gain intervals.
Neither is an FPGA timing or hardware accuracy measurement. Long real-MAC tests
can take several minutes on this machine. Use bounded workers, for example:

```sh
make MODULES="$PWD" import
./.venv/bin/python -m pytest -q -n 2 tests/ethernet/PtpCore
./.venv/bin/flake8 tests/ethernet/PtpCore python/surf/ethernet/ptp
```
