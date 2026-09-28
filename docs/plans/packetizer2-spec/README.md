# Packetizer2 specification and compatibility work

## Goal and scope

Establish a reviewable Packetizer2/Depacketizer2 contract from SURF RTL,
Rogue V2 software, and their actual consumers. Resolve ambiguities explicitly,
build independent conformance coverage, and only then consider RTL refactoring.
Legacy Packetizer/Depacketizer work is outside scope.

The working documents are:

- [Working specification](../../../protocols/packetizer/spec/packetizer2.md):
  wire format, endpoint behavior, CRC and configuration profiles.
- [Findings and coverage](findings.md): observations, suspected defects,
  compatibility decisions still open, and regression gaps.
- [PGP separation assessment](pgp-separation.md): configuration provenance and
  the case for or against separate PGP framing/reassembly controllers.
- [Link-recovery history](link-recovery-history.md): the 2017 PGP3 origin,
  evolution of cleanup/initialization, and the distinction between invalidating
  internal context and terminating already-delivered application frames.
- [Transport continuity](transport-continuity.md): unexpected-SOF rejection,
  RSSI retry versus session closure, PGP4 reacquisition, and abandonment policy.

## Baseline and current status

As of 2026-09-28:

- Worktree: `~/surf-packetizer2-spec`.
- Branch: `docs/packetizer2-spec`.
- Base: the existing `fix/depacketizer2-link-recovery` branch at
  `5520beec22698f4ee07b7bd613089abb5c2e2482`.
- The user committed the initial documentation as `c3c7a1d71` and the
  specification/rendering update as `c76a32dde`, the current branch HEAD.
  The inspected RTL baseline remains `5520beec2`.
- Rogue source inspected at `~/rogue`, revision
  `cf356dc277b13fcd4821e6dc78156c7a33090813`.
- The initial SURF/Rogue/PGP/RSSI source review is recorded. The latest SURF
  recovery fixes and tests are included in the baseline.
- The working specification now follows the PGP4 presentation model: numbered
  narrative sections, exact tables, SVG diagrams, and source/generic mappings
  in appendices. RTL and Rogue endpoint bindings remain explicit in the body.
- The PGP4 shared stylesheet and render tools were imported from `pgp4-spec`
  at `b863a909a9eb5f22236b582496a6ff9cce7b4f89`. The shared guidance now
  accommodates direct prose and draft evidence status. Browser rendering uses
  an isolated temporary profile and avoids the original unused `mktemp` file.
  The local browser stayed alive after writing the PDF, so the renderer now
  checks for a completed temporary PDF, stops its own browser, and installs
  the output. Failure or timeout preserves any previous output.
- Changes are limited to documentation and its rendering tools. No HDL,
  endpoint software, tests, public interfaces, or wire encodings have changed.
  The transport-continuity follow-up is unstaged; no commits were made by
  the agent.

## Working decisions

Source code establishes current behavior; it does not automatically establish
what should become a permanent requirement. Keep observed behavior, tested
expectations, compatibility decisions and suspected defects distinct.

Maintainer clarification, 2026-09-25: use VHDL as the primary reference for
intended protocol behavior. Rogue takes known shortcuts. In particular, CRC
mode matching and NONE-with-zero validation follow the VHDL contract; Rogue's
permissiveness is a documented software departure. This settles F07's protocol
intent without authorizing a software behavior change. The value of cumulative
frame CRC for PGP remains an architectural discussion, with no encoding change
approved.

Preserve existing public interfaces and wire compatibility while investigating.
Any corrective behavior change needs a focused test and a stated compatibility
impact; do not bury it in a structural refactor. PGP separation is a hypothesis,
not an approved implementation direction. External consumers have not yet been
inventoried, so an unused local generic is not necessarily safe to remove.

Independent CRC and packet oracles are central. RTL loopback and software
loopback remain useful integration checks, but neither establishes cross-peer
conformance by itself. The RTL streaming endpoint and Rogue buffered endpoint
need distinct error-delivery contracts.

Use the PGP4 specification as a presentation model, while retaining draft
status and explicit discrepancies. The scope of an endpoint contract is not
reduced by moving implementation mappings into appendices. Importing the
rendering framework does not merge the PGP4 branch or its RTL changes.

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

## Link-recovery history investigation

The 2026-09-25 history review traced `linkGood` and `TERMINATE_S` to
`feaceb989` (2017-04-17), followed immediately by PGP3 integration in
`874618823`. The original scan ended on link return. The bounded scan and
reset-time use arrived in `0dc93f70a` (2018-02-26); explicit completion and
RAM-latency handling followed. The detailed record distinguishes commit
intent, observed diffs, and architectural interpretation. No cleanup removal,
new abort interface, or RTL change has been selected.

## Transport-continuity investigation

The 2026-09-28 review confirms that both receivers discard an unexpected SOF
while clearing the old assembly. RSSI retries within an active connection
preserve context; an actual close flushes application buffering and transmit
window state. PGP4 RX link loss requests PHY reinitialization and suppresses
packet delivery during acquisition. TX application-frame context is not
automatically restarted by either binding. Rogue's RSSI error path clears
transport queues without notifying Packetizer2 to clear its partial assemblies.

The draft now distinguishes transport availability from a decision to abandon
receive continuity. F11 records the unexpected-SOF choice; F12 records binding
and queue-ordering questions. These are source findings, not new simulation
results or approval to change recovery behavior. See the detailed
[investigation](transport-continuity.md) for evidence and coverage limits.

The follow-up discussion records two further constraints in the findings:
F11 requires a careful survey of application dependencies, including accidental
dependence on discarding the first new frame, before changing SOF recovery.
F13 explores graceful local TX abandonment without assuming a reverse channel
or remote-state visibility. Input-frame boundaries, pending transport output,
peer notification, completion and compatibility remain open. The consumer
survey and TX mechanism investigation are outstanding; neither behavior change
nor a new interface has been approved.

## Validation and handoff

Initial review: source inspection only. Existing tests were read, not rerun;
their presence is not recorded as a fresh pass. No simulation, synthesis or
Rogue integration test was needed for the initial documentation change.
Initial documentation validation completed on 2026-09-25:

- `git diff --check` passed.
- Seven Markdown files passed local link, anchor, heading-spacing,
  fenced-block and trailing-whitespace checks.
- All 49 local links and six pinned Rogue source links resolve against
  the inspected checkouts. The historical Confluence page remains
  unverified; external URLs were not fetched for this check.
- At that point the branch still pointed at the requested base commit and
  contained seven unstaged documentation files.

The subsequent PGP4-style revision moves the maintained source to
`protocols/packetizer/spec/packetizer2.md` and updates all local references.
It adds two explanatory diagrams, explicit CRC pseudocode and byte ordering,
directional CRC acceptance rules, and a generic-default mapping. The two
single-packet examples retain the existing regression's literal vectors.
Validation of this revision:

- All 11 Markdown files checked passed formatting and 66 local link/anchor
  checks. Six pinned Rogue source links were resolved against the local
  checkout; external URLs were not fetched.
- Both shell scripts passed `sh -n`; both SVGs parsed successfully.
- A temporary bit-at-a-time implementation of the documented CRC pseudocode
  matched `zlib` and both existing literal packet vectors, including CRC byte
  order; the `123456789` check value also matched. This checks the document,
  not RTL/Rogue conformance.
- Standalone HTML embeds both SVGs and its stylesheet, needs no external
  rendering resources, and has valid internal navigation.
- `make -C protocols/packetizer/spec html` and `make -C protocols/packetizer/spec
  pdf` succeeded. The browser rendering command exits cleanly after the
  renderer lifecycle fix. A temporary failing-browser fixture confirmed that
  an incomplete PDF is rejected and previous output is preserved.
- The 15-page browser PDF was inspected at pages 3, 8, 9, 10, 13, and 14,
  covering the diagrams, packet examples, acceptance/error tables, source
  references, and generic table. No clipping or overlap was found.
- No RTL, Rogue integration, simulation, or synthesis tests were run for this
  documentation and render-tool update.
- `git diff --check` passed. At that validation point the presentation update
  was unstaged and branch HEAD remained `c3c7a1d71`; generated HTML/PDF output
  is ignored under `build/`. The user subsequently committed that update.

The link-recovery history addition was checked against local commit messages
and diffs; its local links, headings, and whitespace were checked. No simulation
was run, and historical regression results are not claimed as fresh passes.

The 2026-09-28 transport-continuity documentation passed `git diff --check`
and checks of six Markdown files, 77 local links/anchors, and nine pinned
Rogue references against the local checkout. HTML and PDF regenerated with
`make -C protocols/packetizer/spec html pdf`; internal HTML navigation and the
updated PDF recovery text were checked. No behavioral tests were run, and
source-based reconnect consequences remain unverified by simulation.

Primary files are the three `*Packetizer2*` RTL units, the V2 standalone tests
under `tests/protocols/packetizer/`, Rogue `ControllerV2.cpp`/`Controller.cpp`,
and PGP3/PGP4/RSSI instantiations. The working specification links these sources.
Keep future logs and simulator output outside this directory; record revision,
command, result and relevant assertion here or in the ledger instead.
