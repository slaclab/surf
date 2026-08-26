# Regression Test Compliance

## Goal And Status

Bring the existing cocotb regression code into closer alignment with the
authoritative [test guidance](../../../tests/README.md) without deleting
coverage, hiding scenarios, or attempting a disruptive whole-tree rewrite.

Status: implementation is complete on `verification-2-test-compliance`.
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

Phase 2 has completed its AXI source-list pass. A fresh ruckus import confirmed
76 literal AXI paths were exact duplicates of design units already supplied by
`build/SRC_VHDL`; those entries were removed from 53 tests while the AXI4 and
DMA wrappers absent from the import were retained in their mixed source lists.
The AXI preservation report found no removed test identifiers. After deleting
only the ignored AXI simulator cache, the complete 117-node AXI suite passed a
fresh xdist build in 227.12 seconds and then passed again from cache in 17.74
seconds. The checked-in duplicate-source baseline now contains no AXI entries.

The remaining source-list pass removed 43 literal duplicate entries from DSP,
batcher, and RSSI tests, plus the dynamically expanded RSSI core source bundles
that the literal audit did not count. Test-only DSP and batcher wrappers absent
from ruckus remain explicit; every RSSI integration wrapper is already imported
and now uses that authoritative copy. The repository duplicate-source count and
blocking baseline are both zero, with no preservation-report changes. From
clean simulator caches, the combined suites pass with 37 passed and 17 gated
skips in 53.42 seconds; the cached repeat reports the same result in 15.51
seconds.

`test_AxiStreamDmaV2Read.py` now uses `run_surf_vhdl_test()` and keeps only its
two AXI4/DMA wrappers that are absent from the ruckus import; the production
read engine is supplied by ruckus. Both public parameter IDs are preserved. A
fresh serial build passes both cases in 16.95 seconds and the cached xdist
repeat passes in 1.10 seconds. The ordinary direct-runner finding and its
blocking baseline entry are now both zero.

The shared source merge now rejects both an extra path resolving to an already
imported file and a different extra file redeclaring an entity, package, or
configuration in the same library. A dynamic-list sweep exercised 153 source
expressions without finding an undisclosed collision, then identified four
helper-mediated duplicates outside the literal audit: three line-code
integration testbenches and `Pgp4TxLiteWrapper`. Those tests now use the ruckus
copies. Their five focused cases pass from clean caches in serial mode and on a
cached parallel repeat; a 16-case Ethernet suite with a legitimate dynamic
source bundle also passes with the runtime guard enabled.

Phase 2 is complete. The 17 RSSI `force_compile=True` arguments were blanket
settings rather than documented exceptions; the shared GHDL runner already
invalidates an elaborated image when any imported source is newer. After
removing them, the full default RSSI suite passed from a deleted simulator
cache with 6 passed and 17 gated skips in 33.68 seconds, then repeated from the
cache under pytest-xdist with the same results in 1.75 seconds. The remaining
VCS SimLink use is retained because that helper deliberately pre-analyzes its
mixed-language topology before asking cocotb-test to elaborate without source
arguments.

Phase 3 has completed its first ownership batch. All 25 unretained non-clock
task findings in `tests/axi/` were lifetime monitors or protocol responders;
the owning benches now retain and name them, while the existing finite AXI
transaction tasks remain awaited. `start_lockstep_clocks()` now returns its
lifetime task so benches can retain that ownership as well. The common helper
suite passes all 84 tests, a representative 14-node serial AXI run passes, and
the full 117-node AXI suite passes under pytest-xdist. No pytest node, cocotb
entrypoint, parameter ID, selector, or gate changed.

The next Phase 3 batch removed 12 more unretained-task findings across the base
FIFO, SSI, Xilinx GT alignment, CoaXPress low-speed TX, and PGP4 elastic-buffer
suites. The two CoaXPress stimulus coroutines are finite and are now awaited;
the remaining responders, source models, monitors, and collectors are named
lifetime agents retained by their owning model. All 14 affected pytest nodes
pass serially in 95.17 seconds and repeat under pytest-xdist in 6.22 seconds.

The RoCEv2 lifecycle batch removed another 16 findings. Finite RDMA packet
producers are awaited, long-running engine/source peers are retained and
cancelled in `finally`, and the resize sideband monitor is bench-owned. This is
especially important on RDMA watchdog failures, which now clean up both the
engine and any incomplete producer before propagating the timeout. All five
affected pytest nodes pass serially in 149.54 seconds and under pytest-xdist in
96.92 seconds.

The JESD204B loopback cleanup removed the final seven unretained-task findings.
GT-forwarding agents now travel with both their stop event and task handle;
every link restart signals and joins the old agent before a replacement starts,
while preserving the original two-cycle handoff margin. All nine loopback
pytest nodes pass serially in 156.58 seconds and under pytest-xdist in 21.40
seconds. The repository unretained-task screening count is now zero. Phase 3
continues with bounded-wait and external-resource review before that structural
result is promoted to a blocking ratchet.

The open-loop audit now recognizes only functions whose docstring explicitly
contains `Lifetime agent:`. Forty-four monitor, responder, clock, source,
transport, and protocol-peer loops have been reviewed and annotated with that
ownership contract. This reduced the ambiguous open-loop report from 66 to 22
finite operations, without allowlisting paths or function names. The remaining
22 are being converted to direct cycle/time bounds; the marker is not permitted
as a substitute for bounding a transaction.

Eight AXI finite loops now use `wait_sampled_ready()` with its 1024-cycle limit
or an equivalent explicit IPbus acknowledgement limit. This removes ad hoc
ready/valid polling from the compact and FIFO integration benches while keeping
the accepting edge semantics unchanged. All 15 affected nodes pass both
serially and under pytest-xdist; 14 finite open-loop findings remain.

Six more RoCEv2, CoaXPress, and PGP waits are bounded. DMA drains now fail with
the number of beats received after a conservative 65,536-cycle deadline; the
stream-facing cases use the shared 1024-cycle accepted-handshake primitive or
an equivalent diagnostic limit. All eight affected nodes pass serially in
94.57 seconds and under pytest-xdist in 37.05 seconds. Eight finite open-loop
findings remain, confined to SRP, SSI, and SimLink.

The SRP and SSI batch removes six more finite open-loop findings. SRP response
collection remains protected by its existing 20-us `with_timeout()` and now
uses condition-driven completion internally; its direct AXI-Lite responder
waits also have 1024-cycle diagnostic limits. The SSI resize waiter retains its
existing 1-ms operation timeout while making terminal-beat completion explicit.
All 175 affected parameter cases pass serially in 1837.27 seconds and from the
cache under pytest-xdist in 76.68 seconds.

The final two finite `while True` findings were SimLink traffic operations.
Multi-instance traffic now carries its existing wall-clock deadline directly
in the loop, and the native receive probe has its own four-second diagnostic
deadline in addition to the parent-process watchdog. Both retain unconditional
task/process/native-context cleanup. The focused native and GHDL SimLink suite
passes all nine nodes in 4.60 seconds with localhost socket access.

The repository reports zero unretained non-clock `start_soon()` calls and zero
unclassified `while True` loops. Both rules now participate in the checked-in
zero-entry compliance baseline, so new implicit task ownership or open-ended
transaction loops fail the blocking repository check. Conditional polling
loops remain a distinct bounded-wait review and are not represented by this
structural zero.

The first conditional-wait batch covers the RoCEv2 RDMA core's ten direct
ready/valid polls. They now use one bench-local 65,536-cycle helper that names
the stalled interface in its failure, while scoreboard/liveness waits retain
their existing operation-level `with_timeout()` watchdogs and fixed-length
CoaXPress capture loops remain directly cycle-bounded by their requested
sample count. The RDMA-core pytest node passes serially in 35.55 seconds.

Phase 4 now has explicit common primitives for its two sampling categories.
`sample_after_delta_cycles()` enters `ReadOnly()` for delta-only observation;
`sample_after_tpd()` advances real simulated time for registered outputs driven
with `after TPD_G`. A reviewed propagation helper identifies itself with a
`Propagation sampling:` docstring, allowing the advisory audit to suppress the
classification at the helper boundary without path allowlists. AXI handshake,
base synchronizer, DSP, CoaXPress, packetizer, batcher, PGP2, and Ethernet
shared helpers now use the propagation primitive. The raw timing inventory fell
from 302 to 295 sites, and 21 representative consumer nodes pass under the
normal pytest configuration in 80.51 seconds.

The final four legacy methodology exceptions are removed. The two RoCEv2 suites
now summarize their complete traffic/congestion sweeps, independent checks,
and watchdog ownership in the standard four-part block; the two real-Rogue
SimLink contracts document their bidirectional stimulus, JSON/DUT checks,
host/simulation bounds, and unconditional child cleanup. The blocking
`missing-methodology` baseline is now zero.

The seven post-activity bare-return findings are also resolved. Five branches
now use explicit `if`/`else` or `for`/`else` structure. The two intentionally
disconnected XLGMII placeholders keep a terminal branch only after completing
their no-output and status assertions, with an immediate `Terminal scenario:`
explanation of that complete parameter contract. The audit recognizes only
that contiguous marker and now blocks every other post-activity bare return
against a zero baseline. All 16 affected AXI, synchronizer, DSP, CoaXPress, and
Ethernet nodes pass in 142.45 seconds; all six affected SimLink wrapper nodes
pass serially in 4.32 seconds with localhost socket access.

The AXI timing migration classifies all 93 raw edge-plus-one-nanosecond sites
across AXI4, AXI-Lite, AXI Stream, bridge, and DMA benches as real propagation
sampling through `sample_after_tpd()`. This is an exact scheduling-preserving
replacement of the default SURF `TPD_G` wait, including handshake monitors and
protocol responders; no delay was converted to delta-only `ReadOnly()`
sampling. The AXI subtree now has zero advisory timing findings and is clean
under flake8. Its full 117-node suite passes under pytest-xdist in 54.19 seconds,
and a 17-node cross-subsystem serial matrix passes in 8.58 seconds.

The DSP, Ethernet, Xilinx-general, and SimLink timing batch classifies the next
24 sites. Default registered-output and handshake samples use
`sample_after_tpd()`, including a deliberate two-nanosecond CRC margin. The GT
alignment reset test instead uses `wait_after_edge_offset()` to identify a real
mid-cycle asynchronous-stimulus offset without mislabeling it as `TPD_G`
propagation. Those subtrees now have zero timing findings and are clean under
flake8. The full affected helper-consumer run passes 81 nodes under pytest-xdist
in 341.53 seconds, a 38-node representative serial matrix passes in 107.72
seconds, and the localhost SimLink multi-instance node passes serially in 4.03
seconds.

Phase 4 is complete. The final base FIFO sites use the explicit two-nanosecond
propagation contract, and all 25 base nodes pass in 133.43 seconds. The
remaining 174 protocol sites now use `sample_after_tpd()` or a reviewed
real-time timing contract: JESD204B alignment tests retain deliberate
time-measurement and midpoint samples, while CoaXPress and RSSI monitors retain
their explicit two-nanosecond propagation margins. The complete protocol suite
passes with 464 passed and 17 existing gated skips in 2612.94 seconds. A
before/after inventory of all 46 edited base/protocol Python files reports no
changes to cocotb entrypoints, pytest functions, parameter IDs, environment
controls, skips, or timeout decorators.

The whole active test tree now reports zero compliance findings. The
`edge-then-timer` rule has therefore joined the checked-in zero-entry blocking
baseline: new raw edge-plus-delay sequences must use the appropriate sampling
helper or carry a narrowly scoped reviewed timing contract.

The focused Phase 5 review adds an independent RSSI checksum anchor using the
literal header word `0x4008_1234_0000_0000` and its hand-worked one's-complement
result `0xADC3`; both the Python oracle and RTL must match it. RSSI multi-stream
frame comparisons now identify the failing beat and payload or sideband, and a
JESD204B soak uses a local seeded generator rather than mutating process-global
random state. The default affected selection passes with 7 passed and 3
existing gated skips, and the checksum/JESD nodes pass all 7 cases serially.

The five large-suite candidates were reviewed for coherent boundaries. Each
currently owns one expensive DUT topology and already separates behavior with
named cocotb entrypoints and local helpers; splitting by line count would
duplicate pytest wrappers and simulation launches without improving ownership.
No file split is planned until a behavior can move with a stable node mapping
and a genuinely independent simulation boundary.

Phase 6 now exposes the structural check directly in CI after the ruckus import
and before any expensive simulator run. `scripts/setup_regression_env.sh` no
longer suggests the superseded flat `tests/test_*.py` layout; it points users to
the blocking check, a focused subsystem command, and `tests/README.md`.

Final validation is complete. A fresh ruckus import succeeds, full Python
compile and flake8 checks are clean, and the blocking audit reports no baseline
differences. The CI-equivalent non-SimLink run passes with 946 passed and 17
existing gated skips in 1344.94 seconds; the dedicated bounded-worker SimLink
run passes with 94 passed and 13 existing gated skips in 21.58 seconds. The
preservation comparison from branch base `4005e7ffe3c6d21953e53441fe8d9efae2b43309`
to the completed branch covers 430 versus 433 tracked Python test files and
reports zero removed pytest functions, cocotb entrypoints, parameter IDs,
environment controls, skips, or timeout decorators. The additions are the
compliance tool's 26 unit tests and 13 explicit selector/control identifiers.

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

1. Push `verification-2-test-compliance` and open its implementation PR against
   `pre-release` when the documentation branch is available there.
2. Include the branch-base preservation result and final validation totals in
   the PR description.
3. Do not merge these implementation commits back into the documentation-only
   `verification-2` branch.
