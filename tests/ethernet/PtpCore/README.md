# PTP endpoint verification

This suite contains independent reference models, leaf RTL scoreboards,
physical protocol tests and autonomous endpoint/MAC regressions. The
[implementation record](../../../ethernet/PtpCore/architecture.md)
separates simulated behavior from remaining device and interoperability work.

- `test_ptp_mac_association.py` drives real XGMII frames through `EthMacTop`
  using `EthMacPtpExperimentWrapper`, with Python capture/association models.
  It checks CRC-loss ambiguity, byte order, FIFO pressure and recovery, and
  queued TX after logical restart and repeated pause.
- `test_ptp_mac_port.py` runs the timing-port composition `PtpMacPortEthMac`
  for GMII and XGMII with passive-adapter oracles on both pin directions and
  a cycle-accurate PHC model (`ptp_mac_port_test_utils.py`). It checks
  bit-identical captures under RATE/SET/PHASE commits and capture aborts
  around the pin cycle, every TX stream-shape rule and outcome, RX
  dispositions and table exhaustion, drain and the forced-abort procedure.
  The MAC-side timing leaves, retires and abort handshake have their own
  `test_EthMacTiming*.py` benches under `tests/ethernet/EthMacCore`.
- `test_ptp_mac_port_contract.py` independently checks all bits of the capture,
  RX metadata and TX completion encodings and initializers, then drives the
  real port through every transport generation to exhaustion using public
  abort acknowledgements. It checks closed admission, retained exhaustion
  and system-reset recovery without forcing internal state.
  Select `-k record_layouts` for a packing-only change. The exhaustive lifecycle
  sweep requires `RUN_PTP_GENERATION_EXHAUSTION=1` and `-k generation_exhaustion`;
  it traverses all 65,534 abort handshakes and is excluded from routine runs.
  Add `--log-cli-level=INFO` to see its generation milestones while it runs.
- `test_ptp_mac_port_rx_errors.py` checks good/bad-FCS/good IPv4/UDP traffic
  with checksum checking enabled, stalled RX delivery and token reuse on
  both PHYs. The wire-error verdict must survive the legacy checksum stage's
  EOFE overwrite; rejected frames retain ownership until retirement.
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
  cycle, through direct, GMII, and XGMII inputs. It uses the model's
  `PipelinedRxFrontend`, which adds the RTL's input packer and one-edge
  completion stage to the same logical results. It additionally checks whole
  frame acceptance and independent capture timing, signed calibration, reset,
  abort priority, byte phase, and minimum-gap throughput.
  The registered-boundary follow-up also checks output stability between edges.
  Its scoreboard distinguishes a detection-edge head transfer from the abort
  consumed on the following edge, including full-queue consume/overflow.
- `test_ptp_rx_mac.py` runs the RX RTL beside the unchanged MAC under the
  original CRC loss, duplicate, FIFO pressure, and retained-head scenarios.
  Both legacy MAC fixtures explicitly load `EthMacPtpExperimentWrapper` and
  its `PtpRxFrontendWrapper` dependency; neither test wrapper is imported by
  the EthMacCore/PtpCore ruckus manifests.
- `test_ptp_rx_storage.py` checks the dedicated two-entry TX observer:
  lossless capture increment/error storage, pointer wrap, generation retention,
  simultaneous consume/enqueue, fixed-length compact-store decoding, consumption and
  reset/flush throughout the write/read pipeline, full-before-edge discard
  and malformed keep/TLV rejection. TLV payload runs, zero/two-length header
  lookahead and split 254/256-byte lengths are checked at every beat width;
  identity, major/minor-version, fixed-body length and FCS cases cover the
  specialized observer's early header checks.
  The RX oracle additionally covers depths one through four, six and seven
  (including the sparse-store address-width boundary), and partial normalized
  beats of every width.
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
  the remaining audit includes the known scheduler departure and profile gaps.

- `test_ptp_domain.py` checks prepare/apply boundaries at domains 0, 127, 128
  and 255 for non-isolated sdoId=000, including continued traffic on the active
  configuration after an invalid candidate.
- `test_ptp_scheduler.py` checks interval scaling, local floors and restart
  determinism through production `PtpDelayReqTx`. A separate strict expected
  failure exposes the default multicast distribution departure using two seeds
  and 512 intervals each. Only the distribution assertion is expected to fail;
  mean-rate, compilation, serialization or progress failures remain real failures.
  This observes stream offers with raw time controlled, not physical wire timing.
- `test_ptp_disturbance.py` checks both oscillator signs and both Sync modes
  through the production protocol/rate engine: 8 Hz timestamps, 100–120 ppm
  drift, signed packet-delay variation, an 800 ns path step, a 100 us outlier,
  four missing Syncs and exact ratio expiry while the port remains active.
  An independent rational oracle checks samples and freshness. Idle raw time is
  skipped; continuous PHC/servo phase-error and holdover bounds remain open.
  A final rejected estimate followed by expiry checks that rejection cannot
  renew ratio freshness, even when the ratio value itself remains unchanged.

- `test_ptp_exchange.py` supplies eight focused configurations: ordinary multicast
  master byte anchors through RX; both editions and Sync modes through the actual
  protocol/ledger/E2E chain; correction-overflow retirement; and isolated response
  identity/sequence/domain/provenance mismatches with same-request recovery.
  `ptp_master_test_utils.py` supplies the source-backed master packets. Timestamp
  and raw-tick advances preserve 1 Hz Sync values while skipping idle simulation
  seconds; these are protocol-boundary checks, not a closed-loop servo run.
  See [exchange coverage](specification-coverage.md#ordinary-master-and-exchange-checks).
- `test_ptp_delay_req_tx.py` exercises the production protocol/ledger/TX chain:
  cancellation before and on reservation acceptance, and restart/AXI reset with
  every frame beat stalled. Literal wire bytes and held sidebands check that
  logical cancellation preserves an accepted physical frame.

**Current authorization:** the maintainer lifted the simulation/pytest pause on
October 9, 2026. See the [resumed results](../../../docs/plans/ethernet-ptp/history/verification.md#october-9-baseline)
and [one-step acceptance checklist](../../../docs/plans/ethernet-ptp/acceptance.md#one-step-receive-acceptance).
The selected standards baseline is IEEE 1588-2019 with 2008 compatibility;
the [specification coverage matrix](specification-coverage.md) distinguishes
normative requirements, endpoint restrictions and implementation checks.

The counterexample tests pass when they demonstrate the rejected algorithm's
failure. They must not be mistaken for successful timestamp-association RTL.
Simulation wrappers are supplied explicitly by each fixture through
`extra_vhdl_sources`; they are not loaded by the production ruckus manifest.
The shared runner puts GHDL outputs under ignored `tests/sim_build/ethernet/PtpCore/`.
Large simulator logs stay there or in temporary storage; durable
historical results are in the
[Phase 0 record](../../../docs/plans/ethernet-ptp/history/verification.md#capture-boundary-experiments).
Follow the [test guidance](../../README.md) for changes and new regressions.

The [RX design decision](../../../ethernet/PtpCore/architecture.md#rx-message-and-capture-boundary)
records the selected replacement and its physical producer contract.
Historical RTL results and synthesis limits are in the
[RX evidence record](../../../docs/plans/ethernet-ptp/history/verification.md#capture-boundary-experiments).

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
| Shared arithmetic services | `test_ptp_arithmetic_services.py` SECOND/variable cases; add affected PHC, servo, E2E or rate/protocol cases. | Direct service tests check contention/cancellation; endpoint integration is still needed for client interactions. |
| Register descriptions or bank RTL | `test_ptp_register_map.py`; add `test_ptp_reg.py` for hardware behavior changes. | Select lifecycle integration when configuration/restart propagation changes. |
| Protocol policy or correction handling | Select `test_ptp_exchange.py::test_exchange_rejection` cases for overflow/response matching; `test_ptp_port_samples.py` for direct production-engine assertions. | Add affected `test_ptp_port.py` PHY cases for wire timing/serialization or physical-path behavior. |
| Delay_Req scheduler or transmitter | `test_ptp_scheduler.py` for interval policy/distribution; `test_ptp_delay_req_tx.py` for stream lifecycle; ordinary exchange cases for wire fields. | Select `test_ptp_port.py -k tx_restart` for both PHYs' stream integration; real-MAC cases when downstream queue/reset behavior changes. |
| Domain admission or rate dynamics | `test_ptp_domain.py` for candidate boundaries; `test_ptp_disturbance.py` for drift, path variation, loss and freshness. | Add continuous endpoint cases for PHC/servo phase-error bounds; raw-tick tests alone do not establish them. |
| PHC subsystem: owner/admission, coordination, resets, qualification/PPS (`PtpPhcCore`, `PtpPhcControl`, `PtpPhc` admission) | `test_ptp_phc_core.py` (all four mode cases); `test_ptp_phc.py` when cycle semantics change; `test_ptp_reg.py` for enclosing coordination. | `test_ptp_phc_mac_port.py` (both PHYs) when the live tuple or capture inhibition changes; affected endpoint/servo cases when servo ownership or expiry changes. |
| PHC carry/normalization or unsigned age arithmetic | `test_ptp_timing_math.py` for integer boundary/random oracles; `test_ptp_phc.py` for cycle semantics and epoch faults. | Add protocol expiry and servo cancellation cases when the shared age predicate changes. |
| Protocol rejection counting or interval decoding | `test_ptp_protocol_ram.py` concurrent-rejection scenario; `test_ptp_intervals.py` for receipt deadlines, caps and invalid/unspecified encodings. | Add `test_ptp_exchange.py` response-association and direct protocol cases for accepted-response metadata or cancellation changes. |
| Sync history or pairing storage/arbitration | Affected scenarios/settings in `test_ptp_protocol_ram.py`; `test_ptp_port_samples.py` for correction, collision and capacity semantics. | Select exchange consumers and a PHY/MAC case when backpressure or publication timing changes. |
| RX parsing, capture or PHY adapter | Relevant reference cases and `test_ptp_rx_rtl.py` configurations. | Add `test_ptp_rx_mac.py` or `test_ptp_mac_association.py` for MAC association, queues or reset interactions. |
| Timing-port RTL backend (`PtpMacPortRxAdapter`, `PtpMacPortTxAdapter`, `PtpMacPortEndpoint`, `PtpRxFrontend` no-FCS mode, `MAC_MODE_G`) | `test_ptp_mac_port_adapters.py` (both PHYs); `test_ptp_endpoint_mac.py` `TIMING_PORT` cases. | Tapped `test_ptp_endpoint_mac.py` and `test_ptp_rx_rtl.py` when shared frontend or composition code changes. |
| Telemetry (`PtpTelemetry`, record format) | `test_ptp_telemetry.py`. | Endpoint/composition cases when the observed signals or `TELEMETRY_EN_G` plumbing change. |
| Timing port (`PtpMacPort*`, `PtpMacPortEthMac`) or MAC timing mode | `test_ptp_mac_port.py` for the affected PHY; the matching `tests/ethernet/EthMacCore/test_EthMacTiming*.py` for leaf, retire or abort changes. | Run both PHY cases when capture timing, lanes or serialization change. |
| Endpoint control, shared bench, TX/MAC lifecycle | Smallest consuming fixture that exercises the changed path: port, closed-loop endpoint or real-MAC endpoint. | Cover additional PHY/mode configurations when their timing, clocking or branches are affected. |

Select by dependency and assertion coverage, not filename alone. For shared helper
changes, inspect callers; choose consumers that exercise each changed path.
GMII/XGMII and one-/two-step cases are not interchangeable when serialization,
capture timing or message association changes. A single case is useful during
iteration, but does not close acceptance for affected configurations left unrun.

The October 9 [runtime evidence](../../../docs/plans/ethernet-ptp/history/verification.md#october-9-baseline)
shows why selection matters: direct protocol samples took about 25 seconds,
math/servo together about 65 seconds, and eight endpoint configurations about
39 minutes with six workers. These are observed batch times with concurrent
work, not per-case estimates or runtime guarantees. Long endpoint cases are
reserved for changes requiring those integration assertions; the full suite is
for substantial integration/release validation or an explicit request.

An October 15 runtime investigation found inherited fixed delays in the physical
port fixtures. The shared-compute migration (`52dfa266f`) increased per-frame
waits from 160 to 9,000 clocks and shared-bench Sync spacing from 2,200 to 30,000.
Those delays survived the fixed-function arithmetic replacement. The two
original `test_ptp_port.py` scenarios contained 678,000 fixed wait clocks per PHY,
before serialization, AXI operations and smaller waits.

A short GMII probe of the TX-extraction working tree over `a3f821fd9`, using
Python 3.12.7/GHDL 6.0.0, observed three two-step Sync completions through AXI
snapshots after 344, 476 and 476 clocks from the start of packet injection.
These samples are not worst-case bounds. Batching a 1,000-clock idle wait into
one timer reduced its mean wall time from 5.90 to 5.52 seconds across two trials
each; a CPU sample showed substantial GHDL signal/event bookkeeping. Avoiding
unnecessary HDL cycles matters more than removing Python wakeups in this probe.

Replace blanket service waits with bounded checks of the completion relevant to
the assertion. Rejected-frame checks must observe ingress retirement and a
defined no-result window; an unchanged counter alone cannot establish completion.
Keep timeout/expiry boundary checks explicit, and use controlled raw ticks in
protocol fixtures when PHC continuity is not under test. Preserve continuous
physical clocks for capture, MAC queuing, servo dynamics and clock-control checks.
Do not globally shorten shared Sync spacing or acceptance limits based on the
three latency samples. The larger endpoint/MAC schedule still needs its own
coverage review. The original long GMII/XGMII runs were interrupted; diagnostic
scripts/profiles remain in the consuming project's ignored
`.planning/ptp-sim-runtime/` cache, outside the maintained test suite.

The port fixture now waits for actual frontend/engine transfers and polls AXI
snapshots for expected Sync publication. Invalid wire frames must increment the
frontend drop counter without a protocol transfer; policy-invalid frames must
retire and increment the protocol rejection counter before checking no Sync result.
The old 9,000-clock allowance
is retained as a failure timeout. Receipt expiry uses a separately configured
2,048-clock interval, and TX qualification uses 1,000-clock spacing above its
800-clock minimum rate span. Closed-loop endpoint/MAC fixtures retain their
30,000-clock spacing at that stage; the endpoint follow-up below replaces it.
Association/expiry, mixed-mode policy and TX restart are
separate pytest scenarios so a TX change can select just `tx_restart` on each PHY.

All six scenarios passed in 278.24 s including their new builds; after adding
explicit protocol-rejection checks, the two affected policy cases passed in
56.54 s. Final scenario results total 21,114 simulated clocks on XGMII and
25,406 on GMII, compared with the old 678,000 fixed wait clocks alone per PHY.
This removes about 96–97% of that cycle cost while retaining physical clocks,
packet checks, expiry and stalled-frame assertions. The old full run was
interrupted, so this is a cycle-count comparison, not a measured wall-time speedup
against a completed old batch. No full closed-loop endpoint/MAC rerun is implied.

The protocol fixtures also use completion-driven negative checks. Previously,
`Bench.no_result()` always waited 512 clocks and `ExchangeBench.no_delay()`
always observed 16,000 clocks, including sixteen repetitions per RAM mode in
history cancellation. They now check public measurement valid on every edge and
require the consumer to hold ready low, so an unwanted result cannot disappear.
The endpoint for observation is actual retirement:

- Sync checks wait for idle pair/history/append/coordinator state and both
  arithmetic clients' ready/valid interfaces to drain.
- Delay checks first wait for held ledger inputs to retire and observe a complete
  ledger sweep with the downstream pipeline idle throughout, using two row-zero
  RAM-read admissions. A previously blocked row must get another publication
  opportunity. This works even when the
  ledger is full or allocation is quarantined; allocation ready is insufficient.
- Four subsequent quiet edges drain registered handoffs and diagnostic counting.
  The 16,000-cycle limit remains a failure timeout rather than a fixed delay.

Internal signals establish completion only; expected payloads, counts and
recovery still come from public interfaces and independent arithmetic. Raw ticks
stay fixed during these waits. An incomplete pair or unresolved wire key cannot
produce a new measurement without another input. These conditions are specific
to the direct protocol fixture and must not replace continuous-clock endpoint or
PHY observations. `negative_guard_retirement` intentionally offers valid Sync
and Delay work to both negative checks: each must detect the late measurement,
which is then verified with the ordinary result oracle. Run it when changing
these completion checks. All sixteen history-cancellation phases remain selected.

Measured October 15 on the refined protocol-split working tree over `a3f821fd9`,
using Python 3.12.7/GHDL 6.0.0: the same fourteen table configurations with
`-n 3 --dist=worksteal` passed in **458.24 s before and 167.65 s after** this
change (63% less wall time, including builds). Their summed cocotb case times,
excluding builds, fell from **792.414 s to 379.976 s** (52%). Build-cache and host
load differences affect wall time; these are observed local runtimes, not fixed
performance budgets or a full-suite benchmark. The matched selection excludes
`history_cancellation` and the new `negative_guard_retirement` scenario; those
are validated separately with all sixteen cancellation phases retained per RAM
mode and both late-result guard checks.

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
`'tests/ethernet/PtpCore/test_ptp_port.py::test_ptp_port[tx_restart-GMII]'`.
Parallelize independent selected simulations, with workers bounded by the case
count and available CPU/memory. Use `-n 0` for tiny pure-model checks or serial
debug logs. Record selected cases/results; retain the rest as unrun rather than
reporting the previous full-suite result as validation of a later edit.

### Endpoint/MAC runtime follow-up

The October 15 review follow-up removes inherited long waits from the two
integration fixtures. The model-MAC endpoint formerly had 26 × 30,000 Sync wait
clocks plus a 250,000-clock holdover wait: **1,030,000 fixed wait clocks** before
packet/configuration overhead. The real-MAC lifecycle fixture inherited seven
30,000-clock waits despite not testing servo settling.

Each source caller now supplies its cadence explicitly; `Bench.source()` has no
default wait. The endpoint uses 1,000-clock Sync spacing, above its configured
800-clock rate observation and 500-clock servo sample minima, a 2,000-clock
request interval and an 8,000-clock holdover timeout. Physical clocks, nominal
PHC increment, oscillator errors, PI gains, both Sync modes and all phase/delay
assertions remain. Link loss must enter holdover while time remains valid, then
expire without changing generation or letting a stale command restore validity.
The test waits for expiry with a bound instead of sleeping beyond it.

The real-MAC test uses the same explicit Sync spacing and checks the actual
bypass FIFO final write before resetting the port. It observes completion of
both ledger input scans, forbids a stale delay offer on every edge, then checks
the public delay counter and fresh recovery. Internal signals establish test
progress; packet contents, timestamps and counters remain independent result
checks. The 9,000-clock limits are failure bounds, not mandatory delays.

Initial two-step XGMII probes passed: endpoint **320.88 s including build**
(about 34,850 simulated clocks), MAC **181.38 s with a cached build** (raw tick
9,675 at completion). These cycle costs are about 96.6% and 95.4% below the old
fixed waits alone. They are not matched wall-time speedup measurements: the
original eight-case batch was interrupted after 1,851.98 s without a completed
case. Final mode/PHY outcomes belong in the
[verification record](../../../docs/plans/ethernet-ptp/history/verification.md#october-15-test-suite-follow-up).

These were already accelerated functional tests. Neither the old long waits
nor the shorter settings qualify default-interval settling, a continuous
disturbance envelope or hardware accuracy. Use focused clock/PHY/mode nodes
during development; reserve all eight configurations for affected integration
validation. Do not restore blanket settling delays without a requirement and
an observable completion condition.

## Autonomous endpoint tests

- `test_ptp_const_divide.py`, `test_ptp_epoch_normalize.py`,
  `test_ptp_limb_product.py` and `test_ptp_tree_product.py`: production arithmetic
  against independent integers, including full-width overflow, exact rounding,
  operand capture, stalls and cancellation. Constant division covers odd and
  maximum 64-bit divisors as well as the endpoint conversions.
- `test_ptp_arithmetic_services.py`: both production shared services with
  independent per-owner scoreboards, round-robin contention, asymmetric held
  responses, reset recovery and cancellation at every execution cycle.
- `test_ptp_timing_math.py`: production compatibility-adder sums at 64/66/67 bits
  and native modulo-tick expiry against Python integers, including every
  word boundary, wrapped/future timestamps, equality and seeded random inputs.
- `test_ptp_math.py`, `test_ptp_phc.py`: checked arithmetic and cycle-by-cycle PHC
  comparison, command/reset ordering, PPS and independent-clock snapshot sessions.
  Math cancellation checks also assert that result-valid stays stable before
  the cancellation edge, including when a completed result is stalled.
  Math covers the default 128-bit divisor magnitude and bounded widths 46/1,
  exact work-cycle counts and zero/out-of-bound rejection. PHC RATE boundary
  cases compare commit-edge time and the published increment independently.
  Snapshot edge cases retain that cycle oracle while capturing SET/PHASE/RATE/VALID
  commits, invalidation and configuration apply; both reset styles are covered.
- `test_ptp_e2e.py`, `test_ptp_tx_ledger.py`: independent full-width E2E vectors,
  calibration across PHC steering, keyed response/completion reordering, narrow
  sequence wrap, unknown physical fate and reset/quarantine behavior.
  Added checks cover registered result/sample validity during cancellation and
  ledger occupancy alignment with allocation, wire completion and MAC reset.
  Execution outcomes are tracked in the acceptance record linked above.
  E2E covers both-zero, each-single-zero and both-nonzero calibration with
  signed corrections, full epochs and cancellation through the shared timestamp
  stages. The same sweep runs with raw timestamps and the production normalized
  history stream; each nonzero plane uses its own captured PHC increment.
  Ledger storage checks additionally cover full capture/response payloads,
  depths one/three/four, inferred distributed/block settings, reordered/simultaneous
  arrivals, consecutive records with valid held high, concurrent row writes/reads,
  output stalls and row reuse, and cancellation at every scan phase. Narrow-key
  exhaustion checks sequence collisions and stored identities across configuration
  changes. A duplicate arriving after scan start must retire the waiting sample
  before publication. Counter cases check swept timeout/rejection multiplicity and distinguish
  logical/MAC reset from system reset. Age cases also check full-width unsigned
  timestamps, response-before-wire and inclusive packet-lifetime boundaries.
  Ledger capacity and response acceptance now have between-edge stability
  checks; response completion must pulse for the submitted response.
- `ptp_endpoint_reference.py`, `test_ptp_endpoint_reference.py`: rational
  calibration, raw-tick rate estimator and PI models; operating-envelope sweeps.
- `rate_feedback_study.py`: deferred standalone integer exploration of residual and
  phase/rate feedback estimators against the current ratio oracle. Run with
  `python -m tests.ethernet.PtpCore.rate_feedback_study`; optional `--csv` saves
  traces. This is not a production oracle or RTL regression. Assumptions and
  results are in the [feedback study](../../../docs/plans/ethernet-ptp/history/design-studies.md#arithmetic-alternatives).
- `test_ptp_servo.py`: every emitted rate command against the independent PI
  model at varied sample intervals, median startup, backpressure and holdover.
  Positive and negative fractional delay asymmetry is configured through AXI;
  corrected offsets and resulting PI commands retain independent expectations.
  Clock parameters cover 125 MHz, 156.25 MHz and a standalone 31.25 kHz
  arithmetic corner that needs a 47-bit nominal divisor; the MAC clocks need
  46-bit seconds/ppb divisors. Injected raw ticks keep numerical intervals
  independent of simulation runtime; the low-clock case is not a PHY mode.
  Direct median checks cover every ordering of five distinct values, each
  startup population, duplicates, signed64 maximum, circular replacement and
  rejected samples. They check the nine-comparison shared-service sort, input backpressure,
  held-valid transfers, cancellation during sorting, AXI-only reset
  and snapshots across publication. PI cases include fractional half ties,
  maximum gains and signed64 offsets, checked integral overflow and cancellation
  around the shared clamp/rounding stages; Q16 rate state is checked before
  PHC-addend quantization.
  It also checks registered command/cancellation/expiry stability between edges.
  `test_ptp_phc.py` exercises revocation after admission and expiry priority over
  validity-setting commands. Execution outcomes are tracked in the acceptance record.
  PHC checks additionally require registered ready/ack/error/capture inhibition;
  cancellation excludes transfer without requiring ready to change mid-cycle.
- `test_ptp_phc_core.py`: the real standalone `PtpPhcCore` through AXI and its
  external port at 125 MHz with a nonzero base, 156.25 MHz behind an
  independent management clock (both `CONTROL_MODE_G = "SELECTABLE"`), fixed
  `"AXI"` at 156.25 MHz and fixed `"EXTERNAL"` behind the crossing. Scenarios
  that need an absent path are skipped explicitly per mode. A
  lockstep checker compares every cycle with `PhcModel`, applying each command
  on its acknowledged edge, and requires capture inhibition exactly one edge
  before SET/PHASE commits. Scenarios cover identity/capabilities, manual
  commands, non-owner offers with no slot/inhibition/validity effect, external
  vetoes (cancel, restart, held abort, stale generation), owner commits swept
  against a continuously offering client (including admission on the prepare
  edge), AXI/management reset during normalization and transition, a
  management reset swept across an in-flight read (later reads must complete),
  snapshot/commit collisions, VALID/clearValid/PPS on the rollover edge and
  system-reset recovery. Mutations of owner-gated ready, owner-gated
  `clearValid`, the PHASE result handshake and the drain wait each fail it.
- `test_ptp_phc_mac_port.py`: the real core driving `PtpMacPortEthMac` and both
  passive oracles (GMII/125 MHz, XGMII/156.25 MHz). External RATE/SET/PHASE
  commits land on scheduled edges around a looped-back frame's pin cycle; port
  captures equal the oracles, inhibition and mid-frame steps invalidate
  captures without changing the SENT outcome, every request completes once
  after wire done, and unqualified captures are usable. Removing SET/PHASE
  admission inhibition fails it.
- `test_ptp_telemetry.py`: `PtpTelemetry` through a flat-port wrapper against
  a cycle model of its buffers, sequence numbers, drops, event coalescing and
  serializer: every output word, SOF, last and the dropped count must match on
  every cycle. Scenarios cover spaced traffic, a state change during a command
  capture, PHC and state events coalescing behind a busy buffer, and held and
  random backpressure. Mutations of the servo capture edge, the drop sequence
  gap, the busy check, PHC deferral and state deferral each fail it.
- `test_ptp_endpoint.py` also enables telemetry and checks the real servo's
  records: each RATE record's status rate converts to its own command, and its
  PHC header already carries that rate (capture two edges after acceptance;
  capturing on the acceptance edge fails), path-delay records' forward values
  equal t2 - (t1 + cSync) of their exchange, and sequence numbers are whole
  with no drops.
- `test_ptp_mac_port_adapters.py`: `PtpMacPortEthMac` with both RTL-backend
  adapters against `PtpRxTimestampTap`/`PtpTxTimestampTap` on the same pins
  (GMII and XGMII, nonzero calibration). With a steady PHC the adapter RX and
  TX record streams equal the taps' bit for bit, including capture increment
  and error, across message types, TLVs, length limits, non-PTP, bad-CRC, runt
  and lane-4 frames. Under scheduled RATE/SET/PHASE/abort commits the only
  differences are the documented ones (store-and-forward staleness, preamble
  steps, invalidated TX captures). Table backpressure never loses a record,
  and frames that never reach the wire yield none and free their slot. At the
  default RX depths, minimum-length frames at the minimum IFG behind maximum
  frames are all delivered, and a wire start sampled on the edge a release
  lowers the offered token is admitted; every frame is accounted for in the
  port counters. The port bank reports capability, status, controller levels,
  TX/RX occupancy with high-water marks and clear, and counters equal to the
  port's, and refuses unmapped and read-only writes. Mutations of the capture alignment, the SENT-only record
  rule, the invalid capture error, the no-FCS length compensation, the
  sampled-token check, the frontend `frameReady` gate and its hold on an
  offered beat each fail it.
- `test_ptp_endpoint_mac.py`: both MAC builds. The timing-port lifecycle repeats
  the tapped pause, queued-request restart, stale-response retirement and
  recovery checks without application traffic.
- `test_ptp_reg.py`: all five endpoint register banks (including the PHC core
  control bank) at zero and nonzero bases, SURF
  field-strobe/address-alias/error behavior, immutable commit candidates, cross-bank
  atomicity, coherent snapshot sequences, queued commands and bus-reset recovery.
  Every moved configuration/snapshot word and the derived association floor are
  exercised, including byte writes while a candidate is frozen and reads held
  across publication. Snapshot requests must remain stable between edges;
  configuration apply is observed separately from the registered endpoint restart path.
  The fixture composes the production `PtpPhcCore` under endpoint coordination,
  matching the production endpoint, and checks that its local submissions are
  refused. A fixed `CONTROL_MODE_G = "EXTERNAL"` case checks the read-only
  owner, absent manual steering and operands, retained PPS, and that
  `ServoEnable` stops the servo without granting AXI steering. Manual phase tests retain all signed128 submission
  words and check the signed96 admission boundary separately from later epoch faults.
- `test_ptp_register_map.py`: every PyRogue field start/access mode against its
  local RTL decoder (including the protocol bank in `PtpProtocolReg`), plus
  exact widths/access and signedness against the documented ABI and an explicit
  signed-field inventory. It also checks touch-one command semantics, child
  offsets, overlap and 4 KiB bank bounds. Eight in-memory mutations prove rejection
  of width, signedness, access and command regressions. No PyRogue installation
  is required; these static checks do not replace hardware bus or live transport tests.
- `test_ptp_port_samples.py` / `PtpProtocolEngineWrapper`: direct production `PtpProtocolEngine` with
  exact independent Q16 forward expectations, one-/two-step correction equivalence,
  signed64 boundaries/widened sums, upper seconds bits, timestamp/flag rejection,
  mixed-mode collisions, capacity/expiry/sequence wrap, rate qualification,
  measurement stalls and lifecycle cancellation, including cancellation in both
  timestamp-conversion stages and the inclusive completion-age boundary. The thin wrapper adds observation
  and backpressure at the port boundary; it contains no alternate protocol model.
  Distributed and block RAM settings exercise the same pairing/history contract.
  Announce snapshot cohorts cover body/metadata publication, capture during
  upload, repeated bank reuse and restart on the common capture edge.
- `test_ptp_protocol_ram.py`: both table RAM settings, nearest selection on either
  side of TX capture, wrapped-slot ties, RX/TX fractional phases, history age and
  separation rejection, concurrent append, cancellation throughout both scans,
  generation recovery, E2E publication during continuous rejected RX traffic
  and pairing expiry at the scan-start boundary. Concurrent RX/E2E rejection
  must increment twice on one edge; restart/AXI reset retain counts and system
  reset clears them. Word-arithmetic cases check Q3/tick carries, unsigned MSBs,
  modulo age across tick wrap, inclusive separation above 64 Q3 bits, oldest-row
  replacement, concurrent pair/history ownership and cancellation in ALU stages.
  RAM enables are observed only to establish overlapping stimulus. Exact public
  measurements and snapshots are checked independently of RAM contents.
- `test_ptp_intervals.py`: all 256 Announce log-interval encodings with large
  and small receipt caps, plus selected Sync boundaries at 125 MHz. Python integer
  periods check inclusive deadlines, negative-exponent rounding, invalid fallback
  and unspecified `0x7f` without rejection.
- `test_ptp_port.py`: GMII/XGMII reordered/conflicting/foreign messages, bounded
  association replacement, timeout, grandmaster change and Announce metadata,
  plus one-step mode transitions and malformed/FCS-bad/truncated wire traffic.
  The separate `tx_restart` scenario qualifies real physical Sync captures and
  checks every stalled/drained Delay_Req beat and retained ledger ownership.
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
  These long cycle-level fixtures select zero propagation delay through the
  wrapper's `TPD_PS_G` parameter to reduce event scheduling. Its default remains
  1000 ps; leaf and model-MAC endpoint cases retain their 1 ns timing checks.
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
