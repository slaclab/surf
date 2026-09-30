# Icarus Verilog SimLink Backend

This backend implements the common SimLink leaves with Icarus Verilog's VPI
foreign-function interface. See the [architecture reference](../docs/architecture.md)
and [shared C internals](../shared/README.md). The leaves are instantiated
through the flat [SystemVerilog wrappers](../sv/README.md), never directly by a
downstream design.

## Call chain and ownership

```text
flat SV wrapper (simlink/sv/Rogue*Wrap.sv)
 -> instantiates Rogue* leaf (simlink/iverilog/Rogue*.sv)
 -> SV always @(posedge clock)
 -> $rogue*Update(handle, ports...)
 -> shared Rogue*Step
```

Each leaf lazily creates one handle on its first rising edge: a positive
32-bit integer returned by `$rogue*Create()` and held in a plain SV `int`
(never a 64-bit pointer-in-register). Every subsequent systf call is
validated against that handle by `RogueVpiInstance.c`, a compatibility bridge
from the VPI handle registry to the common `RogueSimLinkInstance` API, which
rejects an invalid or stale handle, rejects complete-pair port overlap across
model types, and registers `atexit` cleanup. The leaf's `final` block calls the
matching `$rogue*Destroy(handle)` task; the common `atexit` fallback covers
processes that exit without running `final`.

## Timing rule

`$rogue*Update` writes every output into a same-named `_c` local through its
VPI write-back argument. The nonblocking assignment that follows is the
leaf's only register stage: the value the C model decides at rising edge N
becomes visible right after edge N, exactly like a flop, never a cycle later
and never through a second register layer. Design logic driven on the same
edge never races the leaf's outputs. All outputs are 0 at time 0, before the
first update call.

VPI vector arguments are four-state; any argument bit that is X or Z is read
by the adapter as 0 (see `rogueVpiGetU32`/`rogueVpiGetWords` in
`RogueVpiInstance.h`).

## System functions and tasks

| Name | Kind | Arguments | Returns |
| --- | --- | ---: | --- |
| `$rogueTcpStreamCreate` | function | 0 | int32 handle, 0 on failure |
| `$rogueTcpStreamUpdate` | function | 17 | 1 on success, 0 on failure |
| `$rogueTcpStreamDestroy` | task | 1 | none |
| `$rogueTcpMemoryCreate` | function | 0 | int32 handle, 0 on failure |
| `$rogueTcpMemoryUpdate` | function | 22 | 1 on success, 0 on failure |
| `$rogueTcpMemoryDestroy` | task | 1 | none |
| `$rogueSideBandCreate` | function | 0 | int32 handle, 0 on failure |
| `$rogueSideBandUpdate` | function | 9 | 1 on success, 0 on failure |
| `$rogueSideBandDestroy` | task | 1 | none |

## Build

The backend requires Icarus Verilog 12 or newer (`iverilog`, `iverilog-vpi`,
`vvp`), gcc, and the common `libzmq` development package discovered through
`pkg-config`.

```bash
make -C simlink/iverilog
```

builds the adapters and shared cores into a single `RogueSimLink.vpi`.

## Direct use

An external target compiles the flat SV wrappers and the Icarus leaves, then
loads the built module at `vvp` time:

```bash
iverilog -g2012 -o design.vvp simlink/sv/*.sv simlink/iverilog/*.sv design.sv
vvp -M<surf>/simlink/iverilog -mRogueSimLink design.vvp
```

surf sources carry no `` `timescale `` directive; the downstream flow or
top-level design sets the default time unit and precision.

As with every SimLink backend, an instance using `portNum=N` owns both `N`
and `N+1`; the next non-overlapping instance's base port must be at least
`N+2`.

## Tests

`tests/simlink/run-iverilog.sh` and `tests/simlink/iverilog/` exercise this
backend against live pyzmq peers through the shared traffic, eight-instance,
and relaunch tops, and `tests/simlink/rogue/test_RogueIverilogRogue.py` runs
the production Rogue clients against `RogueSvRogueTb`. See the
[test guide](../../tests/simlink/README.md).

## Limitations

- All sockets are worker-owned; VPI calls do not call ZeroMQ.
- `final` is the preferred instance cleanup hook, but process-exit cleanup is
  still retained as a fallback.
- Port ownership and model lifecycle use the same common API as every other
  backend.
