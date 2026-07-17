# xsim Multi-Instance Live-Traffic Test — Progress / Handoff

**Goal:** Prove that 8 DPI-C rogue-cosim instances (4 Stream + 2 Memory + 2 SideBand)
each exchange isolated, per-instance-tagged ZeroMQ traffic through the real Vivado
xsim DPI boundary.

**Final status:** Complete. Full simlink regression passes serial and parallel; the
new live-traffic test and the refactored multi-instance test both pass.

## Files added / changed

- `tests/axi/simlink/rogue_tcp_peer.py` — added per-tag send/expect helpers and a
  `--tag` CLI arg so each spawned peer produces/checks only its own tagged family;
  raised `RCVTIMEO_MS` 10000 → 30000.
- `tests/axi/simlink/test_rogue_tcp_peer_tags.py` — new pure-Python unit tests for the
  tag scheme (no Vivado): payload/txn/vector construction, distinct-tag non-collision,
  foreign-tag detection, and `--tag` argparse.
- `tests/axi/simlink/xsim_test_utils.py` — new shared helpers: tool discovery/skip, the
  system-libstdc++ `LD_PRELOAD` workaround, the `RogueTcpDpi.so` build fixture, and the
  `run_top` split into `compile_and_elaborate` + `run_elaborated`.
- `tests/axi/simlink/test_RogueXsimMulti.py` — refactored to consume `xsim_test_utils`
  (behaviour unchanged).
- `tests/axi/simlink/RogueXsimTrafficTb.vhd` — new 8-instance live-traffic testbench.
- `tests/axi/simlink/test_RogueXsimTraffic.py` — new orchestration test: spawns one peer
  per instance, elaborates + runs xsim, asserts the success banner and per-peer JSON
  isolation.
- `docs/plans/xsim-multi-instance-live-traffic/design.md`, `plan.md` — design + plan
  (pre-existing in this work).

## 8-instance topology + tag scheme

Port base 19740, each instance `i` gets a `(19740 + 2*i, +1)` pair:

- **Stream** i (0..3): ports 19740..19747. Inbound beat tagged `0x80+i`; TB checks the
  outbound byte equals the peer's `0x10+i`.
- **Memory** i (0..1): ports 19748..19751. Each instance's AXI-Lite slave is a real
  per-instance `surf.AxiDualPortRam` (block RAM), not a hand-rolled responder: the DUT
  writes then reads back this instance's tagged vector (data bytes in the `0x40..0x70`
  family). A preserved concurrent TB assertion still guards the address
  (a/awaddr == `0x100 + 0x10*i`, `$fatal` on mismatch); write-data integrity is proven
  by the peer's read-back compare (a real RAM returns exactly what was written, and each
  instance owns a distinct RAM, so cross-instance leakage is impossible by construction).
  The surf library is compiled for xsim from the ordered `SURF_AXI_RAM_SOURCES` list in
  `xsim_test_utils.py` (`SYNTH_MODE_G="inferred"`, no XPM/vendor deps).
- **SideBand** i (0..1): ports 19752..19755. TX opcode `0x60+i` then remData `0x70+i`;
  RX opcode `0x20+i` and remData `0x40+i`. TB asserts received tags match.

## Isolation approach

Two-sided for all three families: (1) positive check that each instance sees exactly its
own tag, and (2) explicit foreign-tag rejection — a peer or TB seeing any tag outside its
own family fails. `$fatal` exits 0 under `xsim -R`, so the pytest layer keys off the
printed success banner plus each peer's JSON (own tag family present, zero foreign tags).

## Environment requirements

- **Vivado version used:** 2024.1
  (`source /sdf/group/faders/tools/xilinx/2024.1/Vivado/2024.1/settings64.sh`).
- **System libstdc++ auto-preload:** the harness (`xsim_test_utils._preload_env`) locates
  the system libstdc++ via `gcc -print-file-name=libstdc++.so.6` and prepends it to
  `LD_PRELOAD`. Every bundled Vivado libstdc++ is older than the host libzmq's required
  `GLIBCXX_*`, so without the preload `xsimk` fails to load `libzmq.so.5`. Harmless when
  Vivado's bundled libstdc++ is already new enough.

## Timing / ordering design

- **Peer-spawn-after-elaboration ordering:** the test elaborates first
  (`compile_and_elaborate`), then spawns the peers immediately before `run_elaborated`.
  This is the real connectedness guarantee — the peers' RCVTIMEO budget must cover only
  the short simulation run, not the multi-second xvlog/xvhdl/xelab flow (during which an
  early-spawned peer would time out waiting).
- **Option B fixed settle delay (defense-in-depth):** `SETTLE_EDGES_C = 2000`
  (~20 us). All three families hold off outbound traffic until this fixed edge count,
  giving peers time to connect and drain before real traffic starts.
- **Watchdog:** `WAIT_EDGES_C = 1_000_000` (~1e6 edges). Because a free-running xsim is
  not paced to wall-clock until a peer connects and the DPI round-trips gate it, the
  watchdog bounds a worst-case hang at roughly 10 s wall-clock — comfortably under the
  120 s pytest timeout. Each per-instance wait loop asserts `waited < WAIT_EDGES_C`.

## Regression results (Task 8, 2026-07-17, Vivado 2024.1)

- **Serial** (`pytest -q -n 0 tests/axi/simlink`): **19 passed, 1 skipped** in ~40 s.
- **Parallel** (`pytest -q -n auto --dist=worksteal tests/axi/simlink`):
  **19 passed, 1 skipped** in ~20 s.
- The single skip is `test_RogueTcpMemoryWrap.py::test_RogueTcpMemory_uninitialized_read`,
  which skips because `valgrind` is not installed on this host (expected).
- `test_RogueXsimTraffic.py::test_xsim_instances_exchange_isolated_traffic` and both
  `test_RogueXsimMulti.py` cases pass. No failures, no flakes observed.

## Lint results

- **flake8** (7.3.0) on the 5 Python sources: clean (rc=0).
- **git diff --check:** clean.
- **VSG** (3.35.0) on `RogueXsimTrafficTb.vhd`: 60 style deviations, all in the same
  categories the sibling `RogueXsimMultiTb.vhd` also reports (86 there): `signal_007` /
  `variable_007` (default assignments), `instantiation_034/036` (direct-entity vs
  component instantiation), `if_002` (parenthesized conditions), `port_map_004`,
  `assert_005` / `report_statement_002` (severity-keyword placement). These are
  established testbench conventions in this directory; **not** changed, to avoid risking
  the working TB. No trivial-safe divergence from the sibling was found to fix.

## Open risks / notes for reviewer

- **Fixed-timing tradeoff (Option B):** `SETTLE_EDGES_C` is a fixed edge count rather than
  a handshake on peer readiness; adequate here but a topology/latency change could require
  retuning.
- **Watchdog is a wall-clock heuristic:** `WAIT_EDGES_C` maps to ~10 s worst case only
  under current sim pacing; treat as a hang guard, not a precise bound.
- **obValid observation race (already fixed):** an earlier single-cycle `obValid`
  observation race is handled by sampling every clock edge rather than at a single point.
- **RCVTIMEO raised to 30 s:** affects all peer-using tests. It only loosens the timeout
  bound (30 s vs 10 s), so it cannot cause false passes; worst case is a slower failure
  when a peer genuinely never connects.
- Simulator artifacts (`sim_build_*`, `xsim.dir`, `*.pb`, `*.jou`) are intentionally kept
  out of git; only summarized here.
