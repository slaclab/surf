# Shared SimLink C Architecture

This directory contains the simulator-neutral Stream, Memory, and SideBand
models, instance registry, and ZeroMQ transport. See the
[architecture reference](../docs/architecture.md) for the layered design and
the [protocol reference](../docs/protocol-reference.md) for wire contracts.

## Components

| Layer | Files | Responsibility |
| --- | --- | --- |
| Stream model/codec | `RogueTcpStreamModel.h`, `RogueTcpStreamCore.h`, `RogueTcpStreamCore.c` | AXI Stream signal state, frame codec, and clock-step FSM |
| Memory model/codec | `RogueTcpMemoryModel.h`, `RogueTcpMemoryCore.h`, `RogueTcpMemoryCore.c` | AXI-Lite signal state, transaction codec, and clock-step FSM |
| SideBand model/codec | `RogueSideBandModel.h`, `RogueSideBandCore.h`, `RogueSideBandCore.c` | Opcode/remote-data state, message codec, and clock-step FSM |
| Transport | `RogueSimLinkTransport.[ch]` | Worker-owned sockets, bounded message handoff, timeouts, and shutdown |
| Instance registry | `RogueSimLinkInstance.[ch]` | Model allocation, handles, validation, cleanup, and process-wide port-pair ownership |
| Backend adapter | `../ghdl`, `../vcs`, or `../xsim` | Simulator ABI translation, callbacks, and diagnostics |
| Stream pacing | `../sim/RogueTcpStreamPacer.vhd` | Deterministic simulated-time payload serialization |

The compiled cores depend on adapter-provided `Rogue*Log()` and
`Rogue*Fatal()` hooks, but contain no simulator API code. The adapters contain
no protocol state or wire framing.

```text
backend callback/update
  -> copy simulator inputs to inSnap[]
  -> Rogue*Step(data)
       -> poll the inbound worker FIFO
       -> advance the codec/protocol FSM
       -> rendezvous with the worker for complete outbound messages
       -> update outState[]
  -> publish outState[] to the simulator
```

## Ownership and lifecycle

| Object | Owner/context | Lifetime |
| --- | --- | --- |
| Model state and snapshots | Simulator instance | Create/elaboration through destroy/process exit |
| ZeroMQ context and sockets | One transport worker per model | First post-reset step through worker shutdown |
| Handle and complete port pair | `RogueSimLinkInstance` registry | Explicit destroy or process `atexit` |
| GHDL integer handle | Process-wide GHDL registry | Process lifetime or `atexit` |
| xsim `chandle` | SystemVerilog DPI leaf | First rising edge through `final`/`atexit` |
| VCS callback metadata | VHPI adapter | Elaboration through process exit |

`RogueSimLinkInstance` allocates zeroed model state, validates model ownership,
and registers fallback cleanup. A model's static descriptor address is its
type token, while the descriptor name is used only for diagnostics. This lets
a new model define its own identity without changing a central model list.
Registry membership is established before an opaque pointer is dereferenced,
so null, fabricated, stale, and wrong-model contexts fail safely without a
magic value in model storage. The model clears protocol-visible state while
reset is asserted. On the first post-reset rising edge, the registry reserves
the complete `portNum`/`portNum+1` pair before the worker binds either socket.
The reservation remains immutable until cleanup.

```text
CREATE -> RESET -> RESERVE PORTS -> START WORKER -> BIND -> RUN
                                                         |
       release pair <- release model <- join <- DESTROY -+
```

During destruction, the instance is first removed from the live registry. The
worker then stops accepting work, wakes from finite polling,
closes both sockets with zero linger, and joins before the model and port pair
are released. GHDL and xsim have explicit/final cleanup paths; VCS destroys the
common instance through process-exit cleanup. Its full VHPI metadata cleanup
routine remains explicit because registering a VCS end callback is unsafe in
the cocotb flow.

## Model state

### Stream

Stream owns fixed inbound/outbound frame buffers, sizes and cursors, SSI user
fields, and output-valid state. It gathers kept bytes until `TLAST`, sends one
four-part message, and emits received payload while honoring `obReady`.
Buffers are 20,000,000 bytes per direction and instance. Partial final beats
read only valid payload bytes; invalid lanes are zero and masked by `TKEEP`.

### Memory

Memory owns one request/completion, a fixed data buffer, transaction metadata,
the current 32-bit word offset, AXI-Lite FSM state, and the retained result.
The readiness probe is handled locally; other operations issue sequential
32-bit AXI-Lite accesses. A multiword transaction retains its first non-OKAY
`RRESP` or `BRESP`. Post keeps the historical completion frame, which Rogue
discards because it completes Post locally.

### SideBand

SideBand retains transmitted/received remote data and opcode/value-valid state.
A received opcode is a one-clock event; received remote data persists. Send
flags are cleared after each event so later updates cannot inherit stale
qualifiers.

## Transport policy

Each model has one worker that exclusively owns its ZeroMQ context and PULL/PUSH
sockets. Only complete multipart messages cross the thread boundary:

- inbound messages enter a 16-message FIFO; when full, the worker stops
  draining ZeroMQ and does not drop or overwrite entries;
- cumulative message size is checked before allocation (`MAX_FRAME` plus
  metadata for Stream, `MAX_DATA` plus metadata for Memory, and four bytes for
  SideBand);
- outbound messages use a single-message rendezvous and PUSH high-water mark
  of one, so a stalled peer cannot be hidden by a large ZeroMQ queue;
- `SURF_SIMLINK_TRANSPORT_TIMEOUT_MS` overrides the 30-second wall-clock
  timeout with a positive decimal millisecond value;
- socket creation, options, bind, polling, sends, and joins all have checked or
  bounded failure paths.

Socket policy uses `ZMQ_IMMEDIATE=1`, `ZMQ_LINGER=0`, PUSH/PULL high-water marks
of 1/16, a 100 ms worker send timeout for observing stop requests, and 10 ms
polling. Worker errors are copied as data; only the simulator thread calls
backend logging or fatal hooks.

## Concurrency invariants

- One worker owns and uses a socket for its entire lifetime.
- Only complete protocol messages cross a thread boundary.
- Only the simulator context mutates model state.
- A port pair is released only after both sockets close.
- Reset has an explicit queue policy and cannot race socket destruction.
- Host queue depth and scheduling do not define simulated link bandwidth.
- Every wait and join has a bounded failure path.

## Timing boundary

Transport handoff uses host wall-clock time. Stream bandwidth is modeled in
simulation time by `RogueTcpStreamPacer`, which counts valid `TKEEP` bytes on
AXI handshakes and caps saved credit at one beat. The shared Stream codec stores
beats as little-endian 32-bit-word arrays and supports 1 through 128 data bytes;
each backend translates its native vector ABI to that representation. See the
[bandwidth contract](../docs/architecture.md#simulated-stream-bandwidth) for
equations.
Memory and SideBand do not provide rate shaping.
