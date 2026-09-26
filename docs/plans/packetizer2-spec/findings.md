# Packetizer2 findings and coverage

This is the initial source-review ledger for the revisions recorded in the
[handoff](README.md). No finding below has a new reproducer or fix from this
effort. Links into RTL refer to that baseline checkout. The
[working specification](../../../protocols/packetizer/packetizer2-spec.md)
defines the evidence terminology.

## Findings requiring characterization or a decision

### F01: Sequence diagnostic uses an overwritten value

Classification: suspected RTL defect, directly visible in source.

In [Depacketizer2](../../../protocols/packetizer/rtl/AxiStreamDepacketizer2.vhd)
`HEADER_S`, the rejection path clears `v.packetSeq` before comparing it with
`ramPacketSeqOut` to set `debug.seqError`. Incoming sequence 1 with expected
sequence 0 can be rejected without that diagnostic. Conversely, another header
error with a matching nonzero sequence can report a sequence error.

Needed evidence: directed mismatch/match cases, monitor the actual debug
strobes, and verify that output termination and later recovery remain correct.
No decision to preserve this diagnostic behavior has been made.

### F02: Zero destination width is not consistently applied by TX

Classification: implicit input constraint or suspected RTL defect.

In [Packetizer2](../../../protocols/packetizer/rtl/AxiStreamPacketizer2.vhd),
`TDEST_BITS_G=0` forces the RAM read address to zero, but `ADDR_WIDTH_C` remains
one. Header destination construction, destination-change detection and the
context write address still use input destination bit 0. The existing zero-bit
loopback drives destination zero and therefore cannot distinguish the cases.

Decision needed: must callers drive zero, or must the module ignore destination
when disabled? Characterize constant nonzero and changing input destinations
across split frames before choosing or correcting the contract.

### F03: Zero sequence width changes the context-storage model

Classification: known implementation limitation, already documented in tests.

RX `NO_SEQ` replaces the per-destination RAM with a single register updated
every clock. It is not simply a switch that disables sequence checking while
preserving independent destination state. The
[reconnect suite](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2Reconnect.py)
tests sequence width zero only with destination width zero. PGP4 Lite motivates
this mode, while PGP4's public configuration can also describe multiple VCs.

Needed decision: supported Lite configurations and whether unsupported
combinations require an assertion or a different implementation. Do not infer
multi-destination cleanup support from successful single-destination tests.

### F04: Output routing overrides cover payload only

Classification: observed behavior; intended compatibility unresolved.

TX applies `OUTPUT_TDEST_G` and `OUTPUT_TID_G` in `MOVE_S`. The header and tail
constructors initialize these transport sidebands to zero. Current standalone
tests use zero overrides and cannot establish nonzero routing behavior.

Needed evidence: nonzero override tests through a destination-sensitive
consumer. Decide whether all packet beats should share routing sidebands.

### F05: Minimum packet limit and runtime sizing need an explicit contract

Classification: observed boundary restriction; completeness gap.

TX requires more than three runtime-limit words to admit a header. A 24-byte
runtime limit stalls although a minimal packet occupies 24 bytes. Normal limits
at or above 32 bytes produce the expected header/payload/tail budget. The generic
checks alignment without asserting that minimum. Small compile-time ceilings,
oversized runtime values, truncation and changes during an active frame need
directed characterization. Preserve the current RSSI negotiated-size use case.

### F06: Synthetic termination payload is not consistently treated as incidental

Classification: test-contract question, not a claim that two tests conflict.

The [mid-packet link-drop test](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2LinkDrop.py)
checks that the synthetic EOFE beat repeats held payload data. The newer
[reconnect test](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2Reconnect.py)
explicitly leaves synthetic payload and ID unspecified. These are different
interruption scenarios, so their assertions are not inherently contradictory.

Decision needed: which payload, keep, user, ID and ordering properties are
requirements in each scenario? Do not freeze stale data merely because it is
currently copied through a register, or weaken a relied-on behavior without
checking consumers.

### F07: Rogue and RTL apply different CRC acceptance policies

Classification: observed compatibility difference.

Rogue ignores the advertised mode, always uses FULL when inbound CRC checking
is enabled, and ignores CRC when it is disabled. RTL requires the configured
mode and requires zero CRC even in NONE. Rogue transmits NONE or FULL only.
The common Rogue network wrapper disables inbound checking and enables
outbound CRC, which can hide receive-direction CRC defects in system testing.

Needed evidence: a directional compatibility matrix including NONE/DATA/FULL,
header-mode mismatch, zero/nonzero CRC and each software enable combination.
Decide whether permissive software reception remains a supported policy.

### F08: Software tail byte count is not validated like the wire field

Classification: parser discrepancy and suspected robustness defect.

Rogue reads all eight bits of the tail byte containing the four-bit count and
passes the resulting adjustment to the buffer before sequence/CRC rejection.
It does not first enforce count 1..8. RTL extracts only the count nibble, but
also lacks comprehensive malformed-length validation. Depending on capacity,
the software adjustment can throw or change the apparent payload unexpectedly.

Needed evidence: counts 0, 1, 8, 9 and 15, nonzero upper reserved nibble,
short packets, and subsequent valid-frame recovery. Separate reserved-bit
policy from malformed-count policy; neither peer's permissiveness is a spec.

### F09: Metadata and error delivery differ across endpoints

Classification: observed endpoint behavior; partly intentional architectural
difference, partly an unresolved field contract.

Rogue buffers until EOF and drops accumulated data on SOF/sequence/CRC error;
RTL can already have delivered data and uses EOFE to terminate. Rogue retains
first user from the first packet and last user from the final packet, ignores
received ID, and repeats first/last user values in transmitted fragments. RTL
restores metadata at packet boundaries and normally sends zero last user on
nonfinal tails. SSI bits are also interpreted or overwritten by endpoint rules.

Needed decision: meaningful values at application-frame versus fragment
boundaries. Cross-peer tests must check those values without requiring identical
buffering or incidental intermediate sidebands.

### F10: Reset and reconnect contracts are incomplete

Classification: characterization gap.

TX has no RX-style destination initialization sweep. Its RAM contents and
read-output resets must be considered separately, especially after an open
frame or partial packet. RX tests cover reset during one cleanup scenario,
but not all reset phases or polarity/asynchronous combinations. Rogue has no
equivalent link-status sweep in the reviewed V2 interface.

Needed evidence: warm reset after partial TX/RX activity, all affected context
types, reset with stalled output, and software reconnect with incomplete
assembly. Establish what downstream can observe and what permits a fresh frame.

## Coverage inventory

These entries describe source-level assertions, not fresh test results.

| Test or helper | Existing protection | Important limits |
| --- | --- | --- |
| [TX standalone](../../../tests/protocols/packetizer/test_AxiStreamPacketizer2.py) | Header/tail words, size split, partial final word, one-byte-over boundary, interleaved destinations, output stalls in NONE/DATA/FULL | Enabled CRC is only checked as nonzero; narrow storage/pipeline configuration |
| [TX wrap](../../../tests/protocols/packetizer/test_AxiStreamPacketizer2SeqWrap.py) | Seventeen packets with a four-bit sequence counter | NONE CRC; header/tail assertions do not independently validate every payload word |
| [RX standalone](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2.py) | Normal/continuation data, metadata, partial keep, invalid version/mode, NONE with nonzero CRC, idle link recovery | Mostly NONE and one storage configuration; error strobes largely unchecked |
| [RX CRC](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2Crc.py) | Bad DATA/FULL CRC causes final EOFE | Short single-packet negative cases |
| [RX link drop](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2LinkDrop.py) | Mid-packet interruption and subsequent fresh frame | One active destination, NONE CRC |
| [RX recovery](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2Recovery.py) | Active/mixed destinations, exact terminations, stalls, reset during cleanup, four RAM/register combinations | NONE CRC; selected interruption timing |
| [RX reconnect](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2Reconnect.py) | Thirteen curated profiles, exact input/output transfers, valid stability, repeated reconnects/flaps, sparse/empty sweeps, immediate fresh traffic, independent valid CRC | Starts frames with sequence zero; does not establish continuation behavior across the profile matrix |
| [V2 loopback](../../../tests/protocols/packetizer/test_AxiStreamPacketizer2Loopback.py) | Split partial frame, sidebands, stalls, three CRC modes and reduced destinations | Matching TX/RX defects can survive; destination-zero case drives only zero |
| [Python packet helper](../../../tests/protocols/packetizer/packetizer_test_utils.py) | Independent first-packet CRC; two literal vectors anchored in reconnect tests | No retained per-destination continuation CRC model; pads generated packets with zero |

Rogue's inspected tests include
[CRC primitives](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/tests/cpp/protocols/packetizer/test_crc.cpp),
[UDP/RSSI/V2 integration](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/tests/integration/test_udp_packetizer_integration.py),
and [SRP/RSSI/V2 integration](https://github.com/slaclab/rogue/blob/cf356dc277b13fcd4821e6dc78156c7a33090813/tests/cpp/protocols/srp/test_srp_rssi.cpp).
UDP reordering is injected below RSSI; it does not directly test the packetizer
receiving out-of-order fragments. These are software-peer tests. No direct
RTL/Rogue conformance suite was found in the inspected files.

PGP integration adds profile-specific loopback and CRC-error tests. RSSI's
multi-stream V2 integration cases exist but are gated by
`RUN_RSSI_KNOWN_ISSUE_TESTS`; they are not default passing evidence. The new
standalone RX reconnect profiles have no such gate.

## Conformance gaps to prioritize for discussion

- Independent exact CRCs for both transmit and receive across continuations,
  destination interleaving, stalls, partial words and nonzero padding bytes.
- Packet loss, duplicate/reordered fragments, SOF mismatch, truncated/header-only
  packets, unexpected SOF during payload, invalid tails and recovery afterward.
- Application metadata and SSI semantics for one-byte/one-word frames and
  all final byte counts; permitted nonfinal keep/user patterns.
- Receiver sequence wrap, reduced-width upper-bit policy, packet-size boundaries
  and runtime changes, nonzero transport routing overrides.
- Debug strobes, duplicate-free output and valid stability beyond the new
  recovery monitor's scenarios.
- TX implementation profiles, reset variants, alternate CRC polynomial, and
  explicit unsupported configuration handling.
- Direct RTL/Rogue exchange in both directions with independently checked wire
  packets; software inbound checking enabled for CRC conformance cases.

No architectural refactor is a substitute for settling these contracts.
