# SimLink Tests

These regressions test the common SimLink wire/model contract and the
GHDL/VHPIDIRECT, VCS/VHPI, and Vivado xsim/DPI adapters. Read the
[SimLink architecture reference](../../simlink/docs/architecture.md) first.
General cocotb
conventions are in [tests/README.md](../README.md).

This file is for test contributors. Users preparing an environment or running
a first production Rogue transaction should use the
[getting-started guide](../../simlink/docs/getting-started.md).

## Test layers

| Layer | Role | What it proves |
| --- | --- | --- |
| Native C through `ctypes`/small harnesses | Instance lifecycle, persistent-peer rebind, socket failure cleanup, overload characterization, bounds, malformed input, codec transactions | Shared/xsim adapter behavior without an HDL simulator |
| GHDL + cocotb | Clock-level scalar leaves and SURF record wrappers | AXI/SSI reset, handshake, sideband, framing, multi-instance behavior, and peer persistence across process relaunch |
| Deterministic pyzmq peer | Protocol oracle and repeatable peer process | SURF multipart framing and expected vectors |
| Real Rogue | Production client/API compatibility | `TcpClient`, `waitReady`, PyRogue Devices, and real frame APIs |
| xsim mixed-language tests | VHDL -> SV -> DPI integration | ABI, elaboration, instance isolation, traffic, and duplicate-pair rejection |
| Native VCS VHPI shim | Declarative ABI compile and generic lifecycle | End callback remains unregistered; direct cleanup releases metadata and common instances |
| VCS + cocotb | Opt-in licensed VHPI integration | Same active eight-instance tagged-traffic and reset scenario as GHDL |

The pyzmq peer is intentionally small and deterministic. It documents the
numeric ordinary Memory result and ASCII probe result, but because it is not
Rogue it cannot by itself prove the advertised Rogue use case. Real-Rogue
coverage must remain a distinct required suite rather than being replaced by
more codec-oracle tests.

## Layout

| Path | Purpose |
| --- | --- |
| `common/` | Protocol codecs/vectors, peer CLI, shared scenarios, orchestration, and pacing reference model |
| `native/` | C/ctypes lifecycle, transport, bounds, overload, and adapter coverage |
| `ghdl/` | Scalar leaves, SURF wrappers, pacing, lifecycle, and multi-instance cocotb tests |
| `vcs/` | Licensed opt-in multi-instance and persistent-peer relaunch runners |
| `xsim/` | Mixed-language DPI ABI, elaboration, isolation, and traffic tests |
| `rogue/` | Separately provisioned production Rogue/PyRogue contract |

Custom outputs go under `tests/sim_build/simlink/<category>/`. Reusable
simulation VHDL lives under `simlink/sim/`. Test-only HDL and SystemVerilog
assets live under `simlink/test/`; this tree owns their Python runners.

GHDL and VCS share the complete active VHDL top and cocotb scenario. xsim uses
the same peer allocation and result validation but retains self-driving VHDL
because its standalone mixed-language DPI run cannot use the VHPI cocotb
driver without adding another simulator-specific layer.

## Process and port orchestration

Every live leaf requires an exclusive adjacent pair `N/N+1`. Fixed allocations
are declared in `ports.py` and checked for overlap by `common/test_ports.py`, so
the suite can run under pytest-xdist. Negative bind/overlap cases remain in
isolated child processes. Use `-n 0` only when serial simulator logs are useful.

Peer processes create/configure their sockets, call ZeroMQ `connect`, and may
write test-only ready files. ZeroMQ connection establishment remains
asynchronous, so active simulator tests also provide a bounded settle period.
Ready files are orchestration only and must not be treated as a production
SimLink handshake. The Memory `TcpBridgeProbe` is the production readiness
operation.

## Contract traceability

Status describes checked-in automated coverage on the current branch.

| Contract | Native | GHDL/cocotb | Real Rogue | xsim | VCS |
| --- | --- | --- | --- | --- | --- |
| Stream framing, `TKEEP`, `TLAST`, SSI metadata | Partial/bounds plus 64/128-byte DPI beats | Yes, including 8/64/128-byte boundaries | Not yet required in CI | Active traffic | Active traffic executed |
| Memory Read/Write numeric results | Yes | Yes | Checked-in opt-in GHDL contract | Active traffic | Active traffic executed |
| Memory Verify | Yes | Yes through PyRogue | Checked-in opt-in GHDL contract | Not explicit | None |
| Memory readiness probe returns ASCII `OK` without AXI | Yes | Yes | Checked-in `waitReady()` contract | Native adapter | None |
| Memory Post with subsequent tracked Read | Yes | Yes through PyRogue | Checked-in opt-in GHDL contract | Native adapter | None |
| Memory `SLVERR`/`DECERR` matrix and multiword error retention | Yes | Incomplete | Not yet | Native adapter | None |
| SideBand opcode/remData behavior | Yes | Yes | Not yet | Active traffic | Active traffic executed |
| Eight independent mixed instances | Yes | Yes | pyzmq only | Yes | Active traffic executed |
| Complete two-port overlap/reuse | Yes for DPI | Yes, process-wide GHDL | N/A | Yes | None |
| No-peer, stalled-peer, saturation, bounded shutdown | Worker and peer teardown bounded; timeout override parsed | Lifecycle/teardown | Incomplete | Native adapter | Native VHPI metadata teardown |
| Persistent software across model/simulator relaunch | Queued request reaches replacement; consumed/in-flight request is not replayed; later traffic recovers | Same peer process spans two GHDL runs | pyzmq peer | Exact `restart`/`relaunch_sim` not yet covered | Checked-in two-`simv` relaunch; exact in-place GUI/UCLI command not yet covered |
| Deterministic Stream bandwidth | Reference model | Exact-cycle pacer and paced wrapper | pyzmq peer | Common VHDL, execution unavailable | None |

The ordinary open-source job permits the real-Rogue test to skip. The separate
required `SimLink Rogue Contract` job supplies the pinned Rogue environment and
runs the test without allowing a skip.

## Commands

### Runner scripts

Convenience wrappers live alongside these tests. Copy the config template and
edit it for your machine (it is git-ignored):

    cp tests/simlink/env.example.sh tests/simlink/env.local.sh

Then run all available layers, or a subset:

    ./tests/simlink/run.sh              # every layer whose tools are present
    ./tests/simlink/run.sh native ghdl  # a subset

Each layer is also runnable on its own (`run-native.sh`, `run-ghdl.sh`,
`run-rogue.sh`, `run-xsim.sh`, `run-vcs.sh`). The scripts require the vendor
toolchains to already be on `PATH` — source your interactive Vivado/VCS alias
(e.g. `x2024.2`, `simX`) first; a layer whose tool or enable gate is missing is
skipped, not failed. Override pytest args with `PYTEST_ARGS` (default
`-q -n auto --dist=worksteal`; use `PYTEST_ARGS="-q -n 0"` for serial logs).

The `vcs` and `xsim` layers wipe their `tests/sim_build/simlink/<layer>`
directory before each run (a simulator will not reuse artifacts analyzed by a
different tool version) and run verbose and serial so the compile/elaboration
log is visible. The VCS version year is auto-derived from `VCS_HOME`, so
sourcing your `simW`/`simX` alias is sufficient — no `VCS_VERSION` needed.

The raw per-directory `pytest` commands below still work and document exactly
what each layer runs.

Run the complete directory suite:

```bash
./.venv/bin/python -m pytest -q -n auto --dist=worksteal tests/simlink
```

Without Vivado tools, xsim cases skip explicitly. Run focused open-source
GHDL tests with:

```bash
./.venv/bin/python -m pytest -q -n 0 \
  tests/simlink/ghdl
```

Run the native adapter contract independently:

```bash
./.venv/bin/python -m pytest -q -n 0 \
  tests/simlink/common \
  tests/simlink/native
```

Run the production Rogue/PyRogue Memory contract by pointing to an interpreter
that can import both `rogue` and `pyrogue`:

```bash
SIMLINK_ROGUE_PYTHON=/path/to/rogue/bin/python \
  ./.venv/bin/python -m pytest -q -n 0 \
  tests/simlink/rogue/test_RogueTcpMemoryRogue.py
```

The test skips when Rogue is unavailable. The required Linux CI contract uses
`rogue/conda.yml` and pins Rogue `v6.15.0` for reproducibility.

To reproduce that package environment on Linux before running the command
above:

```bash
conda env create -f tests/simlink/rogue/conda.yml
conda activate surf-simlink-rogue
python -m pip install -r pip_requirements.txt
```

Run xsim integration in a Vivado-enabled shell:

```bash
./.venv/bin/python -m pytest -q -n 0 \
  tests/simlink/xsim
```

Run VCS active traffic in a licensed Linux shell. `VCS_VERSION` must be the
integer used by the adapter's compatibility checks; the optional license
override is applied only to test subprocesses:

```bash
source /sdf/group/faders/tools/synopsys/vcs/X-2025.06/settings.sh
export VCS_VERSION=2025
export SIMLINK_RUN_VCS=1
export SIMLINK_VCS_LICENSE_FILE=27000@cadlic-ext.stanford.edu  # optional
./.venv/bin/python -m pytest -q -n 0 \
  tests/simlink/vcs
```
