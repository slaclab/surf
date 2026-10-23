# Vivado xsim SimLink Backend

This backend implements the common SimLink leaves with SystemVerilog DPI-C for
Vivado xsim. See the [architecture reference](../docs/architecture.md) and
[shared C internals](../shared/README.md). For common dependencies, backend
selection, and the first transaction, start with the
[getting-started guide](../docs/getting-started.md).

## Call chain and ownership

```text
VHDL entity Rogue*
 -> instantiates SystemVerilog Rogue*Dpi leaf
 -> SV always @(posedge clock)
 -> DPI-C rogue*Update(chandle, ports...)
 -> shared Rogue*Step
```

Each SV leaf lazily creates and retains one `chandle`. Its `final` block calls
the matching destroy function. `RogueDpiInstance.c` is a compatibility bridge
from that stable DPI ABI to the common `RogueSimLinkInstance` API, which
validates model ownership, rejects complete-pair overlap across model types,
and registers `atexit` cleanup.
DPI formal arguments are two-state `bit` values; the SV leaf presents
four-state `logic` ports to mixed-language elaboration and performs the
automatic narrowing at the call. `RogueTcpStreamDpi` parameterizes its packed
data, user, and keep vectors from 1 through 128 data bytes. DPI exposes those
vectors as little-endian `svBitVecVal` arrays consumed by the shared Stream
codec.

## Build, ABI check, and elaboration

The Makefile uses `xsc` to build one combined `libRogueSimLinkDpi.so` from the common
instance manager and all three adapters. `xelab -dpiheader` generates C
prototypes from the SV imports; `abi-check` recompiles the adapters with that
header preincluded to catch signature drift.

The backend requires the Vivado simulator tools `xsc`, `xvlog`, `xvhdl`,
`xelab`, and `xsim` on `PATH`, plus the common `libzmq` development package.

```bash
make -C simlink/xsim all abi-check
```

Elaboration binds the combined library once:

```text
xelab ... -sv_lib libRogueSimLinkDpi
```

## Running an xsim co-simulation

An external target must provide a simulation top containing one or more
`RogueTcpStream`, `RogueTcpMemory`, `RogueSideBand`, or corresponding SURF
wrapper instances. It must drive clock and reset, assign a distinct two-port
pair to every live instance, and start a peer implementing the matching wire
protocol. An instance using `portNum=N` owns both `N` and `N+1`; the next
non-overlapping base port is therefore at least `N+2`.

From a target using the standard ruckus simulation flow, run `make gui` or the
target's xsim make target. `simlink/ruckus.tcl` selects `xsim/`, the build
creates the combined `libRogueSimLinkDpi.so`, and elaboration binds it once with
`-sv_lib libRogueSimLinkDpi`. After reset is released, each instance prints its
`Listening on ports N & N+1` message.

Connect the peer and keep it draining before HDL produces outbound messages.
Receive polling uses the worker FIFO and outbound traffic uses a bounded
worker rendezvous for all three models.

## Checked-in xsim examples

The repository includes two focused multi-instance regressions:

- `simlink/test/xsim/RogueXsimMultiInstanceTb.vhd` instantiates four Stream,
  two Memory, and two SideBand models concurrently.
- `simlink/test/xsim/RogueXsimDuplicatePortTb.vhd` verifies process-wide
  rejection when two leaves claim the same endpoint pair.
- `tests/simlink/xsim/test_RogueXsimMulti.py` builds the DPI library, checks the
  generated DPI-C prototypes, compiles the mixed-language design, runs xsim,
  and verifies duplicate-port rejection.
- `simlink/test/xsim/RogueXsimTrafficTb.vhd` drives the same eight-instance
  topology with isolated Stream, Memory, and SideBand traffic.
- `tests/simlink/xsim/test_RogueXsimTraffic.py` starts one deterministic
  `rogue_tcp_peer.py` process per instance and verifies the xsim and peer-side
  results. It consumes the same backend-neutral peer layout and tagged-result
  validator as the GHDL topology. After traffic completes, the VHDL top pulses
  reset and runs on before reporting success, matching the GHDL reset-survival
  scenario.

The traffic test uses test-only ready files to tell the parent process that
each peer configured its sockets and called ZeroMQ `connect()`. It retains a
short fixed settle delay because connection establishment is asynchronous.
This coordination adds no production socket, message, or handshake to the
Rogue TCP wire protocol.

Run checked-in xsim regressions in a Vivado-enabled shell:

```bash
./.venv/bin/python -m pytest -q -n 0 \
  tests/simlink/xsim
```

They skip with an explicit reason when `xsc`, `xvlog`, `xvhdl`, `xelab`, or
`xsim` is unavailable.

## Troubleshooting

### `libzmq package was not found`

If the Tcl console prints:

```text
libzmq package was not found
Please make sure that you have libzmq installed
or have sourced the necessary rogue setup scripts
```

install its development package or source the Rogue setup scripts that put it
on `PKG_CONFIG_PATH`, then rerun `make gui`. Confirm discovery with:

```bash
pkg-config --modversion libzmq
```

### Listening message but idle waveform

If the console printed `Listening on ports N & N+1` but the waveform never
shows activity, confirm that the peer process is running, targets loopback
`127.0.0.1` and the same port pair, and uses the socket directions documented
in the
[protocol reference](../docs/protocol-reference.md#port-and-socket-directions).
Remember that ZeroMQ `connect()` completes asynchronously; a test-only ready
file proves
the call was issued, not that the connection handshake has finished.

## Limitations

- All sockets are worker-owned; DPI calls do not call ZeroMQ.
- `final` is the preferred instance cleanup hook, but process-exit cleanup is
  still retained as a fallback.
- Port ownership and model lifecycle use the same common API as GHDL and VCS.
- Sockets use zero linger and outbound rendezvous have a finite timeout.
- xsim `restart` (time-zero rewind of a loaded snapshot) and `relaunch_sim`
  (recompile/relaunch) are different lifecycle operations. The latter should
  preserve an external peer by socket reconnection; the former still needs an
  executable DPI-lifecycle regression before it is a supported SimLink claim.
  In particular, the test must establish whether restart restores the SV
  `chandle` to null while retaining its C allocation, which would leave the old
  instance live and make the replacement fail the port-overlap check.
