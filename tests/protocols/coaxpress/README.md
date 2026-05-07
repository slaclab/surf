# CoaXPress Regression Notes

This directory holds the checked-in cocotb regressions for the pure-VHDL
CoaXPress RTL under `protocols/coaxpress/core/rtl/`.

The intent is to keep the benches tied to the published protocol documents,
while also being explicit about places where the current RTL only exposes or
implements a narrower contract than the full normative wire protocol.

## Governing References

- [CoaXPress Standard Version 2.1](https://jiia.org/wp/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf)
  - JIIA `CXP-001-2021`
- CoaXPress over Fiber - Bridge Protocol
  - tests in this directory are aligned to the `CXPR-008` bridge specification family
  - public JIIA bridge-guideline reference currently available online:
    [CoaXPress over Fiber Bridge Protocol Version 1.1](https://jiia.org/wp/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXPR-008-2023_v1.1.pdf)
  - when discussing the original bridge baseline used by the current RTL/tests,
    refer to the document by name and identifier family rather than to any
    local PDF path

The shared constants in `coaxpress_test_utils.py` use the spec packet names and
symbol values directly:

- `0x07` is an event packet
- `0x08` is an event acknowledgment
- `/I/`, `/Q/`, `/S/`, `/T/`, and `/E/` use the CXPoF bridge byte values from
  `CXPR-008-2021`

## Coverage Model

The benches in this directory fall into three categories:

- Normative or near-normative packet checks
  - The test drives protocol-shaped traffic that matches the published packet
    layout closely enough to be treated as spec coverage for the exercised
    subset.
- Partial protocol checks
  - The test uses spec-shaped prefixes and field ordering, but the current RTL
    only consumes a prefix or a reduced subset of the full packet.
- RTL-contract checks
  - The test is primarily proving local assembly, buffering, arbitration, or
    transport behavior rather than full protocol legality.

When a bench is not full normative coverage, that should be treated as an
intentional limitation, not as silent proof of complete spec compliance.

## Bench Map

| Test file | DUT surface | Main spec relation | Status |
| --- | --- | --- | --- |
| `test_CoaXPressRxWordPacker.py` | `CoaXPressRxWordPacker` | Internal packing helper for receive-path word assembly, including handshake hold behavior and SSI `EOFE` propagation; not a direct protocol-surface spec bench | RTL-contract |
| `test_CoaXPressRxLaneMux.py` | `CoaXPressRxLaneMux` | Internal lane arbitration and trailer-marker-gated frame-boundary behavior; not a direct protocol-surface spec bench | RTL-contract |
| `test_CoaXPressRxLane.py` | `CoaXPressRxLane` | `CXP-001-2021` packet-type decode, `IO_ACK`, control acknowledgments, heartbeat payload/trailer handling, bounded event payload validate-before-release plus trailer-gated ACK, stream header/trailer framing, and malformed-packet `rxError` pulses | Partial protocol |
| `test_CoaXPressRxHsFsm.py` | `CoaXPressRxHsFsm` | Rectangular image header and line marker handling from section `10.4.6.2` / `10.4.6.3`, including dual-lane step/alignment, incomplete-frame new-header detection, and trailer-verdict-gated SSI `EOFE` on the final image beat | Near-normative subset |
| `test_CoaXPressRx.py` | `CoaXPressRx` | One-lane control/event-payload assembly plus multi-lane receive rotation/alignment through the lane mux and HS FSM, including malformed stream-trailer `EOFE` recovery | Partial protocol |
| `test_CoaXPressEventAckMsg.py` | `CoaXPressEventAckMsg` | Event acknowledgment wire format, section `9.8.3`, Table 30 | Near-normative subset |
| `test_CoaXPressTxLsFsm.py` | `CoaXPressTxLsFsm` | Low-speed idle cadence and default trigger serialization, section `9.3.1.1` / Table 15 | Partial protocol |
| `test_CoaXPressTx.py` | `CoaXPressTx` | Control/event-acknowledgment arbitration and software-trigger path across the TX assembly | RTL-contract with spec packet classes |
| `test_CoaXPressConfig.py` | `CoaXPressConfig` | Control command packet formatting, CRC generation, tag handling, timeout/status-error responses, and SRPv3 response completion through the real `SrpV3AxiLite` ingress path, section `9.6.1.2` / `9.6.2` | Near-normative subset |
| `test_CoaXPressCore.py` | `CoaXPressCore` | AXI-Lite control of tagged config request generation plus software-visible `RxOverflowCnt` / `RxFsmErrorCnt` status behavior at the full-core boundary | RTL-contract with spec request prefix and top-level error-status checks |
| `test_CoaXPressOverFiberBridgeTx.py` | `CoaXPressOverFiberBridgeTx` | CXPoF start/control/payload/terminate words, section `6.3.1` to `6.3.6` in `CXPR-008-2021` | Near-normative subset |
| `test_CoaXPressOverFiberBridgeRx.py` | `CoaXPressOverFiberBridgeRx` | CXPoF start-word decode back into CoaXPress packet and `IO_ACK` words, `/Q/` sequence tracking, classified `/E/` abort/error status, and HKP status parsing | Partial protocol |
| `test_CoaXPressOverFiberBridge.py` | `CoaXPressOverFiberBridge` | Top-level 32b/64b gearbox integration around the bridge leaf mapping and RX bridge status forwarding | RTL-contract with spec framing |
| `test_CoaXPressOverFiberBridgeAxiL.py` | `CoaXPressOverFiberBridgeAxiL` | Software-visible sticky bridge RX status, last-observed sequence/HKP fields, event counters, reset behavior, and HKP classification readback | RTL-contract status consumer |

## Spec Section Notes

### Packet classes and framing

The benches use the packet-class values from `CXP-001-2021` section `9.2.3`
and the generic data-packet framing from Table 19:

- `0x01` stream data
- `0x03` control acknowledge without tag
- `0x06` control acknowledge with tag
- `0x07` event packet
- `0x08` event acknowledgment
- `0x09` heartbeat

`test_CoaXPressEventAckMsg.py` and the TX-side bridge benches are the cleanest
examples of direct packet-type usage because they serialize or decode the wire
symbols directly.

### Trigger and I/O acknowledgment

The low-speed trigger and `IO_ACK` behavior is covered in pieces:

- `test_CoaXPressTxLsFsm.py`
  - exercises the default low-speed trigger byte patterns from section
    `9.3.1.1`, Table 15
- `test_CoaXPressRxLane.py`
  - checks that the receive lane detects `IO_ACK` and resumes the interrupted
    stream state
- `test_CoaXPressTx.py`
  - checks that the software-trigger path reaches the low-speed trigger FSM

This is not yet full trigger coverage. The current RTL-facing benches now cover
both low-speed rates plus the implemented default/inverted trigger byte
patterns, but Extra-LS modes from Table 16 and the broader high-speed trigger
matrix from Table 17 are still open because that wider trigger surface is not
exposed by the current checked-in RTL.

### Control command and acknowledgment traffic

The current checked-in coverage is split:

- `test_CoaXPressConfig.py`
  - checks all four tagged/untagged read/write control-command formatting
    quadrants for section `9.6.1.2` and `9.6.2`
  - drives requests through the real `CoaXPressConfig` / `SrpV3AxiLite`
    ingress path and validates both the serialized config packet and the
    completed SRPv3 response
  - covers config-response timeout and nonzero control-ack status mapping into
    the local SRPv3 AXI-Lite error footer
- `test_CoaXPressRxLane.py` and `test_CoaXPressRx.py`
  - now drive fuller control-ack shapes on the wire: code, size, reply data,
    CRC, and `EOP`
  - prove that receive-side control acknowledgments are forwarded only after
    CRC and `EOP` validation pass

Important limitation:

- `CoaXPressRxLane` now validates the acknowledgment packet trailer before
  pulsing `cfgMaster`, and malformed acknowledgment trailers pulse `rxError`,
  but it still consumes only the reduced code/size/data subset needed by the
  present receive assembly rather than exposing a richer application-facing
  acknowledgment parser

### Heartbeat and event traffic

Heartbeat and event handling is still intentionally narrow, but the receive
parsers now check complete packet framing before producing output pulses:

- `test_CoaXPressRxLane.py`
  - checks the current 12-byte heartbeat payload collector
  - validates heartbeat CRC/`EOP` before forwarding the heartbeat word and
    suppresses bad-CRC heartbeat packets
- `test_CoaXPressEventAckMsg.py`
  - covers event acknowledgment generation on the transmit side
- `test_CoaXPressRxLane.py` and `test_CoaXPressRx.py`
  - drive full event packet framing through event ID, Packet Tag, payload size,
    payload words, CRC, and `EOP`
  - `CoaXPressRxLane` now acknowledges an event only after the CRC and `EOP`
    pass, suppresses bad-CRC events, and recovers for a later clean event
  - event payload is exported through the receive-side event stream with the
    packet tag and event ID preserved as stream metadata

That means these benches now cover the parser/acknowledgment subset of:

- section `9.8.1` event ordering rules
- section `9.8.2` event payload parsing
- event-payload CRC/trailer handling

They now prove a bounded validate-before-release event-payload delivery contract:
payload words are withheld until the trailing CRC and `EOP` pass, bad-CRC events
do not leak payload words, and oversized events are rejected instead of being
partially forwarded.

### Stream data and rectangular image traffic

The image-path benches are the strongest spec-aligned receive tests today:

- `test_CoaXPressRxHsFsm.py`
  - validates rectangular image header and line marker handling against section
    `10.4.6.2` and `10.4.6.3`
  - detects a new image header arriving before the previously declared frame's
    line count has completed
- `test_CoaXPressRx.py`
  - validates both the original one-lane top-level receive assembly and a
    dual-lane lane-rotation path around the same traffic
  - validates four-lane short-frame rotation, malformed-header recovery, and
    repeated single-line image-frame boundaries at the top-level receive
    assembly
  - also carries opt-in four-lane overflow stress benches behind
    `RUN_STRESS_TESTS=1` because those workloads are intentionally heavier than
    the normal regression slice

`test_CoaXPressRxLane.py` also exercises stream packet handling using
spec-shaped stream headers and CRC/`EOP` trailers. The RTL forwards payload as
it arrives, then publishes an in-order trailer verdict marker after the CRC and
`EOP` check. The receive assembly holds only the final packed SSI image beat
until that verdict arrives. If the stream trailer is malformed, the final image
beat is released with SSI `EOFE` set in `TUSER`; if the trailer is clean, the
final beat is released as a normal SSI EOF. This is not a buffered bad-payload
drop contract: earlier payload words may already have been forwarded, and the
downstream consumer is expected to reject or quarantine the frame based on the
terminal `EOFE` bit. Bad stream trailers pulse the lane-level `rxError`, which
the receive assembly aggregates into `rxFsmError` and the core exposes through
the existing `RxFsmErrorCnt` software counter.

### Receive event payload stream

`CoaXPressRxLane` now exposes event payload words on an AXI-stream style
`eventMaster` interface while preserving the legacy `eventAck/eventTag` trailer
completion pulse. The lane buffers up to 16 event payload words and releases
them only after the event CRC and `EOP` trailer pass. The event payload stream
uses `TDEST[7:0]` for the packet tag and publishes the event ID bytes on
`TUSER[31:0]` at the lane boundary. The `CoaXPressRx` assembly crosses that
payload stream into the `cfgClk` domain with an `AxiStreamFifoV2`.

This is a bounded receive-side payload contract, not an unbounded event
transport. Event payloads longer than the internal store are reported as
malformed and suppressed.

### Software-visible overflow and FSM-error status

`test_CoaXPressCore.py` now covers the two receive-status counters exposed to
software through `CoaXPressAxiL`:

- `RxOverflowCnt`
  - holds the image-header output path stalled until the top-level receive
    assembly overflows, then checks that the AXI-Lite counter increments and
    the path drains once backpressure is released
- `RxFsmErrorCnt`
  - injects a full image-header packet with one corrupted repeated-byte field,
    checks that the top-level counter increments, then verifies the count
    stays stable during idle cycles and that a later clean image transaction is
    still accepted
- `coaxpress_core_rx_overflow_does_not_trigger_fsm_error_storm_test`
  - drives sustained receive-data backpressure with long image lines and encodes
    the expected software-facing behavior: overflow should count,
    `RxFsmErrorCnt` should stay at zero, idle should not create an error storm,
    and a later clean frame should still pass
  - the default workload is sized to overflow the RX data path directly; it can
    be tuned with `CXP_RX_OVERFLOW_STORM_FRAME_COUNT` and
    `CXP_RX_OVERFLOW_STORM_LINE_WORD_COUNT`

This is intentionally a top-level software-facing check, not a replacement for
the lower-level malformed-header coverage in `test_CoaXPressRxHsFsm.py`.

### CoaXPress over Fiber bridge

The bridge benches map to `CXPR-008-2021`, especially:

- section `6.3.1` SOP
- section `6.3.2` EOP
- section `6.3.3` IT
- section `6.3.4` HDP
- section `6.3.5` HKP
- section `6.3.6` LSP

Current checked-in coverage:

- `test_CoaXPressOverFiberBridgeTx.py`
  - start-word control bits
  - low-speed rate/update handling
  - partial-lane low-speed payload fill with CoaXPress idle insertion
  - single-lane-enable sweeps with rotating idle fill in the disabled slots
  - payload packing
  - `/T/` plus `/I/` termination
- `test_CoaXPressOverFiberBridgeRx.py`
  - RX start-word decode for normal packets and `IO_ACK`
  - embedded EOP K-code reconstruction for stream marker and packet-end words
  - HKP forwarding, including a housekeeping-to-payload transition and an
    HKP-carried CXP EOP word
  - HKP K-code semantics: all-data nGMII control-mask enforcement,
    per-byte K-code validation through `hkpKCodeMask/hkpKCodeValid`, and
    whole-word classification through `hkpType`
  - `hkpValid/hkpData/hkpEop/hkpSof/hkpWordCount` status for HKP words that are
    forwarded on the reconstructed CXP side, plus `hkpError` for malformed HKP
    control masks or invalid HKP K-code bytes
  - lane-0 `/Q/` sequence tracking through `seqValid/seqData/seqExpected`, with
    `seqError/seqErrorExpected` on skipped sequence values while preserving
    no-output behavior on the CXP word stream
  - classified `/E/` status through `rxError/rxAbort/rxErrorCode` for idle and
    active-packet error ordered sets
  - negative lane-placement checks for `/S/`, `/Q/`, `/T/`, and `/E/`
  - lane-0 `/Q/` no-output behavior, `/E/` packet abort behavior before and
    after payload, and recovery to a following valid low-speed packet
- `test_CoaXPressOverFiberBridge.py`
  - top-level 32b/64b gearbox integration around the bridge leaves
  - RX-side 64b gearbox coverage for classified `/E/` abort/recovery,
    HKP-to-payload status, and lane-0 `/Q/` sequence mismatch/no-output/recovery
    guardrails
- `test_CoaXPressOverFiberBridgeAxiL.py`
  - AXI-Lite readback of sticky bridge RX status bits, last-observed
    sequence/HKP fields, and event counters
  - write-one reset coverage for sticky status and counters
  - named HKP K-code classification sweep through the packed HKP status register

The product-facing bridge status contract is the `CxpofRxStatusType` record in
`CoaXPressPkg.vhd`. The cocotb benches use thin wrapper entities to flatten
that record back to scalar ports only because GHDL/cocotb does not reliably
expose top-level VHDL record fields as child handles. Those wrappers are a test
surface, not the intended RTL integration contract.

`CoaXPressOverFiberBridgeAxiL` makes the bridge RX status software-visible for
the GT wrapper integrations. The GTH/GTY wrapper AXI-Lite port now reports
sticky status, last observed sequence/HKP fields, and counters instead of
returning only a default decode error. The current AxiL regression also sweeps
the named HKP K-code classifications through the packed HKP readback register
so software-visible consumers are not only checked against one EOP case. The
current register map is:

- `0x000`: sticky status bits for `rxError`, `rxAbort`, `seqValid`,
  `seqError`, `hkpValid`, and `hkpError`
- `0x004`: last `rxErrorCode`
- `0x008`: last `seqData`
- `0x00C`: last `seqExpected`
- `0x010`: last `seqErrorExpected`
- `0x014`: last `hkpData`
- `0x018`: packed HKP status: `hkpWordCount[7:0]`, `hkpKCodeMask[11:8]`,
  `hkpKCodeValid[12]`, and `hkpType[19:16]`
- `0x020` to `0x034`: event counters for the six sticky status bits above
- `0x03C`: write-one counter/sticky reset strobe

Current RTL support limits observed while expanding the bridge tests:

- `/Q/` ordered sets are not decoded into the CXP-side word stream. The current
  contract initializes on the first sequence word, expects a 24-bit increment on
  each later `/Q/`, pulses `seqError` on mismatch, reports the expected value,
  and resynchronizes from the received value.
- `/E/` is published through `rxError`, `rxAbort`, and `rxErrorCode` status. Idle
  `/E/`, active-payload `/E/`, malformed control placement, overwrite, sequence
  mismatch, and malformed HKP conditions now have distinct cause codes. When
  `/E/` appears during a packet, the RX bridge aborts the active nGMII packet
  and returns to idle; if the start word was already accepted, the CXP `SOP` and
  packet-type words may already have been emitted, but no synthetic CXP `EOP` is
  generated.
- HKP handling now follows the CXPoF High-Speed K-Code Payload contract: HKP is
  received with nGMII control flags clear, reconstructed on the CXP side with
  K-code flags asserted, validated as K-code bytes, and classified as known CXP
  K-code words where possible. HKP does not define a separate command opcode
  layer in this bridge contract.

## Known Limitations

The current checked-in CoaXPress suite should not be described as full protocol
compliance coverage.

The most important open limits are:

- the four-lane overflow recovery checks are opt-in stress benches because they
  intentionally fill and drain deep receive FIFOs; enable them with
  `RUN_STRESS_TESTS=1`
- receive-side event payload is validated for framing/CRC before ACK and
  released through a bounded application-facing payload interface
- the receive stream-data path now validates CRC/`EOP` trailer framing before
  accepting the next packet and marks malformed frames with SSI `EOFE` on the
  final image beat, but it still streams payload before the trailer result is
  known instead of buffering and dropping a bad frame internally
- trigger coverage still does not include the broader low-speed extra modes or
  the full high-speed trigger matrix, though the low-speed FSM now covers
  active-pulse shortening through a runtime `txPulseWidth` update
- CXPoF bridge coverage now includes `/Q/` sequence mismatch policy, classified
  `/E/` causes, and HKP K-code validation/classification

## Running The Slice

Latest focused validation for the current receive-side SSI `EOFE` work:

```bash
./.venv/bin/python -m pytest -q tests/protocols/coaxpress/test_CoaXPressRx.py
./.venv/bin/python -m pytest -q tests/protocols/coaxpress/test_CoaXPressRxHsFsm.py
./.venv/bin/python -m pytest -q \
  tests/protocols/coaxpress/test_CoaXPressRxLane.py \
  tests/protocols/coaxpress/test_CoaXPressRxWordPacker.py \
  tests/protocols/coaxpress/test_CoaXPressRxLaneMux.py
./.venv/bin/python -m pytest -q \
  tests/protocols/coaxpress/test_CoaXPressCore.py::test_CoaXPressCore
```

Typical local commands:

```bash
./.venv/bin/python -m pytest -n auto --dist=worksteal -q tests/protocols/coaxpress
```

Focused receive-path rerun:

```bash
./.venv/bin/python -m pytest -n auto --dist=worksteal -q \
  tests/protocols/coaxpress/test_CoaXPressRxLane.py \
  tests/protocols/coaxpress/test_CoaXPressRx.py
```

Use `-n 0` only when debugging a single cocotb simulation or preserving serial
log ordering is more important than runtime.
