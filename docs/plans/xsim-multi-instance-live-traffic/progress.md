# xsim Multi-Instance Live-Traffic Test — Progress / Handoff

> **Historical implementation record:** Paths and commands under
> `axi/simlink` and `tests/axi/simlink` describe the pre-alignment branch and
> are not current usage instructions. Start with the current
> [SimLink documentation](../../../simlink/README.md).

**Goal:** Prove that 8 DPI-C rogue-cosim instances (4 Stream + 2 Memory + 2 SideBand)
each exchange isolated, per-instance-tagged ZeroMQ traffic through the real Vivado
xsim DPI boundary.

**Current status:** Implementation complete; final reconciled Vivado rerun pending.
The original live-traffic implementation passed the full simlink regression serially
and in parallel. Subsequent reconciliation with pull request 1450 changed the Stream
vector shape and added a peer-ready barrier, so those final test-only changes still need
one run on a Vivado-enabled host.

## Files added / changed

- `tests/axi/simlink/rogue_tcp_peer.py` — uses the canonical pull request 1450
  per-instance vector helpers and dedicated `stream-instance`, `memory-instance`, and
  `sideband-instance` modes; added the test-only `--ready-file` option; raised
  `RCVTIMEO_MS` 10000 → 30000.
- `tests/axi/simlink/test_rogue_tcp_peer_tags.py` — new pure-Python unit tests for the
  canonical instance vectors and ready-file coordination (no Vivado): exact vector
  construction, instance-mode dispatch, readiness signaling, accepted readiness, and
  early peer-exit rejection.
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

- **Stream** i (0..3): ports 19740..19747. The TB sends one full frame
  `[0x80+i, 0x90+i, 0xA0+i, 0xB0+i]` and checks the peer's full frame
  `[0x10+i, 0x20+i, 0x30+i, 0x40+i]`.
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

Two-sided for all three families: the VHDL testbench checks the inbound vectors while
each peer compares the outbound traffic with its exact expected instance result. Any
missing, corrupted, or cross-instance value fails. `$fatal` exits 0 under `xsim -R`, so
the pytest layer keys off the printed success banner plus exact per-peer JSON results.

## Environment requirements

- **Vivado version used:** 2024.1
  (`source /sdf/group/faders/tools/xilinx/2024.1/Vivado/2024.1/settings64.sh`).
- **System libstdc++ auto-preload:** the harness (`xsim_test_utils.xsim_run_env`) locates
  the system libstdc++ via `gcc -print-file-name=libstdc++.so.6` and prepends it to
  `LD_PRELOAD`. Every bundled Vivado libstdc++ is older than the host libzmq's required
  `GLIBCXX_*`, so without the preload `xsimk` fails to load `libzmq.so.5`. Harmless when
  Vivado's bundled libstdc++ is already new enough.

## Timing / ordering design

- **Peer-spawn-after-elaboration ordering:** the test elaborates first
  (`compile_and_elaborate`), then spawns the peers immediately before `run_elaborated`.
  The peers' RCVTIMEO budget therefore covers only the short simulation run, not the
  multi-second compile/elaborate flow.
- **Test-side ready barrier:** each peer writes its unique ready file after socket setup
  and its ZeroMQ `connect()` calls. The parent waits for all eight files with a bounded
  deadline and fails early if a peer exits. This removes Python import and socket-setup
  variability without changing the Rogue-TCP wire protocol.
- **Fixed settle delay after readiness:** `SETTLE_EDGES_C = 2000` (~20 us). ZeroMQ
  connection establishment is asynchronous, so all three families still hold off
  outbound traffic after the model binds. The ready file means the peer is prepared to
  connect and drain, not that the protocol connection is already complete.
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

These Vivado results cover the original live-traffic implementation at pull request
head `c505a2e08`. After the pull request 1450 API reconciliation and ready-barrier
addition, the focused peer/native tests pass locally, as do Python lint, VSG, and diff
checks. A final Vivado run is required because the Stream vector shape and xsim startup
orchestration changed.

## Lint results

- **flake8** (7.3.0) on the 5 Python sources: clean (rc=0).
- **git diff --check:** clean.
- **VSG** (3.35.0) on `RogueXsimTrafficTb.vhd`: clean. The prior `type_006`,
  declaration-alignment, and PascalCase violations were corrected without changing test
  behavior.

## Open risks / notes for reviewer

- **Readiness boundary:** the ready-file barrier removes Python import/socket-setup races,
  but cannot prove an asynchronous ZeroMQ connection is complete. `SETTLE_EDGES_C` remains
  a fixed margin after model bind and may need retuning if topology or latency changes.
- **Watchdog is a wall-clock heuristic:** `WAIT_EDGES_C` maps to ~10 s worst case only
  under current sim pacing; treat as a hang guard, not a precise bound.
- **obValid observation race (already fixed):** an earlier single-cycle `obValid`
  observation race is handled by sampling every clock edge rather than at a single point.
- **RCVTIMEO raised to 30 s:** affects all peer-using tests. It only loosens the timeout
  bound (30 s vs 10 s), so it cannot cause false passes; worst case is a slower failure
  when a peer genuinely never connects.
- Simulator artifacts (`sim_build_*`, `xsim.dir`, `*.pb`, `*.jou`) are intentionally kept
  out of git; only summarized here.
