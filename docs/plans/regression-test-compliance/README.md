# Regression Test Compliance

## Goal And Status

Bring the existing cocotb regression code into closer alignment with the
authoritative [test guidance](../../../tests/README.md) without deleting
coverage, hiding scenarios, or attempting a disruptive whole-tree rewrite.

Status: implementation is in progress on `verification-2-test-compliance`.
Phase 0 delivered the structural audit, preservation-report comparison, and
checked-in baseline ratchet under `tests/common/`. This branch was created from
`verification-2` so the implementation can use the new guidance while it is
reviewed. Test-code commits from this effort must not be merged back into
`verification-2`. Once the documentation branch lands, rebase or retarget the
implementation onto `pre-release`.

This effort improves the structure and reliability of existing tests. It does
not reinstate the historical module-coverage queue or require new functional
tests for unrelated RTL.

Phase 1 has completed its batcher pilot. The event-builder transition-frame
scenario is now excluded explicitly from the INDEXED configuration with
`COCOTB_TEST_FILTER` instead of returning a no-op pass. Preservation comparison
kept all 13 cocotb names, the pytest wrapper, and all three parameter IDs; the
INDEXED result reports one explicit skip while both ROUTED configurations run
all 13 scenarios.

The RSSI pilot removed 19 additional no-op entrypoint returns across the
connection FSM, core, wrapper, multi-stream wrapper, and receive FSM suites.
Pytest now selects client/server role groups, excludes focused checksum/BUSY/
loss/AXI-Lite/sequence cases from unrelated simulations, and retains the
existing known-issue and extended gates. The preservation comparison reports no
removed identifiers and four newly explicit `COCOTB_TEST_FILTER` controls.
Client/server FSM simulation passes in serial and xdist modes. Enabling the
known-issue RxFSM nodes still exposes their pre-existing behavioral failures;
their XUnit results confirm that the normal node skips only the disabled-
checksum case and the focused node skips the other 13 scenarios.

The base-library migration converted 45 configuration and opt-in guards across
18 delay, FIFO, arbiter, RAM, and synchronizer modules into decorator-level
cocotb skips. The only remaining base early return is the intentional
common-clock terminal path in `SynchronizerFifo`: it first exercises and
asserts every passthrough value, then avoids the inapplicable dual-clock FIFO
path. All 171 base pytest nodes and all cocotb entrypoint names are preserved.
A representative 33-node serial run and the complete 94-node edited subset
under pytest-xdist both pass; the generated cocotb XUnit files report
configuration-inapplicable entrypoints as skips rather than passes.

The AXI migration removed the remaining seven early no-op returns from
`AxiDualPortRam`, `AxiStreamPipeline`, and the AXI Stream FIFO integration
matrix. System-write, registered-pipeline reset, metadata truncation,
frame-ready, threshold, burst, and dynamic-pause scenarios now declare their
applicability in the cocotb decorator. The later return in
`AxiStreamResize.backpressure_and_reset_test` is retained because it follows a
completed equal-width handshake/clear check and intentionally terminates before
the inapplicable stateful-reset path. Preservation comparison reports no
removed nodes or entrypoints; all 17 edited parameter cases pass both serially
and under pytest-xdist.

Phase 1 is complete. The protocol pass converted 36 remaining lane-, mode-,
known-issue-, overflow-, address-width-, subclass-, and scrambling-specific
no-op branches in CoaXPress, PGP4, SRPv0, and JESD204B into explicit cocotb
applicability skips. The audit now defines an early return by semantics—a bare
return before any awaited simulator activity or assertion—rather than by an
arbitrary line-distance threshold, and that rule is blocking with a zero-entry
baseline. Seven post-activity returns remain report-only and were reviewed as
intentional successful terminal paths. Protocol preservation comparison found
no removed pytest nodes or cocotb entrypoints. The 14 CoaXPress/PGP4/SRP
parameter nodes pass both serially and under pytest-xdist; the JESD-specific
24-node matrix also passes in both modes.

## Non-Negotiable Preservation Rules

- Do not remove an existing test, parameter case, opt-in gate, or behavioral
  assertion merely to make the suite conform to the style guide.
- Before changing a subsystem, record its pytest nodes, cocotb entrypoints,
  parameter IDs, skips, known-issue gates, and extended-test gates. Afterward,
  account explicitly for every removed, renamed, split, or consolidated case.
- A moved or split test must retain equivalent DUT stimulus and assertions.
  Preserve public pytest node names and gate semantics when practical; otherwise
  provide a before/after mapping in the commit or pull-request description.
- Treat a reduced test count, an unexpected skip, or a formerly exercised
  cocotb entrypoint becoming unreachable as a regression until explained.
- Keep compliance cleanup separate from unrelated RTL behavior changes. A
  discovered RTL defect should receive a focused reproducer/fix change rather
  than being masked by relaxing an assertion.
- Make changes one subsystem or one shared mechanism at a time, and validate
  both serial execution and the parallel mode used by CI.

## Audit Baseline

The initial source scan produced the following triage baseline. These are
screening signals, not confirmed violations; every site needs semantic review.

- 726 cocotb entrypoints were found across 320 Python files.
- The AST audit reports 99 entrypoints in 33 files with a bare return within 12
  lines of the function declaration, plus 14 later bare returns in nine files.
  Early returns are the highest priority because an inapplicable scenario can
  be recorded as a pass.
- At least 119 literal paths passed through `extra_vhdl_sources`, across 70
  files, resolve to design units already present in the current ruckus import.
  Variable-generated lists mean the true count may be higher.
- 447 non-clock `cocotb.start_soon()` calls were found. Of those, 61 calls in 23
  test modules and two helpers do not retain the returned task. Many may be
  legitimate lifetime agents, but their ownership is currently implicit.
- The AST audit reports 304 directly adjacent edge-then-delay pairs across 129
  files. The initial broader text scan found 574 candidates. Some correctly
  model a real nonzero `TPD_G`; others may only be compensating for delta-cycle
  scheduling.
- 66 open-ended `while True` loop sites occur across 38 files, while 42 files
  use `with_timeout()`. The counts do not establish whether an enclosing wait
  is bounded.
- Two cocotb entrypoints use decorator-level timeouts. This is not a target
  count: bounded operation waits are preferable, with decorator watchdogs
  reserved for complex concurrent tests.
- One ordinary GHDL regression, `test_AxiStreamDmaV2Read.py`, bypasses the
  shared runner without an obvious simulator-specific requirement.
- Four cocotb files lack the labeled methodology marker used by the structural
  ratchet; they remain in the initial legacy baseline pending focused review.

The largest reviewed test modules are useful structural-cleanup candidates:

| Test module | Approximate lines | Cocotb tests |
| --- | ---: | ---: |
| `test_RssiCore.py` | 1,453 | 26 |
| `test_Jesd204bLoopback.py` | 1,254 | 4 |
| `test_CoaXPressRx.py` | 1,174 | 8 |
| `test_RoCEv2AxiStreamRdmaCore.py` | 848 | 16 |
| `test_AxiStreamFifoV2IpIntegrator.py` | 843 | 6 |

Re-run the audit after material tree changes and before declaring the effort
complete. Record both the raw signal count and the number confirmed to require
change so the metrics are not mistaken for defect counts.

## Implementation Plan

### Phase 0: Capture And Ratchet The Baseline

Create a lightweight, read-only audit under `tests/common/` that can report the
screening categories above. Where a static rule is reliable, add a checked-in
legacy allowlist so new or substantially edited tests cannot introduce another
violation while existing cases are migrated gradually.

The first enforcement candidates are methodology-header presence, selected
tests that silently return before stimulus, ordinary direct-runner exceptions,
and literal duplicate imported sources. Coroutine and timing scans should begin
as reports because static syntax cannot determine intent reliably.

Add a repeatable preservation report for each migrated subsystem. At minimum it
should capture pytest collection and the discovered cocotb test names. For gated
suites, capture the default, known-issue, and extended configurations
separately. Do not encode one expected repository-wide test count that changes
whenever legitimate coverage is added.

### Phase 1: Eliminate No-Op Passes

Review the 97 early-return candidates first, one subsystem at a time.

- Move configuration applicability into the pytest parameter or selector
  matrix when the scenario should not launch.
- Use an explicit skip with a configuration-specific reason when collection is
  valuable but execution is unavailable.
- Keep an early return only when it follows meaningful assertions and represents
  an intentional successful terminal path; add a short comment where that is
  not self-evident.
- Start with batcher and RSSI because their routed/unrouted and gated scenarios
  now have explicit local documentation. Continue with configuration-heavy AXI
  and protocol suites.

For each migrated subsystem, compare the preservation report before and after,
then run the focused suite serially and with pytest-xdist.

### Phase 2: Normalize Runner And Source Handling

Remove `extra_vhdl_sources` entries that duplicate units supplied by the ruckus
import. Audit exceptions rather than deleting every matching path mechanically;
a test may intentionally compile a different implementation or library, which
must be documented and isolated explicitly.

After cleaning the callers, enhance `run_surf_vhdl_test()` or its source-merge
path to diagnose duplicate resolved files/design units before compilation. Use
an explicit, reviewed escape hatch only if a legitimate override exists.

Migrate `test_AxiStreamDmaV2Read.py` to the shared runner if the focused audit
confirms that it needs no special lifecycle or simulator capability. Review
`force_compile=True` callers at the same time, but remove that setting only
after clean and cached builds prove reuse is safe.

Validate source changes with a fresh `make MODULES="$PWD" import`, a clean
simulation build, a repeated cached run, and an xdist run. Source cleanup must
not change the elaborated DUT boundary.

### Phase 3: Make Coroutine And Resource Ownership Explicit

Classify each unretained non-clock task as finite work, a lifetime agent, or an
actual leak.

- Await finite producers, consumers, transactions, and checks before the test
  completes.
- Store monitors and protocol peers on the bench with names that communicate
  their purpose.
- Add a small shared task registry/cleanup helper only if repeated lifecycle
  mechanics justify it; avoid forcing simple leaf tests into a large framework.
- Put process, socket, port, temporary-file, and native-library cleanup in a
  `finally` block or fixture teardown that also runs after assertion failure.
- Add bounded operation waits first. Add a decorator-level deadlock watchdog to
  complex integration entrypoints only after their normal progress waits are
  bounded.

Prioritize RSSI core/wrappers, CoaXPress, RoCEv2, JESD204B, SimLink, and other
tests with several concurrent agents or external resources.

### Phase 4: Clarify Sampling And Propagation Timing

Classify edge-plus-delay sites into two semantic categories:

1. delta-cycle settling after a clock edge, which should use `ReadOnly()`; and
2. real modeled propagation delay from a nonzero VHDL `after TPD_G`, which
   should wait for the configured delay and then sample a stable value.

Introduce narrowly named shared helpers for these two cases if they remove
repeated mechanics without hiding intent. Migrate high-reuse helper modules
before leaf tests. Do not perform a global textual replacement: changing a real
propagation wait to `ReadOnly()` can create a race, while retaining an arbitrary
fixed timer can conceal one.

Timing cleanup must retain accepted-handshake behavior and should be validated
under both serial and parallel execution. For parameterized `TPD_G`, include at
least the default and a representative nonzero value when practical.

### Phase 5: Improve Oracles, Diagnostics, And Structure

Anchor protocol reference models with published or hand-worked known-answer
vectors independent of both the DUT and the main encoder path. Add these while
touching a protocol suite rather than launching a broad rewrite.

Improve assertion context where pytest's rewritten expression is insufficient,
especially for parameter cases, frames, beats, sequence numbers, expected versus
observed sidebands, and randomized seeds. Do not mechanically add messages to
simple assertions that are already diagnostic.

Split oversized modules by coherent behavior, not a line-count threshold. The
first candidates and suggested boundaries are:

- RSSI core: negotiation/close, data/retransmission, flow control/keepalive,
  connection lifecycle, and AXI-Lite control.
- JESD204B loopback: configuration/bring-up, data-path checking, error/recovery,
  and long-running integration behavior.
- CoaXPress RX: framing/decoding, trigger/control behavior, error/recovery, and
  integration scenarios.
- RoCEv2 RDMA: packet/oracle mechanics, operation classes, errors, and
  multi-transaction integration.
- AXI Stream FIFO integration: configuration families, traffic/backpressure,
  sideband behavior, and reset/status behavior.

Keep shared mechanics in `*_test_utils.py`; keep the policy assertions and a
specific methodology block in the test module that owns each behavior. Preserve
case names and gates through every split.

### Phase 6: Make The Ratchet Blocking

Once each audit rule has low false-positive risk, make it blocking for new and
modified tests. Retain reviewed legacy exceptions and remove them as migration
PRs land. The final policy should reject:

- a newly introduced no-op passing scenario;
- an unexplained duplicate ruckus/extra-source design unit;
- a new ordinary direct runner without a documented need;
- an unowned external resource or finite background transaction; and
- a methodology or local invocation that contradicts `tests/README.md`.

Update `scripts/setup_regression_env.sh` separately so its suggested pytest
commands match the current directory layout and authoritative README. Keep this
small operational cleanup out of behavior-heavy migration commits.

## Pull Request Slicing

Prefer a sequence of independently reviewable pull requests rather than one
repository-wide compliance change:

1. Audit/report infrastructure with nonblocking legacy baselines.
2. No-op-pass cleanup, one subsystem per PR.
3. Duplicate-source cleanup and runner enforcement, grouped by related source
   manifests.
4. Coroutine/resource ownership, grouped by integration family.
5. Timing-helper introduction followed by subsystem migrations.
6. Large-suite splits, one suite per PR.
7. CI ratchet promotion as each rule becomes trustworthy.

Every implementation PR should ultimately target `pre-release`, identify the
baseline commit used for comparison, include the before/after preservation
report, list focused and parallel validation, and state any remaining legacy
exceptions. Do not merge implementation commits into `verification-2`.

## Validation Expectations

Apply validation in proportion to each change, with the following minimums:

- `git diff --check` and focused Python lint for edited test code.
- `make MODULES="$PWD" import` for source-list or runner-source changes.
- A serial focused pytest run with `-n 0` for readable simulator evidence.
- The nearest practical subsystem suite under pytest-xdist.
- Default and explicitly gated configurations when selection/gating changes.
- Fresh and cached simulation builds when build identity or source merging
  changes.
- Before/after pytest/cocotb case accounting for every move, split, skip, or
  selector change.
- VSG lint for any edited wrapper VHDL.

No phase is complete solely because its screening count reaches zero. The
behavioral preservation report and focused regressions are the acceptance
criteria.

## Risks And Mitigations

- **Coverage loss during cleanup:** require before/after case accounting and
  treat unexplained count reductions as failures.
- **False positives from static scans:** begin ambiguous rules as reports, use
  reviewed allowlists, and enforce only semantically reliable checks.
- **Simulator cache changes hiding source mistakes:** validate both clean and
  cached builds and reject duplicate design units before compilation.
- **Timing cleanup introducing races:** distinguish delta settling from real
  `TPD_G` waits and migrate shared helpers incrementally.
- **Large diffs becoming unreviewable:** keep subsystem and mechanism changes in
  separate PRs and avoid unrelated RTL/style cleanup.
- **Branch topology violating the documentation-only contract:** never merge
  this implementation branch into `verification-2`; rebase or retarget onto
  `pre-release` once the documentation is available there.

## Immediate Next Steps

1. Begin duplicate-source cleanup by subsystem, starting with the shared AXI
   wrapper paths and a fresh ruckus import.
2. Migrate `test_AxiStreamDmaV2Read.py` to the shared runner and add duplicate
   source diagnostics after caller cleanup establishes the legitimate
   exception set.
3. Classify `force_compile=True` callers while touching their source lists,
   retaining only cases with a documented cache or source-topology need.
