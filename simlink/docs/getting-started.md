# Getting Started with SimLink

This guide takes the shortest checked path from a clean SURF checkout to a
real Rogue/PyRogue Memory transaction through GHDL. The last section shows the
VCS and Vivado xsim setup differences. For wrapper-level integration, use the
[HDL guide](hdl-integration.md); for software, use the
[Rogue client guide](rogue-clients.md). Protocol and implementation details
remain in the [SimLink reference](../README.md).

## 1. Choose a backend

The public VHDL wrappers are the same for every backend. Choose the simulator
from the environment in which the rest of your design already runs.

| Backend | Use it when | Required simulator setup | Foreign interface |
| --- | --- | --- | --- |
| GHDL | You want the open-source baseline or CI-friendly regression path | `ghdl` on `PATH` | VHPIDIRECT |
| VCS | Your project uses licensed Synopsys VCS | Linux VCS environment with `VCS_HOME` and `VCS_VERSION` | VHPI |
| xsim | Your project uses a Vivado simulation target | Vivado environment with `xsc`, `xvlog`, `xvhdl`, `xelab`, and `xsim` | DPI-C |

VCS X-2025.06 has executed the checked-in active-traffic regression. xsim has
checked-in Vivado-enabled regressions, but this guide does not claim that every
Vivado or operating-system combination has been qualified.

Set the backend explicitly before invoking a downstream ruckus simulation when
your shell contains more than one simulator environment:

```bash
export RUCKUS_SIM_BACKEND=ghdl  # or vcs or xsim
```

If it is not set, `simlink/ruckus.tcl` selects GHDL when `GHDLFLAGS` exists,
then VCS when `VCS_VERSION` exists, and otherwise xsim. It loads exactly one
backend so the three implementations of each leaf entity do not collide.

## 2. Check the common prerequisites

All backends compile a native shared library and use ZeroMQ for loopback
transport. From the repository root, verify the common tools:

```bash
gcc --version
make --version
pkg-config --version
pkg-config --modversion libzmq
```

SimLink requires `libzmq >= 4.1.0`, including its development metadata for
`pkg-config`. Install the compiler, `make`, `pkg-config`, and ZeroMQ development
package with the host package manager if any command is missing. On macOS,
`gcc` may be the Clang driver supplied by the Xcode command-line tools; that is
sufficient for the GHDL library build.

The repository conda environment supplies GHDL, ZeroMQ, `pkg-config`, and the
Python regression packages. For a first-time setup:

```bash
conda env create -f conda.yml
conda activate surf-test
python -m pip install -r pip_requirements.txt
python -m pip install -r ruckus/scripts/pip_requirements.txt
```

A system C compiler is still required. Reuse an existing equivalent SURF
environment instead of creating `surf-test` again when one is already
available.

## 3. Build and smoke-test GHDL

Confirm GHDL and build the combined VHPIDIRECT library:

```bash
ghdl --version
make -C simlink/ghdl
```

The build produces:

```text
simlink/ghdl/build/libRogueSimLinkVhpiDirect.so
```

Run the focused Memory-wrapper test before adding a downstream design:

```bash
python -m pytest -q -n 0 \
  tests/simlink/ghdl/test_RogueTcpMemoryWrap.py
```

The test helper stages the shared library where GHDL can load it. Success is a
zero exit status with no failures; the file also contains native negative
cases, so the exact pass/skip count depends on the host. Once reset is
released, the simulator reports the reserved pair in this form:

```text
RogueTcpMemory: Listening on ports N & N+1
```

## 4. Run the real Rogue/PyRogue contract

The ordinary SURF test environment does not require Rogue. Create the pinned
Rogue environment separately so its package constraints do not alter the test
runner:

```bash
conda env create -f tests/simlink/rogue/conda.yml
conda activate surf-simlink-rogue
export SIMLINK_ROGUE_PYTHON="$CONDA_PREFIX/bin/python"
python -c 'import rogue, pyrogue; print(rogue.Version.current())'
conda deactivate
conda activate surf-test
```

Then run the checked production-client contract:

```bash
SIMLINK_ROGUE_PYTHON="$SIMLINK_ROGUE_PYTHON" \
  python -m pytest -q -n 0 \
  tests/simlink/rogue/test_RogueTcpMemoryRogue.py
```

This is more than a socket smoke test. A separate process creates the real
`rogue.interfaces.memory.TcpClient` and a PyRogue `Root`/`RemoteVariable`, then
executes `waitReady`, Write, Verify, Read, Post, and a final Read against an
AXI-Lite RAM behind `RogueTcpMemoryWrap`. The test passes only when both Rogue
and cocotb observe the expected values.

`SIMLINK_ROGUE_PYTHON` is a regression-runner variable, not a SimLink runtime
requirement. A normal application simply runs entirely inside its Rogue
environment.

## 5. Add the Memory wrapper to a design

Downstream VHDL should instantiate the stable record-based wrapper, not the
backend leaf. The following instance turns Rogue Memory requests into an
AXI-Lite master:

```vhdl
U_RogueMemory : entity surf.RogueTcpMemoryWrap
   generic map (
      PORT_NUM_G => 9000)
   port map (
      axilClk         => axilClk,         -- [in]
      axilRst         => axilRst,         -- [in]
      axilReadMaster  => axilReadMaster,  -- [out]
      axilReadSlave   => axilReadSlave,   -- [in]
      axilWriteMaster => axilWriteMaster, -- [out]
      axilWriteSlave  => axilWriteSlave); -- [in]
```

The instance owns both TCP ports 9000 and 9001. Use base ports from 1024
through 49151 and leave at least two ports between base values; no live Stream,
Memory, or SideBand instance may overlap another complete pair. SimLink rejects
invalid, changed, or overlapping pairs before binding.

Ensure the ordinary SURF import graph includes the top-level `simlink/ruckus.tcl`
and run the project's normal simulator target. That manifest loads the public
wrappers and the selected backend. Do not manually add all three backend source
directories.

## 6. Connect the production client

This reduced client follows the checked-in contract in
[`rogue_memory_client.py`](../../tests/simlink/rogue/rogue_memory_client.py):

```python
import pyrogue as pr
import rogue.interfaces.memory


class Device(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.add(pr.RemoteVariable(
            name="Scratch",
            offset=0x0000,
            bitSize=32,
            bitOffset=0,
            mode="RW",
            verify=True,
        ))


root = pr.Root(name="SimLinkExample", timeout=2.0, pollEn=False)
client = rogue.interfaces.memory.TcpClient("127.0.0.1", 9000, True)
root.addInterface(client)
root.add(Device(name="Device", memBase=client))

with root:
    assert client.waitReady(2.0, 0.05)
    root.Device.Scratch.set(0x12345678, write=False)
    root.Device.writeAndVerifyBlocks(force=True)
    assert root.Device.Scratch.get() == 0x12345678
```

The client takes the HDL base port and internally uses its adjacent pair. For
Memory, `waitReady()` probes the complete request/response path without issuing
an AXI-Lite transaction. Stream and SideBand do not currently provide an
equivalent production readiness operation.

The software process may call ZeroMQ `connect()` before the simulator binds.
A reliable startup sequence is:

```text
start client -> create TcpClient -> start simulation -> release HDL reset
 -> observe Listening message -> waitReady -> issue Memory traffic
```

Connection establishment is asynchronous. Do not treat process creation or a
test-only ready file as proof that the sockets are already connected.

## VCS setup delta

Source the site's VCS environment, verify `VCS_HOME` and `VCS_VERSION`, and use
the downstream project's normal VCS target with `RUCKUS_SIM_BACKEND=vcs`. Build
the library directly only when diagnosing the adapter:

```bash
make -C simlink/vcs \
  SIMLINK_PWD="$PWD/simlink/vcs" \
  VCS_HOME="$VCS_HOME" VCS_VERSION="$VCS_VERSION"
```

The result is `simlink/vcs/libRogueSimLinkVhpi.so`. See the
[VCS backend guide](../vcs/README.md) for the licensed opt-in regression and
the VCS/cocotb shutdown limitation.

## xsim setup delta

Source the Vivado environment and confirm its simulator executables:

```bash
command -v xsc xvlog xvhdl xelab xsim
make -C simlink/xsim all abi-check
```

The result is `simlink/xsim/libRogueSimLinkDpi.so`. A normal ruckus xsim
target binds the combined library once with `-sv_lib libRogueSimLinkDpi`; use
the project's `make gui` or equivalent instead of reconstructing the complete
compile/elaboration command. See the [xsim backend guide](../xsim/README.md)
for the checked mixed-language examples and loader troubleshooting.

## Runtime controls and first diagnostics

| Variable | Scope | Meaning |
| --- | --- | --- |
| `RUCKUS_SIM_BACKEND` | ruckus source selection | Explicitly selects `ghdl`, `vcs`, or `xsim` |
| `SURF_SIMLINK_TRANSPORT_TIMEOUT_MS` | All SimLink instances in the simulator process | Positive decimal timeout for stalled/missing-peer transport; default is 30000 ms |
| `VCS_HOME`, `VCS_VERSION` | VCS build and selection | Locate the VCS headers/tools and identify the compatibility version |
| `SIMLINK_ROGUE_PYTHON` | Tests only | Select a Python interpreter that imports Rogue and PyRogue |
| `SIMLINK_RUN_VCS` | Tests only | Explicitly permits the licensed VCS regression to run |

Start diagnosis with these checks:

- No listening message: confirm reset is released, the clock advances, and the
  selected backend library loaded.
- `libzmq package was not found`: fix `PKG_CONFIG_PATH` or install the ZeroMQ
  development package, then rerun `pkg-config --modversion libzmq`.
- Duplicate entity definitions: load only `simlink/ruckus.tcl`, set
  `RUCKUS_SIM_BACKEND`, and remove manually added sibling backend sources.
- Port rejection: reserve the full `N/N+1` pair for every instance and check
  that another simulator process is not using it.
- Listening but no Memory traffic: confirm loopback address, the base port,
  `waitReady()`, and that reset remains released while clocks continue.
- Fatal timeout after 30 seconds: ensure the peer is running and draining the
  direction in which the HDL is sending; increase the timeout only after
  fixing direction or startup errors.

The [protocol reference](protocol-reference.md#port-and-socket-directions)
defines the socket direction for Stream, Memory, and SideBand. Backend-specific
failures belong in the corresponding backend guide. The
[troubleshooting guide](troubleshooting.md) provides a symptom-oriented path
across all three backends.
