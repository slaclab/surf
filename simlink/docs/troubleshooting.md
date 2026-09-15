# SimLink Troubleshooting

Start with the first failing boundary: source selection, native-library build,
foreign-library load, socket bind, connection readiness, or protocol traffic.
Avoid changing the wire format or public wrapper until the corresponding
boundary has been isolated.

The [getting-started guide](getting-started.md) provides the baseline commands.
Backend-specific build details remain in the [GHDL](../ghdl/README.md),
[VCS](../vcs/README.md), and [xsim](../xsim/README.md) guides.

## Fast triage

From the same shell that starts the simulator, run:

```bash
echo "$RUCKUS_SIM_BACKEND"
pkg-config --modversion libzmq
gcc --version
make --version
```

Then verify the selected simulator tools:

```bash
command -v ghdl
command -v vcs vhdlan vlogan
command -v xsc xvlog xvhdl xelab xsim
```

Only one group needs to be present for the chosen backend. Confirm that the
expected shared library exists after its build:

```text
GHDL  simlink/ghdl/build/libRogueSimLinkVhpiDirect.so
VCS   simlink/vcs/libRogueSimLinkVhpi.so
xsim  simlink/xsim/libRogueSimLinkDpi.so
```

After reset release, expect one line per live leaf/channel:

```text
RogueTcpStream: Listening on ports N & N+1
RogueTcpMemory: Listening on ports N & N+1
RogueSideBand: Listening on ports N & N+1
```

No listening line means the problem precedes Rogue traffic. A listening line
followed by idle traffic usually means port, direction, connection, reset, or
application-graph setup.

## `libzmq` is missing

Typical ruckus diagnostic:

```text
libzmq package was not found
Please make sure that you have libzmq installed
or have sourced the necessary rogue setup scripts
```

The development package must be visible to `pkg-config`, not merely a runtime
library somewhere on the host:

```bash
pkg-config --exists 'libzmq >= 4.1.0'
pkg-config --cflags --libs libzmq
pkg-config --variable=libdir libzmq
```

Source the site's Rogue/conda environment or add the package's metadata
directory to `PKG_CONFIG_PATH`. Do not hard-code a library path into one
backend; all three builds use the same discovery contract.

## Wrong backend or duplicate entities

Symptoms include duplicate `RogueTcpStream`, `RogueTcpMemory`, or
`RogueSideBand` definitions, a backend leaf compiled by the wrong simulator,
or a missing DPI/VHPI library during elaboration.

Fix the target at the manifest boundary:

```bash
export RUCKUS_SIM_BACKEND=ghdl  # or vcs or xsim
```

Import top-level SURF and remove manually listed `simlink/ghdl`,
`simlink/vcs`, `simlink/xsim`, and old `axi/simlink` sources. The current
manifest loads one backend and removes stale sibling sources from persistent
Vivado projects.

## GHDL cannot load VHPIDIRECT

If GHDL executes a VHDL stub body such as:

```text
rogueTcpMemoryCreate: VHPIDIRECT stub body should never execute
```

the foreign symbol did not resolve. Rebuild the library and confirm its exact
name:

```bash
make -C simlink/ghdl
ls -l simlink/ghdl/build/libRogueSimLinkVhpiDirect.so
```

The checked pytest helpers copy the library into the simulation build directory
and prepend the build directory to `LD_LIBRARY_PATH`. A downstream GHDL flow
must provide an equivalent loader path at elaboration/run time. On macOS the
Makefile records a basename-only install name so the runtime search path can
locate the staged library.

Use the focused wrapper test to distinguish environment loading from project
source-list problems:

```bash
python -m pytest -q -n 0 \
  tests/simlink/ghdl/test_RogueTcpMemoryWrap.py
```

## VCS build, elaboration, or license failure

Confirm the sourced VCS environment supplies both variables and tools:

```bash
test -n "$VCS_HOME"
test -n "$VCS_VERSION"
command -v vcs vhdlan vlogan
test -f "$VCS_HOME/include/vhpi_user.h"
```

`VCS_VERSION` must be the integer expected by the adapter compatibility checks,
not an arbitrary marketing-version string. The checked X-2025.06 flow uses
`VCS_VERSION=2025`.

Messages such as `Port ... direction mismatch` or `Port ... size mismatch`
mean the VHDL leaf and declarative VHPI table do not agree. Remove stale
compiled libraries and ensure all VCS leaf and adapter sources come from the
same SURF revision.

The regression intentionally requires `SIMLINK_RUN_VCS=1` before it checks out
a license. `SIMLINK_VCS_LICENSE_FILE` can override `SNPSLMD_LICENSE_FILE` for
test subprocesses when the site's default server ordering is unusable. These
are test controls, not runtime SimLink protocol settings.

Do not register `vhpiCbEndOfSimulation` to address a cocotb shutdown issue. The
current absence of that callback is deliberate; see the
[VCS lifecycle notes](../vcs/README.md#lifecycle-and-limitations).

## xsim cannot build or load DPI

First run the standalone build and generated-prototype check:

```bash
make -C simlink/xsim all abi-check
```

Common failure classes are:

- missing Vivado simulator tools on `PATH`;
- `libzmq` missing from `pkg-config`;
- `cannot find crti.o`, `-lzmq`, or `-lm` from an older Vivado-bundled GCC;
- a `GLIBCXX_* not found` error because the Vivado loader injected an older
  `libstdc++.so.6`; or
- elaboration without `-sv_lib libRogueSimLinkDpi`.

The checked Makefile adds the host multiarch directory for the older GCC link
case. The ruckus xsim hooks locate a `libstdc++` compatible with the discovered
ZeroMQ and preload it when needed. Use the normal project xsim target so those
hooks run; a handwritten `xelab` command must reproduce both library binding
and runtime environment.

## Invalid, changed, or overlapping port pair

Representative diagnostics are:

```text
RogueTcpMemory: invalid SimLink base port 0
RogueTcpStream: SimLink base port changed from 9000 to 9002
RogueSideBand: SimLink port pair 9001/9002 overlaps live RogueTcpStream port pair 9000/9001
```

Fix the allocation rather than suppressing the check:

- base ports must be 1024 through 49151 at the public wrappers;
- every base reserves `N` and `N+1`;
- Stream `CHAN_COUNT_G` and `CHAN_MASK_G` derive additional pairs; and
- PGP/HTSP wrappers reserve SideBand at documented offsets.

If the registry accepts the plan but ZeroMQ reports `PULL bind failed` or
`PUSH bind failed`, another process or host policy owns/blocks the port. On a
Unix host, inspect both members:

```bash
lsof -nP -iTCP:9000
lsof -nP -iTCP:9001
```

Terminate only the process you own, or choose a different complete pair. A
sandbox may reject all loopback binds with `Operation not permitted`; run the
simulation in an environment allowed to create local TCP listeners.

## Listening appears, but Memory is not ready

Use the same base port in VHDL and software:

```python
client = rogue.interfaces.memory.TcpClient("127.0.0.1", 9010, True)
if not client.waitReady(2.0, 0.05):
    raise TimeoutError("Memory client is not ready")
```

Check that:

- the simulator clock continues after reset release;
- reset is not being reasserted continuously;
- the Rogue process uses loopback and the base port rather than `N+1`;
- no firewall/sandbox blocks local TCP; and
- both client sockets were created before `waitReady()`.

The readiness probe does not touch AXI-Lite. If it succeeds but a register
operation hangs or errors, inspect the AXI subordinate, address map, and
`BRESP/RRESP` behavior rather than the socket connection.

## Stream is idle or reaches the wrong channel

Remember the wrapper direction names:

```text
HDL sAxisMaster -> Rogue
Rogue -> HDL mAxisMaster
```

For a multi-channel wrapper, one Rogue `TcpClient` is required per derived base
port. HDL-to-Rogue `sAxisMaster.tDest` chooses the channel; Rogue-to-HDL frames
receive the route `TDEST` associated with the socket that delivered them.
`frame.setChannel()` does not replace selecting the correct client/port.

Also check:

- `TLAST` eventually terminates every HDL-to-Rogue frame;
- `TKEEP` marks the intended payload bytes;
- `TVALID` is held with stable data while `TREADY=0`;
- the local Rogue source is connected into the `TcpClient` and a sink is
  connected after it; and
- the application accounts for asynchronous connection establishment because
  Stream has no `waitReady()` transaction.

An SSI metadata discrepancy usually indicates `SSI_EN_G`, first/last user, or
error mapping, not byte-order corruption. Compare the exact `AXIS_CONFIG_G`
with the DUT interface.

## SideBand event or state is missing

Use `pyrogue.interfaces.simulation.SideBandSim` with the wrapper base port.
SideBand socket order is opposite the Stream/Memory base-port order, but the
class handles that detail internally.

Check that:

- HDL `txOpCodeEn` is a one-clock pulse alongside a stable `txOpCode`;
- software calls `send(opCode=...)` for an event and `send(remData=...)` for a
  retained-state update;
- the receive callback accepts `(op_code, remote_data)` and handles `None` for
  an unchanged field; and
- callback work is short/thread-safe because it runs on the receive worker.

SideBand has no readiness probe. Wait for the listening diagnostic and an
appropriate startup barrier before the first non-retryable event.

## Transport timeout

Representative diagnostic:

```text
RogueTcpStream: transport timeout on port 9001 during outbound send
```

The simulator attempted to send toward software, but no connected peer drained
that direction within the configured interval. Before increasing the timeout,
confirm the Rogue process is alive, connected to the correct base, and has a
sink/callback consuming HDL-originated traffic.

The process-wide override must be a positive decimal number of milliseconds:

```bash
export SURF_SIMLINK_TRANSPORT_TIMEOUT_MS=60000
```

Zero, signs, suffixes, whitespace, non-decimal text, and overflow are rejected
at model startup. A longer timeout accommodates known slow startup; it does not
repair wrong directions or a peer that never drains.

## Malformed or oversized input

Diagnostics such as `Bad message sizes`, `inbound message exceeds ... parts`,
`inbound message exceeds ... bytes`, or a Memory transaction shape error mean
the sender violated the established Rogue wire contract. Production Rogue
clients should not generate those messages. They usually identify:

- a hand-written pyzmq peer with wrong multipart boundaries;
- Stream flags/channel/error fields with incorrect sizes;
- a Memory request whose type, size, or data part is inconsistent; or
- a process connected to a pair assigned to a different model type.

Compare against the canonical wire tables in the
[protocol reference](protocol-reference.md). Do not weaken validation to accept
an incompatible peer.

## Pacing assertion

The Stream pacer intentionally fails configuration errors at elaboration or
simulation startup. Check these relationships:

```text
PAYLOAD_RATE >= 0
AXIS_CLK_FREQ > 0 when PAYLOAD_RATE > 0
PAYLOAD_RATE <= 8 * TDATA_BYTES * AXIS_CLK_FREQ
```

Very small nonzero rates below the fixed-point resolution are also rejected.
Use zero for bypass. Runtime throughput is based on kept bytes transferred on
`TVALID && TREADY`, so sparse `TKEEP` or downstream backpressure lowers
payload progress by design.

## Escalation information

When reporting a SimLink failure, include:

- SURF revision and selected backend;
- simulator and host operating-system versions;
- `pkg-config --modversion libzmq`;
- the complete port allocation, including derived Stream channels;
- wrapper generics and reset/clock behavior;
- the first SimLink diagnostic, not only the final simulator exit code; and
- whether the focused backend test passes in the same shell.

For protocol issues, also identify the Rogue version and whether the peer is a
production Rogue client or the deterministic test oracle.
