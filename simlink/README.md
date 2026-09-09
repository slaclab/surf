# SimLink

SimLink lets Rogue and PyRogue software communicate with an HDL simulation
through the same Stream, Memory, and SideBand interfaces used for hardware.
SURF provides interchangeable adapters for GHDL/VHPIDIRECT, Synopsys
VCS/VHPI, and Vivado xsim/DPI. The downstream `Rogue*Wrap` interfaces are
common; only the simulator leaf and foreign-function boundary change.

## Start here

If you are setting up SimLink for the first time, follow the
[getting-started guide](docs/getting-started.md). It covers backend selection,
the common native dependencies, a clean GHDL setup, a real Rogue/PyRogue
Memory round trip, and the equivalent VCS and xsim entry points.

| Task | Documentation |
| --- | --- |
| Choose a backend and run the first transaction | [Getting started](docs/getting-started.md) |
| Add Stream, Memory, or SideBand to VHDL | [HDL integration](docs/hdl-integration.md) |
| Connect production Rogue/PyRogue software | [Rogue clients](docs/rogue-clients.md) |
| Move an existing `axi/simlink` VCS target | [Legacy VCS migration](docs/migration-from-vcs.md) |
| Diagnose setup, bind, readiness, or traffic failures | [Troubleshooting](docs/troubleshooting.md) |
| Integrate with a specific simulator | [GHDL](ghdl/README.md), [VCS](vcs/README.md), or [xsim](xsim/README.md) |
| Understand lifecycle, ownership, or pacing | [Architecture reference](docs/architecture.md) |
| Check ports, framing, or compatibility invariants | [Protocol reference](docs/protocol-reference.md) |
| Maintain the common C transport/model layer | [Shared internals](shared/README.md) |
| Run or extend the regressions | [SimLink test guide](../tests/simlink/README.md) |

Use the public `Rogue*Wrap` entities in downstream VHDL. The backend leaves,
foreign-function adapters, deterministic pyzmq peer, and flat test harnesses
are integration or test implementation details.

## Public interfaces

| Link | Backend VHDL leaf | Public SURF wrapper | DUT-facing role |
| --- | --- | --- | --- |
| Stream | `RogueTcpStream` | `RogueTcpStreamWrap` | Bidirectional AXI Stream/SSI frames |
| Memory | `RogueTcpMemory` | `RogueTcpMemoryWrap` | AXI-Lite master driven by Rogue memory transactions |
| SideBand | `RogueSideBand` | `RogueSideBandWrap` | Eight-bit opcode events and remote-data state |

The leaves are backend integration details. The public simulation interfaces
retain one API across simulators, derive Stream width from `AXIS_CONFIG_G`,
enforce complete port-pair ownership, and provide optional aggregate Stream
pacing.

## Backend summary

All backends require `libzmq >= 4.1.0`, discoverable through `pkg-config`.
`simlink/ruckus.tcl` loads the reusable simulation interfaces and exactly one
backend implementation:

| Backend | Foreign interface | Combined library | Guide |
| --- | --- | --- | --- |
| GHDL | VHPIDIRECT | `libRogueSimLinkVhpiDirect.so` | [GHDL](ghdl/README.md) |
| VCS | VHPI | `libRogueSimLinkVhpi.so` | [VCS](vcs/README.md) |
| xsim | DPI-C | `libRogueSimLinkDpi.so` | [xsim](xsim/README.md) |

Use `RUCKUS_SIM_BACKEND` to select explicitly. The
[getting-started guide](docs/getting-started.md) covers setup and automatic
selection; the [architecture reference](docs/architecture.md) compares the
three adapter and lifecycle implementations.

## Source layout

| Path | Purpose | Normal `ruckus` import |
| --- | --- | --- |
| `sim/` | Reusable, simulator-neutral VHDL interfaces and pacing | Yes, simulation-only |
| `shared/` | Common C model, transport, lifecycle, and ownership code | Through the selected backend library |
| `ghdl/`, `vcs/`, `xsim/` | Simulator-specific leaves and foreign-interface adapters | Exactly one selected backend |
| `test/` | HDL and SystemVerilog harnesses, bridges, and testbench tops used only by `tests/simlink` | No; tests supply sources explicitly |

The directory names describe responsibility rather than synthesizability:
`sim/` is downstream simulation library code, while `test/` is verification
infrastructure and is not part of the public SimLink import.

## Further reading

- [Getting started](docs/getting-started.md)
- [HDL integration](docs/hdl-integration.md)
- [Rogue and PyRogue clients](docs/rogue-clients.md)
- [Architecture reference](docs/architecture.md)
- [Protocol reference](docs/protocol-reference.md)
- [Legacy VCS migration](docs/migration-from-vcs.md)
- [Cross-backend troubleshooting](docs/troubleshooting.md)
- [Shared C architecture and ownership](shared/README.md)
- [Test architecture and traceability](../tests/simlink/README.md)
- [Alignment and hardening plan](../docs/plans/simlink-alignment/README.md)
