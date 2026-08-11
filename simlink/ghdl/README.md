# GHDL SimLink Backend

This backend implements the common SimLink leaves with GHDL's VHPIDIRECT
foreign-function interface. See the
[architecture reference](../docs/architecture.md) and
[shared C internals](../shared/README.md). For the complete environment and
first real Rogue transaction, start with the
[getting-started guide](../docs/getting-started.md).

## Call chain and value representation

Each VHDL architecture declares foreign create, update, and getter functions.
Its clocked process lazily creates an integer handle, calls one C update on
every rising edge, then reads outputs through handle-based getters.

GHDL passes `std_logic` values as enumeration ordinals: `0` is encoded as `2`
and `1` as `3`. Vectors are byte arrays in VHDL index order, with the most
significant bit first. `RogueVhpiDirect.h` is the adapter's single conversion
point. The parameterized `RogueTcpStream` vectors are converted to
little-endian 32-bit word arrays and support 1 through 128 data bytes per beat.

## Instances, ports, and cleanup

`RogueVhpiDirectRegistry.h` is a thin integer-handle bridge to the compiled
`RogueSimLinkInstance` API. Each model supplies a static descriptor whose
address is its registry type token; adding another model does not require
editing a central enum or recovering identity from names. All three adapters and cores link into one
`libRogueSimLinkVhpiDirect.so`, so handles and complete two-port reservations are
process-wide across model types without inter-library loader dependencies. It
rejects invalid/changed ports and any overlap before ZeroMQ bind. The VHDL
process itself has no portable end-of-elaboration destructor, so normal
teardown relies on common `atexit` cleanup.

## Build and load

The Makefile builds one process-wide library:

```text
build/libRogueSimLinkVhpiDirect.so
```

It uses `gcc -shared -fPIC`, `pkg-config libzmq`, and generated dependency
files so shared/local header edits rebuild the library. On macOS it records a
basename-only Mach-O install name so the staged library resolves through the
loader path. No backend library depends on another SimLink shared object.

Build directly with:

```bash
make -C simlink/ghdl
```

Run the focused GHDL suite from the repository root with:

```bash
./.venv/bin/python -m pytest -q -n 0 tests/simlink/ghdl
```

Individual leaf, wrapper, lifecycle, and active multi-instance tests can be
selected by filename; see the [test guide](../../tests/simlink/README.md).

## Limitations

- All sockets are worker-owned; simulator callbacks do not call ZeroMQ.
- Fatal adapter errors use `printf` plus `abort`, so negative cases require a
  subprocess.
- Destruction is principally process-exit cleanup. Sockets use zero linger;
  outbound traffic uses a bounded rendezvous with a fatal timeout.
- GHDL has no supported in-process time-zero restart for this foreign runtime.
  Rerun the simulator process; the relaunch regression keeps one external peer
  alive across two runs and verifies reconnection to the same port pair.
