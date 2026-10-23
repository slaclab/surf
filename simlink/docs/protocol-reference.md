# SimLink Protocol Reference

This document is the canonical port, socket, and wire-contract reference for
the Stream, Memory, and SideBand links. Users should normally connect through
the production endpoints in the [Rogue client guide](rogue-clients.md) rather
than constructing ZeroMQ messages directly.

All integer fields are copied in host byte order, matching the established
Rogue TCP simulation protocol. The current supported environments are
little-endian. Changing byte order or multipart framing is a wire-protocol
change, not an adapter refactor.

## Port and socket directions

The SimLink side binds both sockets to loopback. “Software sends” and
“software receives” below are from the Rogue process's point of view.

| Link | Base port `N` | Port `N+1` |
| --- | --- | --- |
| Stream | SimLink PULL; software sends frames to HDL | SimLink PUSH; software receives frames from HDL |
| Memory | SimLink PULL; software sends requests | SimLink PUSH; software receives completions |
| SideBand | SimLink PUSH; software receives HDL events/state | SimLink PULL; software sends events/state to HDL |

Use base ports from 1024 through 49151 when using the SURF wrappers. Reserve
both `N` and `N+1`, including between different model types. The common
registry rejects zero, `65535`, changed ports, and overlap between complete
live pairs consistently for GHDL, VCS, and xsim before ZeroMQ bind.

## Stream wire contract

A frame is one four-part ZeroMQ multipart message:

| Part | Size | Meaning |
| --- | ---: | --- |
| flags | 2 bytes | Low byte is first-user; high byte is last-user |
| channel | 1 byte | Wire channel; currently transmitted as zero by the leaf |
| error | 1 byte | SSI end-of-frame error indication |
| payload | variable | Frame bytes in AXI lane order; maximum is 20,000,000 bytes |

Only lanes selected by `TKEEP` become payload bytes. `TLAST` completes an
HDL-to-software message. In SSI mode, first/last `TUSER` information is mapped
to `flags`, and EOFE is mapped to `error`. The wrapper owns `TDEST` routing and
resizing; the scalar leaf does not transport `TID` and transmits channel zero.
AXI Stream backpressure is honored at the VHDL boundary.

The Stream leaf supports 1 through 128 data bytes per simulation beat. Beat
width changes AXI transfer granularity only; it does not change the multipart
message or payload byte order.

## Memory wire contract

Requests contain four frames for Read/Verify/probe and five for Write/Post:

| Part | Size | Meaning |
| --- | ---: | --- |
| id | 4 bytes | Transaction identifier |
| address | 8 bytes | Byte address |
| size | 4 bytes | Transfer size in bytes |
| type | 4 bytes | Read `1`, Write `2`, Post `3`, Verify `4`, probe `0xFFFFFFFE` |
| data | `size` bytes | Present for Write and Post |

Every SimLink completion has six frames: the same id, address, size, and type,
followed by `size` data bytes and a result frame. Ordinary transactions keep
the historical four-byte numeric AXI response. Current Rogue accepts numeric
zero as success in practice; nonzero values represent AXI errors.

The internal readiness probe is different: it must have size zero, never
reaches AXI-Lite, and receives the two ASCII bytes `OK`, as required by Rogue's
`TcpClient.waitReady()`.

Transactions other than the probe must have a nonzero, 32-bit-word-aligned
size within the model maximum. The current FSM issues one 32-bit AXI-Lite
access at a time and preserves the first non-OKAY `RRESP` or `BRESP` across a
multiword transaction.

SimLink preserves its historical six-frame completion for Post. Rogue
completes Post locally and does not retain its transaction ID, so it discards
that response; the real-Rogue contract proves a subsequent tracked Read still
completes and observes the posted value.

## SideBand wire contract

SideBand uses one four-byte message:

| Byte | Meaning |
| ---: | --- |
| 0 | Opcode-valid flag |
| 1 | Opcode value |
| 2 | Remote-data-changed flag |
| 3 | Remote-data value |

An opcode is a one-cycle event at the receiving HDL interface. Remote data is
state: it retains the most recently received value. The transmit core clears
both change flags after every send so a later independent event cannot inherit
stale qualifiers; native coverage pins this isolation behavior.

## Compatibility invariants

Preserve these unless making a separately reviewed protocol change:

- public `Rogue*Wrap` ports and generics, plus backend leaf entity names;
- two adjacent TCP ports per live instance and existing socket directions;
- multipart frame order, field sizes, host byte order, and transaction ids;
- Stream byte-lane order, `TKEEP`, `TLAST`, SSI SOF/EOF/EOFE mapping, and
  wrapper `TDEST` routing;
- Memory request ordering, 32-bit AXI-Lite accesses, numeric ordinary results,
  and ASCII `OK` only for the readiness probe;
- one-cycle received opcode events and retained remote-data state; and
- reset clearing model-visible transaction state before sockets are started.

The deterministic peer and codec helpers under `tests/simlink/common/` are the
executable protocol oracle. The [test matrix](../../tests/simlink/README.md)
identifies which invariants also have simulator and real-Rogue coverage.
