# Batcher Regression Plan

## Objective
- Add focused, standalone cocotb regressions for the VHDL modules under
  `protocols/batcher/`.
- Start with leaf-module behavior, then add AXI-Lite and event-builder coverage
  only where it proves wrapper or integration behavior that the leaf tests do
  not already prove.
- Keep executable stimulus and scoreboards in Python.
- Keep VHDL additions limited to thin cocotb-facing wrappers beside the batcher
  RTL.

## Parent Methodology
- Follow `docs/plans/rtl-regression/plan.md`.
- New Python regression files need the standard SURF header, a module-specific
  `Test methodology` block, and in-body comments explaining major cocotb steps.
- Checked-in VHDL wrappers need the standard SURF banner and short section
  comments for bus shims, DUT hookup, and flattened/status wiring.
- Validate edited VHDL with `./.venv/bin/vsg -c vsg-linter.yml ...`.
- Validate Python syntax with the repo virtualenv interpreter.
- After any pytest/cocotb/GHDL run, sweep for stale simulator processes.

## Helper And Reuse Directives
- Keep shared batcher test code in `tests/protocols/batcher/batcher_test_utils.py`
  or another clearly named helper in the same package.
- Do not duplicate flat AXI Stream endpoint drivers, ready/valid wait loops,
  reset/clock setup, byte packing/unpacking helpers, V2 header/tail builders,
  or common receive/backpressure monitors across individual test files.
- Prefer extending the batcher helper with narrow reusable utilities over adding
  local helper functions to each module test.
- Keep module test files focused on scenario setup and assertions that are
  specific to that module.
- Reuse existing repo helpers first where they already fit, especially
  `tests/axi/utils.py` for sampled ready/valid handshakes and
  `tests/common/regression_utils.py` for cocotb/GHDL launch plumbing.
- If AXI-Lite wrapper tests need repeated register transactions, add small
  batcher-local register helpers or reuse existing AXI-Lite helpers rather than
  spelling out raw bus operations in every test.
- Keep helper code from becoming a hidden DUT oracle: shared utilities may build
  protocol bytes and perform mechanical handshakes, but module-specific policy
  checks should remain visible in the tests that depend on them.

## Module Inventory
| Module | Role | Planned Coverage |
| --- | --- | --- |
| `AxiStreamBatcher` | Leaf stream batcher for V1/V2 superframes | Direct functional regression |
| `AxiStreamBatcherAxil` | AXI-Lite register/control wrapper around the leaf batcher | Register-map and control-path regression after the leaf contract is covered |
| `AxiStreamBatcherEventBuilder` | Multi-input event-builder wrapper above the batcher | Integration regression for source selection, TDEST remap, timeout/drop behavior, and counters |

## Phase 1: Leaf Batcher Contract
Target `protocols/batcher/rtl/AxiStreamBatcher.vhd` through a thin wrapper that
exposes flat AXI Stream ports, control generics, and runtime termination knobs.

Planned checks:
- V2 superframe header formatting, including version, width, and sequence byte.
- V2 compacted byte stream through the `AxiStreamGearbox` path: header, payload,
  and 7-byte subframe tail with no zero-padding bytes.
- Subframe tail metadata: byte count, `TDEST`, first-byte `TUSER`, and last-byte
  `TUSER`.
- Termination modes: `maxSubFrames`, `maxClkGap`, `superFrameByteThreshold`, and
  `forceTerm` where the EOFE bit placement can be asserted cleanly.
- Multiple subframes inside one superframe, including non-word-aligned payloads.
- Output backpressure stability while `M_AXIS_TREADY` is low.
- Reset/idleness recovery after a partial or pending superframe.
- Curated generic sweep after the default V2 case is stable:
  - V2 at the default 8-byte width first.
  - V1 with a power-of-two stream width if the compacted expected model remains
    readable.
  - Avoid broad Cartesian sweeps unless a bug or high-risk branch justifies them.

Acceptance for Phase 1:
- One checked-in wrapper under `protocols/batcher/wrappers/` if an existing shim
  is insufficient.
- Tests under `tests/protocols/batcher/`.
- Focused validation passes for the batcher test file.
- `vsg`, `py_compile`, and `git diff --check` are clean.

## Phase 2: AXI-Lite Wrapper
Target `AxiStreamBatcherAxil` only after Phase 1 establishes the underlying
stream contract.

Planned checks:
- Reset values and readback for:
  - `superFrameByteThreshold` at `0x00`
  - `maxSubFrames` at `0x04`
  - `maxClkGap` at `0x08`
  - idle/version status at `0x0C`
- Writes to the threshold/count/gap registers affect subsequent superframe
  termination behavior.
- `softRst` at `0xFC` returns the stream path to idle and clears any pending
  partial superframe.
- `blowoff` at `0xF8` accepts/drops inbound traffic without emitting malformed
  output.
- `COMMON_CLOCK_G=true` first; async AXI-Lite crossing can be deferred unless the
  wrapper proves stable under the local GHDL flow.

Acceptance for Phase 2:
- AXI-Lite helper reuse from existing test utilities where practical.
- Tests prove register-visible behavior and one stream-side effect per control
  register family.
- No duplicate leaf-batcher packet grammar tests unless they are necessary to
  prove AXI-Lite control propagation.

## Phase 3: Event Builder
Target `AxiStreamBatcherEventBuilder` as an integration layer, not as another
full batcher grammar test.

Planned checks:
- Indexed mode source selection and output `TDEST` remap.
- Routed mode `TDEST_ROUTES_G` behavior for fixed and passthrough bits.
- Transition-frame handling through `TRANS_TDEST_G`.
- Bypass/drop behavior and related counters.
- Timeout behavior: stale or missing source data increments timeout-drop counters
  and does not corrupt later accepted events.
- AXI-Lite readback for status/counters that are visible through the event
  builder.
- Backpressure on the shared output while multiple inputs are ready.

Acceptance for Phase 3:
- Event-builder tests use small `NUM_SLAVES_G` cases first.
- The Python expected model focuses on arbitration/remap/drop policy and reuses
  leaf-batcher byte-stream helpers for the final output shape.
- Known intentionally untested branches are recorded in `progress.md`.

## Out Of Scope
- Exhaustive generic Cartesian sweeps.
- Throughput/performance benchmarking.
- Replacing the existing RTL register map or public Python APIs.
- Vendor or mixed-language simulator work.
- Re-proving every leaf-batcher byte in higher-level wrappers when a narrower
  control/integration assertion is sufficient.

## Validation Commands
Planned focused commands:

```bash
./.venv/bin/vsg -c vsg-linter.yml -f protocols/batcher/wrappers/*.vhd
PYTHONPYCACHEPREFIX=/private/tmp/surf-pycache ./.venv/bin/python -m py_compile tests/protocols/batcher/*.py
./.venv/bin/python -m pytest -n 0 -q tests/protocols/batcher
git diff --check
```

After simulator runs, sweep for stale processes with an explicit `ps`/`rg`
filter and kill only leftover run trees.

## Risks
- V2 output uses `AxiStreamGearbox`, so expected data must model compacted bytes
  rather than raw input beats.
- `forceTerm` sets SSI EOFE through `TUSER_FIRST_LAST_C`; bit placement should
  be checked against SURF helpers before asserting exact raw `TUSER` bits.
- The byte threshold logic counts in word-sized internal increments; tests
  should assert externally visible termination behavior, not an over-precise
  internal byte accounting model.
- Event-builder scope can grow quickly; keep it to integration-specific policy
  and avoid recreating a complete event-system simulation.

## Done Criteria
- The batcher task docs identify what is covered, what is intentionally deferred,
  and how to resume.
- Focused batcher regressions pass locally.
- New wrappers and tests follow the RTL regression style rules.
- `docs/plans/rtl-regression/progress.md` and `handoff.md` are updated only
  after validated batcher work lands in the working tree.
