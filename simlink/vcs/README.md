# VCS SimLink Backend

This backend implements the common SimLink leaves with Synopsys VCS VHPI. See
the [architecture reference](../docs/architecture.md) and
[shared C internals](../shared/README.md). For common dependencies, backend
selection, and the first transaction, start with the
[getting-started guide](../docs/getting-started.md).

## Call chain and value representation

The VHDL leaves carry a VHPI `FOREIGN` attribute naming each model's init
function. At elaboration, each `Rogue*Init` supplies a static direction/width
table to `VhpiGeneric`, which allocates port values and registers a clock
value-change callback. The generic callback reads VHPI values, calls the model
update, and writes outputs. The model update detects the rising edge and
invokes one shared FSM step.

VHPI exposes scalar and vector enumeration values. `VhpiGeneric` converts
logic zero/one to integers and vectors before the shared step, then performs
the inverse conversion for outputs. Ports up to 32 bits retain the historical
integer representation. Wider Stream ports use little-endian arrays of 32-bit
words, with the elaborated vector width inferred from `RogueTcpStream`.

## Build and load

A VCS environment must define `VCS_HOME` and `VCS_VERSION`; the ruckus VCS
flow defines `SIMLINK_PWD`. The Makefile compiles the three adapters and
`VhpiGeneric.c` with the VCS headers into one `libRogueSimLinkVhpi.so`:

```bash
make -C simlink/vcs \
  SIMLINK_PWD="$PWD/simlink/vcs" \
  VCS_HOME="$VCS_HOME" VCS_VERSION="$VCS_VERSION"
```

Use the normal ruckus VCS simulation target for a project build. SURF also
provides an opt-in cocotb regression that builds this library, compiles the
same active eight-instance VHDL topology used by GHDL, wraps it with a thin
SystemVerilog VPI-visible bridge, and runs the common tagged-traffic scenario
through VCS. The bridge is required because cocotb supports VCS through VPI,
not through a VHDL VHPI top; the production Rogue leaves inside the topology
continue to use their independent VHPI callbacks.

```bash
source /sdf/group/faders/tools/synopsys/vcs/X-2025.06/settings.sh
export VCS_VERSION=2025
export SIMLINK_RUN_VCS=1
export SIMLINK_VCS_LICENSE_FILE=27000@cadlic-ext.stanford.edu  # optional
./.venv/bin/python -m pytest -q -n 0 \
  tests/simlink/vcs
```

`SIMLINK_RUN_VCS=1` is an intentional license-checkout opt-in. The test skips
unless it is running on Linux with `VCS_HOME`, `VCS_VERSION`, `vcs`, `vhdlan`,
`vlogan`, the C build tools, and that opt-in. VHDL and the SystemVerilog bridge
are pre-analyzed into the same `work` library before elaboration. Every build,
elaboration, simulation, peer, and cocotb wait is bounded.
`SIMLINK_VCS_LICENSE_FILE`, when set, overrides
`SNPSLMD_LICENSE_FILE` only for the test subprocesses; this is useful on hosts
whose default server list begins with an unreachable license server.

## Lifecycle and limitations

The legacy `axi/simlink/src` implementation had no simulator-restart callback
or preserved-state mechanism. Every elaboration allocated fresh zeroed model
state, and the functions then named `Rogue*Restart` merely created and bound
the ZeroMQ sockets after the port was first sampled. The familiar workflow in
which Rogue survived a VCS reload worked because Rogue's client sockets stayed
alive and reconnected when the newly loaded model rebound the same ports.
Queued client work could consequently arrive as a burst after reload.

The aligned implementation retains that external-software contract. Its
internal transport-start functions are named `Rogue*StartTransport` to avoid
confusing socket startup with a simulator restart. It does not attempt to copy
old simulator-side FSM state into newly loaded modules.

- Model, port metadata, port-value, vector-buffer, and name allocations are
  checked and report a fatal VHPI error on failure. Callback records are
  embedded in retained metadata rather than allocated separately.
- No `vhpiCbEndOfSimulation` callback is registered in the cocotb/VCS flow.
  Registering it can race VPI teardown and cause a simulator shutdown fault.
  Common `atexit` cleanup handles worker/socket side effects. The exported
  `VhpiGenericCleanup` routine still removes value/error callbacks, releases
  callback and port handles, frees vector values and names, and destroys each
  common instance when a safe non-cocotb caller invokes it.
- The common process-wide registry rejects invalid, changed, and overlapping
  complete port pairs before socket bind.
- All sockets are worker-owned; VHPI callbacks do not call ZeroMQ.
- Parameterized Stream beats support 1 through 128 data bytes.
- Checked-in active-traffic coverage uses VCS X-2025.06.
- An opt-in licensed regression elaborates and invokes VCS twice against one
  persistent peer, with its second request queued between `simv` runs. The
  exact in-place VCS GUI/UCLI module re-exec command still needs separate
  characterization, especially with an interrupted transaction.

The generic lifecycle and declarative adapter ABIs also have a simulator-free
native regression under `tests/simlink/native/`. It verifies that the end
callback is absent and calls `VhpiGenericCleanup` directly. See the
[test matrix](../../tests/simlink/README.md) for exact VCS coverage.
