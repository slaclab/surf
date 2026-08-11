# Xsim Multi-Instance Live Traffic Design

> **Historical implementation record:** Paths and commands under
> `axi/simlink` and `tests/axi/simlink` describe the pre-alignment branch and
> are not current usage instructions. Start with the current
> [SimLink documentation](../../../simlink/README.md).

## Goal

Prove, under real Vivado xsim, that the eight-instance mixed-language DPI
topology (4 Stream, 2 Memory, 2 SideBand) exchanges **isolated, live ZeroMQ
traffic** through the actual DPI-C boundary — not just elaborates and binds
sockets. Each instance must exchange canonical per-instance vectors with its
dedicated peer, and no instance's traffic may reach another instance's peer.

This extends the existing xsim coverage. Today `RogueXsimMultiTb` proves
per-`chandle` creation, distinct port binding, repeated reset, and normal
`final` cleanup, but drives benign constant inputs with **no external peer**, so
no data flows. The native `test_dpi_instances_exchange_isolated_active_traffic`
test proves live isolated traffic, but through host `gcc`, not the xsim DPI
boundary. This design closes the gap between them: live isolated traffic
*through xsim*.

## Background and Constraints

- **Original plan split (docs/plans/xsim-cosim-multi-instance/README.md,
  Milestone 4):** live transport was deliberately kept in the native C+ZMQ test
  so it stays runnable without a Vivado license, while xsim covered only
  ABI/elaboration. This design is an additive step now that Vivado is available;
  it does not remove or weaken the native or elaboration coverage.
- **Connected-and-draining contract:** the shared cores send over ZeroMQ
  synchronously on the simulator thread. Peers must be connected and draining
  before the HDL produces outbound traffic, or a send can stall the sim and
  inbound frames can be dropped (the slow-joiner race). This design honors that
  contract with a test-side ready-file barrier followed by a fixed post-reset
  settle delay (see Readiness).
- **No wire-protocol handshake:** the plan forbids adding a readiness handshake
  to the Rogue-TCP protocol. The ready file coordinates only the pytest parent
  and peer subprocess; it adds no message or socket to the model protocol.
- **Source untouched:** no changes to any model C, SV, or VHDL *entity* source.
  Changes are test-only, plus a backward-compatible extension to the peer
  script.
- **Environment:** validated under Vivado 2024.1 at
  `/sdf/group/faders/tools/xilinx/2024.1`. Every installed Vivado bundles a
  libstdc++ older than the host libzmq, so the xsim run must preload the system
  libstdc++ (already solved by `xsim_run_env()` in `xsim_test_utils.py`).

## Approach

Approach A (chosen): a self-contained VHDL testbench drives the eight model
instances, and eight independent `rogue_tcp_peer.py` subprocesses (one per
instance) provide the connected-and-draining peers. Orchestration and final
assertions run in pytest via the already-validated
`make → xvlog → xvhdl → xelab → xsim -R` pipeline.

Rejected alternatives:

- **cocotb-driven xsim:** runs cocotb's VPI/VHPI foreign interface and the SV
  DPI leaves in the same xsim process (two foreign-function paths), targets the
  flat wrappers rather than the raw model entities, and is the least-mature
  simulator combination. Highest yak-shave risk.
- **Single multi-socket peer:** one process managing all eight port pairs; a
  stall on one socket can mask another, and it is less faithful to the
  "independent peer per instance" isolation story.

## Data Flow

```
pytest (test_RogueXsimTraffic.py)
  1. make -C axi/simlink/xsim all abi-check          # build RogueTcpDpi.so (reused fixture)
  2. xvlog / xvhdl / xelab  RogueXsimTrafficTb        # compile + elaborate (env = xsim_run_env(), LD_PRELOAD)
  3. Popen 8 rogue_tcp_peer.py, one per instance      # canonical *-instance mode and unique ready file; spawned
                                                      # AFTER elaboration so their RCVTIMEO covers only the run
  4. wait for all 8 ready files                        # sockets configured and connect() calls issued
  5. xsim -R  RogueXsimTrafficTb                      # run the elaborated snapshot with peers ready to drain
        - VHDL top holds off outbound traffic for a fixed settle delay (asynchronous ZMQ handshake margin)
        - each of 8 instances exchanges canonical vectors with its own peer
        - top $fatal on any wrong/missing tag; prints banner on full success
  6. assert: banner in stdout AND all 8 peers exited 0 AND each peer's JSON exactly matches
     its own expected instance result
  7. finally: reap all 8 peers unconditionally
```

Instance `i` uses the same vectors as pull request 1450. Stream peer-to-DUT is
`[0x10+i, 0x20+i, 0x30+i, 0x40+i]`; DUT-to-peer is
`[0x80+i, 0x90+i, 0xA0+i, 0xB0+i]`. Memory keys address/data to `i`, and
SideBand keys opcode/remData to `i`. Exact comparison against each instance's
expected vectors detects missing, corrupted, or cross-instance traffic.

## Components

### 1. `tests/axi/simlink/RogueXsimTrafficTb.vhd` (new)

VHDL top instantiating the same eight models as `RogueXsimMultiTb` on the same
distinct port-pair scheme, but with active per-instance stimulus and checking
instead of tie-offs:

- **Stream `i`:** drive one inbound (`ib*`) frame containing
  `[0x80+i, 0x90+i, 0xA0+i, 0xB0+i]`; hold `obReady = '1'`; collect the
  outbound frame and compare all four bytes with
  `[0x10+i, 0x20+i, 0x30+i, 0x40+i]`, `$fatal` on mismatch.
- **Memory `i`:** drive AXI-Lite responses so the model completes the peer's
  write-then-read transactions at address/data keyed to `i`; `$fatal` if an
  observed transaction address is not `i`'s family.
- **SideBand `i`:** strobe `txOpCodeEn` / `txRemData` with `i`-keyed values;
  check `rxOpCode` / `rxRemData` latch the peer's `i`-keyed values, `$fatal` on
  mismatch.
- After all eight instances pass, `report "Rogue xsim traffic test passed"`
  then `stop`.

All waits are bounded clock-cycle loops: a generous fixed settle delay after
reset before any outbound traffic, and a bounded per-instance wait for each
expected inbound item with `$fatal` if it never arrives. No unbounded `wait`.

Because `$fatal` under `xsim -R` exits 0 (established in
`test_RogueXsimMulti.py`), correctness is judged by the success banner and the
peer exit codes/JSON, not by the xsim return code. The top must not print the
banner on any failing path.

### 2. `tests/axi/simlink/rogue_tcp_peer.py` (extend, backward-compatible)

Reuse the canonical peer API introduced by pull request 1450:

- `stream_instance_vectors(tag)` with the `stream-instance` CLI mode,
- `memory_instance_transactions(tag)` with the `memory-instance` CLI mode,
- `sideband_instance_vectors(tag)` with the `sideband-instance` CLI mode.

Each mode compares the received traffic with its exact instance vector and
writes a JSON result. The optional `--ready-file` is test coordination only:
the peer writes it after configuring its sockets and issuing its ZeroMQ
`connect()` calls. Existing non-instance modes remain unchanged.

### 3. `tests/axi/simlink/xsim_test_utils.py` (new; refactor, no behavior change)

Factor the shared xsim helpers currently in `test_RogueXsimMulti.py` into one
module so both test modules import them rather than copy-paste:

- `xsim_run_env()` (LD_PRELOAD of system libstdc++),
- the required-tools `pytestmark` skip predicate and tool list,
- the `build_dpi_library` fixture (`make ... all abi-check`),
- the compile/elaborate/run helper (`xvlog`/`xvhdl`/`xelab`/`xsim`).

`test_RogueXsimMulti.py` is updated to import from here; its tests keep passing
unchanged.

### 4. `tests/axi/simlink/test_RogueXsimTraffic.py` (new)

Orchestrates the run: launches the eight peers, runs the traffic top, and makes
the final assertions. It removes stale result and ready files, waits for all
eight ready files with a bounded deadline, fails early if any peer exits, and
then starts xsim. It reuses the shared skip mark, build fixture, and
`xsim_run_env()` from `xsim_test_utils.py` and reaps all peers in a `finally:`
on every path.

## Readiness (test-side barrier plus settle delay)

There is no Rogue-TCP protocol handshake or new socket. Each peer writes a
unique ready file after Python startup, socket configuration, and its ZeroMQ
`connect()` calls. The pytest parent waits for all eight files before starting
xsim, with a bounded deadline and early peer-exit detection.

ZeroMQ connection establishment remains asynchronous, so the VHDL top also
holds off outbound traffic for a fixed number of clock cycles after reset.
The file barrier removes Python import and socket-setup variability; the
settle delay supplies margin for the protocol handshake after the model binds.
The ready file therefore means “prepared to connect and drain,” not “the
ZeroMQ connection is fully established.”

## Error Handling and Liveness

- **VHDL:** bounded cycle loops everywhere; `$fatal` on any wrong/missing tag or
  unmet expectation; banner only on full success.
- **pytest:** `xsim -R` bounded by `RUN_TIMEOUT_SECONDS`; every peer `Popen`
  reaped in `finally:` so no orphan peers leak across xdist workers. Peer
  readiness has its own bounded deadline and reports an early subprocess exit
  before xsim is launched.
- **peers:** existing `RCVTIMEO` bounds keep any peer from blocking forever; a
  timed-out peer writes its JSON and exits nonzero.
- **diagnostics:** failing assertions include xsim stdout+stderr and the
  offending peer's JSON so cross-talk or a dropped frame is diagnosable without
  a rerun.

## Testing / Acceptance

The new test passes only when all of:

1. xsim stdout contains `"Rogue xsim traffic test passed"`.
2. All eight peer processes exit 0.
3. Each peer's JSON exactly matches its expected per-instance result.

Additional required outcomes:

- With Vivado tools absent, the module skips cleanly (unchanged CI stays green).
- The existing `test_RogueXsimMulti.py` tests and all GHDL Wrap tests still pass
  after the `xsim_test_utils.py` refactor, canonical instance-mode reuse, and
  test-only `--ready-file` extension
  (regression check: full `tests/axi/simlink` suite, serial and
  `-n auto --dist=worksteal`).

## Scope

In scope:

- New `RogueXsimTrafficTb.vhd`, `test_RogueXsimTraffic.py`, `xsim_test_utils.py`.
- Canonical per-instance peer modes and a backward-compatible, test-only
  `--ready-file` extension to `rogue_tcp_peer.py`.
- Refactor of shared xsim helpers out of `test_RogueXsimMulti.py`.

Out of scope (YAGNI):

- Porting sparse-tKeep or uninitialized-read reproductions to xsim (stay
  GHDL-only).
- Any change to model C, SV, or VHDL entity source.
- Any change to the Rogue-TCP wire format or transport semantics.
- A Rogue-TCP protocol readiness handshake or new socket.
- Multi-version Vivado sweep (validate on 2024.1; other versions inherit the
  same LD_PRELOAD path).
