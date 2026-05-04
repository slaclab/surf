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
| `test_CoaXPressRxWordPacker.py` | `CoaXPressRxWordPacker` | Internal packing helper for receive-path word assembly; not a direct protocol-surface spec bench | RTL-contract |
| `test_CoaXPressRxLaneMux.py` | `CoaXPressRxLaneMux` | Internal lane arbitration and frame-boundary behavior; not a direct protocol-surface spec bench | RTL-contract |
| `test_CoaXPressRxLane.py` | `CoaXPressRxLane` | `CXP-001-2021` packet-type decode, `IO_ACK`, control acknowledgments, heartbeat payload/trailer handling, truncated-event guardrails, and stream header/trailer framing | Partial protocol |
| `test_CoaXPressRxHsFsm.py` | `CoaXPressRxHsFsm` | Rectangular image header and line marker handling from section `10.4.6.2` / `10.4.6.3`, including a dual-lane step/alignment case and incomplete-frame new-header detection | Near-normative subset |
| `test_CoaXPressRx.py` | `CoaXPressRx` | One-lane control/event assembly plus dual-lane receive rotation/alignment through the lane mux and HS FSM | Partial protocol |
| `test_CoaXPressEventAckMsg.py` | `CoaXPressEventAckMsg` | Event acknowledgment wire format, section `9.8.3`, Table 30 | Near-normative subset |
| `test_CoaXPressTxLsFsm.py` | `CoaXPressTxLsFsm` | Low-speed idle cadence and default trigger serialization, section `9.3.1.1` / Table 15 | Partial protocol |
| `test_CoaXPressTx.py` | `CoaXPressTx` | Control/event-acknowledgment arbitration and software-trigger path across the TX assembly | RTL-contract with spec packet classes |
| `test_CoaXPressConfig.py` | `CoaXPressConfig` | Control command packet formatting, CRC generation, tag handling, timeout/status-error responses, and SRPv3 response completion through the real `SrpV3AxiLite` ingress path, section `9.6.1.2` / `9.6.2` | Near-normative subset |
| `test_CoaXPressCore.py` | `CoaXPressCore` | AXI-Lite control of tagged config request generation plus software-visible `RxOverflowCnt` / `RxFsmErrorCnt` status behavior at the full-core boundary | RTL-contract with spec request prefix and top-level error-status checks |
| `test_CoaXPressOverFiberBridgeTx.py` | `CoaXPressOverFiberBridgeTx` | CXPoF start/control/payload/terminate words, section `6.3.1` to `6.3.6` in `CXPR-008-2021` | Near-normative subset |
| `test_CoaXPressOverFiberBridgeRx.py` | `CoaXPressOverFiberBridgeRx` | CXPoF start-word decode back into CoaXPress packet and `IO_ACK` words | Partial protocol |
| `test_CoaXPressOverFiberBridge.py` | `CoaXPressOverFiberBridge` | Top-level 32b/64b gearbox integration around the bridge leaf mapping | RTL-contract with spec framing |

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
  pulsing `cfgMaster`, but it still consumes only the reduced code/size/data
  subset needed by the present receive assembly rather than exposing a richer
  application-facing acknowledgment parser

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
  - event payload is validated for framing/CRC but is not exported through a
    receive-side payload interface

That means these benches now cover the parser/acknowledgment subset of:

- section `9.8.1` event ordering rules
- section `9.8.2` event payload parsing
- event-payload CRC/trailer handling

They still do not prove an application-facing event-payload delivery contract,
because the current RTL exposes only `eventAck` and `eventTag`.

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
it arrives, so the trailer check proves that the lane parser does not accept a
new packet until the declared stream packet has completed; it is not a buffered
bad-payload drop contract.

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
  - negative lane-placement checks for `/S/`, `/Q/`, `/T/`, and `/E/`
  - lane-0 `/Q/` no-output guardrail, `/E/` packet abort behavior before and
    after payload, and recovery to a following valid low-speed packet
- `test_CoaXPressOverFiberBridge.py`
  - top-level 32b/64b gearbox integration around the bridge leaves
  - RX-side 64b gearbox coverage for `/E/` abort/recovery, HKP-to-payload
    transition, and lane-0 `/Q/` no-output/recovery guardrails

Still open on the bridge side:

- normative `/Q/` sequence handling beyond the current no-output/recovery guardrails
- fuller `/E/` error semantics beyond malformed-placement and abort-and-recover guardrails
- full housekeeping protocol semantics beyond raw HKP forwarding and the current
  HKP-to-payload transition check

Current RTL support limits observed while expanding the bridge tests:

- `/Q/` ordered sets are not decoded into any bridge-visible state, sequence
  tracker, status output, or CXP-side indication. The current contract is only
  that `/Q/` in the interpacket gap is suppressed and later valid traffic
  recovers.
- `/E/` has no bridge-visible status output. When it appears during a packet,
  the RX bridge aborts the active nGMII packet and returns to idle; if the start
  word was already accepted, the CXP `SOP` and packet-type words may already
  have been emitted, but no synthetic CXP `EOP` is generated.
- HKP handling is raw forwarding. The RX bridge does not validate HKP content
  semantics or expose a separate housekeeping parser; it reconstructs K-coded
  words and then returns to normal payload/EOP handling.

## Known Limitations

The current checked-in CoaXPress suite should not be described as full protocol
compliance coverage.

The most important open limits are:

- the four-lane overflow recovery checks are opt-in stress benches because they
  intentionally fill and drain deep receive FIFOs; enable them with
  `RUN_STRESS_TESTS=1`
- receive-side event payload is validated for framing/CRC before ACK, but is not
  exposed through an application-facing payload interface
- the receive stream-data path now validates CRC/`EOP` trailer framing before
  accepting the next packet, but payload still streams before the trailer result
  is known
- trigger coverage still does not include the broader low-speed extra modes or
  the full high-speed trigger matrix, though the low-speed FSM now covers
  active-pulse shortening through a runtime `txPulseWidth` update
- CXPoF bridge coverage still does not exhaustively cover normative `/Q/`,
  `/E/`, and full housekeeping protocol semantics

## Running The Slice

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
