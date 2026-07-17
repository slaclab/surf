# Xsim Multi-Instance Live Traffic Design

## Goal

Prove, under real Vivado xsim, that the eight-instance mixed-language DPI
topology (4 Stream, 2 Memory, 2 SideBand) exchanges **isolated, live ZeroMQ
traffic** through the actual DPI-C boundary — not just elaborates and binds
sockets. Each instance must exchange a few tagged items with its own dedicated
peer, and no instance's traffic may reach another instance's peer.

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
  contract with a fixed post-reset settle delay (see Readiness).
- **No wire-protocol handshake:** the plan forbids adding a readiness handshake
  to the Rogue-TCP protocol. Readiness is handled by timing, not by a new
  message or socket.
- **Source untouched:** no changes to any model C, SV, or VHDL *entity* source.
  Changes are test-only, plus a backward-compatible extension to the peer
  script.
- **Environment:** validated under Vivado 2024.1 at
  `/sdf/group/faders/tools/xilinx/2024.1`. Every installed Vivado bundles a
  libstdc++ older than the host libzmq, so the xsim run must preload the system
  libstdc++ (already solved by `_xsim_run_env()` in `test_RogueXsimMulti.py`).

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
  2. xvlog / xvhdl / xelab  RogueXsimTrafficTb        # compile + elaborate (env = _xsim_run_env(), LD_PRELOAD)
  3. Popen 8 rogue_tcp_peer.py, one per instance      # each with --tag <i>, its own port pair; spawned
                                                      # AFTER elaboration so their RCVTIMEO covers only the run
  3b. xsim -R  RogueXsimTrafficTb                      # run the elaborated snapshot with peers already draining
        - VHDL top holds off outbound traffic for a fixed settle delay (peers connect/drain)
        - each of 8 instances exchanges a few tagged items with its own peer
        - top $fatal on any wrong/missing tag; prints banner on full success
  4. assert: banner in stdout AND all 8 peers exited 0 AND each peer's JSON shows
     only its own tag family and zero foreign tags
  5. finally: reap all 8 peers unconditionally
```

Tag families: instance `i` sends items identifying itself and expects only its
peer's matching family back. Stream uses payload bytes `0x80+i` (DUT→peer) and
`0x10+i` (peer→DUT); Memory keys address/data to `i`; SideBand keys
opcode/remData to `i`. Foreign tags are any `*+j` with `j != i`.

## Components

### 1. `tests/axi/simlink/RogueXsimTrafficTb.vhd` (new)

VHDL top instantiating the same eight models as `RogueXsimMultiTb` on the same
distinct port-pair scheme, but with active per-instance stimulus and checking
instead of tie-offs:

- **Stream `i`:** drive a few inbound (`ib*`) beats carrying tag `0x80+i`; hold
  `obReady = '1'`; on each `obValid`, check the outbound byte equals the peer's
  expected `0x10+i`, `$fatal` on mismatch.
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

Add an optional `--tag <int>` argument. When present, each `run_*_peer`:

- sends items carrying its own tag family, and
- asserts every received item carries only that family; a foreign tag is
  recorded in the JSON result and causes a nonzero exit.

When `--tag` is omitted, behavior is byte-for-byte the current fixed-vector
behavior, so the existing GHDL Wrap tests are unaffected.

### 3. `tests/axi/simlink/xsim_test_utils.py` (new; refactor, no behavior change)

Factor the shared xsim helpers currently in `test_RogueXsimMulti.py` into one
module so both test modules import them rather than copy-paste:

- `_xsim_run_env()` (LD_PRELOAD of system libstdc++),
- the required-tools `pytestmark` skip predicate and tool list,
- the `build_dpi_library` fixture (`make ... all abi-check`),
- the compile/elaborate/run helper (`xvlog`/`xvhdl`/`xelab`/`xsim`).

`test_RogueXsimMulti.py` is updated to import from here; its tests keep passing
unchanged.

### 4. `tests/axi/simlink/test_RogueXsimTraffic.py` (new)

Orchestrates the run: launches the eight peers, runs the traffic top, and makes
the final assertions. Reuses the shared skip mark, build fixture, and
`_xsim_run_env()` from `xsim_test_utils.py`. Reaps all peers in a `finally:` on
every path.

## Readiness (Option B — fixed settle delay)

No file marker and no protocol handshake. The VHDL top holds off all outbound
traffic for a large fixed number of clock cycles after reset deassertion,
sized against wall-clock peer-startup time with a wide margin, giving eight
freshly-`Popen`'d Python peers time to import, connect, and begin draining.

Known tradeoff, documented in the test: this is the same fixed-timing class as
the GHDL Wrap tests (whose `test_RogueSideBandWrap` has shown occasional
cold-start flakiness). The mitigation is a generous margin rather than a
handshake, per the chosen approach.

## Error Handling and Liveness

- **VHDL:** bounded cycle loops everywhere; `$fatal` on any wrong/missing tag or
  unmet expectation; banner only on full success.
- **pytest:** `xsim -R` bounded by `RUN_TIMEOUT_SECONDS`; every peer `Popen`
  reaped in `finally:` so no orphan peers leak across xdist workers.
- **peers:** existing `RCVTIMEO` bounds keep any peer from blocking forever; a
  timed-out peer writes its JSON and exits nonzero.
- **diagnostics:** failing assertions include xsim stdout+stderr and the
  offending peer's JSON so cross-talk or a dropped frame is diagnosable without
  a rerun.

## Testing / Acceptance

The new test passes only when all of:

1. xsim stdout contains `"Rogue xsim traffic test passed"`.
2. All eight peer processes exit 0.
3. Each peer's JSON shows exactly its own tag family received and zero foreign
   tags.

Additional required outcomes:

- With Vivado tools absent, the module skips cleanly (unchanged CI stays green).
- The existing `test_RogueXsimMulti.py` tests and all GHDL Wrap tests still pass
  after the `xsim_test_utils.py` refactor and the `--tag` peer extension
  (regression check: full `tests/axi/simlink` suite, serial and
  `-n auto --dist=worksteal`).

## Scope

In scope:

- New `RogueXsimTrafficTb.vhd`, `test_RogueXsimTraffic.py`, `xsim_test_utils.py`.
- Backward-compatible `--tag` extension to `rogue_tcp_peer.py`.
- Refactor of shared xsim helpers out of `test_RogueXsimMulti.py`.

Out of scope (YAGNI):

- Porting sparse-tKeep or uninitialized-read reproductions to xsim (stay
  GHDL-only).
- Any change to model C, SV, or VHDL entity source.
- Any change to the Rogue-TCP wire format or transport semantics.
- A readiness handshake or new socket.
- Multi-version Vivado sweep (validate on 2024.1; other versions inherit the
  same LD_PRELOAD path).
```