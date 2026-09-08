# PTP Phase 0 experiments

This suite validates planning assumptions before production PTP RTL exists.

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
records the selected replacement and the remaining physical producer proof.
Run the models alone without starting a simulator:

```sh
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/PtpCore/test_ptp_reference.py tests/ethernet/PtpCore/test_ptp_rx_reference.py
```
