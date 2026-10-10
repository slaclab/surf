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
- `test_ptp_wire_vectors.py` anchors the shared Sync builder against four
  literal wire frames and both E2E reference solvers against three hand-worked
  examples. These are pure model/helper checks, not additional RTL or IEEE
  conformance results; provenance and remaining gaps are in the matrix below.
- `test_ptp_specification.py` provides seven short, separately selected RTL
  cases: literal RX packets/recovery, signed two-step corrections, minor versions,
  TLV suffixes, ignored control/reserved bits and complete Delay_Req bytes for
  both transmitted versions. The
  [source/applicability table](specification-coverage.md#source-backed-directed-checks)
  records verified 2019 clauses, 2008 compatibility and implementation policy;
  the remaining audit includes known scheduler, domain and profile gaps.

- `test_ptp_exchange.py` supplies eight focused configurations: ordinary multicast
  master byte anchors through RX; both editions and Sync modes through the actual
  protocol/ledger/E2E chain; correction-overflow retirement; and isolated response
  identity/sequence/domain/provenance mismatches with same-request recovery.
  `ptp_master_test_utils.py` supplies the source-backed master packets. Timestamp
  and raw-tick advances preserve 1 Hz Sync values while skipping idle simulation
  seconds; these are protocol-boundary checks, not a closed-loop servo run.
  See [exchange coverage](specification-coverage.md#ordinary-master-and-exchange-checks).

**Current authorization:** the maintainer lifted the simulation/pytest pause on
October 9, 2026. See the [resumed results](../../../docs/plans/ethernet-ptp/rtl-review.md#october-9-behavioral-verification)
and [one-step acceptance checklist](../../../docs/plans/ethernet-ptp/rtl-review.md#one-step-receive-acceptance).
The selected standards baseline is IEEE 1588-2019 with 2008 compatibility;
the [specification coverage matrix](specification-coverage.md) distinguishes
normative requirements, endpoint restrictions and implementation checks.

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

## Selecting tests

Default to focused tests chosen from the changed behavior and affected interfaces.
Do not run the full directory after every edit or as an automatic handoff check.
Before execution, state the selection and why it covers the change. Once it
passes, expand only if a failure, an uncovered interaction or the scope of the
change warrants it. Keep unrun acceptance work explicit.

| Change | First selection | Expand when needed |
| --- | --- | --- |
| Documentation or comments only | Links/anchors and diff whitespace; no pytest or simulation. | Executable behavior also changes. |
| Reference arithmetic or packet helpers | Relevant cases in `test_ptp_reference.py`, `test_ptp_endpoint_reference.py`, `test_ptp_rx_reference.py`, or `test_ptp_wire_vectors.py`. | Run a consuming RTL fixture when its stimulus/oracle behavior changes; model checks alone do not exercise cocotb drivers. |
| Ordinary master traffic | `test_ptp_exchange.py::test_master_headers` and affected `test_ordinary_master` edition/mode nodes. | Add a continuous PHY/PHC/servo run only when that interaction changes; raw-tick fixture results do not qualify hardware rates. |
| Sourced header, version, TLV or two-step checks | The relevant node/scenario in `test_ptp_specification.py` (RX or protocol). | Expand for affected PHY timing or normative cases absent from that fixture; the selected cases are not the whole standards audit. |
| Math, PHC, servo, E2E or ledger RTL | Corresponding leaf `test_ptp_<block>.py` and relevant independent reference cases. | Add affected consumers; select a closed-loop endpoint case for acquisition, stability or holdover changes. |
| Register descriptions or bank RTL | `test_ptp_register_map.py`; add `test_ptp_reg.py` for hardware behavior changes. | Select lifecycle integration when configuration/restart propagation changes. |
| Protocol policy or correction handling | Select `test_ptp_exchange.py::test_exchange_rejection` cases for overflow/response matching; `test_ptp_port_samples.py` for direct production-engine assertions. | Add affected `test_ptp_port.py` PHY cases for wire timing/serialization or physical-path behavior. |
| RX parsing, capture or PHY adapter | Relevant reference cases and `test_ptp_rx_rtl.py` configurations. | Add `test_ptp_rx_mac.py` or `test_ptp_mac_association.py` for MAC association, queues or reset interactions. |
| Endpoint control, shared bench, TX/MAC lifecycle | Smallest consuming fixture that exercises the changed path: port, closed-loop endpoint or real-MAC endpoint. | Cover additional PHY/mode configurations when their timing, clocking or branches are affected. |

Select by dependency and assertion coverage, not filename alone. For shared helper
changes, inspect callers; choose consumers that exercise each changed path.
GMII/XGMII and one-/two-step cases are not interchangeable when serialization,
capture timing or message association changes. A single case is useful during
iteration, but does not close acceptance for affected configurations left unrun.

The October 9 [runtime evidence](../../../docs/plans/ethernet-ptp/rtl-review.md#october-9-behavioral-verification)
shows why selection matters: direct protocol samples took about 25 seconds,
math/servo together about 65 seconds, and eight endpoint configurations about
39 minutes with six workers. These are observed batch times with concurrent
work, not per-case estimates or runtime guarantees. Long endpoint cases are
reserved for changes requiring those integration assertions; the full suite is
for substantial integration/release validation or an explicit request.

Run from the SURF root, using the existing configured Python environment; refresh
the HDL import only when missing or stale. For example, check the models alone:

```sh
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/PtpCore/test_ptp_reference.py tests/ethernet/PtpCore/test_ptp_rx_reference.py
```

For a math/servo change, select those two fixtures and run them concurrently:

```sh
./.venv/bin/python -m pytest -q -n 2 --dist=worksteal tests/ethernet/PtpCore/test_ptp_math.py tests/ethernet/PtpCore/test_ptp_servo.py
```

Use a quoted pytest node ID for one configuration, for example
`'tests/ethernet/PtpCore/test_ptp_port.py::test_ptp_port[GMII]'`.
Parallelize independent selected simulations, with workers bounded by the case
count and available CPU/memory. Use `-n 0` for tiny pure-model checks or serial
debug logs. Record selected cases/results; retain the rest as unrun rather than
reporting the previous full-suite result as validation of a later edit.

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
  Execution outcomes are tracked in the acceptance record linked above.
  Ledger capacity and response acceptance now have between-edge stability
  checks; response completion must pulse for the submitted response.
- `ptp_endpoint_reference.py`, `test_ptp_endpoint_reference.py`: rational
  calibration, raw-tick rate estimator and PI models; operating-envelope sweeps.
- `test_ptp_servo.py`: every emitted rate command against the independent PI
  model at varied sample intervals, median startup, backpressure and holdover.
  It also checks registered command/cancellation/expiry stability between edges.
  `test_ptp_phc.py` exercises revocation after admission and expiry priority over
  validity-setting commands. Execution outcomes are tracked in the acceptance record.
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

The older endpoint helper intentionally retains legacy received controls and
unspecified intervals for accelerated functional tests; it is not the nominal
standards-valid master. The separate exchange fixture checks normal header and
interval values without replaying the long servo/MAC lifecycle scenarios.

The endpoint tests use accelerated packet timers and fractional correction
fields; the numerical sweeps separately cover realistic default-gain intervals.
Neither is an FPGA timing or hardware accuracy measurement. Cases have isolated
build directories. When full-suite validation is warranted by the selection
policy above, use parallel execution:

```sh
make MODULES="$PWD" import
./.venv/bin/python -m pytest -q -n auto --dist=worksteal tests/ethernet/PtpCore
```

Run flake8 on changed Python files; run VHDL lint and test-structure checks as
required by the shared guides. These static checks do not require a full
behavioral regression.
