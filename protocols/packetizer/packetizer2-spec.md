# Packetizer2 working specification

Status: initial draft, 2026-09-25. This document records behavior found in
the current implementations. It is not yet a complete conformance standard.
Open questions and suspected defects are tracked in the
[findings ledger](../../docs/plans/packetizer2-spec/findings.md).

The scope is `AxiStreamPacketizer2`, `AxiStreamDepacketizer2`, and Rogue
Packetizer V2. The legacy packetizer and depacketizer are outside this work.
PGP3/PGP4 are included as consumers of the V2 RTL and as distinct wire protocols.

## Evidence and interpretation

The initial source baseline is:

| Source | Revision | Relevant implementation |
| --- | --- | --- |
| SURF | `5520beec22698f4ee07b7bd613089abb5c2e2482` | [Package](rtl/AxiStreamPacketizer2Pkg.vhd), [transmitter](rtl/AxiStreamPacketizer2.vhd), [receiver](rtl/AxiStreamDepacketizer2.vhd) |
| Rogue | `cf356dc277b13fcd4821e6dc78156c7a33090813` | [ControllerV2.cpp](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/src/rogue/protocols/packetizer/ControllerV2.cpp), [Controller.cpp](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/src/rogue/protocols/packetizer/Controller.cpp) |

SURF links refer to this checkout; compare with the baseline revision when
implementation changes begin. Rogue links pin the inspected revision.
The RTL headers also reference a
[historical protocol page](https://confluence.slac.stanford.edu/x/3nh4DQ).
That page could not be retrieved during the initial review and has not been
reconciled with this draft.

Evidence is classified as follows:

- **Observed:** established by reading an implementation; not necessarily a
  requirement to preserve every incidental value or cycle.
- **Tested expectation:** asserted by a named checked-in test. This does not
  imply the test was executed during this documentation effort.
- **Compatibility decision:** a requirement agreed for supported peers and
  configurations. The initial review has not settled the open decisions.
- **Suspected defect:** behavior that appears inconsistent or incorrect and
  needs a focused reproducer before correction.

Unless stated otherwise, the following sections describe observed behavior.
Legal-input requirements and malformed-input responses still need review.

## Terminology and boundaries

A **frame** is one application transfer ending at application `TLAST` in RTL
or one Rogue application `Frame`. A **packet** is one transport fragment,
containing a header, payload words, and tail. One application frame can span
multiple packets. Different destinations can have simultaneously open frames.

Application EOF and transport end-of-packet are different events. On the RTL
transport interface, every tail has `TLAST=1`; its in-band EOF flag determines
whether the application frame ends. Likewise, every packet header carries a
transport SSI SOF marker, while the header's in-band SOF flag identifies the
first packet of an application frame.

The core RTL operates on 64-bit words. Surrounding stream resize/packing
blocks are outside this protocol boundary. An AXI transfer occurs at a rising
clock edge with both valid and ready asserted. Stalled output must retain
valid and all associated fields; the newer recovery tests check this directly.
Exact latency and throughput promises are still to be characterized by profile.

## Wire representation

Packet words are serialized least-significant byte first. Header and tail bit
numbers below are relative to their respective 64-bit words. The CRC field has
an additional byte-order rule described in [CRC processing](#crc-processing).

### Header

| Bits | Field | Encoding |
| --- | --- | --- |
| 3:0 | Version | `0x2` |
| 7:4 | CRC mode | `0=NONE`, `1=DATA`, `2=FULL` |
| 15:8 | First user | Eight user bits captured at the packet boundary |
| 23:16 | Destination | Eight-bit wire field; RTL can implement fewer destination bits |
| 31:24 | ID | Eight-bit wire field |
| 47:32 | Sequence | Sixteen-bit wire field; RTL can use a reduced counter |
| 62:48 | Reserved | Zero from the current constructors |
| 63 | SOF | First packet of an application frame |

### Tail

| Bits | Field | Encoding |
| --- | --- | --- |
| 7:0 | Last user | Eight user bits associated with the last payload byte |
| 8 | EOF | Final packet of an application frame |
| 15:9 | Reserved | Zero from the current constructors |
| 19:16 | Last byte count | Number of application bytes in the final payload word |
| 31:20 | Reserved | Zero from the current constructors |
| 63:32 | CRC | Zero in NONE; encoded CRC in DATA/FULL |

Ordinary generated payload words contain 1 through 8 valid bytes on the final
application beat; count 8 represents a full word. A minimal nonempty packet
has three words, totaling 24 transport bytes. Rogue explicitly rejects input
packets shorter than 24 bytes or not aligned to eight bytes. The RTL receiver
does not implement equivalent length validation. Empty frames, count zero,
counts above eight, sparse keep masks, and nonzero reserved bits are unresolved
input cases, not established supported encodings.

The RTL transmitter forces transport `TKEEP=0xFF` and clears payload `TUSER`.
Partial application words still travel as complete transport words, with the
valid byte count in the tail. Bytes outside application `TKEEP` are not required
by the current transmitter to be zero. Header/tail constructors set transport
destination and ID to zero; `OUTPUT_TDEST_G` and `OUTPUT_TID_G` currently apply
only to payload beats. See finding F04 before treating that as desired routing.

## Transmit behavior and frame state

For each implemented destination, the RTL stores an active-frame flag, the next
packet sequence, and the CRC remainder. A packet starting for an inactive
destination has SOF set and sequence zero. Each completed nonfinal packet
advances the sequence modulo the configured counter width. EOF clears the
active flag and resets the next sequence to zero. Unused upper wire sequence
bits are zero on transmit.

A destination change closes the current packet without accepting the new
destination's beat as payload. The subsequent header selects that destination's
stored context. A size boundary also closes the packet without ending the
application frame. The normal application `TLAST` path generates EOF and
captures the final byte count and last user field. An input SSI SOF bit does
not itself restart the transmitter's destination context.

### Packet size selection

`MAX_PACKET_BYTES_G` is a compile-time ceiling and `maxPktBytes` is a runtime
limit. The runtime input is truncated to a multiple of eight and capped by the
compile-time ceiling. The selected payload limit is captured while preparing
each header. For normal limits of at least 32 bytes, the maximum payload per
packet is the selected transport limit minus the 16-byte header/tail overhead.

The current admission check requires the runtime limit to contain more than
three words. Thus a runtime limit of 24 bytes stalls admission, although a
one-payload-word packet itself occupies 24 bytes. The generic only asserts
eight-byte alignment; small compile-time limits need separate characterization.
These restrictions and mid-frame changes of the runtime limit remain open
compatibility decisions. `rearbitrate` is currently held at its initialized
zero value; it does not request arbitration at packet boundaries.

### Software transmission

Rogue requests buffers from the transport, reserves eight bytes each for header
and tail, and aligns available payload to eight bytes. Each application buffer
becomes one packet. The application call generates its packets in sequence;
receive-side per-destination reassembly supports interleaved peers.

Rogue uses a 16-bit wire sequence, sets SOF only on the first packet, and sets
EOF only on the final packet. It sends ID zero and repeats the application's
first and last user fields in every fragment. With SSI enabled it sets the
first-user SOF bit. Increasing the last buffer's payload to word alignment does
not explicitly zero the padding bytes in `ControllerV2::applicationRx`.

## CRC processing

The default polynomial is `0x04C11DB7`, with the standard reflected CRC-32
processing, initialization and final inversion corresponding to CRC-32/ISO-HDLC
(the check value for `123456789` is `0xCBF43926`). The RTL stores an internal
remainder; Rogue and the Python oracle use their libraries' incremental CRC
interface. Those representations must not be confused.

CRC state continues across packets of the same frame and is independent for
each destination in the normal state-table implementation. Start of frame
initializes the calculation. The current packet's CRC field is excluded, and
the transmitted CRC field from a previous packet is not fed into continuation.

| Mode | Bytes included, in transport order, for each packet |
| --- | --- |
| NONE | No calculation; transmitter writes zero |
| DATA | All payload word bytes, including padding outside the final byte count |
| FULL | Eight header bytes, all payload word bytes, and the low four tail bytes |

Across continuation packets, apply the relevant row repeatedly to the retained
CRC state. Padding bytes participate exactly as transmitted; this draft does
not impose zero padding. The four CRC bytes appear most-significant CRC byte
first in the serialized packet. This differs from ordinary little-endian
numeric field packing within a word.

The [existing oracle](../../tests/protocols/packetizer/packetizer_test_utils.py)
constructs first packets using `zlib`. The
[known-answer tests](../../tests/protocols/packetizer/test_AxiStreamDepacketizer2Reconnect.py)
pin these complete packet byte strings for payload `12345678`, destination 0,
ID `0x40`, first user `0x20`, last user 0, SOF/EOF set, sequence 0:

```text
DATA: 1220004000000080 3132333435363738 000108009ae0daaf
FULL: 2220004000000080 3132333435363738 000108004c7742b2
```

Independent continuation/interleaving vectors and exact transmitter CRC
comparisons are not yet provided by that helper.

### Receiver CRC profiles

The RTL checks the header mode against `CRC_MODE_G`. DATA and FULL compare
the received CRC against the corresponding calculation. NONE still requires
a zero CRC field.

Rogue transmits NONE or FULL according to `enObCrc`. Its receiver ignores the
header mode field. With `enIbCrc=true` it always calculates FULL; with
`enIbCrc=false` it ignores the CRC. The
[network wrapper](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/python/pyrogue/protocols/_Network.py)
constructs V2 with inbound checking disabled and outbound generation enabled.
Connection success through that wrapper is not evidence of correct inbound CRC.
Mode acceptance is an explicit compatibility decision still to be made.

## Receive, error and recovery behavior

### RTL endpoint

The receiver restores destination and ID from each accepted header, places the
header user field on the first payload beat of that packet, and overrides its
SSI SOF bit from the in-band SOF flag. It holds the final payload word until
the tail supplies EOF, byte count and last user. Earlier payload can already
have transferred when an error is discovered.

A valid header must match expected SOF/active state, sequence, version, and CRC
mode. Reduced sequence configurations compare only their selected low bits.
Header rejection resets destination frame tracking and can generate an EOFE
termination, with a stored flag suppressing repeated header-error terminations
until the context is reestablished. Payload data and sidebands of synthetic
terminations are not yet fully specified. Diagnostic strobes have known review
questions, including F01.

A bad tail CRC or transport EOFE causes the held payload word to end the frame
with EOFE. Application EOFE carried in the tail's last-user field is distinct
from transport EOFE used to flag a damaged transport packet. Error detection
does not retract payload that has already transferred.

On a falling `linkGood`, the receiver enters a destination cleanup sweep. The
latest recovery tests require one EOF+EOFE termination per open destination,
no termination for inactive destinations, stability under stalls, and fresh
payload after pending terminations. The sweep clears state as entries are
consumed and waits for output capacity. Link return does not cancel pending
terminations. `initDone` indicates completion of the state-table sweep; it
does not by itself mean all termination beats have been accepted downstream.

Reset also enters initialization. Global reset during cleanup cancels the
pending output in the existing directed test. Broader reset behavior, including
transmitter RAM context after an interrupted frame, remains uncharacterized.
Do not infer that resetting RAM output registers clears its stored contexts.

### Rogue endpoint

Rogue rejects transport frames with an error, multiple buffers, invalid size
or alignment, or an invalid version. SOF/sequence/CRC mismatch clears the
destination's partially assembled application frame and resets its expected
sequence. A new SOF arriving while that destination expects continuation is
rejected; it is not immediately accepted as a replacement frame.

Only EOF delivers the assembled frame to an application endpoint. First user
comes from the first packet and last user from the final packet; received ID
is parsed but not propagated. When SSI is enabled, final last-user EOFE marks
the delivered frame with error `0x80`. This buffered delivery model deliberately
differs from the RTL's already-streamed data followed by EOFE.

The reviewed V2 API has no RTL-equivalent `linkGood` cleanup sweep. Software
reconnect behavior and the lifetime of partially assembled frames need their
own characterization; RTL reset/link guarantees cannot be assumed to apply.

## Configuration and integration profiles

The entity declarations expose implementation choices as well as protocol
choices. Their declared ranges do not prove every combination is supported.

| Setting | Current meaning and limitations |
| --- | --- |
| `CRC_MODE_G` | NONE, DATA, or FULL; affects format acceptance and CRC coverage |
| `CRC_POLY_G` | Alternate RTL CRC implementation when not `0x04C11DB7`; software supports the standard CRC here |
| `SEQ_CNT_SIZE_G` | TX 4..16; RX 0..16; zero selects one shared RX state register, not independent destination contexts |
| `TDEST_BITS_G` | At most 8; low bits select context and transmitted/restored destination; zero TX behavior needs review (F02) |
| `MEMORY_TYPE_G`, `REG_EN_G` | Context storage and read latency; used by both PGP and RSSI profiles |
| `CRC_PIPELINE_G` | RX 0 or 1; changes CRC/state timing and buffering requirements |
| Input/output pipeline stages | AXI interface buffering and latency |
| Reset polarity/asynchronous selection, `TPD_G` | Implementation interface behavior requiring preservation |
| Packet limit and output destination/ID | TX boundary policy and transport routing; see F04/F05 |

Current in-repository profiles include:

- [RSSI V2](../rssi/v1/rtl/RssiCoreWrapper.vhd): FULL CRC, 16-bit sequence,
  eight destination bits, registered block RAM, negotiated runtime packet size.
- [PGP3](../pgp/pgp3/core/rtl/Pgp3Tx.vhd): DATA CRC and 12-bit sequence;
  [RX](../pgp/pgp3/core/rtl/Pgp3Rx.vhd) uses four destination bits.
- [PGP4](../pgp/pgp4/core/rtl/Pgp4Rx.vhd): DATA CRC, 12-bit sequence for
  normal mode, reduced destination storage and optional CRC pipeline.
- PGP4 Lite RX: zero sequence width. The new standalone recovery tests cover
  this only with zero destination bits; see F03 for the shared-context limit.

PGP converts V2 words to its own control/data encoding and reconstructs them
on receive. It does not transport every V2 header field. PGP-native controllers
are an open architectural alternative, discussed in the
[PGP assessment](../../docs/plans/packetizer2-spec/pgp-separation.md).

## Conformance status

This draft is grounded in source review and existing test assertions. No new
RTL/Rogue conformance run or behavioral-equivalence claim accompanies it.
The [coverage ledger](../../docs/plans/packetizer2-spec/findings.md#coverage-inventory)
identifies the existing tests and missing independent checks. Legal input,
recovery guarantees, supported profiles and incidental fields need review
before the draft can become a normative specification.
