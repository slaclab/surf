# One-step Sync receive implementation plan

## Goal and status

Add one-step Sync reception to the existing autonomous, fixed-source Layer-2
E2E TimeReceiver while preserving two-step reception. Select the receive path
from each Sync's `twoStepFlag`; no software mode selection is needed.

Status: **implemented; static checks pass; behavioral verification paused**.
Implemented 2026-10-06 in the working tree based on SURF
`fc75fe24ab1dfb3da77164843c71783ab1aa3ba8`. The original plan used
`aa6b2c4084aafbea77761a5ff96b9605fbb952f9`; comparison with the implementation
baseline found no intervening PTP RTL or fixture changes. Documentation and
unrelated subsystems had advanced. This document remains the handoff.

The [current validation gate](README.md#current-validation) remains in force:
**do not run simulation or pytest regressions until the maintainer approves
the VHDL**. Implementing this plan does not lift that gate. Lint, Python static
checks and HDL compile/link smoke checks are allowed. Record unrun acceptance
checks explicitly; static success is not behavioral approval.

The protocol RTL is now `PtpProtocolEngine.vhd` (formerly `PtpPort.vhd`).
Historical source names and evidence below retain their original names; the
`PtpPortWrapper` fixture and software `Port` bank are unchanged.

## Scope and preparation

Read [SURF agent guidance](../../../AGENTS.md),
[VHDL conventions and review checklist](../../vhdl-conventions.md),
[endpoint contract](autonomous-endpoint.md),
[registered timing contracts](rtl-readability.md),
[test methodology](../../../tests/README.md),
[runner conventions](../../../tests/common/README.md), and the
[PTP test guide](../../../tests/ethernet/PtpCore/README.md).

Preserve public entity ports, exported record layouts, register addresses,
defaults, counters and PyRogue ABI. Keep changes local to Sync admission and
association, related test fixtures and maintained documentation. No one-step
transmit insertion, TimeTransmitter role, BMCA, Pdelay, UDP, VLAN, Signaling,
new profile, physical-clock control or board integration is included.
Do not stage, commit, change branches or advance the parent submodule pin.

## Baseline and affected files

Paths below are relative to the SURF root.

| File or area | Baseline behavior / planned change |
| --- | --- |
| `ethernet/PtpCore/rtl/PtpRxFrontend.vhd` | Retains Sync body, flags, correction and physical capture; Sync and Follow_Up both have a 44-byte fixed PTP length. One-step needs no new frame layout or capture path. Verify this remains true before editing. |
| `ethernet/PtpCore/rtl/PtpPkg.vhd` | Owns `PTP_TWO_STEP_FLAGS_C`, body timestamp accessors and sample types. Add a named flag bit/mask only if needed; revise stale two-step-only comments. Preserve exported layouts. |
| `ethernet/PtpCore/rtl/PtpPort.vhd` | Main RTL change: `PairType`, `completedPair`, RX dispatch and completed-sample correction assembly. At baseline accepted only exact two-step Sync flags, obtained remote time from Follow_Up, and waited for both messages. |
| `tests/ethernet/PtpCore/ptp_endpoint_test_utils.py` and existing wire helpers | Add explicit one-step stimulus selection; retain two-step defaults for existing tests. |
| `tests/ethernet/PtpCore/test_ptp_port.py` | Association, rejection, counters, stale/duplicate traffic and mode transitions. |
| `tests/ethernet/PtpCore/test_ptp_endpoint.py`, `test_ptp_endpoint_mac.py` | End-to-end timing equivalence, autonomous acquisition and recovery through physical GMII/XGMII paths. |
| RX fixtures/reference checks and other PTP tests | Extend only where they assume two-step-only traffic or need independent one-step wire coverage. Preserve existing two-step cases. |

`PtpPhc`, `PtpServo`, `PtpE2e`, `PtpMath`, physical timestamp adapters and the
Delay_Req TX ledger should not need functional changes. Investigate any proposed
change there as a scope expansion rather than silently refactoring them.
Update the nearest ruckus manifest only if HDL membership changes; no new production HDL
entity is required. Implementation adds the thin `PtpPortWrapper` simulation
fixture to observe exact measurements and drive backpressure/cancellation;
the existing directory-based wrapper manifest loads it.

## Required receive behavior

Keep existing source identity, multicast destination, domain, version,
transport-specific, control-field, FCS, length, epoch and generation checks.
Expand only Sync's accepted flag values from `0x0200` to `0x0000` or `0x0200`;
do not accept arbitrary flags merely because the two-step bit is readable.
This preserves the endpoint's restricted profile policy.

| Input | Departure timestamp | Correction | Completion condition |
| --- | --- | --- | --- |
| One-step Sync, `twoStepFlag = 0` | Sync `originTimestamp` | Sign-extended Sync correction only | Validated Sync with its own physical capture |
| Two-step Sync, `twoStepFlag = 1` | Matching Follow_Up `preciseOriginTimestamp` | Signed, widened Sync + Follow_Up correction | Both messages present, in either order |

For one-step, require nanoseconds less than 1,000,000,000 before association
state is changed. Use the existing timestamp accessor and Q16 conversion;
preserve all 48 seconds bits and signed fractional correction bits. Keep the
existing two-step rule that the authoritative timestamp comes from Follow_Up,
not the Sync body. Apply the correction exactly once.

Both paths must construct the existing `PtpSyncSampleType` with the Sync's
local capture, sequence ID, remote timestamp and combined correction. Feed it
through the same freshness, monotonicity, rate estimation, history, E2E and
measurement-publication path. One-step completes after frame validation, not
while the frame is arriving. It must still wait for existing processing capacity.

## Association and lifecycle decisions

Implement explicit internal one-step/two-step state in `PairType` (a mode bit
qualified by `syncSeen` is sufficient). Keep `followSeen` truthful: do not set
it to simulate a Follow_Up for a one-step Sync. Make completion require
`syncSeen` plus either one-step mode or `followSeen`, and exclude retired or
invalidated entries using the existing completion lifecycle.

Use these conservative local policies; they are implementation choices, not a
claim that IEEE 1588 prescribes this exact error handling:

- A fresh one-step Sync stores its own origin timestamp and correction and
  becomes eligible for completion. Its unused Follow_Up correction is zero.
- A Follow_Up arriving first may still create a partial association for a
  later two-step Sync, preserving today's out-of-order support.
- A one-step Sync colliding with a stored Follow_Up for the same live key is
  inconsistent: reject it and retire that association without publishing a
  sample. Do not combine or silently overwrite the two timestamps.
- A Follow_Up colliding with an existing one-step association is rejected and
  counted, without modifying that Sync's timestamp, correction, readiness,
  age or completion state. It cannot publish an additional sample.
- A duplicate Sync for an existing association remains ambiguous because it
  is a different physical capture. Preserve current rejection/retirement
  behavior, including duplicates with a different step mode or timestamp.
  A retired entry must not become eligible again through a later message.
- New sequence IDs may alternate modes without reconfiguration or a global
  restart. Mode belongs to the association, not to a sticky port-wide setting.
- Preserve bounded table capacity, completed-entry replacement, expiry and
  chronology checks. Do not promise replay rejection beyond retained history
  and existing lifetime assumptions; sequence wrap is not a new session ID.

Trace collisions both before publication and after acceptance. A later packet
cannot retroactively revoke a measurement already consumed downstream. Preserve
registered measurement holding, backpressure, child cancellation and abort
priority described in [RTL timing contracts](rtl-readability.md). Reset,
configuration/source changes, RX epoch changes and PHC generation changes must
flush the new mode state wherever they already flush associations. AXI-only
reset must retain its existing meaning.

## Execution sequence

1. Inspect the current decoder, pair allocation/retirement, rate-engine state
   and abort paths. Record any drift from this baseline and trace one exchange
   of each mode through to a measurement before coding.
2. Extend internal association state, exact flag admission, one-step timestamp
   validation and mode-dependent correction assembly. Preserve the two-process
   structure and registered outputs. Keep the existing downstream sample path.
3. Extend the frame builders/source driver and focused tests below. Expected
   values must come from independent timestamps/arithmetic, not DUT output or
   a model that merely repeats the new RTL branches. Retain the test methodology
   blocks and SLAC headers required by the test guide.
4. Apply the VHDL review checklist and authorized static checks. Use the
   [compile/link handoff](rtl-review.md#compilelink-procedure)
   and current runner documentation; do not depend on old temporary build paths.
   Do not execute a built simulator or use pytest collection as a static check.
5. Update the PtpCore README, endpoint contract, PTP test README, and affected
   two-step-only statements in this directory's README. Describe implemented
   receive support separately from pending behavioral/hardware qualification.
6. Once explicit maintainer RTL approval is recorded, run focused port tests,
   then the affected GMII/XGMII endpoint and MAC regressions and relevant
   existing two-step coverage. Record commands, parameters, revisions and results
   here. Preserve unrelated outstanding acceptance work.

## Acceptance coverage

| Case | Required observation |
| --- | --- |
| Valid one-step Sync with no Follow_Up | Completes once; enters the existing rate/history path; repeated valid exchanges enable E2E acquisition and servo operation. |
| Equivalent one-step and two-step exchanges | Equal remote time, capture and net correction produce equal numerical forward/E2E results. Account for different message arrival/completion latency; do not require cycle-identical publication. |
| Correction arithmetic | Positive, negative and fractional Q16 corrections, including crossing a second boundary; sum of two-step corrections equals the one-step correction in paired fixtures. No truncation or double application. |
| Timestamp validation | Nanoseconds 999,999,999 accepted; 1,000,000,000 and larger rejected; exercise nonzero upper seconds bits. Invalid one-step input cannot contaminate an existing association. Two-step Sync body remains non-authoritative. |
| Flags and source policy | Accept the two supported Sync flag values; reject other flags, wrong control, source, domain and unsupported versions as before. |
| Association collisions | Follow_Up before/after one-step Sync; duplicate one-step Sync; mixed-mode duplicate sequence; identical/conflicting Follow_Up. Assert counters, no unintended completion and unchanged accepted sample contents. |
| Lifecycle boundaries | Back-to-back mode changes on distinct sequences, 16-bit sequence wrap, stale/replayed messages, expiry, full table and completed-entry replacement. No resurrection or permanent table leak. |
| Stalls and invalidation | Measurement backpressure, rate-engine busy, RX overflow/abort, generation/epoch changes and reset/reconfiguration around admission/completion. Stable registered payloads; cancellation at the documented consumption edge. |
| Physical integration | Full-rate GMII 125 MHz and XGMII 156.25 MHz, including both XGMII start lanes. Bad FCS/truncation never publishes a sample. Preserve timestamp calibration and Delay_Req TX completion behavior. |
| Two-step compatibility | Existing Sync/Follow_Up arrival orders, duplicate policy, correction sum, acquisition, holdover/recovery and MAC-composition behavior remain covered. |

For equivalent-mode fixtures, explicitly split a known total correction between
Sync and Follow_Up in the two-step case. Check against the one-step total and an
independent expected result. Closed-loop fixtures must compare at corresponding
measurement times or use mode-specific timing expectations so that Follow_Up
latency is not mistaken for an arithmetic discrepancy.

## Completion evidence and open risks

- [x] Plan grounded in the checked-out port, frontend, helpers and existing tests.
- [x] RTL and stimulus implemented; public interfaces and ABI checked.
- [x] VHDL source checklist review, lint, Python static checks and HDL compile/link recorded.
- [ ] Maintainer approval to resume behavioral verification recorded.
- [ ] Focused and integration acceptance coverage executed and results recorded.
- [x] Maintained documentation updated; remaining limitations stated.

### Implementation and review

- `PtpPort.PairType.twoStep` is private and qualified by `syncSeen`. Completion
  requires a used, unretired Sync and either one-step mode or a real Follow_Up.
  Exact Sync flags and one-step nanoseconds are checked before slot lookup/update.
  One-step stores the existing 80-bit timestamp accessor result and zero unused
  Follow_Up correction. Sample assembly sign-extends Sync and adds Follow_Up only
  in two-step mode. No exported record, entity declaration, register, default,
  counter definition or PyRogue interface changed.
- The existing frontend already retains all required Sync body/flag/correction
  fields after FCS/length validation. `PtpPkg`, PHC, servo, E2E/math, physical
  capture logic and TX ledger need no functional edits. No new mode setting exists.
  Review follow-up names the exact one-step flag word `PTP_ONE_STEP_FLAGS_C`
  beside `PTP_TWO_STEP_FLAGS_C` in `PtpPkg` and uses it in Sync comparisons.
  The package comment now describes both accepted flag words. This is a
  behavior-preserving substitution; VSG passed for package/port and GHDL
  compile/link passed for `PtpPort`. Behavioral verification remains paused.
  A further readability follow-up separates Sync and Follow_Up admission into
  explicit flag, control and timestamp rejection branches, then gates slot
  updates with `if not malformed`. The acceptance conditions and rejection
  counting are unchanged; port VSG and compile/link passed again.
- Reviewed both arrival orders and collision directions, before completion and
  after downstream consumption. An admitted one-step completes in the same
  IDLE evaluation, or starts rate processing with its frozen sample. RX cannot
  admit a following collision while rate processing or a measurement stalls;
  the retained key then rejects it after capacity returns. Already consumed
  samples are not revoked. Existing expiry/replacement and final whole-table
  abort priority clear the new mode with the other association fields.
- Applied the VHDL checklist: one owner/two-process state, unchanged registered
  outputs and reverse-ready timing, explicit signed128 arithmetic, no new CDC,
  unchanged reset/AXI-only reset semantics, and directory-based source loading.
  The new wrapper only adapts records and the real local AXI register bank.

### Prepared checks (not executed)

| Fixture | New acceptance checks |
| --- | --- |
| `test_ptp_port_samples.py` | Independent Q16 forward arithmetic for equivalent modes and both two-step orders; signed/fractional correction limits and widened sum; all 48 seconds bits; canonical timestamp boundaries; exact flags/source policy; Follow_Up/mixed-mode/duplicate collisions and no resurrection; full table, reuse, expiry, chronology, sequence wrap; AXI-only reset, stalled measurement, queued RX during rate work, ratio qualification and cancellation. |
| `test_ptp_port.py` | GMII/XGMII mode alternation and wrap, both XGMII start lanes, bad FCS, short body, unsupported versions and profile errors followed by a valid same-key one-step copy; original two-step adversarial scenarios retained. |
| RX reference/RTL fixtures | Explicit one-step encoding; complete body/flags/signed correction/capture preservation, both start lanes, CRC and truncation rejection. |
| `test_ptp_endpoint.py` | One-step and two-step variants at both PHY rates with oscillator error; correction total carried by one-step or explicitly split between Sync and Follow_Up; independent 100 ns symmetric-path delay and absolute phase checks, acquisition/holdover/recovery. |
| `test_ptp_endpoint_mac.py` | Both receive modes through real MAC composition, pause/restart, late completion and fresh E2E recovery. |

One-step source timestamps are built from the scheduled physical edge using
independent simulator time, then checked against the observed edge; no DUT PHC
value generates the source timestamp. Direct port vectors compare Python integer
arithmetic at controlled capture times. Closed-loop modes compare each result
with the same independent path/phase expectation at its own acquisition point,
so Follow_Up latency is not treated as an arithmetic error.

### Static evidence, 2026-10-06

- VSG 3.35.0 with `vsg-linter.yml`: zero violations in `PtpPort.vhd` and the new
  `PtpPortWrapper.vhd`. Python AST parsing and flake8 pass for the eight changed/
  added Python fixture files. Static compliance screening against the HEAD
  fixtures reports no new findings; no tests were imported or collected.
- Fresh ruckus source import passed with the checked-out sibling ruckus. Initial
  sandbox attempts failed in Tcl subprocess temporary-file creation; the same
  isolated import succeeded with sandbox escalation. The initial recipe's
  `MODULES="$PWD"` also needed adjustment for this workspace's sibling layout.
  `GIT_STATUS=skip-index-refresh` suppressed Make's incidental Git index refresh.
- GHDL 6.0.0 (LLVM 22.1.0) import and compile/link passed for `PtpPort`,
  `PtpPortWrapper`, `PtpEndpoint`, `PtpEndpointLoopbackWrapper`,
  `PtpRxFrontendWrapper`, and `EthMacPtpEndpoint`, using
  `--std=08 --ieee=synopsys -frelaxed-rules -fexplicit`. The current
  `ETHMAC_RTL_SOURCES` selection supplied MAC RTL plus `DspXor.vhd`; the imported
  `EthMacPkg` was not duplicated. Builds used checked-out sources and a fresh
  temporary library. No executable was run; run-time generics/assertions and
  behavior remain untested. Dependency warnings include shared variables,
  elaboration, port attributes and name hiding; the unchanged servo's
  `maximum` warning remains.
- Production entity declarations and the RTL AXI register calls match HEAD;
  public package layouts and PyRogue sources are unchanged. Documentation links/
  anchors and diff whitespace were checked. No staging, commit, branch or parent
  gitlink update was performed.

Reproduce the import from this checkout (choose a fresh temporary output path):

```sh
make MODULES="$PWD/.." OUT_DIR=/private/tmp/ptp-one-step-import \
  IMAGES_DIR=/private/tmp/ptp-one-step-images GIT_STATUS=skip-index-refresh import
```

This checkout has no `.venv`; static tools were invoked explicitly from the
existing `/Users/bareese/surf/.venv/bin` (Python 3.13.2). No environment was
installed, changed or prepended to `PYTHONPATH`. Use the current
[compile/link procedure](rtl-review.md#compilelink-procedure) for the MAC source
supplement and isolated `ghdl -i`/`ghdl -m` calls. Temporary logs under
`/private/tmp/ptp-one-step-*` are disposable and are not prerequisites.

Next step: maintainer VHDL review, then explicit approval before any simulation
or pytest, including pure models/collection. After approval run the focused
port sample/physical tests, affected RX fixtures, then endpoint and real-MAC
variants, followed by the existing two-step acceptance coverage. Record actual
commands, parameters, revision and outcomes here. No known-bad simulation was
run under the gate; the one-step completion/count assertions would fail against
the prior exact-two-step-only admission policy.

The main remaining risks are unexecuted fixture timing/expectations, mixed-mode
association handling, bounded retained-key reuse, and registered cancellation/
publication timing. Earlier endpoint simulations do not validate this change.
Protocol interoperability, FPGA timing/resources, physical CDC and calibrated
hardware accuracy remain separate acceptance work.
