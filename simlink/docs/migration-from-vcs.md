# Migrating from the Legacy VCS SimLink

The aligned SimLink architecture replaces the pre-alignment implementation
under `axi/simlink` with one top-level, multi-backend subsystem under
`simlink`. Existing designs that instantiate the public `Rogue*Wrap` entities
should need little or no VHDL change, but build integration and native-library
assumptions must be updated.

Use [getting started](getting-started.md) for a new environment and the
[HDL integration guide](hdl-integration.md) for current wrapper examples.

## Path and build changes

| Legacy | Current |
| --- | --- |
| `axi/simlink/ruckus.tcl` | `simlink/ruckus.tcl`, imported by top-level SURF |
| `axi/simlink/tb/Rogue*Wrap.vhd` | `simlink/sim/Rogue*Wrap.vhd` |
| `axi/simlink/sim/` VCS leaves | `simlink/vcs/` |
| Placeholder `axi/simlink/ghdl/` leaves | Functional `simlink/ghdl/` VHPIDIRECT backend |
| No xsim backend | `simlink/xsim/` VHDL/SystemVerilog/DPI backend |
| `axi/simlink/src/` native sources | Backend adapters plus `simlink/shared/` common model/transport |
| `libAxiSim.so` / VHPI library name `AxiSim` | `libRogueSimLinkVhpi.so` for VCS |

The current combined native libraries are:

| Backend | Library |
| --- | --- |
| GHDL | `simlink/ghdl/build/libRogueSimLinkVhpiDirect.so` |
| VCS | `simlink/vcs/libRogueSimLinkVhpi.so` |
| xsim | `simlink/xsim/libRogueSimLinkDpi.so` |

Remove target scripts that compile `axi/simlink/src` directly, reference
`libAxiSim.so`, or manually add `axi/simlink/sim`. Import SURF normally and let
ruckus build/load the selected combined library.

## Backend selection

The old manifest selected its non-GHDL path whenever `GHDLFLAGS` was absent.
That behavior is ambiguous in shells containing both Vivado and VCS settings.
The current order is:

1. explicit `RUCKUS_SIM_BACKEND`;
2. GHDL when `GHDLFLAGS` exists;
3. VCS when `VCS_VERSION` exists; or
4. xsim otherwise.

Set the value explicitly in shared setup scripts:

```bash
export RUCKUS_SIM_BACKEND=vcs
```

Only `ghdl`, `vcs`, and `xsim` are valid backend directory names. In a
persistent Vivado project, the manifest removes stale sibling-backend sources
so switching targets does not leave duplicate `RogueTcp*` entities.

## Preserved public contracts

The following remain the compatibility surface:

- entity names `RogueTcpStreamWrap`, `RogueTcpMemoryWrap`, and
  `RogueSideBandWrap`;
- existing wrapper ports and original generics;
- one adjacent port pair per live leaf;
- Stream, Memory, and SideBand ZeroMQ multipart formats and socket directions;
- host-order integer fields on the supported little-endian hosts;
- AXI Stream byte order, `TKEEP`, `TLAST`, and SSI first/last/error semantics;
- AXI-Lite request ordering and Rogue transaction identifiers; and
- one-cycle SideBand opcode events plus retained remote-data state.

Rogue applications can keep the same Memory and Stream `TcpClient` base ports
and SideBand `SideBandSim` base port when the allocation is already disjoint.

## Stream wrapper additions

The existing Stream generics are retained. Three optional pacing generics were
added with compatibility defaults:

```vhdl
AXIS_CLK_FREQ_G       : real := 0.0;
S_AXIS_PAYLOAD_RATE_G : real := 0.0;
M_AXIS_PAYLOAD_RATE_G : real := 0.0
```

Both rates default to zero, which bypasses pacing. Existing instances therefore
retain their unpaced behavior without adding a generic map.

The old foreign boundary was fixed at eight data bytes. The current leaf width
follows `AXIS_CONFIG_G.TDATA_BYTES_C` from 1 through 128, while the public AXI
record interface remains unchanged. Review target-specific assumptions that a
SimLink beat is always 64 bits; frame payload and wire framing remain
compatible.

Non-power-of-two `CHAN_COUNT_G` values now elaborate without overrunning the
internal channel map. Port and `TDEST` behavior remains the documented routed
mapping.

## Lifecycle and transport changes

The native architecture no longer embeds the model and synchronous ZeroMQ
sockets directly in the VCS callback adapter. Each elaborated leaf owns an
explicit common instance and a worker-owned transport. Shared instance
validation makes that ownership consistent across GHDL, VCS, and xsim.

Behavioral changes to account for:

- Complete `N/N+1` pairs are registered process-wide before bind. Invalid,
  changed, and overlapping pairs fail with a direct diagnostic.
- ZeroMQ calls occur on the worker, not the simulator callback. HDL-facing
  steps exchange bounded queues/rendezvous with that worker.
- Missing or stalled outbound peers fail after 30 seconds by default instead
  of hanging indefinitely. Set `SURF_SIMLINK_TRANSPORT_TIMEOUT_MS` to a
  positive decimal millisecond value when a different process-wide bound is
  justified.
- Sockets use zero linger and shutdown joins are bounded.
- Memory exposes the production Rogue `waitReady()` probe without issuing an
  AXI-Lite transaction.
- Reset clears transaction state before first socket startup and preserves the
  instance's configured port on later reset pulses.

These changes can reveal latent target problems—overlapping PGP/Memory ranges,
an undrained HDL-to-software stream, or a peer with reversed socket direction—that
the synchronous legacy implementation could hide as a hang.

## VCS shutdown behavior

Do not add a `vhpiCbEndOfSimulation` callback back to the cocotb/VCS flow as a
migration workaround. That callback can race cocotb's VPI teardown and cause a
simulator shutdown fault. The current adapter deliberately leaves it
unregistered:

- common `atexit` cleanup handles worker and socket side effects;
- `VhpiGenericCleanup` remains exported for a safe future non-cocotb caller;
  and
- the simulator-free lifecycle regression calls that routine directly to
  verify callback/handle/value/name cleanup.

The licensed VCS active-traffic test validates normal elaboration, traffic,
reset survival, and process exit with this arrangement.

## Migration checklist

1. Rebase onto the aligned top-level `simlink/` tree.
2. Remove old `axi/simlink` source paths and `libAxiSim.so` build/load logic.
3. Import top-level SURF and set `RUCKUS_SIM_BACKEND=vcs` in the VCS target.
4. Keep the existing public wrapper instances and Rogue base ports initially.
5. Audit every complete pair, including PGP/HTSP SideBand offsets and derived
   multi-channel Stream ports.
6. Confirm `pkg-config --modversion libzmq` reports at least 4.1.0.
7. Build `simlink/vcs/libRogueSimLinkVhpi.so` through the ordinary ruckus VCS
   flow or the direct diagnostic command in the [VCS guide](../vcs/README.md).
8. Release reset and confirm one listening diagnostic per leaf/channel.
9. Run Memory `waitReady()` and one read/write before broader application
   traffic.
10. Verify both Stream directions and SideBand state/events, then confirm the
    simulator exits cleanly.

For failures, use the [cross-backend troubleshooting guide](troubleshooting.md)
before changing the wrapper or wire protocol.
