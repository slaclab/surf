# RX message/capture boundary

Status: selected architecture, executable boundary model, and an
[RX RTL proof](rx-rtl-proof.md) covering physical normalization and real-MAC
loss. Endpoint consumer integration, timing closure, and hardware validation
remain open.
This replaces the rejected RX key join in the [main plan](README.md). The
[Phase 0 experiments](phase-0-experiments.md) remain the regression evidence
for rejecting that join, not evidence that this replacement RTL already works.

## Decision and alternatives

Use a passive PTP RX frontend at the MAC/PCS bus. Bind the capture to the frame
at its first destination-MAC byte, retain it while validating the entire frame,
and publish a single decoded-message/capture record only after FCS and frame
validation. Drain the MAC's redundant PTP bypass output unconditionally.

| Alternative | Identity guarantee | Cost and decision |
| --- | --- | --- |
| Metadata through an opt-in receive MAC | Capture and frame remain one transaction only if every importer, pipeline, filter, FIFO, and reset carries or discards both. | Viable, but changes several existing MAC boundaries or creates maintained siblings. Prefer for a future general timestamp API. |
| Passive validated RX frontend | The producer owns frame bytes and capture before the first lossy queue. No later packet lookup exists. | Selected. Duplicates FCS/framing validation, but confines new logic to PtpCore and preserves the public MAC. |
| Header key plus aggregate drop flush | No complete frame-local loss identity; CRC rejection and retained FIFO data break the join. | Rejected by the real-MAC counterexamples. More table entries or key bits do not repair it. |

Inspection supports the boundary choice: `EthMacRxImport` exposes AXI packets
and aggregate status, without frame-local capture metadata; its GMII/XGMII
leaves perform physical import and CRC. `EthMacRx` then passes traffic through
additional processing before `EthMacRxFifo`. Existing `TUSER` fields already
have SOF/error meanings. Adding a parallel FIFO at any one of those boundaries
would require proving identical admission, loss, and reset behavior again.

## Ownership and interfaces

`EthMacPtpEndpoint` instantiates the unchanged `EthMacTop`, one selected
`Ptp[Gmii|Xgmii]TimestampTap`, `PtpRxFrontend`, and `PtpEndpoint`.

The target combined physical adapter retains the TimestampTap name with an RX
framing output. RX and TX have separate state. RX removes preamble/control
symbols and produces ordered destination-MAC-through-FCS bytes together with
the capture on SOF; TX still produces keyed wire-completion events. Both use
the PHC message point and signed latency conventions in the main plan.
The current RX-only proof uses `PtpRxTimestampAdapter` with `PHY_TYPE_G`; it
does not implement TX completion or the combined tap composition yet.

| Boundary | Contract |
| --- | --- |
| Adapter → RX frontend | Existing `AxiStreamMasterType`, eight-byte configuration, contiguous low-byte `TKEEP`, SSI SOF/EOFE and `TLAST`, plus a capture sidecar meaningful on SOF. No `TREADY`: every valid beat is consumed. GMII uses one valid byte; XGMII uses up to eight. The final beat may have zero data bytes when termination follows a full word. No independent capture queue. |
| SOF capture | Q16 timestamp, unsteered tick counter plus three-bit byte phase, time/configuration generation, and PHC time-valid status sampled from the same physical frame. A false time-valid status is retained for acquisition; it does not discard otherwise usable Sync observations. |
| RX frontend → port | One `PtpRxMessageType` valid/ready channel for **all four** supported RX types: Sync, Follow_Up, Delay_Resp, Announce. Includes the SOF capture, RX epoch, header fields, and fixed decoded body. No raw RX packet port or separate RX timestamp port on `PtpEndpoint`. |
| MAC bypass RX → wrapper | Always-ready drain, including through logical PTP restart. These packets never reach protocol state. MAC CRC/FIFO status remains diagnostic and cannot invalidate or select frontend records. |
| Port → MAC / TX tap → port | Existing proposed Delay_Req AXI builder and keyed TX completion interfaces. R6 key reservation and wire-fate rules still apply. |

The unsteered capture includes a three-bit phase in eighths of a cycle. GMII
uses phase zero; XGMII normalizes `(startLane + 8)` byte times into whole ticks
and a remainder. Both RX and TX must retain it. Subtract complete tick/phase
coordinates when reconstructing elapsed master time; a lane-4 RX followed by
a lane-0 TX otherwise biases delay by 1.6 ns at nominal 10 Gb/s. The new test
proves this with exact rational arithmetic. R5's fixed-point implementation
must include the extra three fractional bits in its multiply/rounding budget;
its earlier integer-tick vectors did not cover this case.

The sidecar and SOF beat must have identical pipeline enables/reset behavior.
There is no independently stallable interface between adapter and validator.
This is the remaining physical producer proof; the boundary model assumes it
and therefore cannot certify the adapter. At XGMII line rate, normalization and
CRC must sustain eight bytes each cycle, including consecutive short frames.
Reuse SURF CRC helpers where applicable; do not insert an unbounded or lossy
byte serializer in the physical path.

## Validation before admission

The adapter rejects invalid preamble/SFD, illegal XGMII start lanes/control
sequences, and GMII error indication, and reports any in-frame error through
EOFE. A physical error is sticky until termination. Missing termination cannot
grow storage: byte counters saturate and the frame remains rejected until
resynchronization. A nested SOF invalidates the partial frame and the nested
candidate; recovery is permitted at a subsequent clean SOF.

The frontend owns these structural checks:

- Complete frame length of 64–1518 bytes, destination MAC through FCS.
  Jumbo and tagged PTP are outside this first contract.
- Ethernet FCS across the complete frame, including legal padding. Nothing is
  queued before the final CRC result and framing status are known.
- Outer EtherType `88 F7`, major version 2, minor version 0 or 1, and a supported
  RX message type. The byte-order convention remains distinct from `x"F788"`
  in the MAC bypass generic.
- `messageLength` covers the fixed body (44/44/54/64 bytes respectively), fits
  the received frame, and is at most 1500. Padding beyond that length is
  excluded from PTP decode, but included in CRC.
- Optional TLVs walk exactly to `messageLength`; reject partial headers and
  values extending beyond it. Structurally valid unknown TLVs are skipped.
  Profile-specific TLV semantics and conformance fixtures remain a parser
  qualification task; the model checks boundary lengths, not full IEEE conformance.

`PtpPort` still owns configured destination/source/domain/transport-specific
policy, flag legality, valid nanoseconds, requesting-port identity, Announce
semantics, timeouts, and Sync/Follow_Up transaction matching. Keep structural
parsing and mutable protocol policy separate. Configuration changes abort all
in-flight frontend work through the common generation contract, including a
frame that began before the change and terminates afterward.

The wire key identifies a protocol exchange, not a physical frame. Two valid
same-key Sync copies produce two internally consistent records. Protocol
duplicate/replay policy must still prevent reusing completed exchange keys and
reject conflicting live content; this design does not prove which of two
conflicting, CRC-valid Follow_Up messages a sender intended. No oracle wire ID
is carried in the interface or used by the reference model.

## Bounded storage and same-edge behavior

The reference validator keeps at most 78 prefix bytes (Ethernet header plus
Announce's fixed body), four trailing FCS bytes, a CRC accumulator, saturating
length counters, up to three TLV-header bytes, a TLV remaining-length counter,
and one SOF capture. It streams past arbitrary supported TLV values without
buffering the frame. This storage bound holds even when termination never
arrives. A typed RTL implementation may decode fields directly instead of
retaining the prefix.

Default output depth is four, configurable at elaboration. A record includes
the 108-bit message key, 96-bit timestamp, 64-bit unsteered ticks plus three-bit byte phase, provisional
32-bit time generation and RX epoch, time-valid, destination MAC, minor
version/transport-specific, message length, flags, signed 64-bit correction,
control, signed log interval, and up to 240 body bits. That is 744 bits with
those provisional generation widths: four entries require 2,976 data bits,
before FIFO implementation overhead. This is a logical storage budget, not a
synthesized LUT/FF/BRAM estimate. Finite generation widths remain part of R4.

Normal transfer is `valid && ready && !rxAbort`. A stalled head and all its
fields remain stable until transfer or explicit abort. `rxAbort` is a
same-clock transaction invalidation signal, not ordinary ready/valid behavior;
every consumer must qualify transfer and next-state updates with it.

Priority on an edge is:

1. System/port/link restart or a changed time/configuration generation clears
   partial decode and the complete queue, advances the RX epoch, asserts
   `rxAbort`, and suppresses same-edge SOF, completion, and consumption.
2. A valid completion encountering a queue that was full **before the edge**
   discards the completion and entire queue, advances only the RX epoch,
   increments overflow status, and asserts `rxAbort`. This wins even if ready
   was high. The next clean frame can be admitted in the new RX epoch.
3. Otherwise consume the old head if ready, then enqueue a valid completion.
   A newly enqueued item does not fall through on its arrival edge.

CRC, malformed, and unsupported frames do not enqueue and do not cause queue
overflow even when the queue is full. Ordinary packet loss need not flush
other internally consistent records. Queue overflow is deliberately more
conservative: the port invalidates live RX-derived transactions and pending
measurements on `rxAbort`; committed past measurements remain past history.
It neither resets the PHC nor releases unresolved TX wire keys. Do not change
the global PHC generation just because RX capacity was exhausted.

RTL may pipeline final validation. If so, its completion, capture, generation,
and abort state must travel together; tests must cover flush at every stage.
The model's completion edge is a functional boundary, not a pipeline latency
promise. Independent resets/CDC require coordinated abort acknowledgement
before admitting new work; no CDC is present in this first common-clock boundary.

## Evidence and next steps

[The executable model](../../../tests/ethernet/PtpCore/ptp_rx_reference.py)
consumes normalized wire bytes and computes CRC using an independent bitwise
oracle; [the tests](../../../tests/ethernet/PtpCore/test_ptp_rx_reference.py)
encode FCS with zlib. The 25 tests pass CRC-bad/valid duplicates, distinct
same-key captures, retained-head restart, mid-frame/EOF reset, stale generation,
overflow simultaneous with consumption, 1/8-byte groups, signed correction,
all final-byte positions, empty termination, sub-cycle unsteered provenance,
four message types, malformed lengths/TLVs, maximum
frame length, bounded unterminated input, and 400 randomized frames with stalls
and restart. Combined with the existing arithmetic/PHC suite: 60 tests passed.
Flake8 and documentation/whitespace checks also passed.

R3 now has a selected, modeled replacement and an implemented physical RX
slice. Its [verification record](rx-rtl-proof.md) covers comparison with this
model and the original real-MAC loss stimuli. Remaining work includes abort
priority in the future protocol consumer and FPGA resource/timing bounds.
The rejected-join tests remain counterexample regressions.

In parallel work packages, R4 still needs the integrated reset/generation
contract, R5 rate-estimator qualification under delay variation, and R6 the
TX drain/quarantine lifecycle. In particular, primary TX traffic must not be
allowed to emit a Delay_Req with the endpoint's reserved wire identity; either
document exclusive ownership as an integration precondition or enforce it in
an opt-in classifier. The RX redesign does not solve that TX spoof/alias case.
