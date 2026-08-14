# Rogue and PyRogue Clients for SimLink

SimLink speaks the established Rogue TCP simulation protocols over loopback
ZeroMQ sockets. Use Rogue's production client classes in applications; the
`tests/simlink/common` pyzmq peer is a regression oracle, not a replacement for
Rogue.

See [getting started](getting-started.md) for environment creation and the
[HDL integration guide](hdl-integration.md) for wrapper direction and port
allocation.

## Client map

| HDL wrapper | Production software endpoint | Constructor |
| --- | --- | --- |
| `RogueTcpMemoryWrap` | `rogue.interfaces.memory.TcpClient` | `TcpClient(host, base_port, wait_ready)` |
| `RogueTcpStreamWrap` | `rogue.interfaces.stream.TcpClient` | `TcpClient(host, base_port)` |
| `RogueSideBandWrap` | `pyrogue.interfaces.simulation.SideBandSim` | `SideBandSim(host, base_port)` |

Pass the HDL base port, not `base_port+1`. Each client internally connects both
members of the pair. Use `127.0.0.1`; the simulator binds only to loopback.

## Install and verify Rogue

The checked SURF contract uses the environment pinned in
`tests/simlink/rogue/conda.yml`:

```bash
conda env create -f tests/simlink/rogue/conda.yml
conda activate surf-simlink-rogue
python -c 'import rogue, pyrogue; print(rogue.Version.current())'
```

That file currently pins `rogue=v6.15.0`. A site's standard Rogue environment
is also suitable when it exposes the same interfaces. Do not use the pyzmq-only
SURF regression environment as evidence that Rogue itself is installed.

## Memory client

Memory is the strongest production-client path: SURF has a checked real-Rogue
GHDL contract for readiness, Write, Verify, Read, Post, and a subsequent Read.

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


class Root(pr.Root):
    def __init__(self):
        super().__init__(name="SimLinkRoot", timeout=2.0, pollEn=False)
        self.mem = rogue.interfaces.memory.TcpClient(
            "127.0.0.1", 9010, True)
        self.addInterface(self.mem)
        self.add(Device(name="Device", memBase=self.mem))


root = Root()
with root:
    if not root.mem.waitReady(2.0, 0.05):
        raise TimeoutError("SimLink Memory did not become ready")

    root.Device.Scratch.set(0x12345678, write=False)
    root.Device.writeAndVerifyBlocks(force=True)
    print(hex(root.Device.Scratch.get()))
```

The third constructor argument enables the production readiness behavior used
by the checked contract. Calling `waitReady(timeout, period)` sends a special
probe through the complete request/response socket path. SimLink answers it
without creating an AXI-Lite cycle.

Enter the PyRogue `Root` context before transactions and leave it on every
shutdown path. PyRogue then starts and stops the interfaces it owns. The full
checked example is
[`rogue_memory_client.py`](../../tests/simlink/rogue/rogue_memory_client.py).

## Stream client

`rogue.interfaces.stream.TcpClient` is both a Rogue stream slave and master:

```text
local Rogue source -> TcpClient -> HDL mAxisMaster
HDL sAxisMaster -> TcpClient -> local Rogue sink
```

Connect it to the application's normal Rogue stream graph:

```python
import threading

import rogue.interfaces.stream as ris


class Capture(ris.Slave):
    def __init__(self):
        super().__init__()
        self.frames = []
        self.received = threading.Event()

    def _acceptFrame(self, frame):
        self.frames.append(bytes(frame.getBa()))
        self.received.set()


source = ris.Master()
sink = Capture()
tcp = ris.TcpClient("127.0.0.1", 9000)

source >> tcp
tcp >> sink

try:
    payload = b"SimLink stream frame"
    frame = source._reqFrame(len(payload), True)
    frame.write(payload)
    frame.setFirstUser(0x00)
    frame.setLastUser(0x00)
    source._sendFrame(frame)

    # If the DUT is an echo path, wait for the returned frame.
    if not sink.received.wait(2.0):
        raise TimeoutError("No HDL-to-Rogue frame received")
    assert sink.frames[0] == payload
finally:
    tcp.close()
```

This example assumes the connected DUT returns the transmitted payload; SimLink
does not echo frames itself. In a real application replace `ris.Master` and
`Capture` with the protocol source, sink, file writer, SRP engine, or other
Rogue modules used by the design.

The underscore-prefixed frame allocation/send methods are the established
Python subclass interface used by Rogue stream modules. Allocate through the
connected master, finish payload and metadata updates before `_sendFrame()`,
and do not modify a frame after sending it.

With `SSI_EN_G=true`, `setFirstUser()`, `setLastUser()`, and `setError()` map to
the SSI metadata transported by the wrapper. With `SSI_EN_G=false`, those SSI
interpretations are disabled. The current SimLink wrapper selects multi-channel
routes by the client's port pair, not by `frame.setChannel()`: create one
`TcpClient` for each derived base port. HDL-to-Rogue frames currently report
Rogue channel zero on each client.

Stream has no production equivalent of Memory `waitReady()`. Constructing the
client issues asynchronous ZeroMQ connects but does not prove that the
simulator has bound or that an application sink is ready. Coordinate startup
with the simulator's listening diagnostic and an application-level handshake
when the first frame cannot be retried. In the SimLink test harness this is
handled by driving the first frame HDL-to-client: the model's outbound PUSH
sets `ZMQ_IMMEDIATE` and retries on `EAGAIN`, so that first frame blocks until
the client's PULL connects rather than being dropped, warming the pipe before
the client sends.

The constructor and graph operations above are verified Rogue APIs. A checked
real-Rogue Stream contract now exists
([`test_RogueStreamRogue.py`](../../tests/simlink/rogue/test_RogueStreamRogue.py)),
exchanging a frame in each direction against `RogueTcpStreamWrap` under GHDL
with the real `stream.TcpClient`. Extending the required `simlink_rogue` CI job
to run it (and the SideBand contract) alongside the Memory contract is a tracked
follow-up; until then it runs locally with `SIMLINK_ROGUE_PYTHON` set.

## SideBand client

`SideBandSim` sends optional opcode and remote-data fields and invokes a
callback for events/state received from HDL:

```python
import threading

import pyrogue.interfaces.simulation as pis


received = []
event = threading.Event()


def on_sideband(op_code, remote_data):
    received.append((op_code, remote_data))
    event.set()


with pis.SideBandSim("127.0.0.1", 9032) as sideband:
    sideband.setRecvCb(on_sideband)

    sideband.send(opCode=0x12)
    sideband.send(remData=0x34)
    sideband.send(opCode=0x56, remData=0x78)

    if not event.wait(2.0):
        raise TimeoutError("No HDL-to-Rogue SideBand update received")
```

Each argument to `send()` is optional. An opcode becomes a one-clock pulse on
`rxOpCodeEn`; remote data updates the retained `rxRemData` state. In the other
direction, a one-clock HDL `txOpCodeEn` pulse produces a callback with an
opcode, while changes to `txRemData` produce a callback with remote data. An
unchanged field is passed to the callback as `None`.

The receive callback runs on the SideBand worker thread. Keep it short and
thread-safe; signal another thread for substantial processing. Prefer the
context manager so `_stop()` joins the receive worker and closes both sockets.

SideBand has no production readiness operation. Do not call `send()` until the
simulation has released reset, printed its listening diagnostic, and had an
appropriate connection settle or application handshake.

As with Stream, the class and methods above are verified Rogue APIs. A checked
real-Rogue SideBand contract now exists
([`test_RogueSideBandRogue.py`](../../tests/simlink/rogue/test_RogueSideBandRogue.py)),
exchanging opcode/remData in each direction against `RogueSideBandWrap` under
GHDL with the real `SideBandSim` (note the `None`-for-unchanged-field callback
convention above: the receive callback must guard `int(...)` on each field).
Wiring it into the required `simlink_rogue` CI job is the same tracked follow-up
noted for Stream.

## PGP2b convenience endpoint

Rogue provides `pyrogue.interfaces.simulation.Pgp2bSim` for the established
PGP2b simulation layout:

```python
import pyrogue.interfaces.simulation as pis

with pis.Pgp2bSim(vcCount=4, host="127.0.0.1", port=9000) as pgp:
    vc0 = pgp.vc[0]
    pgp.sb.setRecvCb(lambda op_code, rem_data: print(op_code, rem_data))
    pgp.sb.send(opCode=0x12)
```

It creates Stream clients at 9000, 9002, 9004, and 9006 and SideBand at 9008,
matching `RoguePgp2bSim`. `Pgp2bSim` always uses `base+8` for SideBand, so do
not use a `vcCount` or extra allocation that overlaps that pair. PGP3, PGP4,
HTSP, and custom layouts should create their Stream clients and `SideBandSim`
explicitly using the offsets in the corresponding HDL wrapper.

## Startup and shutdown

Recommended Memory order:

```text
create Root/TcpClient -> start simulation -> release reset
 -> waitReady -> transact -> leave Root context -> stop simulation
```

Recommended Stream/SideBand order when the peer has no retry protocol:

```text
start simulation -> release reset -> observe Listening on ports N & N+1
 -> create/connect client -> application settle/handshake -> send
 -> close TcpClient or SideBand context -> stop simulation
```

Clients may be constructed earlier, but the first application send must account
for asynchronous connection establishment. SimLink's default 30-second
transport timeout bounds an HDL-to-software send when no peer is draining; it
is not a readiness delay that applications should routinely consume.

## Socket directions for diagnosis

These are the sockets owned by the simulator. Rogue owns the complementary
connect-side sockets:

| Link | Base `N` | `N+1` |
| --- | --- | --- |
| Stream | SimLink PULL; Rogue sends to HDL | SimLink PUSH; Rogue receives from HDL |
| Memory | SimLink PULL; Rogue sends requests | SimLink PUSH; Rogue receives completions |
| SideBand | SimLink PUSH; Rogue receives HDL events/state | SimLink PULL; Rogue sends events/state |

If one direction is idle, check the correct member of the pair, the wrapper
direction table in the [HDL guide](hdl-integration.md#direction-convention),
and whether the local Rogue graph has both its source and sink connected.
