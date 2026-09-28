# PGP and Packetizer2 separation assessment

Status: exploratory design question. No controller split, generic removal or
wire-protocol change has been selected. See the [task context](README.md) and
[working specification](../../../protocols/packetizer/spec/packetizer2.md).

## Existing boundary

Normal PGP3/PGP4 TX multiplexes application streams, feeds Packetizer2, and
converts its header/tail words into PGP control words. RX reconstructs V2
header/tail words and feeds Depacketizer2. Packetizer2 is therefore an internal
representation as well as reusable state/CRC logic; its complete header is not
the PGP wire format.

```mermaid
flowchart LR
    A[Application streams] --> B[Interleaving mux]
    B --> C[Packetizer2]
    C --> D[PGP TX encoding]
    D --> E[PGP link]
    E --> F[PGP RX decoding]
    F --> G[Depacketizer2]
    G --> H[Application streams]
```

In [PGP4 TX](../../../protocols/pgp/pgp4/core/rtl/Pgp4Tx.vhd), comments explicitly
assign chunking to the mux. Packetizer2 additionally enforces its own size
limit and supplies framing, per-destination sequence/CRC context and tails.
The [encoder](../../../protocols/pgp/pgp4/core/rtl/Pgp4TxProtocol.vhd) maps SOF/SOC,
VC and sequence from the V2 header; it maps EOF/EOC, last user, byte count and
CRC from the tail. It does not transport V2 ID or first user.
The [RX protocol](../../../protocols/pgp/pgp4/core/rtl/Pgp4RxProtocol.vhd)
reconstructs those V2 words with DATA mode and default metadata where absent.
PGP3 uses the same overall arrangement.

The [link-recovery history](link-recovery-history.md) also establishes that
`linkGood` and per-destination EOFE cleanup originated in the PGP3 integration
in April 2017. RSSI subsequently adopted the same interface. Separating PGP
would allow more direct ownership of link-loss policy, but downstream frame
abandonment would remain an obligation for each streaming endpoint.

## Configuration provenance

The local git history provides concrete provenance rather than inferred intent:

| Commit | Change | Implication |
| --- | --- | --- |
| `fd2812d6ad79e6c145dcf2f6145d9444fb098ab1` (2021-02-07) | Adds configurable sequence width to fix PGP3/PGP4 carrying 12 bits while V2 expected 16; message cites large-frame sequence errors | Reduced sequence width is a demonstrated PGP requirement |
| `5c2715889d280db6d175565602db120fa5facf57` (2022-11-21) | Adds RX sequence width zero alongside PGP4 Lite RX changes | The single-context special case is tied to Lite support |
| `7fc64014d2a077dceee985bf3c9aaabcc0978340` (2025-06-24) | Adds CRC latency mode explicitly for PGP4 at 25 Gb/s; later renamed `CRC_PIPELINE_G` | CRC scheduling is partly driven by PGP timing |
| `561c792d669b6cd90af5d49de58d9955e428b403` (2018-02-27) | Adds selectable header/tail versus payload CRC coverage | Current consumers diverge: DATA for PGP, FULL for Rogue/RSSI |
| `292c518ae3da550c74330330e96534e7cf953478` (2018-08-23) | Adds dynamic fragment-size input | Still used by RSSI's negotiated packet-size path |
| `35f544ab80da29f4ef1d209fb6f72e1fec9f2063` (2018-03-02) | Adds destination-width generic and updates RSSI wrapper | Destination sizing cannot simply be classified as PGP-only |

Current PGP3/PGP4 both use polynomial `0x04C11DB7`; an arbitrary polynomial is
not required by those instantiations. That does not establish absence of
external users. RAM/register and interface-pipeline choices also have general
timing/resource purposes; RSSI uses registered block RAM.

PGP4's CRC pipeline choice has an additional integration consequence:
`Pgp4TxProtocol` can insert a two-cycle idle gap after EOF/EOC to accommodate
RX processing. Moving the receiver logic must preserve or deliberately revisit
that link timing contract, not merely produce matching payload bytes.

## What separation could simplify

A PGP-native controller could express VC state, 12-bit cell sequence,
SOF/SOC/EOF/EOC, payload CRC and PGP recovery directly. It could avoid creating
a generic V2 byte header solely for another block to decode and rewrite.
The ordinary Packetizer2 profile might then have fewer sequence and CRC-mode
exceptions, subject to external-consumer review.

The useful design question includes receive-side reassembly, error termination
and timing. Replacing only TX frame splitting would leave much of the current
complexity and the internal V2 translation intact. Moving PGP4 alone also leaves
PGP3 requiring reduced sequences and DATA mode.

## What would remain

Rogue/RSSI still need fragmentation, interleaved destination contexts, full CRC
continuation, partial final words, backpressure and recovery. They therefore
retain many of the hardest correctness problems after any PGP separation.
CRC cannot be removed from the software-facing V2 protocol merely because PGP
motivated some of its original development.

Separate controllers would duplicate some sequence, context and termination
logic. Maintaining two copies requires explicit shared behavioral tests or
independent oracles, particularly for interrupted frames and stalls. Sharing
small CRC, memory and AXI buffering primitives remains useful. A common
fragmentation/context helper is worth considering only if it has a clear
contract and actually reduces conditional behavior; it should not relocate
the same sprawling controller behind another interface.

There is an existing limited precedent:
[Pgp4TxLiteProtocol](../../../protocols/pgp/pgp4/core/rtl/Pgp4TxLiteProtocol.vhd)
performs native framing and CRC without Packetizer2. It always sends SOF/EOF,
does not support SOC/EOC and rejects partial final words. Its smaller problem
does not establish the cost or correctness of a full replacement.

## Questions before choosing an architecture

- Which PGP3, PGP4 and Lite configurations must remain supported, including
  multi-VC Lite and the CRC-pipeline gap contract?
- Which V2 generics and metadata behaviors have external FPGA consumers?
- Can fixed protocol profiles clarify the current modules sufficiently without
  separate controllers?
- Would a shared state mechanism with separate encoders/decoders genuinely
  simplify buffering and recovery ownership?
- What synthesis, timing and throughput evidence is needed alongside wire and
  application-level conformance?

The current preference is to evaluate PGP-native controllers seriously while
preserving deployed wire formats. A smaller public configuration space is a
possible outcome, not an assumption or a compatibility decision already made.
