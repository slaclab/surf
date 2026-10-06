# One-step Sync receive implementation plan

## Goal and status

Add one-step Sync reception to the existing autonomous, fixed-source Layer-2
E2E TimeReceiver while preserving two-step reception. Select the receive path
from each Sync's `twoStepFlag`; no software mode selection is needed.

Status: **planned, not implemented or behaviorally validated**. Prepared
2026-10-06 against SURF `aa6b2c4084aafbea77761a5ff96b9605fbb952f9`.
Recheck the working tree and current interfaces before implementation. This
document is the implementation handoff; update its progress and evidence in
place rather than creating another session report.

The [current validation gate](README.md#current-validation) remains in force:
**do not run simulation or pytest regressions until the maintainer approves
the VHDL**. Implementing this plan does not lift that gate. Lint, Python static
checks and HDL compile/link smoke checks are allowed. Record unrun acceptance
checks explicitly; static success is not behavioral approval.

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

## Existing implementation and affected files

Paths below are relative to the SURF root.

| File or area | Existing behavior / intended work |
| --- | --- |
| `ethernet/PtpCore/rtl/PtpRxFrontend.vhd` | Retains Sync body, flags, correction and physical capture; Sync and Follow_Up both have a 44-byte fixed PTP length. One-step needs no new frame layout or capture path. Verify this remains true before editing. |
| `ethernet/PtpCore/rtl/PtpPkg.vhd` | Owns `PTP_TWO_STEP_FLAGS_C`, body timestamp accessors and sample types. Add a named flag bit/mask only if needed; revise stale two-step-only comments. Preserve exported layouts. |
| `ethernet/PtpCore/rtl/PtpPort.vhd` | Main RTL change: `PairType`, `completedPair`, RX dispatch and completed-sample correction assembly. Currently accepts only exact two-step Sync flags, obtains remote time from Follow_Up, and waits for both messages. |
| `tests/ethernet/PtpCore/ptp_endpoint_test_utils.py` and existing wire helpers | Add explicit one-step stimulus selection; retain two-step defaults for existing tests. |
| `tests/ethernet/PtpCore/test_ptp_port.py` | Association, rejection, counters, stale/duplicate traffic and mode transitions. |
| `tests/ethernet/PtpCore/test_ptp_endpoint.py`, `test_ptp_endpoint_mac.py` | End-to-end timing equivalence, autonomous acquisition and recovery through physical GMII/XGMII paths. |
| RX fixtures/reference checks and other PTP tests | Extend only where they assume two-step-only traffic or need independent one-step wire coverage. Preserve existing two-step cases. |

`PtpPhc`, `PtpServo`, `PtpE2e`, `PtpMath`, physical timestamp adapters and the
Delay_Req TX ledger should not need functional changes. Investigate any proposed
change there as a scope expansion rather than silently refactoring them.
Update the nearest ruckus manifest only if HDL membership changes; no new HDL
entity is expected.

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
   [compile/link handoff](../ptp-registered-boundaries/README.md#validation-and-handoff)
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
- [ ] RTL and stimulus implemented; public interfaces and ABI checked.
- [ ] VHDL review, lint, Python static checks and HDL compile/link recorded.
- [ ] Maintainer approval to resume behavioral verification recorded.
- [ ] Focused and integration acceptance coverage executed and results recorded.
- [ ] Maintained documentation updated; remaining limitations stated.

Current evidence is source inspection only. No RTL was changed and no simulator
or pytest was run to prepare this plan. The main risks are mixed-mode association
contamination, premature entry reuse, accidental changes to two-step duplicate
behavior, and violating registered abort/publication timing. Protocol hardware
interoperability, FPGA timing/resource qualification and absolute accuracy remain
separate acceptance work even after simulations pass.

Next step: execute steps 1–4 within the existing verification gate, then hand off
the reviewable RTL and prepared behavioral checks. Do not report the feature as
validated while those checks remain paused.
