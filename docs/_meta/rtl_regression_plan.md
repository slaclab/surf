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
- If simulator limitations make direct generic overrides awkward, prefer generated test-local VHDL wrappers over checking in one-off wrapper files for each module.
- Keep generated wrappers thin and declarative: expose cycle-friendly or cocotb-friendly generics, map them onto the real DUT generics, and emit them from shared Python helpers.
- For integration wrappers, test the wrapper-specific behavior rather than replaying the full underlying leaf matrix through the wrapper.
- If only a simulator-stable subset of a wrapper is practical in phase 1, keep that subset intentionally narrow and document the unvalidated branches explicitly in the handoff/progress docs.

## CI And Runtime Policy
- Tier-first split.
- Separate `smoke` and `functional` regression tiers.
- Shard by subsystem only if runtime requires it.
- Keep room for PR-vs-nightly expansion later if runtime and coverage needs justify it.

## Reuse Policy
- Legacy VHDL testbenches are reference material only.
- Rewrite executable test logic in Python when migrating a module into the new regression system.
- Keep VHDL wrappers only when they make Python stimulus materially cleaner.
- Do not preserve old benches purely for historical reasons.
- When a wrapper is needed only to adapt simulator-hostile generics, generate it into the test build area from shared helper code rather than keeping a permanent checked-in HDL shim.
- For SURF AXI/AxiLite record ports, prefer the existing IP-integrator shim layers (`SlaveAxiStreamIpIntegrator`, `MasterAxiStreamIpIntegrator`, `SlaveAxiLiteIpIntegrator`, `MasterAxiLiteIpIntegrator`) instead of hand-writing record-to-flat unpacking in each test wrapper.
- If a DUT has extra nonstandard side signals, compose those on top of the standard AXI shim pair rather than replacing the standard flattening pattern.
- For wrapper-style protocol benches, prefer thin subsystem wrappers plus cocotb protocol masters/RAM models, and add accepted-handshake monitoring whenever timing-visible protocol behavior is part of the contract being proven.
- More generally, if a VHDL shim layer is needed to make a module practical to drive from cocotb, place that file in the nearest real subsystem `ip_integrator/` folder beside related adapter layers.
- Do not place cocotb-facing shim/adaptor VHDL under `tests/` or generic `hdl/` buckets when it is serving the same integration role as the existing `*IpIntegrator.vhd` files.
- When a wrapper is checked in under `ip_integrator/`, treat it like production repo HDL for readability purposes: keep the standard file banner and add concise section comments instead of relying on file naming alone.
- Treat checked-in Python cocotb tests the same way: use the normal repo header/comment style in the first draft instead of leaving cleanup for later.

## Rollout Planning Policy
- Use a checked-in RTL instantiation graph to guide bottom-up rollout decisions.
- Prefer testing high-reuse leaf primitives directly before spending effort on higher-level assemblies that mostly repackage them.
- Use the graph to reduce repeated behavioral testing across adjacent hierarchy levels, not as a substitute for engineering judgment about externally visible behavior.
- Keep the graph artifacts for provenance, but use the generated path-qualified phase-1 queue in `docs/_meta/rtl_phase1_queue.{md,json}` as the day-to-day source of truth.
- Record manual phase-1 deferrals and manual order exceptions only in `docs/_meta/rtl_phase1_queue_overrides.json`; do not hand-edit queue order in this plan.
- Do not re-analyze `rtl_instantiation_graph.json` before every module. Regenerate the queue when needed and take the next non-deferred item from `rtl_phase1_queue.md` unless a concrete blocker forces a documented override.
- The current manual rollout preference is to finish `axi/` first. That preference is encoded as temporary subsystem deferrals in `docs/_meta/rtl_phase1_queue_overrides.json`, not as a hand-maintained side list in this plan.

## Flat Build Order
The phase-1 simulator-friendly queue is now generated from the checked-in graph as a path-qualified bottom-up order rather than maintained inline in this plan.

Operational artifacts:
- `docs/_meta/rtl_phase1_queue.md`
- `docs/_meta/rtl_phase1_queue.json`
- `docs/_meta/rtl_phase1_queue_overrides.json`

Workflow:
1. Regenerate the graph and queue with `./.venv/bin/python scripts/build_rtl_instantiation_graph.py`.
2. Use `docs/_meta/rtl_regression_progress.md` plus the inventory to identify the current completion frontier.
3. Take the next unfinished, non-deferred entry from `docs/_meta/rtl_phase1_queue.md`.
4. If a concrete blocker forces a defer or reorder, record that exception in `docs/_meta/rtl_phase1_queue_overrides.json` instead of hand-editing this plan.

## Phase Breakdown
### Phase 1
- Create the regression inventory and artifact scaffolding.
- Generate and maintain a repo-wide RTL instantiation graph to guide bottom-up prioritization.
- Establish shared Python regression helpers.
- Add smoke coverage for simulator-friendly modules.
- Add functional Python tests for the highest-value pilot modules and reusable blocks.
- Define the migration pattern for wrappers and generic-heavy modules.
- Standardize the generated-wrapper pattern for real- or vector-generic leaves that need cycle-native test knobs under GHDL.

### Phase 2
- Deepen randomized and adversarial coverage.
- Expand curated configuration sweeps for generic-heavy modules.
- Add stronger reusable scoreboards and protocol-specific helpers.
- Revisit deferred vendor-heavy modules after phase 1 baseline stability.

## Acceptance Criteria For Phase 1
- The repo has a checked-in inventory and handoff system.
- New windows can recover project state by reading the handoff artifacts only.
- The Python-only regression direction is documented and stable.
- The first pilot modules are selected and ready for implementation.
- The smoke/functional tier split is established in the plan and progress tracking.

## Open Questions And Deferred Decisions
- Whether PR-vs-nightly split is needed immediately or only after runtime data.
- Exact criteria for moving a vendor-heavy module out of `deferred_vendor_heavy`.
- Which subsystem should be the first large-scale migration after the pilot modules.
- Whether a separate tracked list of high-risk behavioral package helpers is needed once the module inventory stabilizes.
