# RSSI

This directory contains the Reliable SLAC Streaming Interface implementation.
Most firmware applications should instantiate `v1/rtl/RssiCoreWrapper.vhd`
rather than `RssiCore.vhd` directly.

`RssiCoreWrapper` adds the user-facing AXI Stream mux/demux and optional
packetizer/depacketizer layer around `RssiCore`. `RssiCore` is still useful for
focused protocol integration tests or custom wrappers that already own stream
chunking and routing.

## Typical Instantiation

Common SLAC application patterns instantiate one `RssiCoreWrapper` server behind
an Ethernet/UDP server path, or a matched client/server pair in a testbench.
Most designs drive `openRq_i` high after reset and use AXI-Lite only when they
need runtime parameter control or status access.

Set these generics deliberately:

- `SERVER_G`: `true` for a passive listener, `false` for an active opener.
- `APP_AXIS_CONFIG_G`: one entry per application stream. Use an SSI-compatible
  config. Multi-stream routed applications should include enough `TDEST` bits
  for the route table.
- `TSP_AXIS_CONFIG_G`: match the lower transport stream, usually the Ethernet
  or UDP engine AXI Stream config.
- `APP_STREAMS_G`: number of application streams exposed by the wrapper.
- `APP_STREAM_ROUTES_G`: route table used by the wrapper mux/demux. A common
  pattern is `0 => x"00"`, `1 => x"01"`, and so on.
- `BYPASS_CHUNKER_G`: `true` when the application already provides frames that
  fit the negotiated RSSI segment size; `false` to use the wrapper
  packetizer/depacketizer.
- `APP_ILEAVE_EN_G`: enables the packetizer2/depacketizer2 path for interleaved
  multi-stream traffic. Leave `false` for the simpler legacy packetizer path.
- `WINDOW_ADDR_SIZE_G`: transmit/receive window depth is
  `2**WINDOW_ADDR_SIZE_G` segments. Reducing this lowers buffer depth and can
  reduce memory use, at the cost of fewer outstanding segments.
- `MAX_SEG_SIZE_G`: maximum RSSI segment size in bytes. It must be a power of
  two. `RssiCoreWrapper` derives the core segment-buffer address width from
  this value.
- `ACK_TOUT_G`, `RETRANS_TOUT_G`, `NULL_TOUT_G`, `MAX_RETRANS_CNT_G`, and
  `MAX_CUM_ACK_CNT_G`: local defaults advertised during negotiation unless
  AXI-Lite register mode is enabled.

The wrapper currently forces `MAX_NUM_OUTS_SEG_G` passed into `RssiCore` to
`2**WINDOW_ADDR_SIZE_G`; the legacy wrapper generic with the same name is not
used.

## Segment Size Selection

`MAX_SEG_SIZE_G` is the maximum RSSI DATA payload size, in bytes, that this
endpoint can advertise and buffer. It is not the full Ethernet frame size. A
DATA segment sent on the transport stream also carries the 8-byte RSSI DATA
header, and lower layers may add UDP/IP/Ethernet headers.

When using `RssiCoreWrapper`, configure `MAX_SEG_SIZE_G` and leave
`SEGMENT_ADDR_SIZE_G` alone. The wrapper's `SEGMENT_ADDR_SIZE_G` generic is a
legacy generic and is not passed through; the wrapper derives the core value
from `MAX_SEG_SIZE_G`.

For UDP/IPv4 over Ethernet, choose a value that fits inside the path MTU:

```text
MAX_SEG_SIZE_G + 8 <= UDP payload budget
UDP payload budget = Ethernet MTU - 20-byte IPv4 header - 8-byte UDP header
```

For a standard 1500-byte Ethernet MTU, the UDP payload budget is 1472 bytes, so
the RSSI payload budget is 1464 bytes. Because `MAX_SEG_SIZE_G` must be a power
of two, `1024` is the usual safe choice.

For a 9000-byte jumbo Ethernet MTU, the UDP payload budget is 8972 bytes, so
the RSSI payload budget is 8964 bytes. The usual power-of-two choice is `8192`.
Only use a jumbo-sized RSSI segment when every relevant MAC, UDP/IP block, peer,
switch path, and software endpoint is configured for jumbo frames. Otherwise the
design may rely on IP fragmentation or drop oversized frames, depending on the
transport.

Smaller values such as `64`, `128`, or `256` are useful when minimizing memory
or testing constrained links, but they increase per-payload overhead and may
reduce throughput. Larger values improve efficiency for bulk transfer, but
increase per-endpoint buffer memory. With `RssiCoreWrapper`, the segment buffer
depth scales with both `MAX_SEG_SIZE_G` and `WINDOW_ADDR_SIZE_G`; each side has
TX and RX segment storage sized roughly by:

```text
2**WINDOW_ADDR_SIZE_G * MAX_SEG_SIZE_G
```

per direction, before implementation overhead and extra FIFOs.

When `BYPASS_CHUNKER_G=false`, the wrapper packetizer uses the negotiated RSSI
segment size as its maximum output packet size. The packetizer header/tail words
fit inside the RSSI payload budget, so the maximum original application payload
per RSSI DATA segment is smaller than `MAX_SEG_SIZE_G`. When
`BYPASS_CHUNKER_G=true`, the application must already keep each transmitted
frame within the negotiated RSSI segment size.

## Direct Core Buffer Sizing

`SEGMENT_ADDR_SIZE_G` only matters when instantiating `RssiCore` directly. It is
the address width of one segment buffer, measured in 64-bit RSSI words:

```text
segment capacity in bytes = 2**SEGMENT_ADDR_SIZE_G * 8
```

For direct `RssiCore` use, set it to the smallest value that can hold
`MAX_SEG_SIZE_G`:

```text
2**SEGMENT_ADDR_SIZE_G * 8 >= MAX_SEG_SIZE_G
```

For power-of-two segment sizes, this means:

```text
SEGMENT_ADDR_SIZE_G = log2(MAX_SEG_SIZE_G / 8)
```

Common examples:

- `MAX_SEG_SIZE_G=64` uses `SEGMENT_ADDR_SIZE_G=3`
- `MAX_SEG_SIZE_G=128` uses `SEGMENT_ADDR_SIZE_G=4`
- `MAX_SEG_SIZE_G=256` uses `SEGMENT_ADDR_SIZE_G=5`
- `MAX_SEG_SIZE_G=1024` uses `SEGMENT_ADDR_SIZE_G=7`
- `MAX_SEG_SIZE_G=8192` uses `SEGMENT_ADDR_SIZE_G=10`

So an application using `SEGMENT_ADDR_SIZE_G=7` is sized for 128 64-bit words,
or 1024 bytes per RSSI segment. That is the natural direct-core pairing for
`MAX_SEG_SIZE_G=1024`; it is not independently tuned beyond matching the segment
size. A larger value wastes buffer memory unless `MAX_SEG_SIZE_G` is also
larger.

## Direct `RssiCore` Use

Instantiate `RssiCore` directly only when the surrounding design already
handles application stream resizing, packetization, and routing. Direct use
requires one application AXI Stream and one transport AXI Stream.

For direct `RssiCore`, keep these relationships valid:

- `MAX_NUM_OUTS_SEG_G <= 2**WINDOW_ADDR_SIZE_G`
- `MAX_SEG_SIZE_G <= (2**SEGMENT_ADDR_SIZE_G)*8`
- `SEGMENT_ADDR_SIZE_G` is the number of 64-bit payload words per segment.

## Regression Coverage

Default cocotb coverage under `tests/protocols/rssi/` includes:

- Module-level checksum, header, RX FSM, TX FSM, monitor, connection FSM, and
  AXI-Lite register-interface tests.
- `test_RssiCore.py`: direct `RssiCore` client/server integration with
  connection, parameter negotiation, payload delivery, retransmission,
  checksum-corruption recovery, keepalive, missing-keepalive close, explicit
  close, close/reopen lifecycle, partial `TKEEP` delivery, transport
  backpressure stalls, and BUSY recovery without lost or duplicate frames.
  Focused pytest entries also cover AXI-Lite controlled open/parameter
  writes/status/counter reads/checksum injection/close and
  `HEADER_CHKSUM_EN_G=false` connection/payload delivery.
- `test_RssiCoreWrapper.py`: one-stream `RssiCoreWrapper` smoke coverage across
  bypass-chunker and legacy packetizer/depacketizer modes, including
  `WINDOW_ADDR_SIZE_G` values 1, 2, and 3 and `MAX_SEG_SIZE_G` values 64, 128,
  and 256. Partial-`TKEEP` coverage compares only bytes selected by `TKEEP`;
  bytes outside `TKEEP` are not part of the payload contract and may be changed
  by the packetizer path.
- `test_RssiCoreWrapperMultiStream.py`: two-stream `RssiCoreWrapper` active-open
  and routed payload coverage with `APP_STREAMS_G=2`, routed stream
  destinations, `APP_ILEAVE_EN_G=true`, and the packetizer2/depacketizer2 path.
  The routed payload test waits after RSSI connection so the server-side
  `AxiStreamDepacketizer2` can finish initializing its per-`TDEST` route state.
  It also covers routed partial-`TKEEP` and EOFE preservation through the
  packetizer2 application boundary.

Current EOFE behavior is path-specific in the regression suite: direct
`RssiCore` and the one-stream legacy wrapper path clear application EOFE on
receive, while the packetizer2 routed wrapper path preserves EOFE at the routed
application boundary.

Known remaining test gaps:

- Hardware resource reduction from smaller `WINDOW_ADDR_SIZE_G` values still
  needs synthesis or target-level validation. The cocotb tests prove
  elaboration and basic behavior, not BRAM inference.
- Repeated same-direction DATA loss without an intervening clean ACK/drain
  interval remains a future characterization item if that behavior becomes part
  of the hardware contract.
