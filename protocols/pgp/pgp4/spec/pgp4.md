---
title: PGP Version 4 Protocol Specification
---

# PGP Version 4 Protocol Specification

Status: Repository-canonical specification for PGP4 protocol behavior.

## 1. Introduction

PGP Version 4 (PGP4) is a lightweight, full-duplex serial link protocol for
transporting frame-oriented traffic between two endpoints. A PGP4 link carries
user frames, virtual-channel identity, receiver backpressure, receiver overflow
events, link readiness, low-rate sideband link data, and 48-bit user opcodes in
one ordered 64b/66b word stream per direction.

The protocol is designed for hardware endpoints that need deterministic framing
with a small amount of in-band link management. Data words carry frame payload.
Control words carry the symbols that start and end cells, publish link state,
insert clock-compensation or sideband data, and deliver user opcodes. Because
all of these functions share the same word stream, receivers can recover the
frame boundary, virtual channel, and link metadata without a separate management
lane.

PGP4 is symmetric. Each endpoint is simultaneously a transmitter and a receiver.
The receive side of an endpoint advertises its readiness and per-virtual-channel
pause state to the remote transmitter by placing that information in outgoing
control words. The remote transmitter then uses the received metadata to decide
when it may select new traffic for each virtual channel.

This document specifies the wire-visible behavior needed for interoperable
PGP4 endpoints:

- 66-bit word headers and the meaning of data and control words
- control-word encodings and control-word checksums
- `LINKINFO`, pause, overflow, opcode, and sideband-data semantics
- cell and frame sequencing rules
- CRC behavior for frame payload protection
- link bring-up, link maintenance, and link-loss behavior
- the Full PGP4, Pgp4Lite, and FEC-enabled profile distinctions

This document intentionally does not specify:

- transceiver-family wrapper internals
- vendor IP internals
- register-map implementation details
- AXI-Stream, AXI-Lite, or other local bus binding details
- resource-usage guidance
- future optimization or refactor plans

Non-normative appendices describe local RTL, test, and software mappings used
by this repository.

## 2. Conformance Language

The key words `MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, and `MAY` in this
document are to be interpreted as normative requirements.

Unless explicitly marked otherwise, figures are explanatory and tables define
the exact field allocations and values. Appendices are non-normative.

## 3. Protocol Model

A PGP4 direction is an ordered sequence of 66-bit words. Each word consists of
a 64-bit payload and a 2-bit header. The header identifies whether the payload
is frame data or a PGP4 control word. The protocol does not define a separate
out-of-band control channel; every link-management event that is visible to the
remote endpoint is represented as a control word in this same ordered stream.

PGP4 transports frames. A frame belongs to one virtual channel (VC), begins
with a start control word, contains zero or more 64-bit data words, and ends
with an end control word. Full PGP4 may divide a long frame into multiple
cells. The first cell starts with `SOF`, continuation cells start with `SOC`,
non-final cells end with `EOC`, and the final cell ends with `EOF`. Pgp4Lite
uses a constrained single-cell form that emits `SOF`, data words, and `EOF`
only.

Cells are the unit that carries sequence and CRC metadata. The sequence field
is present in `SOF` and `SOC`. The CRC and last-byte count are present in
`EOF` and `EOC`. A receiver reconstructs frame data by interpreting these
control words and passing intervening data words to the VC identified by the
most recent `SOF` or `SOC`.

Control words that are not cell delimiters may appear between frames and, in
specified cases, between cells or data words. `IDLE` words fill otherwise empty
link time and publish receiver state. `SKP` words provide clock-compensation
or low-rate sideband link data. `USER` words carry a 48-bit application-defined
opcode. These control words do not themselves start or end a frame.

![Non-normative: protocol layering and interface model.](assets/pgp4-stack.svg)

## 4. Word Format

### 4.1 66-bit headers

Every PGP4 word uses one of the following header values.

| Header bits | Meaning |
| --- | --- |
| `01` | Data word |
| `10` | Control word |
| `00` | Reserved / invalid for PGP4 |
| `11` | Reserved / invalid for PGP4 |

A transmitter `MUST` use header `01` for frame payload data words and header
`10` for PGP4 control words. A receiver `MUST` treat header values `00` and
`11` as invalid for PGP4.

Data-word payload bits are frame payload bits. PGP4 does not reinterpret those
64 bits while they are in a data word. Any byte-lane meaning, user metadata, or
local stream convention is part of the endpoint binding, not the data-word
encoding itself.

### 4.2 64b/66b scrambling

PGP4 words are transported through a 64b/66b scrambler and descrambler pair.
Compatible endpoints `MUST` use the PGP4 scrambler configuration with taps 39
and 58. The scrambler protects transition density and avoids long runs on the
physical serial stream; it does not change the logical control-word or data-word
formats described in this document.

The protocol does not mandate a particular serial line rate. Any line rate
`MAY` be used provided both endpoints and the transport medium can reliably
transport the scrambled 66-bit word stream.

## 5. Control Words

### 5.1 Common control-word layout

Every control word uses the following 64-bit payload layout.

| Bit range | Field | Meaning |
| --- | --- | --- |
| `63:56` | `BTF` | Block type field identifying the control word kind |
| `55:48` | `CSC` | 8-bit checksum over `BTF` and payload bits `47:0` |
| `47:0` | Payload | Control-word-specific payload |

A transmitter `MUST` set `CSC` to the checksum defined in Section 8.1. A
receiver `MUST` reject a control word whose `CSC` does not match its `BTF` and
payload.

Compatible receivers `MUST` interpret `BTF` values as listed below.

| Name | BTF value | Meaning |
| --- | --- | --- |
| `IDLE` | `0x99` | Idle fill plus `LINKINFO` and overflow-event metadata |
| `SOF` | `0xAA` | Start of frame |
| `EOF` | `0x55` | End of frame |
| `SOC` | `0xCC` | Start of continued cell |
| `EOC` | `0x33` | End of continued cell |
| `SKP` | `0x66` | Skip / clock-compensation character with sideband link data |
| `USER` | `0x78` | Sideband 48-bit user opcode |

A receiver `MUST` treat any other `BTF` value as an invalid PGP4 control word.

### 5.2 LINKINFO

`LINKINFO` is a 32-bit receiver-state field inserted into `IDLE`, `SOF`, and
`SOC` control words. It is the normal path by which an endpoint tells the
remote transmitter whether its receive side is usable and which VCs are paused.

| Bit range | Field | Meaning |
| --- | --- | --- |
| `7:0` | `Version` | PGP protocol version. PGP4 uses `0x04`. |
| `8` | `RXREADY` | Local receiver link-ready indication |
| `15:9` | Reserved | Transmitted as zero; ignored on receive |
| `31:16` | `Pause[15:0]` | Per-VC pause state |

A transmitter `MUST` set `Version` to `0x04`. A receiver `MUST` treat a
received `LINKINFO.Version` value other than `0x04` as a protocol version
error. A transmitter `MUST` set pause bits for implemented VCs according to
the local receive-buffer state and `MUST` transmit pause bits for unimplemented
VCs as zero. A receiver `MUST` ignore pause bits for VCs it does not implement.

`RXREADY` describes the readiness of the endpoint that transmitted the
`LINKINFO`; it is not an acknowledgement of the word that carried it.

### 5.3 IDLE

`IDLE` is the default fill word when no higher-priority protocol word is sent.
It keeps the receiver supplied with valid control words and refreshes link
metadata even when no user frame is in progress.

| Bit range | Field | Meaning |
| --- | --- | --- |
| `63:56` | `BTF` | `0x99` |
| `55:48` | `CSC` | Control-word checksum |
| `47:32` | `Overflow[15:0]` | Per-VC overflow event flags |
| `31:0` | `LINKINFO` | Version, `RXREADY`, and pause bits |

Overflow event bits `MUST` be carried in `IDLE` words. A transmitter `MUST`
set overflow bits for unimplemented VCs to zero. A receiver `MUST` update
remote overflow status from received `IDLE` words.

### 5.4 SOF and SOC

`SOF` starts the first cell of a frame. `SOC` starts a continuation cell of a
frame that has already begun. Both words identify the VC and carry `LINKINFO`
so that receiver-state metadata continues to advance when frame traffic is
active.

| Bit range | Field | Meaning |
| --- | --- | --- |
| `63:56` | `BTF` | `0xAA` for `SOF`, `0xCC` for `SOC` |
| `55:48` | `CSC` | Control-word checksum |
| `47:36` | `SEQ` | 12-bit cell sequence field |
| `35:32` | `VC` | 4-bit virtual-channel index |
| `31:0` | `LINKINFO` | Version, `RXREADY`, and pause bits |

A transmitter `MUST` place the selected VC in `VC`. A receiver `MUST` use that
VC value for the data words and terminating control word of the cell that
follows. `SEQ` is interpreted by the cell sequencing rules in Section 7.

### 5.5 EOF and EOC

`EOF` terminates the final cell of a frame. `EOC` terminates a non-final cell,
allowing another VC to use the link before the original frame continues with a
later `SOC`.

| Bit range | Field | Meaning |
| --- | --- | --- |
| `63:56` | `BTF` | `0x55` for `EOF`, `0x33` for `EOC` |
| `55:48` | `CSC` | Control-word checksum |
| `47:16` | `CRC32` | 32-bit data CRC for the cell payload |
| `15:12` | `BytesLast` | Number of valid bytes in the final data word |
| `11:8` | Reserved | Transmitted as zero; ignored on receive |
| `7:0` | `TUSER_LAST` | Endpoint-defined terminal user bits |

`BytesLast` is the count of valid bytes in the last data word of the cell. A
value of `8` indicates that all eight bytes are valid. Endpoint bindings that
do not support partial final words `MUST` transmit `BytesLast = 8`.

### 5.6 SKP

`SKP` is a control word used for skip insertion and low-rate sideband link
data. It does not start, continue, or terminate a cell.

| Bit range | Field | Meaning |
| --- | --- | --- |
| `63:56` | `BTF` | `0x66` |
| `55:48` | `CSC` | Control-word checksum |
| `47:0` | `RemoteLinkData` | Low-rate sideband link data |

The `RemoteLinkData` field is advisory. A sender `SHOULD NOT` use it for
time-critical control, and a receiver `MUST NOT` infer frame progress from
`SKP` words.

### 5.7 USER

`USER` carries a 48-bit application-defined opcode outside the frame payload
stream. It does not start, continue, or terminate a cell.

| Bit range | Field | Meaning |
| --- | --- | --- |
| `63:56` | `BTF` | `0x78` |
| `55:48` | `CSC` | Control-word checksum |
| `47:0` | `Opcode` | User-defined 48-bit opcode payload |

A receiver that accepts a valid `USER` word `MUST` present the 48-bit opcode
as a sideband event. The opcode is ordered with respect to the PGP4 word stream,
but it is not part of any frame payload.

## 6. Flow Control and Sideband Metadata

PGP4 flow control is receiver-driven. Each endpoint publishes its own receive
state in the control words it transmits. The far endpoint consumes that state
as remote receive state and uses it to decide whether it may start or continue
traffic for a VC.

![Non-normative: flow-control and sideband exchange.](assets/pgp4-flow-control.svg)

A transmitter `MUST` include `LINKINFO` in every `IDLE`, `SOF`, and `SOC`
word. A receiver `MUST` update remote pause and remote link-ready state from
the `LINKINFO` carried by those words. A receiver `MUST` update remote overflow
state from `IDLE.Overflow`.

When flow control is enabled, a transmitter `MUST NOT` select new traffic for
a VC whose synchronized remote pause bit is asserted. An endpoint `MAY` provide
a local configuration mode that disables this flow-control gating; when that
mode is used, interoperability depends on the receiver being able to absorb or
discard the resulting traffic.

Pause and overflow bits are state advertisements, not frame delimiters. They
do not change the interpretation of a data word already accepted into the word
stream. A pause bit affects future VC selection; it does not retroactively
invalidate a cell already in flight.

`USER` opcodes and `SKP.RemoteLinkData` are sideband mechanisms. They share
the link with frame traffic but do not consume a VC and do not alter frame
payload bytes. An endpoint that requires reliable delivery of control
information should carry that information in a framed VC payload rather than
in `SKP.RemoteLinkData`.

## 7. Cells, Frames, and Virtual Channels

Full PGP4 uses cells to prevent one long frame from permanently occupying the
link. A long frame can be split into a first cell, zero or more continuation
cells, and a final cell. Other VCs may be scheduled between cells. The wire
therefore carries an interleaving of cells, while each VC still observes its
own ordered sequence of frame payloads.

![Non-normative: frame-to-cell sequencing view.](assets/pgp4-cell-sequence.svg)

### 7.1 Full PGP4 cell rules

For Full PGP4:

- Each transmitted payload word `MUST` use data header `01`.
- The first cell of a frame `MUST` start with `SOF`.
- A continuation cell of the same frame `MUST` start with `SOC`.
- A non-final cell `MUST` end with `EOC`.
- The final cell of a frame `MUST` end with `EOF`.
- The `VC` field in `SOF` and `SOC` `MUST` identify the virtual channel for
  that cell.
- The `SEQ` field in `SOF` and `SOC` `MUST` carry the cell sequence value for
  the frame on that VC.
- `EOF` and `EOC` `MUST` carry the CRC for the data words in the cell that
  they terminate.

The first data word of a cell, if present, is the word immediately after `SOF`
or `SOC` unless another permitted non-data control word is inserted by the
transmitter. The cell terminates at the matching `EOF` or `EOC`. A receiver
`MUST` preserve the order of data words within a VC.

### 7.2 Sequence behavior

`SEQ` provides receiver-visible cell ordering information. A transmitter
`MUST` advance the sequence for successive cells of a frame according to the
profile's packetization rules. A receiver `MUST` report a sequence error when
the sequence behavior for a frame on a VC is inconsistent with those rules.

The sequence field is scoped to cell sequencing. It is not a global word count,
not a byte count, and not a substitute for the payload CRC.

### 7.3 Pgp4Lite cell rules

Pgp4Lite uses the same word headers, control-word checksum, `LINKINFO`, `USER`,
`SKP`, and CRC concepts as Full PGP4, but constrains frame emission:

- Lite transmitters `MUST` emit `SOF` and `EOF` only for frame boundaries.
- Lite transmitters `MUST NOT` emit `SOC` or `EOC`.
- Lite transmitters `MUST` set the `SEQ` field in `SOF` to zero.
- Lite transmitters that do not support partial final words `MUST` set
  `EOF.BytesLast` to `8`.
- Lite receivers `MUST` still accept the standard PGP4 receive word format.

Pgp4Lite is therefore wire-compatible with the common PGP4 control-word
encoding, but it is not equivalent to the Full PGP4 multi-cell scheduling
model.

## 8. Integrity Mechanisms

PGP4 uses two integrity mechanisms. Control words use an 8-bit checksum so the
receiver can reject malformed K-code metadata. Frame data uses a 32-bit CRC so
the receiver can detect payload corruption within each cell.

| Mechanism | Width | Coverage |
| --- | --- | --- |
| Control-word checksum (`CSC`) | 8 bits | Control-word `BTF` plus payload bits `47:0` |
| Data CRC | 32 bits | Cell data payload |

### 8.1 Control-word checksum

For every control word, the `CSC` field is computed over the concatenation of:

- payload bits `47:0`
- `BTF` bits `63:56`

The `CSC` field itself is excluded from the calculation. The checksum uses CRC
polynomial `0x07`, initial value `0xFF`, reflected input ordering as defined by
the PGP4 algorithm, and a final bit-reversal plus inversion.

### 8.2 Data CRC

The data CRC polynomial is `0x04C11DB7`, matching the Ethernet CRC-32
polynomial. The CRC covers the data payload words in the cell and is carried
in `EOF.CRC32` or `EOC.CRC32`.

A transmitter `MUST` compute the CRC over the cell payload and place the result
in the terminating `EOF` or `EOC`. A receiver `MUST` check that CRC before
accepting the cell as error-free. A receiver that detects a data CRC mismatch
`MUST` report a frame or cell error for the affected payload.

A data CRC failure does not by itself require the PGP4 link to drop. Link loss
is governed by the link-state rules in Section 9 and by the endpoint's error
policy.

## 9. Link Bring-Up and Operational Behavior

A PGP4 receiver must distinguish an inactive or misaligned physical stream from
a valid PGP4 word stream. Link bring-up therefore relies on repeated valid
control words before the receiver declares the protocol link ready. Once ready,
the receiver continues to require periodic valid link-management control words
to keep the link in the operational state.

![Non-normative: link bring-up and operational state flow.](assets/pgp4-link-state.svg)

### 9.1 Transmit startup

After reset or transmitter disable, a transmitter `MUST` begin by emitting
valid control words rather than user payload. During startup hold, the
transmitter `MAY` emit `IDLE` and `SKP`; it `MUST NOT` emit frame data. After
startup completes and the local transmit side is ready, the transmitter may
start normal arbitration subject to remote receive readiness and flow-control
state.

When flow control is enabled, a transmitter `MUST NOT` send user frame traffic
until the remote endpoint has advertised receiver readiness through
`LINKINFO.RXREADY`.

### 9.2 Receive acquisition

While unlinked, a receiver `MUST` count repeated valid PGP4 control words.
Data words do not establish link readiness while the receiver is unlinked.
When the receiver observes the required run of valid control words, it asserts
local link readiness and begins interpreting data and control words as the
active protocol stream.

The required run length is profile-defined.

### 9.3 Link maintenance and loss

While linked, a receiver `MUST` refresh its link-maintenance watchdog when it
receives a valid `IDLE`, `SOF`, or `SOC` with the expected protocol version.
If too many words arrive without such a refresh, the receiver `MUST` leave the
link-ready state.

A receiver `MUST` leave link-ready state when the physical receive path becomes
inactive, when reset is asserted, or when a malformed protocol condition
requires reinitialization. A receiver `SHOULD` report a link-down event when it
transitions from ready to not ready after previously being ready.

### 9.4 Transmit word priority

When several word types are eligible in the same transmit opportunity, a
transmitter needs a deterministic selection policy. The policy `MUST` preserve
valid cell structure and `MUST` prevent metadata words from being interpreted
as frame data. A compliant policy may insert `IDLE`, `SKP`, or `USER` words
between frame cells, and may insert `IDLE` words to publish urgent pause or
overflow metadata.

A transmitter `MUST NOT` acknowledge local acceptance of a payload word if a
higher-priority control word is emitted instead. This rule prevents a local
frame source from believing payload entered the PGP4 stream when the link
actually carried an opcode, skip, or metadata update.

## 10. Profiles and Optional FEC

This specification covers the following PGP4 profiles.

| Profile | Purpose | Key protocol behavior |
| --- | --- | --- |
| Full PGP4 | General-purpose multi-VC transport | Supports SOF/SOC and EOF/EOC, VC interleaving between cells, CRC-protected cells, and optional SKP insertion. |
| Pgp4Lite | Reduced-complexity profile | Uses the same control-word format but emits only SOF/EOF frame boundaries and whole-word transmit payloads. |
| FEC-enabled PGP4 | Full PGP4 with an external FEC profile | Preserves the same logical PGP4 word stream at the protocol boundary while adding profile-specific FEC below or around that stream. |

| Feature | Full PGP4 | Pgp4Lite | FEC-enabled PGP4 |
| --- | --- | --- | --- |
| Data header `01` and control header `10` | Yes | Yes | Yes |
| SOF / EOF | Yes | Yes | Yes |
| SOC / EOC | Yes | No TX support | Yes |
| Multi-VC interleaving between cells | Yes | Not part of Lite TX behavior | Yes |
| Partial final data word on TX | Yes | No, full 64-bit beats only | Yes |
| SKP support | Optional | Optional | Optional |
| External FEC wrapper | Optional | Not part of the Lite profile definition | Yes |

The FEC-enabled profile does not redefine PGP4 control words, frame boundaries,
or `LINKINFO` semantics. A FEC wrapper may add error-correction behavior at a
lower layer, but the logical PGP4 stream presented to the protocol encoder and
decoder remains the stream specified above. Wrapper-specific lanes, vendor IP,
error counters, and bypass controls are outside the normative protocol body.

## Appendix A. Local Stream Mapping (Non-Normative)

The repository implementation maps PGP4 frame traffic onto 8-byte AXI-Stream
interfaces with a 4-bit VC value and endpoint-defined terminal user bits. That
binding is a local implementation interface, not a requirement on other PGP4
implementations.

In the full profile, the local transmit path packetizes stream frames into
cells, derives `SOF`/`SOC` and `EOF`/`EOC`, computes the last-byte count, and
generates the cell CRC and sequence field. The receive path performs the
inverse operation and demultiplexes accepted frame payloads by VC.

In the Lite profile, the local transmit protocol block derives `SOF`, data
words, CRC, and `EOF` directly from a flat frame stream. Because Lite TX does
not emit continuation cells, it sets the sequence field to zero and emits a
whole-word final-byte count.

![Non-normative: full-profile TX/RX data path.](assets/pgp4-txrx-path.svg)

## Appendix B. Monitor and Control Surface (Non-Normative)

The repository AXI-Lite monitor/control surface is organized into three
address windows.

| Address window | Block | Purpose |
| --- | --- | --- |
| `0x000-0x3FF` | `Ctrl` | Configuration, capabilities, skip interval, loopback, disable, reset, FEC bypass |
| `0x400-0x7FF` | `RxStatus` | Receive counters, sticky/error status, remote sideband data, RX clock frequency |
| `0x800-0xBFF` | `TxStatus` | Transmit counters, local sideband data, TX clock frequency |

Key control and capability fields include:

| Offset | Field | Notes |
| --- | --- | --- |
| `0x004` | Capability bits | `WRITE_EN_G`, `PGP_FEC_ENABLE_G`, `NUM_VC_G`, counter widths |
| `0x008` | `SkipInterval` | Default comes from the transmit input initialization record |
| `0x00C` | Control bits | Loopback, flow-control disable, TX disable, TX reset, RX reset, FEC bypass |
| `0x010` | `FecInjectBitError` | Present only when write-enabled and FEC support is enabled |
| `0x014` | `UpTimeCnt` | Seconds since reset or counter reset |

The Python model in `python/surf/protocols/pgp/_Pgp4AxiL.py` is the
repository-backed source for field naming and monitor grouping.

## Appendix C. Repository Implementation Notes (Non-Normative)

This specification was derived from the repository implementation and
regressions. The protocol body avoids depending on local module names, but the
following files are the primary implementation sources:

- `protocols/pgp/pgp4/core/rtl/Pgp4Pkg.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Core.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4CoreLite.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Tx.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4TxProtocol.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4TxLiteProtocol.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Rx.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4RxProtocol.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4AxiL.vhd`
- `python/surf/protocols/pgp/_Pgp4AxiL.py`
- `tests/protocols/pgp/pgp4/*`

Implementation-specific constants and behaviors that inform, but do not by
themselves broaden, the normative protocol are:

| Item | Repository value or behavior |
| --- | --- |
| PGP version | `PGP4_VERSION_C = 0x04` |
| Default full-profile cell payload bound | `PGP4_DEFAULT_TX_CELL_WORDS_MAX_C = 128` 64-bit words |
| Data header | `PGP4_D_HEADER_C = "01"` |
| Control header | `PGP4_K_HEADER_C = "10"` |
| Scrambler taps | `PGP4_SCRAMBLER_TAPS_C = (39, 58)` |
| Data CRC polynomial | `PGP4_CRC_POLY_C = 0x04C11DB7` |
| Full-profile startup hold | `STARTUP_HOLD_G = 1000` by default |
| Lite-profile startup hold | `STARTUP_HOLD_G = 0` by default |
| Receive link acquisition threshold | 1000 valid control words |
| Receive no-valid-data reinit threshold | 10000 receive-side cycles while PHY is active |
| Full-profile VC arbitration | Round-robin arbitration with cell-level interleaving |
| Full-profile CRC pipeline spacing | Optional forced `IDLE` gap after `EOF` or `EOC` |

The repository control-word checksum routine is named `pgp4KCodeCrc()`. It
computes an 8-bit CRC over payload bits `47:0` followed by `BTF`, using
polynomial `0x07`, initial value `0xFF`, and the bit ordering described in
Section 8.1.

The full-profile transmitter chooses among eligible words using an override
chain: `IDLE` fill, accepted frame-derived traffic, `USER` opcode, `SKP`,
optional CRC-pipeline spacing `IDLE`, and urgent pause/overflow publication
`IDLE`. This is an implementation scheduling policy; the protocol requirement
is that the emitted stream remain structurally valid and preserve the semantics
specified in Sections 5 through 9.

## Appendix D. Confluence Comparison Notes (Non-Normative)

Confluence material at the SLAC PGP4 page was used only as reference during
specification authoring. When this document differs from that page, this
repository specification follows implementation-backed repository behavior.

The control-word values, `LINKINFO` structure, startup narrative, and the
general distinction between Full PGP4 and Pgp4Lite are materially consistent
with the repository implementation. This specification keeps FEC at the profile
level and does not embed wrapper-specific vendor IP details into the normative
body. It also does not adopt Confluence resource commentary, implementation
discussion, or future-looking optimization notes as normative text.

## Appendix E. Verification Notes (Non-Normative)

The specification content was cross-checked against repository regressions
covering the following behaviors:

- full-core and Lite-core loopback with optional pause and backpressure
- raw protocol TX sequences for `USER`, `SOF`, data, and `EOF`
- raw protocol RX interpretation of `IDLE`, `LINKINFO`, `USER`, and packet
  sequences
- rejection of malformed K-code checksum words
- CRC-detected receive corruption without forced link drop
- low-speed Lite receive-lane lock and stability behavior
- AXI-Lite monitor/control readback and field wiring

The full PGP4 RTL/cocotb regression suite was not re-run as part of this
documentation-only revision unless stated in the change log or review notes
for the commit that updates this file.
