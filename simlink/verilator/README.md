# Verilator SimLink Backend

This backend implements the common SimLink leaves with SystemVerilog DPI-C for
Verilator. See the [architecture reference](../docs/architecture.md) and
[shared C internals](../shared/README.md). The leaves are instantiated
through the flat [SystemVerilog wrappers](../sv/README.md), never directly by
a downstream design.

## Call chain and ownership

```text
flat SV wrapper (simlink/sv/Rogue*Wrap.sv)
 -> instantiates Rogue* leaf (simlink/verilator/Rogue*.sv)
 -> SV always @(posedge clock)
 -> DPI-C rogue*Update(chandle, ports...)
 -> shared Rogue*Step
```

Each leaf is derived from the corresponding `../xsim/Rogue*Dpi.sv` leaf, with
unchanged DPI import declarations (same function names, argument order, and
qualifiers) except where noted below. The DPI-C adapters themselves --
`RogueDpiInstance.c`, `RogueTcpStream.c`, `RogueTcpMemory.c`, and
`RogueSideBand.c` -- are compiled in place from `../xsim/` by
`simlink/verilator/Makefile`; no C source is copied or modified. Each leaf
lazily creates and retains one `chandle`; its `final` block calls the matching
destroy function, with the common `atexit` fallback covering processes that
exit without running `final`.

The `RogueTcpStream` leaf's DPI import declares its wide data, user, and keep
vector arguments at the shared core's fixed maximum width (128 data bytes)
rather than deriving them from `TDATA_BYTES_G`, because Verilator requires
every SV import of a given DPI function name to bind to one C prototype
across the whole design; a leaf elaborated at more than one `TDATA_BYTES_G`
in the same design cannot use a per-instance parameterized import width. The
C adapter only ever reads or writes the low `dataBytes/4` words of these wide
arguments, so the extra width carries no meaning beyond the real port width.
`RogueTcpMemory` and `RogueSideBand` have no such parameter and their DPI
imports are unchanged from xsim's.

## Timing rule

Every rising edge stages the DPI call's outputs into `_c` temporaries, then
publishes each port-width output with exactly one nonblocking assignment.
The value the C model decides at edge N is visible right after edge N,
exactly like a flop, never a cycle later and never through a second register
layer. All outputs are 0 at time 0, before the first update call.

## Build and ABI check

The backend requires Verilator 5.020 or newer, gcc, and the common `libzmq`
development package discovered through `pkg-config`.

```bash
make -C simlink/verilator all abi-check
```

`all` builds the four xsim C adapters and the shared cores, compiled against
Verilator's own `svdpi.h`, into a single `libRogueSimLinkDpi.so`.

`abi-check` regenerates each leaf's DPI header directly from its `.sv` import
declaration with `verilator --dpi-hdr-only`, then syntax-checks the matching
xsim C adapter against that regenerated header. A prototype mismatch between
the SV import and the C definition fails the build instead of surfacing as a
runtime ABI mismatch.

## Direct use

```bash
verilator --binary --timing --top-module design \
  simlink/sv/*.sv simlink/verilator/*.sv design.sv \
  <surf>/simlink/verilator/libRogueSimLinkDpi.so \
  -LDFLAGS -Wl,-rpath,<surf>/simlink/verilator
```

surf sources build warning-clean under Verilator's default warning set.

As with every SimLink backend, an instance using `portNum=N` owns both `N`
and `N+1`; the next non-overlapping instance's base port must be at least
`N+2`.

## Tests

`tests/simlink/run-verilator.sh` and `tests/simlink/verilator/` exercise this
backend against live pyzmq peers through the shared traffic, eight-instance,
and relaunch tops, and `tests/simlink/rogue/test_RogueVerilatorRogue.py` runs
the production Rogue clients against `RogueSvRogueTb`. Every test builds
through the `simlink/test/sv` ruckus project on `system_verilator.mk` rather
than a hand-built `verilator` command line; the `abi-check` guard still runs
before every build. See the [test guide](../../tests/simlink/README.md).

## Limitations

- All sockets are worker-owned; DPI calls do not call ZeroMQ.
- `final` is the preferred instance cleanup hook, but process-exit cleanup is
  still retained as a fallback.
- Port ownership and model lifecycle use the same common API as every other
  backend.
