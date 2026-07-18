# Simlink

This directory holds three interchangeable Rogue co-simulation backends -- GHDL/VHPIDIRECT (`ghdl/`), Synopsys VCS/VHPI (`vcs/`), and Vivado xsim/DPI (`xsim/`) -- selected automatically by `ruckus.tcl` based on the active simulator. All three backends share the same `shared/` C cores and speak the same ZeroMQ wire protocol to a Rogue-side Python peer, so a testbench built against one backend behaves the same on any of the others.

## Prerequisites

- `libzmq >= 4.1.0` -- check with `pkg-config --modversion libzmq`.
- Vivado simulator tools (`xsc`, `xvlog`, `xvhdl`, `xelab`, and `xsim`) for
  the xsim backend.
- A compatible Rogue or ZeroMQ peer for the selected Stream, Memory, or
  SideBand wire protocol.

## Running the Vivado xsim Co-Simulation

An external target must provide a simulation top containing one or more
`RogueTcpStream`, `RogueTcpMemory`, `RogueSideBand`, or corresponding SURF
wrapper instances. It must drive clock/reset, assign a distinct two-port pair
to every live instance, and provide a peer that implements the matching wire
protocol. The first instance uses `portNum` and `portNum+1`; a subsequent
instance must therefore start at least two ports higher.

From a target using the standard ruckus simulation flow, run `make gui` or the
target's xsim make target. `axi/simlink/ruckus.tcl` selects `xsim/`, the build
creates the combined `RogueTcpDpi.so`, and elaboration binds it once with
`-sv_lib RogueTcpDpi`. After reset is released, each instance prints its
`Listening on ports N & N+1` message.

The transport preserves the long-standing VCS/GHDL operating contract:
connect the peer and keep it draining before HDL produces outbound messages.
Simulator-thread receive is nonblocking, but send retains the existing
synchronous ZeroMQ behavior across all three backends.

## Checked-In xsim Examples

The repository includes two focused multi-instance regressions:

- `tests/axi/simlink/RogueXsimMultiTb.vhd` instantiates four Stream, two
  Memory, and two SideBand models concurrently.
- `tests/axi/simlink/test_RogueXsimMulti.py` builds the DPI library, checks the
  generated DPI-C prototypes, compiles the mixed-language design, runs xsim,
  and verifies duplicate-port rejection.
- `tests/axi/simlink/RogueXsimTrafficTb.vhd` drives the same eight-instance
  topology with isolated Stream, Memory, and SideBand traffic.
- `tests/axi/simlink/test_RogueXsimTraffic.py` starts one deterministic
  `rogue_tcp_peer.py` process per instance and verifies the xsim and peer-side
  results.

The standalone DPI library and ABI check can be built with:

```bash
make -C axi/simlink/xsim all abi-check
```

Run it from the repository root in a Vivado-enabled shell:

```bash
./.venv/bin/python -m pytest -q -n 0 \
  tests/axi/simlink/test_RogueXsimMulti.py \
  tests/axi/simlink/test_RogueXsimTraffic.py
```

The test skips with an explicit reason when Vivado simulator tools are not on
`PATH`. The protocol codecs and deterministic ZeroMQ peer used by the broader
simlink regressions are in `tests/axi/simlink/rogue_tcp_peer.py`. The active
traffic regression uses test-only ready files to tell the parent process that
each peer has configured its sockets and issued its ZeroMQ connect calls. It
then retains a short fixed settle delay because the underlying ZeroMQ
connection handshake is asynchronous. This coordination does not add a socket,
message, or handshake to the production Rogue TCP wire protocol.

## Troubleshooting

**"libzmq package was not found"**
If the Tcl console prints:
```
libzmq package was not found
Please make sure that you have libzmq installed
or have sourced the necessary rogue setup scripts
```
install libzmq (or source the Rogue setup scripts that put it on `PKG_CONFIG_PATH`) and re-run `make gui`.

**Idle waveform, no data movement**
If the console printed `Listening on ports N & N+1` but the waveform never shows activity, the peer has not connected. Confirm the driver script is running, targeting the same host (loopback `127.0.0.1`) and port pair as the module under test, and that push/pull directions are not swapped.
