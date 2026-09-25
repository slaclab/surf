# RSSI

This directory contains the Reliable SLAC Streaming Interface implementation.
Most firmware applications should instantiate `v1/rtl/RssiCoreWrapper.vhd`
rather than `RssiCore.vhd` directly.

`RssiCoreWrapper` adds the user-facing AXI Stream mux/demux and optional
packetizer/depacketizer layer around `RssiCore`. `RssiCore` is still useful for
focused protocol integration tests or custom wrappers that already own stream
chunking and routing.

## Keepalive Compatibility Contract

This section records the SURF/Rogue implementation compatibility contract for
an established connection with retransmission/keepalive enabled. The historical
[SLAC RSSI page](https://confluence.slac.stanford.edu/x/1IyfD) and its attached
Word document are useful protocol references, but archived versions contain
DATA/NULL-only timeout wording that does not describe deployed ACK keepalive
behavior. The live page still needs reconciliation. This is a
maintained statement of that behavior, not a claim that those references have
been updated or that a complete reconciled RSSI specification exists.

- **Client NULL generation:** NULLs supply keepalive traffic when the client
  is transmit-idle. The RTL client and Rogue v6.15.0 postpone NULL transmission
  when they transmit ACKs, as well as DATA or NULL segments. The idle interval
  is nominally one third of the negotiated NULL timeout. Receipt of server
  DATA alone is not the timer refresh; transmitting its ACK is.
- **Server receive liveness:** accepted DATA, NULL, ACK, or BUSY-bearing traffic
  refreshes the server's NULL timeout. This includes pure ACKs and ACKs with
  BUSY set. Continuous server-to-client streaming can therefore remain open
  with only ACKs in the reverse direction and no client DATA/NULL segments.
- **Validation and silence:** only traffic accepted by the receiver
  (`rxValid_i`) qualifies. Stale flag values and rejected frames do not refresh
  liveness. The server closes the connection when qualifying traffic stops for
  the negotiated timeout, even if its transmit window has already drained.
- **Separate mechanisms:** a pure ACK does not consume a DATA sequence number.
  Sequence advancement is not required to demonstrate receive liveness. BUSY
  flow control, periodic BUSY ACKs, and retransmission accounting have their
  own rules; this keepalive correction does not change them. DATA+BUSY legality
  is a separate receive-validation question.

ACK/BUSY timeout refresh was explicitly added in
[2016](https://github.com/slaclab/surf/commit/b768834bd43c47fc32765de980fe54b3c505a701).
[PR #1454](https://github.com/slaclab/surf/pull/1454) removed it while adding
periodic BUSY ACK handling. The removal shipped in v2.74.0 and remains in
v2.75.0; this branch restores keepalive compatibility while retaining the
periodic BUSY ACK changes. Rogue's
[`transportTx()`](https://github.com/slaclab/rogue/blob/e30812114e7e6c338d8ab204d2ec2f61aa1527e8/src/rogue/protocols/rssi/Controller.cpp#L590-L619)
updates the last-transmit timestamp for ACKs, and
[`stateOpen()`](https://github.com/slaclab/rogue/blob/e30812114e7e6c338d8ab204d2ec2f61aa1527e8/src/rogue/protocols/rssi/Controller.cpp#L914-L934)
uses that timestamp to decide when to send NULLs. The RTL client implements the
corresponding ACK-sensitive idle counter in `RssiMonitor`.

`test_RssiMonitor.py` checks individual timer inputs and invalid flags.
`test_RssiCoreKeepalive.py` checks the complete server core against an
independent Python wire peer, including payload delivery with ACK-only replies
for several timeout periods followed by silence and timeout. Neither runs the
Rogue implementation or Ethernet. Sustained server-to-host acceptance through
the deployed Rogue, Ethernet and FPGA image remains necessary; see the
[test guide](../../tests/protocols/rssi/README.md#keepalive-compatibility-regression).

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

## DATA And BUSY

DATA carries payload and an ACK. SYN, EACK, RST, and NULL are clear; BUSY may
be set. BUSY reports the sender's receive-side backpressure independently of
its outgoing payload. This matches the clarification to the
[RSSI specification](https://confluence.slac.stanford.edu/spaces/ppareg/pages/211782868/Reliable+SLAC+Streaming+Protocol+RSSI)
and the existing SURF header generator and Rogue transmitter.

A duplicate of the most recently accepted DATA segment does not rewrite the
receive buffer or produce another application frame. Its ACK is still reported
when the header, ACK window, and payload termination pass validation. This
allows acknowledgment progress for traffic in the opposite direction.

## Application Frames Across Reconnect

With packetizer V2 enabled, `RssiCoreWrapper` passes connection state to the
depacketizer's `linkGood` input. Link loss must terminate open application frames
with EOF+EOFE before accepting new frames for those destinations. It does not
globally reset an attached SRP bridge or cancel AXI transactions already issued.

The termination sweep must read a destination's active-frame flag before
clearing that same RAM entry. Its output pipeline must consume each pending
beat exactly once under backpressure. Otherwise an attached `SsiFrameLimiter`
can retain an unterminated frame and consume the first post-reconnect SOF as
that old frame's error ending, losing the new request.

The local recovery correction on `fix/rssi-rx-keepalive-integration` addresses
both the sweep RAM address and pending-beat ownership. Firmware built before
that correction can lose the first request after a congested disconnect.
Queued responses from the old connection may still emerge; reconnect is not
a global application flush. See the [recovery tests](../../tests/protocols/rssi/README.md)
and [integration handoff](../../docs/plans/rssi-rx-keepalive/README.md) for the
tested boundary and remaining hardware acceptance.

## Regression Coverage

Run the default suite with:

```sh
make MODULES="$PWD" import
.venv/bin/pytest -q tests/protocols/rssi
```

Default coverage includes the checksum and header generator, RX and TX FSMs,
monitor, connection FSM, and the focused core-RX and keepalive entries below.
AXI-Lite and broad core/wrapper regressions remain gated by
`RUN_RSSI_KNOWN_ISSUE_TESTS=1`.
Their presence in the tree does not mean they pass by default.

- `test_RssiRxFsm.py` uses the production synchronous payload RAM. It checks
  DATA+BUSY with one-word, two-word and full-buffer payloads and partial final
  `TKEEP`; duplicate ACK validation without RAM writes or second delivery;
  a wrapped, occupied receive window; malformed duplicate rejection; closure
  before the first beat, mid-frame, before the final beat and at completion;
  and the actual PyRogue application-state map. A separate case connects the
  real checksum block for standalone and contiguous SYN/DATA traffic and
  malformed-SYN recovery. Checksum-disabled behavior has its own entry.
- `test_RssiConnFsm.py::test_RssiConnFsm_timeout` checks bounded retries and
  timeout closure in both client and server modes. The full connection suite
  also runs by default, including parameter negotiation and rejection.
- `test_RssiCoreKeepalive.py` exercises the production server core with an
  independent ACK-only peer for four negotiated NULL timeout periods, checking
  every DATA payload and continuous connection before verifying that peer
  silence closes it. The monitor unit tests independently cover valid
  DATA/NULL/ACK/BUSY liveness and invalid-traffic rejection.
- `test_RssiCoreRx.py` checks real client/server negotiation and drives an
  independent Python wire peer into a server core. The latter exercises the
  real checksum, payload RAM and application FIFO through DATA+BUSY,
  duplicate suppression, sequence wrap, and close/reopen with unread data.
  Unexpected application output is an error; the test does not drain it away.

Broader core and wrapper regressions remain opt-in. A passing default run does
not establish complete retransmission, backpressure, or wrapper integration
coverage.

Simulation does not establish FPGA resource use or timing closure. In
particular, compare synthesis/timing reports for representative window and
segment sizes before treating this critical-path review as complete.

Hardware acceptance of the combined RX and keepalive fixes remains pending.
See the [integration handoff](../../docs/plans/rssi-rx-keepalive/README.md)
for the exact source baseline, validation and bench comparison.
