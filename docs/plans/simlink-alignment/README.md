# SimLink Alignment and Hardening

## Goal

Align the GHDL/VHPIDIRECT, VCS/VHPI, and Vivado xsim/DPI SimLink backends while
preserving the public `Rogue*Wrap` interfaces and established Rogue wire
protocols. Simulator adapters should contain only ABI translation, callbacks,
and diagnostics; shared C code should own model, lifecycle, and transport
behavior.

Code-review and hardening findings (all resolved or dispositioned; one xsim
test flake deferred to a licensed run) are summarized in
[findings.md](findings.md).

## Branch and Baseline

- Branch: `simlink-alignment`
- Base: `cosim-xsim`

## Status

The alignment implementation is complete. Reload/restart hardening now has
portable coverage, with exact proprietary lifecycle commands still open:

- SimLink is a top-level subsystem under `simlink/`, with tests under
  `tests/simlink/`.
- Stream, Memory, and SideBand share compiled model cores, instance lifecycle,
  complete port-pair ownership, and a worker-owned ZeroMQ transport.
- GHDL links all models into one process-wide VHPIDIRECT library; VCS and xsim
  likewise build one combined backend library.
- The Stream foreign boundary supports 1 through 128 payload bytes per beat.
- `RogueTcpStreamWrap` provides independent aggregate payload-rate controls in
  both directions, with zero-rate compatibility bypass.
- GHDL and VCS share an active eight-instance cocotb topology and scenario.
  xsim uses the same allocation and result contract with a self-driving
  mixed-language top.
- A separately provisioned real-Rogue test verifies Memory readiness and
  PyRogue Write/Verify/Read/Post/Read behavior.
- Model type validation uses caller-owned static descriptors rather than a
  central enum, and live-registry membership replaces the former magic-value
  check.
- A persistent ZeroMQ peer is tested across model recreation and across two
  complete GHDL simulator runs, including a request queued during the gap. An
  equivalent two-`simv` VCS regression is checked in behind the license gate.

User-facing architecture, wire contracts, backend setup, and test commands are
documented in [simlink/README.md](../../../simlink/README.md) and
[tests/simlink/README.md](../../../tests/simlink/README.md).

## Decisions

### Compatibility surface

- The record-based `RogueTcpStreamWrap`, `RogueTcpMemoryWrap`, and
  `RogueSideBandWrap` entities are the stable downstream interfaces.
- Backend leaves retain their entity names but may use simulator-oriented
  scalar/vector ports.
- Existing multipart frame order, field sizes, host byte order, socket
  directions, transaction identifiers, and SSI/AXI sideband behavior remain
  unchanged.
- Memory ordinary responses remain four-byte numeric AXI responses. Only the
  `TcpBridgeProbe` readiness response uses ASCII `OK`, as required by
  `TcpClient.waitReady()`.

### Ownership and transport

- One worker exclusively owns each model's ZeroMQ context and socket pair.
- Complete inbound messages cross into a bounded 16-entry FIFO. The worker
  stops draining when full and never drops or overwrites an entry.
- Cumulative inbound size is checked before allocation: Stream permits
  `MAX_FRAME` plus metadata, Memory permits `MAX_DATA` plus metadata, and
  SideBand permits four bytes.
- Outbound messages use a single-message rendezvous with a PUSH high-water
  mark of one.
- Missing or stalled peers use a 30-second wall-clock deadline followed by a
  fatal model diagnostic. `SURF_SIMLINK_TRANSPORT_TIMEOUT_MS` provides one
  positive-decimal millisecond override for all model types.
- Sockets use `ZMQ_IMMEDIATE=1` and `ZMQ_LINGER=0`; worker polling, sends, and
  shutdown joins are bounded.
- The complete adjacent port pair is reserved process-wide before either bind
  and released only after both sockets close.

### Timing model

- Host transport handoff uses wall-clock time and does not define simulated
  bandwidth.
- `RogueTcpStreamPacer` uses fixed-point payload-byte credit and debits only
  completed AXI Stream handshakes.
- Credit is capped at one beat, preventing an unlimited catch-up burst after
  idle time or backpressure.
- Pacing is aggregate across channels in each direction. It models payload
  rate only, not encoding efficiency, frame overhead, inter-frame gap,
  propagation latency, or software launch timestamps.
- Memory and SideBand do not provide rate shaping.

## Implementation map

| Area | Files |
| --- | --- |
| Public overview and backend selection | `simlink/README.md`, `simlink/ruckus.tcl` |
| Shared Stream model and codec | `simlink/shared/RogueTcpStreamModel.h`, `RogueTcpStreamCore.h`, `RogueTcpStreamCore.c` |
| Shared Memory model and codec | `simlink/shared/RogueTcpMemoryModel.h`, `RogueTcpMemoryCore.h`, `RogueTcpMemoryCore.c` |
| Shared SideBand model and codec | `simlink/shared/RogueSideBandModel.h`, `RogueSideBandCore.h`, `RogueSideBandCore.c` |
| Common lifecycle and port registry | `simlink/shared/RogueSimLinkInstance.[ch]` |
| Worker-owned transport | `simlink/shared/RogueSimLinkTransport.[ch]` |
| GHDL adapter | `simlink/ghdl/` |
| VCS adapter | `simlink/vcs/` |
| xsim adapter | `simlink/xsim/` |
| Public simulation interfaces and pacing | `simlink/sim/` |
| Test-only HDL/SV harnesses and testbenches | `simlink/test/` |
| Shared test support and protocol peer | `tests/simlink/common/` |
| Native transport/adapter tests | `tests/simlink/native/` |
| Simulator runners | `tests/simlink/{ghdl,vcs,xsim}/` |
| Production Rogue contract | `tests/simlink/rogue/` |

## Verification

### Open-source/local

- The complete local run before adding the VCS-gated relaunch case passed 94
  with 12 skips. The final aggregate collection added that expected VCS skip
  and hit the then host-scheduling-sensitive GHDL multi-instance edge limit
  (93 passed, 13 skipped, 7/8 peers complete in the remaining case). That case
  now waits for peer readiness before the model binds and bounds peer
  completion by wall clock, so host scheduling no longer shrinks the allowance.
  Skips require unavailable proprietary tools or separately provisioned Rogue
  environments.
- GHDL shared-library build succeeds on macOS, including basename-only Mach-O
  install-name handling and generated header dependencies.
- VCS and xsim Makefile dry runs select all intended adapters and shared cores.
- Targeted flake8, C builds, and `git diff --check` pass.

### Licensed/Linux evidence

Execution on `rdsrv419` on 2026-07-20 established the following. These counts
predate the later review/hardening fixes in [findings.md](findings.md) (which
added tests and changed open-source totals); the licensed backends should be
re-run once before merge to confirm they still pass with those changes.

- GHDL complete suite: 88 passed, 7 skipped in the plain GHDL environment.
- Vivado 2025.2 xsim: all three mixed-language tests passed.
- VCS X-2025.06: the checked-in opt-in active eight-instance cocotb test passed
  after analyzing the SystemVerilog VPI bridge into the same `work` library as
  the VHDL topology.
- Linux Valgrind lifecycle and uninitialized-read tests passed.
- Production Rogue Memory readiness and PyRogue transactions passed.

Run proprietary backends in separate configured shells. Vivado's library-path
changes can perturb GHDL loading, and VCS runtime checkout may require
`SIMLINK_VCS_LICENSE_FILE` when the default server list begins with an
unreachable host.

## Remaining risks and follow-up

- VCS teardown at `$finish` is intentionally passive: registering a
  `vhpiCbEndOfSimulation` callback segfaults VCS under the cocotb VPI flow, so
  the process-exit `atexit(rogueSimLinkDestroyAll)` hook owns the only teardown
  with side effects. `VhpiGenericCleanup` is exported for a future non-cocotb
  path that can register it safely (see [findings.md](findings.md)).
- Exact lifecycle-command coverage remains to be added on licensed tools. In
  particular, distinguish the checked two-`simv` VCS relaunch from an in-place
  VCS GUI/UCLI module re-exec, and xsim `relaunch_sim` from xsim's same-runtime,
  time-zero `restart`; the GHDL process-rerun test proves the portable reconnect
  contract but is not evidence for all of those commands.
  The xsim restart test must also determine whether the SV `chandle` rewinds to
  null while its C allocation survives, a combination that would intentionally
  fail registry overlap validation until explicit restart reconciliation is
  added.
- Stream and SideBand have no production readiness transaction comparable to
  Memory's `TcpBridgeProbe`.
- Software-originated frame admission depends on host scheduling because the
  wire protocol carries no target simulation timestamp. Serialization after
  admission is deterministic.
- Stream allocates fixed 20,000,000-byte inbound and outbound buffers per
  instance. A future allocation redesign could reduce idle memory cost without
  changing the wire protocol.
- Real-Rogue CI currently covers the Memory API. Stream, SideBand, and a
  production SURF PyRogue Device-to-RTL contract remain useful extensions.
- Exact-cycle pacing is covered in GHDL and the reference model; equivalent
  paced execution through xsim and VCS would strengthen cross-backend timing
  evidence.
- Generalize the legacy PGP2b-oriented SideBand path as a follow-on task.
  Prefer a protocol-neutral, bidirectional framed-message transport with an
  AXI Stream HDL interface, then put PGP2b, PGP2fc, PGP3, and PGP4 event/state
  encoding in protocol-specific simulation adapters. Preserve
  `RogueSideBandWrap` and Rogue `SideBandSim` compatibility during migration;
  widening the existing opcode/remData fields alone would not cover the
  different message types, field widths, and ready/valid semantics.

These are follow-up opportunities, not blockers for the completed alignment
scope.
