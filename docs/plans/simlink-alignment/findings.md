# SimLink Alignment — Review and Hardening Findings

Closed-out summary of the code-review and hardening findings for the SimLink
subsystem (`simlink/` and `tests/simlink/`) on the `simlink-alignment` branch.
Complements [README.md](README.md), which tracks phase status and design
decisions. Findings came from two review passes (a full 4-area review of shared
C transport, simulator adapters, VHDL, and Python/CI/build, plus a follow-up
"new items only" sweep) and from running the full `tests/simlink` suite.

Provenance tags: **branch-new** = introduced by this branch; **pre-existing** =
carried in via the `axi/simlink/` → `simlink/` relocation.

Status at close: all actioned or dispositioned. One item is deferred (an xsim
test flake that needs a licensed Vivado run to fix and verify); everything else
is resolved or was confirmed not a defect. Full open-source regression:
**95 passed, 7 skipped, 0 failed** (skips need proprietary tools or separately
provisioned environments).

## High-severity defects — fixed

- **`channelMap`/`CHAN_COUNT_C` overflow for non-power-of-two `CHAN_COUNT_G`**
  (pre-existing) — `simlink/sim/RogueTcpStreamWrap.vhd`. With `CHAN_MASK_G=X"00"`,
  `CHAN_COUNT_C := CHAN_COUNT_G` while the derived `CHAN_MASK_C` spans
  `ceil(log2(N))` bits, so `channelMap` produces `2**ceil(log2(N))` subset codes
  and writes past `ret(0 to N-1)` for N = 3, 5, 6, 7…; `CHAN_COUNT_G=0` also
  yields null-range arrays. Byte-identical to `master` — relocated, not
  introduced. Fixed by bounding the append loop to `chan < CHAN_COUNT_C` and
  adding a `CHAN_COUNT_G >= 1` elaboration assert. A persistent regression test
  was added: the now-renamed `RogueTcpStreamFlatHarness.vhd` gained a pass-through
  `CHAN_COUNT_G` generic (default 1) and `test_RogueTcpStreamWrap.py` a `chan3`
  elaborate-and-idle case (reserved port range `GHDL_STREAM_MULTICHAN`).
  Confirmed the test fails on the unfixed loop and passes on the fix.

- **`vhpiIn == 0` port-spec false-fatal** (branch-new) — `d4d249145`. The new
  `VhpiGenericInit` treated `direction == 0` as an "unset" sentinel, but the VHPI
  standard defines `vhpiIn == 0`, so every input port tripped a `vhpiFatal` at
  0 ps and segfaulted. Fixed by validating against the real modes
  (`vhpiIn`/`vhpiOut`); the legitimate `width < 0` check is kept.

- **VCS `$finish` teardown segfault** (branch-new) — `32e35212e`. Registering a
  `vhpiCbEndOfSimulation` callback under the cocotb VPI-driven flow segfaults
  inside VCS's `vpi_control [vpiFinish]` (~2/3 of runs, vanishes under gdb) — a
  VHPI/VPI shutdown-ordering conflict in the simulator, reproducible with an
  empty callback body. Fixed by not registering the callback; teardown at
  `$finish` is unnecessary (process exits, OS reclaims), and the worker
  thread/ZeroMQ sockets are still released by `atexit(rogueSimLinkDestroyAll)`.

- **VCS lifecycle harness left out of sync by the `$finish` fix** (branch-new) —
  surfaced this session by a full-suite run; missed originally because the
  gcc-only `test_VhpiGenericLifecycle` lived in `tests/simlink/vcs/` (excluded
  from the `native`-scoped verification by path) with no `skipif` guard. It
  failed to build (`-Werror=unused-variable` on the now-orphaned cleanup-callback
  statics) and, once built, aborted (`assert(callbacks[vhpiCbEndOfSimulation]
  != NULL)`). Fixed by exporting `VhpiGenericCleanup`, dropping the orphaned
  statics, and rewriting the harness to assert the callback is *not* registered
  and drive teardown directly. Also closed the process gap: the test, its
  harness, and the stub `vhpi_user.h` were moved to `tests/simlink/native/` and
  given a `skipif(which("gcc") is None)` guard, so a native-scoped run now
  collects it (44 tests, was 42).

## Medium/Low findings — resolved

- **VCS per-edge callbacks missing NULL guard** and **signed-shift UB in AXI
  write-word assembly** (`9eaa42d01`); **xdist port collision**, scattered port
  literals, and two unbounded cocotb loops (`3ba772acd`, via the central
  `tests/simlink/ports.py` `PortRange` registry + collection-time disjointness
  test); **dead includes / unused macros / leaked `blockName`** dead-code
  cleanup.
- **Missing port-direction comments** — annotated the three core-instance port
  maps in `Rogue{TcpStream,SideBand,TcpMemory}Wrap.vhd` (the flat-wrapper maps
  the finding also cited were already annotated).
- **Pacer flat-wrapper generic names/units** — renamed to `AXIS_CLK_FREQ_HZ_G`
  and `PAYLOAD_RATE_BPS_G`; the bps (pacer) vs kbps (stream wrapper) split is
  intentional and now documented (sub-kbit/s resolution vs 32-bit-`natural`
  overflow at Gbit/s).
- **Misc VHDL** — removed dead `std_logic_arith`/`std_logic_unsigned` clauses in
  the two VCS empty-architecture files; commented out the dead `tStrb` write in
  the stream flat wrapper (`TSTRB_EN_C => false`); standardized the `CHAN_MASK_G`
  default literal to `x"00"`.
- **TOCTOU in `_unused_tcp_port_pair`** — replaced the bind/close/rebind probe
  with a statically-reserved `GHDL_MEMORY_MALFORMED` range (one pair per case,
  disjointness-checked).
- **Timing-fragile overload assertion** — replaced the `+40`-cycle margin with a
  monotonic property (a longer peer delay lands on a strictly later cycle).
- **Duplicated socket helpers** — consolidated into
  `tests/simlink/common/zmq_sockets.py` (`make_socket`/`pull_socket`); call
  sites delegate.
- **Brittle VCS banner assertions** — match only the `"<first> & <second>"` port
  fragment, not the surrounding prose (VCS-gated; validate under license).
- **Flaky GHDL multi-instance traffic** — an env-overridable edge budget was
  only a workaround; the budget covered eight peer process startups and was
  denominated in simulated edges, so its real-time allowance scaled with host
  simulation speed (10,000 edges was ~5 s on a loaded CI runner). Fixed by
  waiting for every peer's readiness file before the model binds, and by
  bounding peer completion by wall clock instead
  (`SIMLINK_MULTI_MAX_TRAFFIC_SECONDS`, default 60).
- **Tri-state paths in `VhpiGeneric.c`** — kept + documented as an
  intentionally-dormant general-VHPI-helper capability (`outEnable` is always 1
  today; comment-only).

## Investigated — not defects

- **Backend failure contract is consistent** — xsim's `return 0` is not "silently
  continue": each xsim DPI leaf checks it and raises `$fatal(1, ...)`, so all
  three backends fail hard.
- **`T_READ`/`T_VERIFY` are used** — the C-side wire contract in
  `RogueTcpMemoryModel.h`, consumed by the Python harness. Kept.
- **Fixed result files "not pre-cleared"** — already handled: all fixed-path
  result writes go through `managed_peer`/`spawn_peer_group`, which
  `unlink(missing_ok=True)` first; other writes use pytest `tmp_path`.
- **"Unconditional sideband remData sampling"** — the suggested "gate
  symmetrically" fix is wrong: `rxRemData` updates on an independent wire flag
  from the one-cycle `rxOpCodeEn` pulse and is a held register; gating it drops
  valid updates (empirically fails `test_rogue_ghdl_multi_instance_traffic`).
  Current ungated capture is correct.

## Resolved

- **Flaky `test_rogue_xsim_traffic` under back-to-back load** (branch-new) —
  originally filed against `SETTLE_EDGES_C = 2000` as an "async-connect settle
  budget too short" flake. A licensed Vivado run disproved that: widening the
  settle window to 100x (via a temporary `xelab -generic_top SETTLE_EDGES_G`)
  still failed, and the isolated test flaked fail/fail/pass at a fixed setting.
  Transport-C instrumentation (temporary `stderr` probes at the worker
  socket-recv and ring-dequeue boundaries) pinned the true cause: the
  peer→model **Stream** frame is dropped at the ZeroMQ layer *before the model's
  worker ever receives it* — a classic **PUSH slow-joiner drop**. The test
  peer's PUSH `connect()`s and immediately `send()`s its inbound frame; if the
  pipe to the model's bound PULL is not yet established, ZMQ silently discards
  it (the peer's PUSH did not set `ZMQ_IMMEDIATE`). No HDL settle can recover an
  already-dropped frame. Memory is immune (request/response is self-
  synchronizing); only Stream/SideBand are exposed because they are fire-and-
  forget with no production readiness transaction (see README "Lifecycle and
  readiness"). **Fix (peer-side; no product-C or wire-protocol change, so
  real-Rogue compatibility is untouched):** each sending peer now waits for its
  PUSH socket's `ZMQ_EVENT_CONNECTED` (bounded, via a ZMQ socket monitor) after
  signaling ready and before its first send, hard-failing on timeout
  (`SIMLINK_PEER_CONNECT_TIMEOUT_MS`, default 30000). The settle-generic work
  was reverted as not-the-lever. Verified under Vivado 2025.2 on rdsrv419:
  isolated traffic x5 and full `run-xsim.sh` x5 all green (was ~2/3 failing
  under load), GHDL (25 passed / 2 skipped) and native (70 passed) unaffected.

## Deferred

- **CI never exercises the xsim or VCS layers** — `.github/workflows/surf_ci.yml`
  runs only on hosted `ubuntu-24.04` runners with no proprietary tools, so the
  xsim (Vivado) and VCS (Synopsys) adapters are **manual-verify-only**: a fully
  green CI run does not cover them, and the recent xsim slow-joiner flake could
  never have been caught by CI. (native/GHDL/rogue are genuinely covered —
  valgrind is apt-installed at surf_ci.yml:102 so the memory-safety checks run,
  and the required `simlink_rogue` job hard-fails if rogue is unimportable.)
  Also note there is no pytest skip-strictness, so a test that regresses into a
  skip passes silently. **Follow-up (infra, tracked):** add a self-hosted runner
  (e.g. rdsrv419-class, with Vivado + VCS + valgrind) that runs `run-xsim.sh`
  and `run-vcs.sh` in CI. Until then, run the full `tests/simlink/run.sh` on a
  licensed host before release. Not a product-code defect.
  **Companion (same CI touch):** the required `simlink_rogue` job
  (`surf_ci.yml:138`) currently runs only `test_RogueTcpMemoryRogue.py`. Now
  that `test_RogueStreamRogue.py` and `test_RogueSideBandRogue.py` exist and
  pass locally (real `stream.TcpClient` / `SideBandSim` against GHDL), extend
  that job's pytest invocation to include them — a one-line change, batched with
  this CI follow-up.

- **VCS layer coverage is shallow (one test)** — VCS runs only the eight-instance
  traffic scenario (`test_RogueVcsMultiInstance.py`); it covers none of the
  leaf/wrapper surface GHDL does (Memory `SLVERR`/`DECERR` matrix, TKEEP/TLAST
  boundaries, pacing, malformed-request rejection, SideBand opcode/remData edge
  cases). A VHPI-adapter bug in one of those paths would ship undetected. The
  enhancement mechanism already exists: `RogueSimLinkVcsVpiBridge.sv` is a VPI
  bridge that flattens the shared VHDL top so cocotb can drive it; per-family
  bridges over the wrapper tops would let VCS reuse GHDL's wrapper cocotb bodies.
  **Follow-up (in progress):** design full VCS wrapper coverage via the bridge
  pattern.

- **`channelMap` overflow for non-power-of-two counts also affects `master`** —
  the fix above lives on this branch; the identical latent bug on `master`
  outside `simlink/` is a maintainer call, out of scope here.

## Known design-level items (intentional)

Documented in [README.md](README.md) and not defects: single-thread global
instance registry (`atexit`-only release hook); `CLOCK_REALTIME` condvar
deadlines; 64-bit AXI address truncated to `unsigned int` in the memory FSM
(harmless for 32-bit AXI-Lite); host-endianness assumption for scalar frames;
process-abort error model for GHDL/xsim; fixed 20 MB Stream buffers per instance.
