# SURF RTL Regression Plan

## Objective
- Build a repo-wide regression system for synthesizable SURF RTL.
- Standardize on a single executable test framework so new work stays consistent.
- Make progress resumable across many context windows without re-discovery.

## Chosen Methodology
- Python-only executable test logic.
- Primary stack: `pytest + cocotb + GHDL + ruckus`.
- Local Python commands should use the repo virtualenv interpreter (`./.venv/bin/python`) unless the virtualenv has already been explicitly activated in that shell.
- VHDL is allowed only for thin wrappers, shims, or required simulation models.
- Existing VHDL testbenches are reference material, not execution constraints.
- New Python regression code should use tutorial-style comments by default.
- New Python cocotb test files should start with the standard SURF/SLAC header block, not an ad hoc local header.
- Every Python regression should also carry a short module-specific `Test methodology` block immediately under the SLAC header comment.
- The header methodology block should use four wrapped bullets: `Sweep`, `Stimulus`, `Checks`, and `Timing`.
- The methodology bullets must describe the actual curated parameter sweep, the actual driven input sequence, the expected outputs or state changes, and the timing/latency/pulse/backpressure behavior being checked for that specific module.
- Do not use generic placeholder methodology prose; the header should tell a reader what this specific bench is proving.
- Keep methodology comment lines at a normal source width so the block is readable in the editor instead of turning into single-line paragraphs.
- Assume the reader is not already comfortable with cocotb.
- Comment the purpose of each major step in the test flow, including clock startup, reset sequencing, trigger waits, stimulus phases, and result checks.
- Treat the header methodology block and the in-body tutorial comments as separate requirements; one does not replace the other.
- Shared helpers may stay somewhat denser, but module-level tests should still explain how the Python coroutine behavior maps onto DUT behavior.
- When a DUT generic assumes truly common clocks, drive those clocks from one shared cocotb coroutine rather than starting two same-period clocks independently.
- For Python cocotb files, the minimum first-draft structure is:
  - standard SURF/SLAC file header,
  - module-specific `Test methodology` block,
  - tutorial-style comments in the executable body.
- Checked-in cocotb-facing VHDL wrappers should follow the in-tree SURF style too: add the standard SLAC/SURF banner at the top and include brief section comments for the major adapter regions.
- For `*IpIntegrator.vhd` wrappers, the minimum expected sectioning is usually:
  - bus shim section,
  - DUT instantiation section,
  - output/status flattening section when present.
- Do not leave permanent checked-in wrappers as uncommented bare port maps even if the logic is thin; future sessions should be able to scan the file and identify the adapter shape immediately.
- For any VHDL file you create or edit, run the `vsg` linter with the same configuration CI uses (`./.venv/bin/vsg -c vsg-linter.yml ...`) before considering the work done.
- When `vsg` reports fixable issues, use `--fix`/autofix first, then rerun the same CI-configured lint command to confirm the file is clean.

## Scope
- Whole repo target.
- Phase 1 focuses on simulator-friendly modules.
- Vendor-heavy modules are deferred in phase 1 unless they become practical under the open-source flow.

## Coverage Model
- `functional_python`
  - Module has a Python-authored cocotb regression.
- `smoke_python`
  - Module has compile/elaborate coverage only.
- `wrapper_required`
  - Module needs a retained or added VHDL wrapper to expose a cocotb-friendly interface.
- `deferred_vendor_heavy`
  - Module is intentionally excluded from phase 1 executable regression.

## Package Coverage Policy
- VHDL packages are not treated as standalone executable regression targets.
- Type/constant packages are covered transitively through the modules that compile and use them.
- Behavioral package functions and procedures should be covered through DUTs that exercise them whenever practical.
- If an important package function or procedure is not well reached transitively, add a minimal VHDL wrapper and test that wrapper from Python.
- Package-helper wrappers should be tracked separately from the main synthesizable-module inventory when they are introduced.

## Generic And Configuration Policy
- Generic-heavy modules are Python-first by default.
- Build curated configuration matrices in Python.
- Do not use naive full Cartesian products for broad generic spaces.
- Compute expected behavior dynamically in Python from the active generics.
- If simulator limitations make direct generic overrides awkward, prefer checked-in subsystem-local VHDL wrappers over ad hoc test-local copies.
- Keep checked-in wrappers thin and declarative: expose cycle-friendly or cocotb-friendly generics, map them onto the real DUT generics, and keep them beside the subsystem RTL they adapt.
- For integration wrappers, test the wrapper-specific behavior rather than replaying the full underlying leaf matrix through the wrapper.
- If only a simulator-stable subset of a wrapper is practical in phase 1, keep that subset intentionally narrow and document the unvalidated branches explicitly in the handoff/progress docs.

## CI And Runtime Policy
- Tier-first split.
- Separate `smoke` and `functional` regression tiers.
- Shard by subsystem only if runtime requires it.
- Keep room for PR-vs-nightly expansion later if runtime and coverage needs justify it.
- Treat simulator process cleanup as part of every verification step, not as optional housekeeping.
- After any command that launches `pytest`, cocotb, GHDL, or another simulation runner, check for stale child processes and kill any leftovers before moving on to the next step.
- When cleanup is needed, prefer an explicit process sweep first (for example with `ps -Ao pid,ppid,stat,time,command`) so only the stale run trees are terminated.

## Reuse Policy
- Legacy VHDL testbenches are reference material only.
- Rewrite executable test logic in Python when migrating a module into the new regression system.
- Keep VHDL wrappers only when they make Python stimulus materially cleaner.
- Do not preserve old benches purely for historical reasons.
- Before writing new cocotb transaction code, search the nearest subsystem `tests/` package for an existing `*_test_utils.py` or equivalent shared helper module and reuse it when possible.
- Prefer extending an existing helper with one more narrowly useful utility over cloning handshake loops, packet builders, frame receivers, or register-access boilerplate into each new test file.
- For AXI-Lite work, look for existing read/write helpers, setup helpers, and protocol-master wrappers first; do not hand-code repeated register transactions if the subsystem already has a stable helper path.
- For AXI Stream work, look for existing frame/beat helpers, contiguous-send helpers, receive helpers, keep-mask helpers, and handshake monitors before writing custom ready/valid loops.
- For SSI work, prefer the existing SSI helper layer for flat endpoint setup, beat modeling, frame send/receive, no-output checks, and `EOFE`/`SOF`-aware assertions instead of rebuilding SSI transaction plumbing in each bench.
- When a wrapper is needed only to adapt simulator-hostile generics, check it into the nearest subsystem-local `wrappers/` or `ip_integrator/` folder instead of hiding it under `tests/` or a generic `hdl/` bucket.
- For SURF AXI/AxiLite record ports, prefer the existing IP-integrator shim layers (`SlaveAxiStreamIpIntegrator`, `MasterAxiStreamIpIntegrator`, `SlaveAxiLiteIpIntegrator`, `MasterAxiLiteIpIntegrator`) instead of hand-writing record-to-flat unpacking in each test wrapper.
- If a DUT has extra nonstandard side signals, compose those on top of the standard AXI shim pair rather than replacing the standard flattening pattern.
- For wrapper-style protocol benches, prefer thin subsystem wrappers plus cocotb protocol masters/RAM models, and add accepted-handshake monitoring whenever timing-visible protocol behavior is part of the contract being proven.
- More generally, if a VHDL shim layer is needed to make a module practical to drive from cocotb, place that file in the nearest real subsystem `wrappers/` or `ip_integrator/` folder beside related adapter layers.
- Do not place cocotb-facing shim/adaptor VHDL under `tests/` or generic `hdl/` buckets when it is serving the same integration role as the existing `*IpIntegrator.vhd` files.
- When a wrapper is checked in under `wrappers/` or `ip_integrator/`, treat it like production repo HDL for readability purposes: keep the standard file banner and add concise section comments instead of relying on file naming alone.
- Treat checked-in Python cocotb tests the same way: use the normal repo header/comment style in the first draft instead of leaving cleanup for later.

## Rollout Planning Policy
- Use a checked-in RTL instantiation graph to guide bottom-up rollout decisions.
- Prefer testing high-reuse leaf primitives directly before spending effort on higher-level assemblies that mostly repackage them.
- Use the graph to reduce repeated behavioral testing across adjacent hierarchy levels, not as a substitute for engineering judgment about externally visible behavior.
- Keep the graph and queue artifacts for provenance and optional analysis, but do not use them as the active day-to-day source of truth for task selection.
- The active planning driver is now manual user-directed area selection, with `docs/_meta/rtl_regression_progress.md` and `docs/_meta/rtl_regression_handoff.md` tracking what is done, what is intentionally narrow, and what remains open.
- Do not hand-maintain queue order in this plan. If the graph or queue is regenerated for analysis, treat it as secondary context unless the user explicitly switches back to queue-driven planning.

## CoaXPress Spec Discipline
- Treat the published CoaXPress specifications as normative for future `protocols/coaxpress/` work, especially for top-level receive/transmit and over-fiber bridge benches.
- The two governing references are the CoaXPress protocol spec (`CXP-001-2021`) and the CoaXPress-over-Fiber bridge spec (`CXPR-008-2021`), matching the links already called out in `protocols/coaxpress/core/rtl/CoaXPressPkg.vhd`.
- When a CoaXPress bench encodes packet classes, control symbols, or bridge control characters, derive those values from the spec-defined names first and mirror them through shared helpers such as `tests/protocols/coaxpress/coaxpress_test_utils.py` instead of scattering raw literals.
- At the packet layer, prefer the published names even when the current RTL signal naming drifts; for example, `0x07` is an event packet and `0x08` is an event acknowledgment even though some existing RTL ports still use `eventAck` for the receive-side event indication.
- For CoaXPress image/header benches, keep the repeated-byte field encoding, header field order, endianness conversion, line-size semantics, and end-of-frame rules explicitly tied to the spec-defined rectangular image packet layout.
- For CoaXPress-over-Fiber benches, keep `/I/`, `/Q/`, `/S/`, `/T/`, and `/E/` handling, lane-0-only start/sequence semantics, and payload-vs-housekeeping start words aligned to `CXPR-008-2021`.
- If a checked-in bench intentionally validates only the current RTL contract instead of the full normative spec behavior, document that narrowed scope explicitly in the progress and handoff docs rather than implying full spec coverage.
- If a CoaXPress top-level bench has to be checked in as skipped because it exposes a likely RTL defect, keep the spec-shaped stimulus and the skip reason in-tree, and record the blocking symptom explicitly in the progress and handoff docs so the next pass resumes from the defect rather than from scratch.

## Historical Queue Artifacts
The phase-1 simulator-friendly queue remains available as a generated bottom-up artifact, but it is now historical context rather than the active workflow.

Retained artifacts:
- `docs/_meta/rtl_phase1_queue.md`
- `docs/_meta/rtl_phase1_queue.json`
- `docs/_meta/rtl_phase1_queue_overrides.json`

If they are regenerated:
1. Use `./.venv/bin/python scripts/build_rtl_instantiation_graph.py`.
2. Treat the resulting graph and queue as reference material only.
3. Keep the real done/open frontier in `docs/_meta/rtl_regression_progress.md` and `docs/_meta/rtl_regression_handoff.md`.

## Phase Breakdown
### Phase 1
- Create the regression inventory and artifact scaffolding.
- Generate and maintain a repo-wide RTL instantiation graph to guide bottom-up prioritization.
- Establish shared Python regression helpers.
- Add smoke coverage for simulator-friendly modules.
- Add functional Python tests for the highest-value pilot modules and reusable blocks.
- Define the migration pattern for wrappers and generic-heavy modules.
- Standardize the subsystem-local checked-in wrapper pattern for real- or vector-generic leaves that need cycle-native test knobs under GHDL.

### Phase 2
- Deepen randomized and adversarial coverage.
- Expand curated configuration sweeps for generic-heavy modules.
- Add stronger reusable scoreboards and protocol-specific helpers.
- Revisit deferred vendor-heavy modules after phase 1 baseline stability.

## Acceptance Criteria For Phase 1
- The repo has a checked-in inventory and handoff system.
- New windows can recover project state by reading the handoff artifacts only.
- The Python-only regression direction is documented and stable.
- The progress and handoff artifacts stay aligned with the actual validated branch frontier instead of lagging behind completed subsystem waves.
- The smoke/functional tier split is established in the plan and progress tracking.

## Open Questions And Deferred Decisions
- Whether PR-vs-nightly split is needed immediately or only after runtime data.
- Exact criteria for moving a vendor-heavy module out of `deferred_vendor_heavy`.
- Which user-directed subsystem slice should be taken next after the current documented frontier.
- Whether a separate tracked list of high-risk behavioral package helpers is needed once the module inventory stabilizes.
