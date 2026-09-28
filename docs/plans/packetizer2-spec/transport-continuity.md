# Packetizer2 transport continuity and frame abandonment

Status: source review, 2026-09-28. SURF documentation HEAD is `c76a32dde`;
the inspected RTL remains identical to base `5520beec2` in the relevant
packetizer, PGP4 and RSSI directories. Rogue is at
`cf356dc277b13fcd4821e6dc78156c7a33090813`. No behavioral change or new
simulation result is implied. See the [work record](README.md),
[findings](findings.md), and [cleanup history](link-recovery-history.md).

## Interpretation

A transport becoming temporarily unavailable does not inherently invalidate
an application frame. An ordered, reliable transport can retain and replay
packets while the packetizer's receive context remains valid. The relevant
question is whether the integration preserves delivery continuity across the
event, including any packet partly delivered to the depacketizer.

The current bindings use stronger events than ordinary backpressure or an
RSSI retransmission. RSSI connection closure resets queues and retransmission
state. PGP4 receive link loss starts reacquisition and requests PHY reset.
These implementations cannot promise preservation of all incomplete frames.
Aborting every open destination is a conservative policy under that uncertainty;
it does not establish that every such frame actually lost a packet.

| Event in the reviewed integration | Effect on continuity | Depacketizer2 consequence |
| --- | --- | --- |
| RSSI loss recovered by retries while the connection stays open | Ordered delivery and retransmission state remain available | Connection status stays high; no link-driven sweep |
| RSSI connection closes | Application-side buffers reset; transmit window is cleared | Registered connection status drives `linkGood` low; abandon open receive frames |
| PGP4 remote receive readiness or per-VC pause stalls TX | Some unsent data can remain buffered | This TX flow-control condition alone is not the local RX `linkGood` input |
| PGP4 local receive link readiness falls | RX requests PHY reinitialization and ignores packet data during acquisition; no replay path was found in the reviewed core | Local RX readiness drives `linkGood` low; abandon open receive frames |

## Unexpected SOF is discarded by both receivers

In [RTL](../../../protocols/packetizer/rtl/AxiStreamDepacketizer2.vhd),
`HEADER_S` checks `sof = not ramPacketActiveOut`, sequence, version and CRC
mode before entering `MOVE_S`. Rejection clears destination tracking and
may emit an EOFE termination. The already-consumed header is not retried.
The rest of that transport packet is discarded while seeking another header.

In [Rogue ControllerV2](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/src/rogue/protocols/packetizer/ControllerV2.cpp),
the combined SOF/sequence/CRC mismatch branch clears the partial frame, resets
expected SOF and sequence, and returns before first-frame assembly.

For otherwise valid packets and an active destination, the source-level trace is:

1. Frame A is incomplete.
2. Frame B's first packet arrives with SOF=1 and sequence=0.
3. A is abandoned and B's first packet is discarded.
4. B's continuation packets cannot start a frame and are also rejected.
5. Frame C's valid beginning can start reception again.

This applies when RTL is parsing a header; a new transport SOF arriving during
`MOVE_S` is a separate malformed-packet case. The trace above has not been
added as a regression in this effort. Neither source branch explains whether
discarding B was a deliberate protocol choice or implementation convenience.
Accepting B after abandoning A remains an open compatibility decision (F11).

## RSSI evidence

The V2 binding exists when `APP_ILEAVE_EN_G=true` and chunking is not bypassed.
[RssiCoreWrapper](../../../protocols/rssi/v1/rtl/RssiCoreWrapper.vhd) registers
`statusReg(0)` into `rssiConnected` and connects that to RX `linkGood`.
[RssiMonitor](../../../protocols/rssi/v1/rtl/RssiMonitor.vhd) constructs bit zero
from `connActive_i`. It separately requests retries and closes the connection
for exhausted retries, keepalive timeout, ACK error or length error.
[RssiConnFsm](../../../protocols/rssi/v1/rtl/RssiConnFsm.vhd) also processes
received RST and explicit close requests. Thus a network interruption can be
recovered without invoking packetizer cleanup if the RSSI session stays open.

An actual connection close is destructive to continuity:

- [RssiCore](../../../protocols/rssi/v1/rtl/RssiCore.vhd) sets
  `s_rstFifo <= rst_i or not s_connActive`. This resets the application ingress
  resizer and both sides of the application receive output FIFO. That receive
  FIFO feeds the depacketizer, so a tail or other buffered packet data can be
  lost even after earlier beats have reached the depacketizer.
- [RssiTxFsm](../../../protocols/rssi/v1/rtl/RssiTxFsm.vhd) clears transmit-window
  bookkeeping and application state while `connActive_i=0`. Old unacknowledged
  segments are not retained for replay into a new connection.
- [RssiRxFsm](../../../protocols/rssi/v1/rtl/RssiRxFsm.vhd) initializes its receive
  window for a new SYN while disconnected. A reopened connection does not
  continue the previous RSSI sequence context.

This is not a claim that every buffer resets together: the transport output
FIFO uses `rst_i`, for example. Exact ordering around close/reopen, buffered
old traffic and stalls still needs integrated characterization.

The wrapper resets its TX Packetizer2 with `rst_i`, not connection status.
Receive abandonment therefore does not also restart the sender's application
frame. The sender can still be working through the old frame after reconnect;
clean recovery must account for continuations and eventual new beginnings.

Rogue has a related asymmetry. Its
[RSSI controller](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/src/rogue/protocols/rssi/Controller.cpp)
`stateError()` sends RST with transmit-list reset, then clears the application,
out-of-order and state queues. The reviewed
[network wrapper](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/python/pyrogue/protocols/_Network.py)
connects RSSI to Packetizer2 without a corresponding receive-context reset
notification. The packetizer can retain an incomplete assembly until later
traffic rejects it or the object is replaced. That can expose the extra-frame
loss described above; it is a source-based consequence to reproduce, not a
newly observed integration-test failure.

## PGP4 evidence

[Pgp4Rx](../../../protocols/pgp/pgp4/core/rtl/Pgp4Rx.vhd) connects
`locRxLinkReadyInt` to depacketizer `linkGood`.
[Pgp4RxProtocol](../../../protocols/pgp/pgp4/core/rtl/Pgp4RxProtocol.vhd) asserts
`protRxPhyInit` on a linked-to-unlinked transition. While unlinked it counts
valid control headers for acquisition and does not translate packet data into
the depacketizer stream. The
[GTY UltraScale+ wrapper](../../../protocols/pgp/pgp4/gtyUs+/rtl/Pgp4GtyUs.vhd)
connects this PHY-init path to the transceiver's `rxReset`.

Errors can remove data before depacketization:
[Pgp4RxKCodeChecker](../../../protocols/pgp/pgp4/core/rtl/Pgp4RxKCodeChecker.vhd)
suppresses a control word with a bad control CRC and asserts `linkError`, with
a subsequent holdoff cycle. Losing a control word may lose the packet tail or
its destination/framing information. The receive core has no mechanism in
this inspected path to recover the missing word by retransmission.

The user's observation about pending data nevertheless applies.
[Pgp4TxProtocol](../../../protocols/pgp/pgp4/core/rtl/Pgp4TxProtocol.vhd) gates
data transmission on readiness, so unsent words can remain upstream.
[Pgp4Tx](../../../protocols/pgp/pgp4/core/rtl/Pgp4Tx.vhd) does not reset its
Packetizer2 from receive-link readiness. An outage need not damage every open
VC. The current policy abandons all of them because the RX path cannot promise
which survived; it trades potentially salvageable frames for explicit closure.
Preserving selected contexts would need its own transport and parser contract.

## Why packet errors are not a complete substitute

Normal error handling can provide eventual recovery when subsequent traffic
exposes the problem. It does not provide all guarantees of explicit abandonment:

- A quiet destination may never receive another packet, leaving its application
  frame open indefinitely. A CRC check cannot run without the remaining bytes.
- In RTL `MOVE_S`, transport `TLAST` identifies the tail; a new transport SOF
  does not independently restart header parsing. If the tail disappears, the
  next packet's header can be consumed as payload instead of checked for a
  sequence mismatch. A later tail/CRC error may recover, but that is a different
  contract from immediately rejecting the next header.
- At a proper packet boundary, current unexpected-SOF handling can sacrifice
  the first otherwise valid new frame in addition to the incomplete old one.

Conversely, clearing context while a transport still guarantees ordered,
complete delivery would unnecessarily discard valid continuations. The decision
to preserve or abandon must belong to the integration, with a defined boundary
between pre-event buffered data and subsequent delivery. `linkGood` currently
combines availability and that abandonment decision in one interface.

## Specification treatment and evidence limits

Describe wire validity and ordinary receive-state transitions in the protocol
body. Describe abandonment as an endpoint event: retire affected contexts and
provide the endpoint's defined error/completion outcome for already-exposed
frames. Name the triggering event and delivery boundary in each transport
binding. Keep the RTL pin, sweep, RAM latency and completion indication in the
implementation mapping. No new wire flag, generic or abort port is selected.

Existing leaf depacketizer tests establish expectations after `linkGood` falls;
they do not establish when a real transport ought to lower it. The inspected
[RSSI core tests](../../../tests/protocols/rssi/test_RssiCore.py) include retry
exhaustion and close/reopen with complete application packets, but do not prove
V2 multi-destination assembly across a mid-frame reconnect. V2 wrapper tests
are separately gated as recorded in the [coverage inventory](findings.md#coverage-inventory).
The inspected PGP4 protocol and CRC tests do not settle preservation versus
abandonment of multiple open application frames across acquisition.

Useful characterization cases are a recoverable RSSI outage that keeps the
session open, actual close/reopen during a fragment, PGP4 loss between and
inside packets, silent open destinations, stalled output, and an immediate new
SOF after an incomplete frame. Preserve current behavior until these endpoint
and binding decisions are explicit. Source inspection supports the distinctions
above; no simulation, synthesis or Rogue integration tests were run here.
