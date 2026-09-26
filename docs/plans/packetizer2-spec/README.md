# Packetizer2 specification and compatibility work

## Goal and scope

Establish a reviewable Packetizer2/Depacketizer2 contract from SURF RTL,
Rogue V2 software, and their actual consumers. Resolve ambiguities explicitly,
build independent conformance coverage, and only then consider RTL refactoring.
Legacy Packetizer/Depacketizer work is outside scope.

The working documents are:

- [Working specification](../../../protocols/packetizer/packetizer2-spec.md):
  wire format, endpoint behavior, CRC and configuration profiles.
- [Findings and coverage](findings.md): observations, suspected defects,
  compatibility decisions still open, and regression gaps.
- [PGP separation assessment](pgp-separation.md): configuration provenance and
  the case for or against separate PGP framing/reassembly controllers.

## Baseline and current status

As of 2026-09-25:

- Worktree: `~/surf-packetizer2-spec`.
- Branch: `docs/packetizer2-spec`.
- Base: the existing `fix/depacketizer2-link-recovery` branch at
  `5520beec22698f4ee07b7bd613089abb5c2e2482`.
- Rogue source inspected at `~/rogue`, revision
  `cf356dc277b13fcd4821e6dc78156c7a33090813`.
- The initial SURF/Rogue/PGP/RSSI source review is recorded. The latest SURF
  recovery fixes and tests are included in the baseline.
- This change is documentation only. No HDL, software, test behavior, public
  interface, or wire encoding has been changed. Nothing is staged or committed.

## Working decisions

Source code establishes current behavior; it does not automatically establish
what should become a permanent requirement. Keep observed behavior, tested
expectations, compatibility decisions and suspected defects distinct.

Preserve existing public interfaces and wire compatibility while investigating.
Any corrective behavior change needs a focused test and a stated compatibility
impact; do not bury it in a structural refactor. PGP separation is a hypothesis,
not an approved implementation direction. External consumers have not yet been
inventoried, so an unused local generic is not necessarily safe to remove.

Independent CRC and packet oracles are central. RTL loopback and software
loopback remain useful integration checks, but neither establishes cross-peer
conformance by itself. The RTL streaming endpoint and Rogue buffered endpoint
need distinct error-delivery contracts.

## Next discussion and work

1. Review the draft's ordinary wire/profile rules and the findings ledger.
   Decide which fields and error behaviors consumers can rely on.
2. Characterize the identified discrepancies with focused tests, including
   independent continuation/interleaving CRC vectors and RTL/Rogue exchange.
   Record reproductions and decisions beside the finding IDs.
3. Extend conformance coverage to the agreed profile matrix, framing errors,
   reset, and backpressure. Establish a reproducible baseline before refactoring.
4. Reassess shared versus PGP-native controllers against those contracts,
   including PGP3, receive-side recovery, timing, and resource requirements.

These are review topics and dependencies, not authorization to rewrite the
modules immediately. The current deliverable is the documentation foundation.

## Validation and handoff

Initial review: source inspection only. Existing tests were read, not rerun;
their presence is not recorded as a fresh pass. No simulation, synthesis or
Rogue integration test was needed for the initial documentation change.
Documentation validation completed on 2026-09-25:

- `git diff --check` passed.
- Seven Markdown files passed local link, anchor, heading-spacing,
  fenced-block and trailing-whitespace checks.
- All 49 local links and six pinned Rogue source links resolve against
  the inspected checkouts. The historical Confluence page remains
  unverified; external URLs were not fetched for this check.
- The branch still points at the requested base commit; the only worktree
  changes are the seven documentation files, all unstaged.

Primary files are the three `*Packetizer2*` RTL units, the V2 standalone tests
under `tests/protocols/packetizer/`, Rogue `ControllerV2.cpp`/`Controller.cpp`,
and PGP3/PGP4/RSSI instantiations. The working specification links these sources.
Keep future logs and simulator output outside this directory; record revision,
command, result and relevant assertion here or in the ledger instead.
