# SimLink Architecture

This document describes SimLink's internal layering, instance ownership,
lifecycle, timing boundary, and backend differences. Application developers
should normally begin with [getting started](getting-started.md) and integrate
the public entities described in the [HDL guide](hdl-integration.md).

## Interface layers

The record-based `RogueTcpStreamWrap`, `RogueTcpMemoryWrap`, and
`RogueSideBandWrap` entities under `simlink/sim/` are the stable downstream SURF
interfaces. Backend leaves expose scalar/vector ports suitable for a foreign
adapter. The entities under `simlink/test/common/` flatten SURF records for
cocotb and other test-facing uses; they are harnesses, not a second downstream
API.

`RogueTcpStreamWrap` derives the leaf width from
`AXIS_CONFIG_G.TDATA_BYTES_C`, keeping the DUT-facing and foreign-function
boundaries aligned. Its resizers normalize `TKEEP` and `TUSER`; width changes
only simulator beat granularity, not ZeroMQ framing or payload byte order.

## Process architecture

All three models use the common worker/rendezvous transport:

```text
separate software process                         simulator process

 Rogue / PyRogue
 TcpClient or SideBandSim
          |
          | ZeroMQ PUSH/PULL over loopback TCP
          v
 +----------------------+       one call per rising simulation clock
 | shared/*Core.c       |<------------------------------------------+
 | codec + model/FSM    |                                           |
 | all models -> worker |                                           |
 +----------------------+                                           |
          |                                                        |
          +--> GHDL VHPIDIRECT / VCS VHPI / xsim DPI adapter ------+
                                                                      |
                                   scalar VHDL/SV leaf                 |
                                             |                        |
                                   SURF record wrapper                 |
                                             |                        |
                              AXI Stream / AXI-Lite / SideBand DUT <---+
```

Each leaf has independent model and transport state. Socket creation and
binding are deferred until the first rising edge after reset is released and
the leaf captures a nonzero `portNum`. Each instance starts one worker that
owns both sockets, polls into a bounded inbound FIFO, and accepts outbound
complete messages through a wall-clock rendezvous.

Missing/stalled-peer waits are bounded by a 30-second default before a fatal
diagnostic. Set `SURF_SIMLINK_TRANSPORT_TIMEOUT_MS` to a positive decimal
millisecond value before starting the simulator to select a different
process-wide limit. An invalid value fails at model startup instead of silently
reverting to the default. No public VHDL generic is required for this
host-transport setting.

Shared model headers define state and signal tables, compiled core units own
wire/step behavior, and `RogueSimLinkInstance` provides common zeroed state,
model validation, cleanup, handles, and process-wide port-pair ownership.
Backend code retains only its ABI/callback translation and diagnostic hooks.
The [shared internals guide](../shared/README.md) documents the C ownership and
threading rules in detail.

## Lifecycle and readiness

Current startup is:

```text
elaborate leaf -> assert reset -> first post-reset rising edge
 -> capture port -> create and bind sockets -> print listening message
 -> peer connects asynchronously -> normal traffic
```

For Memory, software can call `TcpClient.waitReady()`: the probe exercises the
complete request/response socket path without generating AXI-Lite traffic.
Stream and SideBand do not yet have a production readiness transaction. Tests
may coordinate peer processes out of band and then allow a short settle
interval; that test orchestration is not part of the wire protocol.

GHDL destroys instance state through process-exit cleanup, while xsim prefers
its SystemVerilog `final` hooks and retains process-exit cleanup as a fallback.
VCS deliberately does not register a `vhpiCbEndOfSimulation` callback in the
cocotb flow because that callback can race VPI teardown. Common process-exit
cleanup owns VCS worker/socket shutdown; the exported VHPI cleanup routine is
retained and tested directly for a future safe non-cocotb path.

All sockets use zero linger. Worker polling, outbound sends, and thread joins
are bounded so an absent peer cannot leave the simulator blocked forever.

### Reset, restart, and relaunch terminology

These operations are intentionally distinguished:

- **HDL reset** asserts the model's `reset` port inside an existing run. It
  clears protocol-visible FSM/output state but keeps the instance, worker,
  socket pair, and already queued complete inbound messages alive. A Memory
  request already removed from the transport queue but not completed when
  reset arrives is abandoned and receives no response.
- **Time-zero restart** rewinds a loaded simulator runtime without rebuilding
  it. Vivado xsim calls this operation `restart`. Whether foreign C heap,
  `chandle` values, callbacks, and `final` blocks are rewound together is a
  simulator-specific contract and is not yet claimed as supported by SimLink.
  A particularly important case to test is an SV `chandle` rewinding to null
  while its old C allocation remains live: that would create a second instance
  and correctly trip the registry's port-overlap check rather than reconnect.
- **Reload/relaunch** tears down the old simulation modules/runtime and loads a
  fresh one. Vivado calls the compile-and-relaunch workflow `relaunch_sim`; the
  common VCS debugging workflow is often informally called restart or re-exec.
- **Process rerun** starts a fresh simulator process. This is GHDL's supported
  equivalent and is also the portable lower-bound regression for module
  relaunch behavior.

The supported relaunch contract is that the external Rogue/peer process may
remain alive. The old model releases its sockets, the fresh model binds the
same pair, and ZeroMQ reconnects the unchanged client sockets. Simulator-side
C model/FSM state is new; it is not transferred between runs.

Requests still queued on the software/ZeroMQ side while the simulator is absent
may arrive in a burst after the new model binds. That is compatible with the
legacy VCS behavior. A transaction consumed by the old model but interrupted
before its response is not replayed by SimLink and may time out in software.
Applications that require stronger exactly-once behavior need a protocol-level
epoch/recovery mechanism; the current wire protocol has none.

The native relaunch regression destroys and recreates a model behind one live
peer, including a request queued during the gap. The GHDL regression keeps one
external peer process alive across two complete simulator processes. Exact VCS
module re-exec and xsim time-zero `restart`/compiled `relaunch_sim` coverage
remain backend-specific licensed tests rather than aliases for the GHDL case.

## Simulated Stream bandwidth

Configurable Stream bandwidth uses payload bits per simulated second in each
direction:

```text
credit_per_cycle = configured_payload_bits_per_second / axis_clock_hz
transferred_bits = 8 * count_ones(TKEEP), on TVALID && TREADY only
```

`RogueTcpStreamPacer` implements the contract with fixed-point fractional-byte
credit. It initializes and caps credit at one beat, debits only completed AXI
Stream handshakes, counts valid bytes through the configured `TKEEP` mode, and
holds the transfer stable under downstream backpressure. Capping credit means
idle or stalled time cannot create an unlimited catch-up burst.

A zero rate is the compatibility bypass. Credit uses `2^20` units per byte and
rounds the configured increment to the nearest unit; the payload-rate quantum
is `8 * AXIS_CLK_FREQ_G / 2^20` bit/s.

The `S_AXIS` pacer is before the channel demultiplexer and the `M_AXIS` pacer is
after the channel multiplexer. Each direction therefore has one aggregate
budget shared by every routed channel. Host queue depth, worker scheduling,
and ZeroMQ throughput do not modify either credit counter.

The API models payload rate only; it does not include encoding efficiency,
frame overhead, inter-frame gap, or propagation latency.

The foreign boundary moves at most `8 * AXIS_CONFIG_G.TDATA_BYTES_C` payload
bits per simulation clock:

```text
maximum payload rate = 8 * AXIS_CONFIG_G.TDATA_BYTES_C * axis_clock_hz
```

The default eight-byte width represents 6.4 Gb/s at 100 MHz and 10 Gb/s at
156.25 MHz. A 64-byte selection raises the ceiling to 51.2 Gb/s at 100 MHz and
80 Gb/s at 156.25 MHz; the supported 128-byte maximum represents 102.4 and
160 Gb/s at those clocks. Choose the smallest width that meets the intended
aggregate payload rate. Configuration above the selected representation's
ceiling is rejected.

Software-to-HDL launch timing remains distinct from serialization timing. The
wire carries no target simulation timestamp, so an empty receive queue cannot
distinguish “no frame intended” from “software is late.” Deterministic tests
therefore measure serialization from frame admission; arbitrary software
launch timing would require a later timestamp or rendezvous protocol.

Rate shaping applies only to `RogueTcpStream`.

## Backend selection and implementation

`simlink/ruckus.tcl` loads the public simulation interfaces and exactly one
backend. It first
honors `RUCKUS_SIM_BACKEND`, then detects GHDL or VCS environments, and
otherwise selects xsim. In a persistent Vivado project it removes stale
sibling-backend sources to avoid duplicate entity definitions.

| Property | GHDL | VCS | xsim |
| --- | --- | --- | --- |
| Foreign ABI | VHPIDIRECT functions | VHPI foreign architecture/callback | SystemVerilog DPI-C |
| Logic representation | `std_logic` enum-ordinal byte arrays | VHPI enum scalar/vector values | Two-state DPI `bit` values behind SV `logic` ports |
| Update trigger | VHDL calls C on every rising edge | VHPI value-change callback detects rising edge | SV `always @(posedge clock)` calls C |
| Library shape | Combined `libRogueSimLinkVhpiDirect.so` | Combined `libRogueSimLinkVhpi.so` | Combined `libRogueSimLinkDpi.so` |
| Instance handle | Process-wide integer handle | Common instance in VHPI callback `user_data` | Per-leaf common-instance `chandle` |
| Model cleanup | Explicit C destroy API plus `atexit`; VHDL normally relies on exit | Common `atexit` for worker/socket shutdown; exported VHPI cleanup is not registered as an end callback | SV `final` plus common `atexit` fallback |
| Executable coverage | GHDL/cocotb | Opt-in active-traffic cocotb runner; executed with VCS X-2025.06 | Native adapter and Vivado-enabled mixed-language tests |

Exact adapter behavior and build requirements belong to the
[GHDL](../ghdl/README.md), [VCS](../vcs/README.md), and
[xsim](../xsim/README.md) backend guides. The
[test guide](../../tests/simlink/README.md) maps each contract to executable
coverage.
