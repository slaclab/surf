# Ethernet PTP Support

## Goal and status

Explore and stage reusable IEEE 1588 Precision Time Protocol support for the
SURF Ethernet stack. The first application is an autonomous FPGA endpoint that
receives PTP, exchanges the required delay messages, and disciplines its local
time without relying on Linux `ptp4l`. Rogue may configure and observe the
endpoint, but it is not in the timing loop.

Status: detailed architecture planning. The recommended ordinary-PTP module
boundaries, datapath integration, initial protocol subset, time arithmetic,
servo behavior, and provisional register map are specified below. No RTL or
public interface has been implemented.

## Current SURF architecture

- `ethernet/EthMacCore/rtl/EthMacTop.vhd` is the common MAC integration point.
  It joins asynchronous primary and bypass AXI Stream inputs, checksum and
  pause processing, GMII/XGMII export/import, receive filtering, and output
  FIFOs.
- The physical capture planes are the GMII and XGMII buses used by
  `EthMacRxImportGmii`, `EthMacTxExportGmii`, `EthMacRxImportXgmii`, and
  `EthMacTxExportXgmii`. These leaves document the existing preamble and Start
  Frame Delimiter (SFD) behavior. The SFD is the `0xD5` byte at the end of the
  Ethernet preamble that marks the start of the MAC frame. The first PTP
  implementation should observe the same buses with passive sibling taps so
  the leaf entity interfaces stay unchanged.
- `GigEthCore` connects `EthMacTop` to vendor 1 GbE PCS/PMA blocks through
  GMII. `TenGigEthCore` and `XauiCore` connect it through XGMII.
- The XLGMII import/export leaves are placeholders. `XlauiCore` has only empty
  build manifests. They must not be counted as a working 40 GbE PTP target.
- `Caui4Core` is a separate vendor CMAC-style 100 GbE AXI Stream wrapper and
  does not use `EthMacTop`. Its timestamp integration will be a separate
  vendor-IP exercise.
- The current transceiver-based `GigEthCore` wrappers derive `sysClk125` and
  `sysClk62` from a local reference or optional external PLL. The vendor
  PCS/PMA `rxoutclk` and `txoutclk` ports are left open in the inspected
  wrappers. This is not yet a Synchronous Ethernet clock-recovery path.
- The existing Ethernet AXI Stream format has four `TUSER` bits with
  first/last semantics. Those bits already carry fragment/SOF and end/error
  information and cannot hold a full PTP timestamp or a conventional 16-bit
  transmit tag.
- Existing focused cocotb coverage already exercises the GMII and XGMII
  importer/exporter leaves and an XGMII `EthMacTop` loopback. These are the
  right benches to extend with deterministic time stimulus.

## Initial plain-PTP contract

The first deliverable is a bounded, autonomous PTP TimeReceiver, not a complete
IEEE 1588 ordinary clock. It should interoperate with a configured upstream
TimeTransmitter while remaining small enough to verify exhaustively in RTL.

The release-gating behavior is:

- raw layer-2 PTP with EtherType `0x88F7` and the primary PTP multicast
  destination `01:1B:19:00:00:00`;
- untagged Ethernet frames only;
- PTP version 2, accepting minor-version 0 or 1 and transmitting a
  configurable minor version, initially 1;
- configurable `domainNumber`, default 0, and `transportSpecific = 0`;
- one configured upstream `sourcePortIdentity`; there is no BMCA or role
  election in the first endpoint;
- two-step Sync using Sync and Follow_Up, E2E path delay using Delay_Req and
  Delay_Resp, and passive Announce monitoring;
- autonomous PHC and servo operation after AXI-Lite configuration; Rogue is
  not in the message, timestamp, arithmetic, or control loop; and
- fixed local Ethernet clocks. The numerical PHC is disciplined, but the
  physical Ethernet and application clocks are not frequency-locked by plain
  PTP.

Announce is decoded for `grandmasterIdentity`, `currentUtcOffset`, time-source,
traceability, and leap status. It is not used to choose between masters.
Loss of Announce degrades time-properties validity but does not stop an
otherwise valid configured Sync source. Full BMCA, peer delay, UDP/IPv4,
UDP/IPv6, VLAN tags, unicast negotiation, management/signaling messages,
authentication TLVs, transparent clocks, and TimeTransmitter operation remain
later scope.

Receiving one-step Sync is a useful low-cost extension because it only changes
which origin timestamp is selected. It should be designed into the parser but
is not a first-release exit criterion. Generating one-step Sync is much more
invasive because it modifies a frame in flight and remains later scope.

Default interoperability values should follow the common default-profile
behavior used by linuxptp: Sync every `2^0` seconds, mean Delay_Req interval of
`2^0` seconds, Announce every `2^1` seconds, and Announce receipt timeout of
three intervals. The endpoint must derive observed Sync timeout from the signed
`logMessageInterval` field rather than assume one second. Delay_Req scheduling
should include configurable pseudo-random variation so many endpoints do not
transmit simultaneously.

The local port number defaults to 1. Unless overridden, derive its 64-bit
clock identity from the 48-bit MAC address by inserting `FFFE` in EUI-64 form;
the resulting identity still must be unique in the PTP domain. A transmitted
Delay_Req uses message type `0x1`, message length 44, the configured domain and
minor version, zero correction and origin timestamp, local port identity, the
allocated sequence ID, control field 1, and `logMessageInterval = 0x7F`.

When the Announce `ptpTimescale` flag is set, the PHC represents the continuous
PTP time scale rather than UTC. Preserve `currentUtcOffset`, leap flags, and
traceability as status for an application that needs UTC; do not step the PHC
at a leap second. If a source advertises an arbitrary time scale, synchronization
may continue but the exported time-scale-valid status must reflect it.

## Recommended plain-PTP architecture

The least invasive first implementation is a PTP-aware timestamp tap at the
wire-facing GMII or XGMII bus, paired with the existing raw-Ethernet bypass.
The tap observes the frame actually sent or received, captures time when the
SFD crosses the MAC/PCS interface, and parses enough of the PTP header to
identify that timestamp. This removes the need to carry a tag through every
current MAC FIFO, arbitration, checksum, pause, padding, and filtering stage.

The complete composition and signal-flow drawing appears with the module
inventory below. It separates hierarchy, packet/timestamp traffic, PHC
control, and register access so unrelated connections do not share a routing
plane.

Application frames use the existing primary AXI Stream interface. PTP frames
use the private `0x88F7` bypass between `PtpEndpoint` and `EthMacTop`. The
timestamp taps are passive observers of the same GMII/XGMII buses that connect
the MAC to the PCS/PMA; they do not sit in or modify the frame datapath.

`EthMacTop` already gives bypass traffic priority at a transmit frame boundary.
The timestamp tap measures the actual egress SFD after any wait behind a frame
already in progress, so that variable queueing delay is correctly included in
`t3`. On receive, `EthMacRxBypass` selects `0x88F7` before the normal destination
filter. The endpoint should run the bypass in the `ethClk` domain with
`BYP_COMMON_CLK_G = true`, avoiding a CDC in the PTP packet path.

The current bypass classifier compares bytes 12 and 13 directly. A VLAN frame
therefore presents `0x8100` or `0x88A8` rather than `0x88F7` and will not reach
the PTP endpoint. Supporting one or more VLAN tags requires a deliberate
extension to `EthMacRxBypass`; it is not silently included in the first scope.

### Proposed source tree and module inventory

Create a new reusable area and load it immediately after `EthMacCore` in
`ethernet/ruckus.tcl`:

```text
ethernet/PtpCore/
  ruckus.tcl
  rtl/
    PtpPkg.vhd
    PtpPhc.vhd
    PtpGmiiTimestampTap.vhd
    PtpXgmiiTimestampTap.vhd
    PtpPort.vhd
    PtpServo.vhd
    PtpReg.vhd
    PtpEndpoint.vhd
    EthMacPtpEndpoint.vhd
  wrappers/
    PtpPhcWrapper.vhd
    PtpTimestampTapWrapper.vhd
    PtpEndpointLoopbackWrapper.vhd
```

The exact responsibility of each synthesizable block is:

| Entity | Clock domain | Responsibility |
| --- | --- | --- |
| `PtpPkg` | n/a | Wire constants, message types, port identity, time and event records, init constants, array types, byte-order helpers, timestamp normalization, signed time difference, and correction-field conversion. |
| `PtpPhc` | `phcClk` plus optional read clock | Free-running 48-bit-seconds/32-bit-nanoseconds/32-bit-fraction PHC, nominal and signed rate addends, atomic set/phase operation, PPS, validity, discontinuity status, local coherent snapshot, and one optional clock-domain-safe snapshot/read interface. |
| `Ptp[Gmii\|Xgmii]TimestampTap` | `ethClk` | The selected physical-interface variant observes RX and TX, detects SFD, records the PHC value, parses an untagged PTP header, and emits a keyed event after end-of-frame with physical error status. The XGMII variant also applies the correct sub-cycle byte offset for legal start-lane alignment. |
| `PtpPort` | `ethClk` | Owns one fixed-role IEEE 1588 port: raw AXI Stream parsing and Delay_Req generation, keyed RX/TX timestamp association, bounded Sync/Follow_Up and Delay_Req/Delay_Resp tables, Announce/message timers, E2E correction arithmetic, source checks, and port counters. |
| `PtpServo` | `ethClk` | Filters path-delay and offset samples, performs acquisition and PI rate control, produces bounded automatic phase/rate commands, and owns lock, holdover, and fault qualification. It remains separate because it is a replaceable control algorithm, not packet-port behavior. |
| `PtpReg` | `ethClk` | Stable AXI-Lite register map for identity, profile, manual PHC commands, servo parameters, latency calibration, snapshots, counters, and interrupts. This follows the existing SURF `*Reg` naming pattern. Timing-control ports are direct RTL signals rather than AXI transactions. |
| `PtpEndpoint` | `ethClk` | Composes `PtpPort`, `PtpServo`, `PtpPhc`, and `PtpReg`; owns the small manual-versus-servo PHC command selector; and exposes raw bypass streams, timestamp-tap events, AXI-Lite, time/PPS, and summarized state. |
| `EthMacPtpEndpoint` | `ethClk` plus primary clock | Compatibility composition around the unchanged `EthMacTop`: enables the `0x88F7` bypass, instantiates the proper tap for `PHY_TYPE_G`, and connects `PtpEndpoint`. Existing application traffic remains on the primary stream. |

### PtpCore RTL composition and signal flow

![PtpCore RTL composition and signal flow](PtpCoreArchitecture.svg)

The drawing uses manually placed boxes and straight, orthogonal connections;
there is no automatic graph routing. A block repeated in more than one lane is
the same RTL entity, not a second instance. Only one timestamp-tap variant is
instantiated, selected by `PHY_TYPE_G`.

`PtpPkg.vhd` is not instantiated as a hardware block. It is the shared
compile-time package imported by the PTP entities for records, constants,
initialization values, field helpers, and time arithmetic.

For completeness, the point-to-point interfaces are:

| Producer | Interface | Consumer |
| --- | --- | --- |
| `PtpPort` | Raw PTP TX AXI Stream | `EthMacTop` bypass input |
| `EthMacTop` | Raw PTP RX AXI Stream | `PtpPort` |
| `EthMacTop` | TX/RX GMII or XGMII | PCS/PMA |
| GMII/XGMII bus | Passive RX/TX observation | Selected timestamp tap |
| `PtpPhc` | Current PHC time | Selected timestamp tap |
| Selected timestamp tap | Keyed RX/TX SFD timestamp event | `PtpPort` |
| `PtpPort` | Offset and path-delay sample | `PtpServo` |
| `PtpServo` | Automatic PHC command | Selector inside `PtpEndpoint` |
| `PtpReg` | Manual PHC command | Selector inside `PtpEndpoint` |
| Selector inside `PtpEndpoint` | Selected PHC command | `PtpPhc` |
| `PtpReg` | Port and servo configuration | `PtpPort`, `PtpServo` |
| `PtpPort`, `PtpServo`, `PtpPhc` | Status, counters, and snapshots | `PtpReg` |
| `PtpPhc` | Time, PPS, validity, and coherent readback | Application logic |

The manual-versus-servo selection is intentionally not a separate module.
`PtpReg` forms manual commands, `PtpServo` forms automatic commands,
`PtpEndpoint` selects and handshakes one command, and `PtpPhc` executes it. The
recommended policy is:

- while the servo is enabled, only automatic commands are eligible;
- while the servo is disabled, only manual commands are eligible;
- a disallowed manual request sets a sticky conflict/rejected status rather
  than silently overriding the servo; and
- after accepting a command, `PtpEndpoint` holds both the command and its
  source until `PtpPhc` acknowledges it, so a mode change cannot switch the
  source in the middle of an operation.

Changing servo enable state should wait until no PHC command is active. On a
transition to manual mode, hold or reset the servo integrator; on a transition
back to automatic mode, restart acquisition instead of applying the stale
integrator state.

This is intentionally not a one-file-per-operation design. Parsing, message
generation, matching tables, timers, and E2E arithmetic all mutate the same
PTP port state and are not expected to have independent users, so they belong
as internal records/process sections in `PtpPort`. Keep separate entities where
there is a durable boundary: PHC versus protocol policy, servo versus packet
state, AXI-Lite versus the timing loop, GMII versus XGMII physical decoding,
and generic endpoint versus MAC composition. A distinct clock domain must be
explicit in ports and implementation, but it does not by itself require a new
PTP-named public entity: `PtpPhc` can own its readback crossing by instantiating
the existing SURF CDC primitives internally. Extract another public child only
when it has an independently useful interface or verification complexity that
cannot be managed through its parent.

The corresponding PyRogue package should live under
`python/surf/ethernet/ptp/`. Use private implementation files `_PtpPhc.py`,
`_PtpServo.py`, and `_PtpEndpoint.py`, re-exported from `__init__.py`. These
classes mirror hardware registers and do not implement the servo.

### Shared types and narrow interfaces

`PtpPkg` should define, at minimum:

- `PtpTimeType`: 48-bit seconds, 32-bit nanoseconds, and 32-bit fractional
  nanoseconds for the running clock;
- `PtpTimestampType`: 48-bit seconds, 32-bit nanoseconds, and the upper 16
  fractional bits for captured protocol arithmetic;
- `PtpPortIdentityType`: 64-bit clock identity plus 16-bit port number;
- `PtpEventKeyType`: direction, 4-bit message type, 8-bit domain,
  `sourcePortIdentity`, and 16-bit sequence ID;
- `PtpMacTimestampType`: key, timestamp, lane/reference-plane information,
  and valid/error flags;
- decoded Sync, Follow_Up, Delay_Resp, and Announce records; and
- direct `PtpPhcControlType`, `PtpPhcStatusType`, servo configuration, and
  servo status records with initialization constants.

Use a valid/ready interface around timestamp-tap events and completed
measurement records. Internal decoded-message queues follow the same
handshake discipline. A four-entry timestamp-event FIFO, four Sync/Follow_Up
association entries, and four outstanding Delay_Req entries are sufficient
initial defaults and must be generics. PTP message rates are low, but overflow
behavior still has to be deterministic and counted.

Inside `PtpPort`, organize the single-clock state as named subrecords for RX
decode, TX generation, Sync association, delay association, timers, and
counters under the normal `RegType`/`REG_INIT_C`/`r`/`rin` pattern. Pure field
decode and time-arithmetic helpers belong in `PtpPkg`. The useful public
contracts are raw RX/TX AXI Stream, RX/TX tap events, port configuration/status,
and a valid measurement record for the servo. Decoded intermediate messages
do not need public entity boundaries merely to make the implementation appear
layered; cocotb can verify them through packet input, measurement output, and
counters.

The tap emits an event only after enough frame state is known to attach an
error indication. It records time immediately at SFD, then parses Ethernet
bytes 12 and 13 and PTP header fields while the frame continues. For untagged
PTP, the relevant PTP header byte offsets are:

| PTP offset | Field |
| ---: | --- |
| 0 | `transportSpecific[7:4]`, `messageType[3:0]` |
| 1 | `minorVersionPTP[7:4]`, `versionPTP[3:0]` |
| 2-3 | `messageLength` |
| 4 | `domainNumber` |
| 6-7 | `flagField` |
| 8-15 | signed 64-bit correction field in units of `2^-16` ns |
| 20-29 | `sourcePortIdentity` |
| 30-31 | `sequenceId` |
| 32 | `controlField` |
| 33 | signed `logMessageInterval` |

The common PTP header is 34 bytes. Sync, Delay_Req, and Follow_Up are 44-byte
PTP messages, Delay_Resp is 54 bytes, and Announce is 64 bytes before optional
TLVs. The RX codec inside `PtpPort` must use `messageLength`, ignore legal
Ethernet padding, reject truncation, and skip unknown TLVs without trying to
interpret them.

### Receive and transmit behavior

The receive sequence is:

1. The RX tap captures the local time at SFD and later emits a key for a valid
   PTP event frame. For the initial E2E endpoint, only Sync needs its RX
   timestamp; capturing all PTP event message types keeps the tap reusable.
2. `EthMacTop` checks CRC and frame shape, routes outer EtherType `0x88F7` to
   its bypass, and crosses no clock because the bypass uses `ethClk`.
3. The RX codec in `PtpPort` validates the completed frame. A bad-CRC/EOFE
   frame never becomes a protocol message even if a tap event was already
   created.
4. The port's association table joins the Sync frame with its timestamp. A
   dropped bypass frame produces an orphan tap event that expires and
   increments a counter; it cannot be associated with a later frame by FIFO
   order alone.
5. The same port state accepts Sync and Follow_Up in either order and emits a
   master-to-receiver measurement only after source, domain, and sequence all
   match.

The transmit sequence is:

1. After a valid source and Sync have been observed, the `PtpPort` transmit
   state builds Delay_Req with the next sequence ID.
2. The raw frame enters the high-priority MAC bypass. A request is outstanding
   only after the first AXI beat is accepted; an abort or reset cancels it.
3. The TX tap observes the actual GMII/XGMII frame, captures `t3` at SFD, and
   parses the transmitted source identity and sequence ID.
4. `PtpPort` records `t3` only when the tap key matches an outstanding local
   request. Sequence wrap is unambiguous because outstanding depth and timeout
   are bounded well below 65,536 requests.
5. A Delay_Resp is accepted only when its `requestingPortIdentity` equals the
   local port identity, its source equals the configured upstream port, and
   its sequence ID identifies an outstanding request.

The independent key-based event path is the recommended first implementation.
A generic per-frame request/tag metadata plane may still be useful for
non-PTP hardware timestamp users, but it is no longer a dependency for the
autonomous endpoint and should be a separate later design.

### Timestamp capture and reference plane

The timestamp contract is the first bit of the Ethernet Start Frame Delimiter
(SFD) at the MAC/PCS interface, expressed on the local PHC. It is not initially
a timestamp at the connector or remote fiber.

- GMII observes one byte per enabled clock. Capture when `0xD5` is accepted as
  SFD. Initial 1000BASE-X support has `ethClkEn = 1`; 10/100 Mb/s MII-style
  clock-enable behavior is not a first-release claim.
- XGMII detects `/S/` in each legal lane position. If the PHC sample represents
  the lane-0 boundary of that word, the first SFD bit is
  `sample + (startLane + 7) * 0.8 ns`: 5.6 ns for start lane 0 and 8.8 ns for
  start lane 4, with normal carry into the next XGMII cycle. Lane alignment
  must be represented in the fractional field rather than rounded to a 6.4 ns
  cycle.
- RX raw capture occurs later than wire ingress, so a configured positive
  `ingressLatency` is subtracted. TX capture occurs earlier than wire egress,
  so a configured positive `egressLatency` is added. Each is a signed 64-bit
  `2^-16` ns value, and each is applied exactly once in the tap.
- The tap reports physical coding/error indications. Final validity also uses
  the MAC AXI Stream EOFE/CRC result in the `PtpPort` RX codec.

PCS/PMA, transceiver, SFP, and board latency can be fixed, reset-dependent, or
variable. Calibration registers can translate the MAC reference plane toward
a connector reference plane, but no wire-level accuracy claim is valid until
that latency and its reset distribution have been measured.

### Time representation and PHC behavior

Use 32 fractional nanosecond bits in the PHC rather than only 16. The nominal
125 MHz increment is exactly 8 ns. The 156.25 MHz increment is 6.4 ns and
rounding it in Q32 contributes less than 0.02 ppb of rate error; Q16 would
introduce approximately 1 ppm unless additional residual arithmetic were
added. The 16 fractional bits in a correction field and captured metadata are
the upper 16 bits of the PHC fraction.

`PtpPhc` keeps a 64-bit unsigned nominal addend and a signed rate addend,
both in Q32 ns per `phcClk` tick. Every tick it adds
`nominalAddend + rateAddend`, normalizes nanoseconds at 1,000,000,000, and
increments the 48-bit seconds field. The design must detect addend underflow,
time overflow, and illegal nanosecond set values rather than wrap silently.

The PHC has one control command interface. `PtpEndpoint`, not `PtpPhc`,
arbitrates automatic servo commands against manual register commands so the
PHC contains timekeeping mechanics but no PTP port or operator policy. The
direct `phcTime` output, PPS generation, coherent local snapshots, and the
optional single read-domain crossing all belong in `PtpPhc` because together
they define how consumers observe one atomic hardware timebase.

The planned public shape is approximately:

```text
PtpPhc
  generics: TPD/RST conventions, CLK_FREQ_G, READ_COMMON_CLK_G
  phcClk, phcRst
  phcControl, phcStatus       direct command/acknowledge records
  phcTime                     cycle-accurate local-domain time
  pps, timeValid
  timeReadClk, timeReadRst
  timeReadReq
  timeReadTime, timeReadValid, timeReadSequence
```

`CLK_FREQ_G` is converted at elaboration to the nominal Q32 increment. The
read interface is transactional rather than a continuously changing
asynchronous bus: each accepted request returns exactly one coherent record.
If the read side is unused, its input ports take inactive defaults and the CDC
logic may be removed by synthesis.

Clock operations have direct command/acknowledge handshakes:

- coherent snapshot into shadow status registers;
- absolute set from shadow seconds/nanoseconds/fraction;
- signed atomic phase step in Q16 ns;
- signed rate-addend replacement;
- time-valid set/clear; and
- PPS enable and optional pulse-width control.

At reset the PHC free-runs from zero at its nominal addend but `timeValid` is
false. Link loss resets packet association and protocol state, not the PHC or
its last rate command. An explicit PTP/system reset may clear the PHC.

Normal rollover emits one PPS pulse. An absolute set or a large phase step
suppresses PPS for that update cycle and raises `timeDiscontinuity`, avoiding
an ambiguous extra pulse. In acquisition the servo may step once if allowed.
In tracking/locked states it must slew and preserve monotonic time; a negative
step is rejected while monotonic mode is enabled.

### E2E arithmetic

For a completed two-step exchange:

- `t1` is `preciseOriginTimestamp` in Follow_Up;
- `t2` is the calibrated local ingress timestamp of Sync;
- `t3` is the calibrated local egress timestamp of Delay_Req; and
- `t4` is `receiveTimestamp` in Delay_Resp.

Let `cSync` be the sum of the signed correction fields from Sync and matching
Follow_Up, and let `cDelay` be the Delay_Resp correction field. All are Q16 ns.
The engine computes:

```text
forwardDelay = t2 - (t1 + cSync)
reverseDelay = (t4 - cDelay) - t3
meanPathDelay = (forwardDelay + reverseDelay) / 2
offsetFromMaster = forwardDelay - meanPathDelay
```

A positive `offsetFromMaster` means the local PHC is ahead and must be slowed
or stepped backward according to policy. The sign convention must have a
directed unit test; it must not be inferred from whether a particular
simulation happens to converge.

Use at least 128-bit signed intermediates for the two cross-clock differences.
Before initial synchronization, each difference can contain the entire epoch
offset even though that offset cancels when the two paths are added. Do not
apply a small network-delay bound to `forwardDelay` or `reverseDelay`
individually. Reject a transaction if an intermediate overflows, the resulting
mean path delay is negative or exceeds `maxPathDelay`, the final offset cannot
be represented by the selected actuator, or the source/domain/identity
relation is invalid. Do not saturate a bad measurement into a plausible value.

`delayAsymmetry` is separate from ingress/egress hardware latency. Define it as
`(forward physical delay - reverse physical delay) / 2`; compute
`correctedOffset = rawOffset - delayAsymmetry`, and report both values so the
calibration remains auditable.

### Protocol and servo state machines

`PtpEndpoint` uses these port states:

| State | Behavior and transition |
| --- | --- |
| `DISABLED` | Parser may count traffic, but no Delay_Req or clock update occurs. Enable moves to `LISTENING`. |
| `LISTENING` | Waits for the configured domain/source and a valid Sync pair. PHC continues at nominal or last rate. |
| `ACQUIRING` | Builds a valid delay estimate, permits one bounded initial phase step, estimates oscillator frequency, and rejects outliers. |
| `TRACKING` | Runs the PI controller and bounded slew. Moves to `LOCKED` after offset/delay thresholds are met for a configured count. |
| `LOCKED` | Continues PI updates with a tighter step prohibition. Excess error for a configured count returns to `TRACKING`. |
| `HOLDOVER` | On link or Sync timeout, freezes the last good rate command, ages time quality, and stops new Delay_Req. Valid traffic returns to `ACQUIRING`; holdover expiry clears `timeValid`. |
| `FAULT` | Entered on PHC/math overflow, persistent timestamp overflow, or an explicitly fatal configuration error. Clock updates stop until clear/reset. |

Announce age, Sync age, Follow_Up age, Delay_Resp age, and timestamp-association
age are independent timers. Follow_Up may legally arrive before the Sync is
delivered through a software or hardware stack, so the matching table must
support either order. A new mismatched sequence must not overwrite a still
valid pair unless table replacement policy and a counter make that loss
visible.

Delay_Req should start only after a valid Sync source is established. A
16-bit LFSR may vary the configured mean request interval between 0.5 and 1.5
times its nominal value. No new request is launched when the outstanding table
is full. Timeout retires an entry and increments a missing-response counter.

The first servo should be pure RTL and use fixed-point arithmetic:

1. Reject an offset/path-delay sample outside configured absolute and slew-rate
   bounds.
2. Apply a median-of-five path-delay filter, followed optionally by a
   configurable first-order IIR. Five entries are cheap enough for RTL and
   reject isolated switched-network queue spikes.
3. On the first good samples, estimate the required correction as the negative
   offset change over elapsed local time. Clamp it to `maxFrequencyPpb`.
4. Define a positive rate addend as making the PHC faster. For tracking, use
   `I = clamp(I - Ki*offset*sampleInterval)` and
   `rateAddend = clamp(I - Kp*offset)`. Positive offset therefore produces a
   negative rate correction and slows the PHC.
5. Convert rate command in ppb to the signed Q32 addend. Freeze the last
   integral term in holdover and prevent integrator wind-up at either clamp.

Use configurable fixed-point `Kp` and `Ki`, not hard-coded real-number gains.
Provisional safe limits are `maxFrequencyPpb = 100000` and
`maxSlewPpb = 50000`; actual defaults must be selected from closed-loop
simulation. Similarly, a 20 us first-step threshold, 100 ns lock threshold for
eight samples, and 1 us unlock threshold for three samples are starting test
values, not accuracy claims. On the first complete E2E measurement, an allowed
offset above the first-step threshold is corrected directly. If it is too large
for the signed Q16 phase-step port, the servo uses the PHC absolute-set port
while `timeValid` is false. `timeValid` is asserted only after a complete,
valid Sync/delay solution has established both epoch and path delay.

### Clock-domain crossing and application use

For the first GMII and XGMII endpoints, put `PtpPhc`, both taps, `PtpPort`, and
`PtpServo` in the common `ethClk` domain. That is the only domain in which the
exported running timestamp is cycle-accurate.

Do not synchronize the bits of a multiword timestamp independently. `PtpPhc`
should own one optional coherent read interface in addition to its direct
`phcClk`-domain output. A `timeReadReq` from `timeReadClk` crosses into
`phcClk`, atomically captures time plus a sequence number and validity, and
returns the record with `timeReadValid` through a request/acknowledge toggle or
`SynchronizerFifo`. A `READ_COMMON_CLK_G` generic bypasses unnecessary CDC
logic when the clocks are identical.

This integrated interface is suitable for registers, telemetry, and coarse
application time. It does not make `timeReadClk` phase-aligned, and CDC latency
makes the received snapshot stale by a bounded but variable number of cycles.
One read domain is enough for the initial endpoint. Do not add a standalone
`PtpTimeSnapshotCdc` or a vector of read clocks until a concrete multi-domain
consumer requires one.

For precise application actions, initially keep the compare/event generator
in `phcClk` and synchronize only its one-shot event into the destination
domain. A later destination-clock replica requires an explicit frequency and
phase-transfer design and must publish its uncertainty. Plain PTP does not
silently provide that physical clock synchronization.

## Integration into existing Ethernet and GT cores

### `EthMacTop` integration strategy

Keep the public `EthMacTop` entity and all current submodules unchanged for the
first implementation. `EthMacPtpEndpoint` instantiates it with:

```text
BYP_EN_G         = true
BYP_ETH_TYPE_G   = x"88F7"
BYP_COMMON_CLK_G = true
bypClk/bypRst    = ethClk/ethRst
```

It connects the private bypass streams directly to `PtpEndpoint`, taps the
external GMII/XGMII ports in parallel, and leaves the public primary stream
contract untouched. This approach avoids new ports on `EthMacTop`, changes to
`EthMacTxFifo`, tag propagation through `EthMacTxBypass`, or timestamp metadata
through `EthMacRxFifo`.

The compatibility price is that timestamps are PTP-header keyed rather than a
generic user-supplied tag. That is an appropriate first boundary for an FPGA
PTP endpoint. If a general NIC-style timestamp API is later required, add a
separate metadata-plane RFC rather than weakening this key association.

### Required 7-series wrapper work for plain PTP

Plain PTP requires no change to a GT primitive or generated PCS/PMA core. The
changes are SURF composition around existing cores:

| Path | Plain-PTP work | Generated GT/IP change |
| --- | --- | --- |
| 1 Gb/s Kintex-7 GTX | Add `ethernet/GigEthCore/gtx7/rtl/GigEthGtx7Ptp.vhd`. It retains the existing core/config/DRP logic, replaces the local `EthMacTop` composition with `EthMacPtpEndpoint`, taps internal GMII, runs the PHC at `sysClk125`, and adds a PTP AXI-Lite window at base + `0x2000` after the existing Ethernet (`0x0000`) and DRP (`0x1000`) windows. The legacy `GigEthGtx7` remains unchanged. | None. Reuse `images/GigEthGtx7Core.dcp` unchanged. Do not expose or use `txoutclk`, `rxoutclk`, TX phase alignment, or PICXO for ordinary PTP. |
| 10 Gb/s Kintex-7 GTX | After the 1 Gb/s path, add `ethernet/TenGigEthCore/gtx7/rtl/TenGigEthGtx7Ptp.vhd`. Tap internal XGMII, run the PHC at `phyClk`, and add a two-slot AXI-Lite crossbar with Ethernet at base + `0x0000` and PTP at base + `0x1000`. The sibling may add `AXIL_BASE_ADDR_G` because it is a new public entity. | None. Reuse `ip/TenGigEthGtx7Core.dcp` and `.xci` unchanged. Keep `rxrecclk_out` open for plain PTP. |
| Other GMII/XGMII GT families | Add family-specific PTP siblings only when a concrete user needs them. They reuse `EthMacPtpEndpoint` and the common tap/endpoint tests. | None expected for ordinary PTP; verify the family wrapper's MAC clock continuity and latency. |
| 100 Gb/s `Caui4Core` | Separate future integration using the vendor CMAC timestamp interface or an AXI-side contract. | Vendor-core-specific investigation required. |

The new 1 Gb/s wrapper initially duplicates a small amount of composition from
`GigEthGtx7`. Do not refactor every family wrapper merely to remove that
duplication. If a second PTP wrapper makes the common PHY boundary clear, a
later narrow refactor can extract it while keeping all legacy entity ports and
address maps unchanged.

The ordinary-PTP capture point is GMII/XGMII, so fixed PCS/PMA latency belongs
in calibration. Exposing recovered clocks, changing `TXOUTCLKSEL`, taking DRP
ownership, disabling buffers, or regenerating a transceiver checkpoint does
not improve this plain-PTP architecture. Those are specifically SyncE/White
Rabbit tasks described later.

### Provisional AXI-Lite register map

Reserve one 4 KiB endpoint window. Offsets are provisional until the package
and PyRogue model are reviewed, but keeping these functional blocks separated
prevents later register churn:

| Range | Contents |
| --- | --- |
| `0x000-0x0FF` | Version/capabilities, enable, servo enable, monotonic/initial-step policy, clear-fault/counter pulses, domain/minor version, local clock identity/port/MAC, configured source identity, IRQ status/mask, and summarized state. |
| `0x100-0x1FF` | PHC coherent snapshot, set-time shadow words and commit, signed phase-step shadow and commit, nominal/rate addends, time validity, discontinuity, PPS configuration, and command busy/ack/error. |
| `0x200-0x2FF` | Signed log intervals, Sync/Follow_Up/Delay_Resp/Announce/association timeouts, Delay_Req LFSR seed/variability, accepted minor versions, and source-check policy. |
| `0x300-0x3FF` | Servo `Kp`/`Ki` formats and values, initial-step threshold, lock/unlock thresholds and counts, frequency/slew clamps, filter enable/length, and holdover expiry. |
| `0x400-0x4FF` | Signed Q16 ingress latency, egress latency, delay asymmetry, maximum path delay, outlier limits, and calibration-valid/provenance fields. |
| `0x500-0x5FF` | Atomic measurement snapshot: raw/corrected offset, raw/filtered mean path delay, frequency command, last `t1`-`t4`, source/grandmaster identity, time properties, sequence IDs, and message ages. |
| `0x600-0x7FF` | 32-bit counters by message type plus bad version/domain/source/length, bad CRC/EOFE, duplicate, timeout, orphan timestamp/frame, FIFO overflow, rejected measurement, servo transition, holdover, and fault cause. |
| `0x800-0xFFF` | Reserved for later external timestamp/per-out channels and profile extensions. Reads return zero until allocated. |

Multiword time, identity, offset, path-delay, and counter reads use an explicit
snapshot command. Multiword writes use shadow registers and a commit strobe.
Unmapped accesses return `AXI_RESP_DECERR_C`. Pulse and clear-on-write behavior
must be called out in both RTL descriptions and PyRogue.

## White Rabbit and Synchronous Ethernet follow-on

White Rabbit is not simply a more accurate packet servo. The White Rabbit
Specification combines PTP with physical-layer syntonization using Synchronous
Ethernet and precise knowledge of link delay and asymmetry. IEEE 1588-2019
generalized White Rabbit as the High Accuracy default PTP profile.

The PTP work should preserve a future path to these additional layers:

1. A PHY that exposes a stable recovered receive clock and has deterministic,
   measurable transmit and receive latency.
2. A clock-control path that can syntonize the local/transmit reference to the
   recovered upstream clock. This can use a board-level PLL/DPLL or tunable
   oscillator, or a validated device-specific all-digital transceiver DPLL.
3. Fine phase measurement between recovered and local clocks, traditionally a
   DDMTD-style phase detector, plus a phase actuator.
4. Fixed-delay and asymmetry calibration for the FPGA, board, SFP, wavelength,
   and fiber link.
5. High Accuracy/White Rabbit signaling, link setup, delay calculation, state,
   and fallback to ordinary PTP behavior.
6. Stable 1 PPS and frequency outputs, lock/holdover qualification, and
   calibration provenance.

An external controllable oscillator is not required for ordinary PTP. A
fractional PHC can numerically correct its rate while the FPGA and Ethernet
clocks continue to run from a fixed local oscillator. This synchronizes the
represented time, but it does not frequency-lock physical application clocks;
PPS edges are also quantized by the chosen output clock unless a finer phase
actuator is provided.

For White Rabbit, the implementation mechanism is optional but the behavior
is not: the endpoint must transfer frequency with SyncE and control the local
or transmit clock relative to the recovered clock. Viable implementation tiers
are:

1. An external low-jitter DPLL or VCXO/DAC clock loop. This is the established,
   lowest-integration-risk path and can also discipline application clocks.
2. An FPGA transceiver phase-interpolator or fractional-QPLL DPLL. AMD
   documents such digital VCXO replacements for 7-series and newer families,
   but they are device-, PHY-, and clock-topology-specific and require jitter,
   holdover, deterministic-latency, and interoperability validation.
3. A fixed oscillator with only a numerical PHC. This is sufficient for the
   initial ordinary-PTP endpoint but is not a complete SyncE/White Rabbit
   implementation.

### 7-series XAPP589 feasibility

AMD XAPP589 is a credible on-chip SyncE actuator for a Kintex-7 GTX design. It
uses the GTX transmit phase interpolator, controlled through DRP by a fabric
DPLL, to pull an individual serial transmitter by up to approximately
+/-160 ppm. The reference design explicitly lists SyncE and IEEE 1588 among
its applications, was hardware-tested on an XC7K325T, and estimates one GTX
PICXO at 940 LUTs, 992 registers, 17 SRLs, and 355 occupied slices. It does not
consume a board pin or require a controllable oscillator.

The documented phase stepping adds about 0.01 to 0.03 UI peak-to-peak of
transmit jitter, equivalent to roughly 8 to 24 ps at the 1.25 Gb/s
1000BASE-X line rate. XAPP589 recommends a closed-loop bandwidth below 100 Hz
for best clock cleaning, with higher gains optionally used during acquisition.
Those figures are encouraging but are not a substitute for measurement with
the selected GTX placement, reference oscillator, SFP, and link partner.

A 1000BASE-X integration would use this clock topology:

```text
fixed 125 MHz reference ---> GTX CPLL ---> GTX TX phase interpolator ---> TX
                                               ^
                                               | DRP writes
RX ---> GTX CDR ---> recovered RX clock ---> XAPP589 PICXO DPLL
                                               ^
GTX TXOUTCLKPMA ---> BUFG ----------------------+
          |
          +---> 1000BASE-X TX user-clock generation ---> MAC / PHC clocks
```

For a 1 Gb/s 7-series GTX, the PCS/PMA `TXOUTCLK` and `RXOUTCLK` are nominally
62.5 MHz while its user clocks are 62.5 MHz and 125 MHz. The supported PCS/PMA
clocking pattern derives those user clocks from `TXOUTCLK`; this becomes
important once PICXO moves the transmit frequency away from the fixed board
reference. The fixed clock remains the GTX CPLL reference and a free-running
startup/reset reference. On link acquisition, the recovered RX clock becomes
the PICXO reference. On reference loss, the integration must deliberately
select nominal-frequency restart or holdover at the last valid correction.

The present SURF `GigEthGtx7Core.dcp` exposes `txoutclk`, `rxoutclk`, and the
GTX DRP, and its transmit buffer is enabled. It is not otherwise PICXO-ready:

- `TXDLY_LCFG` is `9'h030`, leaving required bit 2 clear;
- `PCS_RSVD_ATTR` is zero, leaving required bit 1 clear;
- `TXPHALIGN`, `TXPHALIGNEN`, and `TXPHOVRDEN` are tied low instead of high;
- `TXOUTCLKSEL` is `001` instead of the required `TXOUTCLKPMA` value `010`;
- the SURF wrapper discards both recovered/output clocks and clocks DRP from
  the fixed 125 MHz domain.

These settings are inside an opaque Vivado 2016.4 checkpoint. A maintainable
implementation therefore needs a regenerated PCS/PMA example/transceiver
wrapper with the XAPP589 attributes and connections, rather than treating
PICXO as an add-on around the current checkpoint or relying on netlist edits.
The regenerated wrapper should retain the transmit buffer, expose the two GT
clocks, expose/reset-coordinate the TX PMA, and use `TXOUTCLK` for the PICXO
clock and GTX DRP clock as required by XAPP589.

PICXO must own the GTX DRP during normal operation. Its supplied arbiter gives
occasional DRP access to a user client. SURF's `AxiLiteToDrp` can remain that
client by enabling its arbitration and mapping `drpReq` to
`DRP_USER_REQ_I` and the inverse of `DRPBUSY_O` to `drpGnt`. Because the
PICXO user DRP interface is synchronous to the nominal 62.5 MHz
`TXOUTCLK_I`, the AXI-Lite bridge must either run in that domain or use its
asynchronous-clock mode; the existing fixed-125-MHz common-clock connection
is not valid for this topology.

XAPP589 solves an important but bounded part of White Rabbit:

- It can implement physical-layer frequency transfer and produce a
  TXOUTCLK-derived clock synchronous to the recovered reference.
- Its phase/frequency detector, loop filter, direct frequency-offset control,
  hold input, and error/overflow outputs support acquisition and holdover
  control. Lock qualification still needs to be implemented around those
  signals; the macro has no single `locked` output.
- The stock interface does not expose the arbitrary, wrap-safe sub-cycle
  phase-setpoint actuator required by the White Rabbit slave offset servo.
  It also does not provide PCS timestamps, DDMTD-quality phase measurements,
  deterministic PHY latency, calibration-pattern support, or delay/asymmetry
  calibration. Extending the supplied phase accumulator might eventually
  provide a phase actuator, but that is a separate feasibility item and must
  not be assumed from the unmodified macro.

The first proof of concept should therefore be a 1 Gb/s, hardware-first SyncE
experiment, isolated behind a new optional wrapper so legacy `GigEthGtx7`
users are unchanged:

1. Obtain and license-review the XAPP589 VHDL/IP package and spreadsheet.
2. Regenerate the 1000BASE-X GTX wrapper with the mandatory PICXO settings and
   `TXOUTCLK`-derived 62.5/125 MHz user clocks.
3. Integrate PICXO reset sequencing and its DRP arbiter, with AXI-Lite access
   only through the PICXO user port.
4. Expose loop gains, hold/direct-offset control, error, accumulator,
   overflow, link, and derived lock/holdover status.
5. On hardware, verify link acquisition, frequency tracking over expected
   oscillator error, reference-loss holdover/reacquisition, serial jitter,
   and reset-to-reset behavior before connecting the clock to a PTP PHC.

The XAPP589 example design has no supported functional or timing simulation,
so simulation should cover SURF control, arbitration, and fault logic while
frequency pull, jitter, and interoperability remain explicit hardware exit
criteria. A 10 Gb/s experiment is possible in principle because XAPP589
supports Kintex-7 GTX rates through 12.5 Gb/s, but it adds QPLL, PCS/PMA, and
DRP/shared-logic integration risk and should follow the 1 Gb/s proof.

The existing `GigEthCore` is a useful ordinary-Ethernet reference but cannot
be declared White Rabbit capable as-is: its inspected wrappers discard the
PCS/PMA recovered clock outputs and drive the user clocks from the local
`sysClk125/sysClk62` tree. A White Rabbit phase should introduce a dedicated
fixed-latency 1000BASE-X/SyncE PHY integration, or adapt a proven White Rabbit
PHY/core after interface and license review. The mature WR ecosystem is
Gigabit-oriented, although current upstream development also contains early
10 GbE endpoint work; the first SURF WR milestone should therefore remain
1 GbE unless a concrete 10 GbE requirement changes it.

Do not put board-specific clock wiring in the generic PTP clock. Use a small
actuator record or interface so projects can connect an external DPLL,
DAC-controlled oscillator, an on-chip transceiver DPLL, or a simulation model
without changing protocol logic.

## Phased implementation plan

### Phase 0: freeze the ordinary-PTP interfaces

- Review `PtpPkg` record widths, sign conventions, SFD reference plane, Q32/Q16
  conversions, and valid/ready semantics.
- Freeze the untagged L2, fixed-source, E2E subset and explicitly record
  accepted PTP minor versions.
- Freeze reset behavior: protocol/link reset clears associations and lock but
  must not reset a valid PHC; system/PTP reset may clear it.
- Freeze the 4 KiB AXI-Lite block allocation and multiword snapshot/commit
  rules, without yet promising every individual register offset.

Exit criterion: `PtpPkg` can be reviewed independently and the equations have
directed Python test vectors, including positive/negative corrections and
offset sign.

### Phase 1: PHC, arithmetic, and CDC

- Implement `PtpPkg`, `PtpPhc`, its integrated coherent read CDC, the PHC
  portion of `PtpReg`, and a thin `PtpPhcWrapper`.
- Verify 48-bit second rollover behavior, nanosecond normalization, Q32
  nominal/rate increments at 125 and 156.25 MHz, atomic set/step, monotonic
  rejection, local and crossed snapshot coherence, PPS, and discontinuity
  handling.
- Implement pure E2E arithmetic helpers in `PtpPkg` early enough to verify bit
  widths and overflow policy before message parsing exists. They need not be a
  separate entity.

Exit criterion: GHDL/cocotb tests match an integer Python reference model for
long randomized runs and every clock command corner case.

### Phase 2: passive physical timestamp taps

- Implement `PtpGmiiTimestampTap` and `PtpXgmiiTimestampTap` as observers; do
  not change an existing MAC entity.
- Decode untagged destination/EtherType and the 34-byte PTP common header,
  capture SFD, apply ingress/egress latency, and emit the full key.
- Exercise back-to-back frames, runt/oversize/truncated frames, physical error,
  reset mid-frame, all PTP event types, sequence wrap, and event FIFO full.
- For XGMII, cover every legal `/S/` alignment and prove fractional byte-time
  correction. For GMII, prove exact `0xD5` capture.

Exit criterion: tap results match a cycle-accurate Python wire model and the
GMII/XGMII data being observed is not modified.

### Phase 3: PTP port packet and transaction engine

- Implement `PtpPort` with internal RX codec, TX builder, keyed timestamp
  tables, message timers, and E2E transaction arithmetic on ordinary AXI
  Stream frames.
- Use known byte-vector fixtures for PTP v2.0 and v2.1 Sync, Follow_Up,
  Delay_Resp, and Announce. Prove network byte order, message-length/padding
  handling, correction-field sign, identity checks, EOFE rejection, and unknown
  TLV skipping.
- Join tap events and decoded frames with randomized relative delay so either
  arrives first. Test duplicates, dropped frames, orphan events, replacement,
  timeout, and sequence wrap.
- Verify that Delay_Req content is correct and remains stable under AXI
  backpressure; the MAC, not the builder, owns preamble/FCS/padding.

Exit criterion: `PtpPort` completes and retires keyed transactions without a
FIFO-order assumption or silent overwrite, and its internal sections do not
need public interfaces solely for unit-test access.

### Phase 4: autonomous endpoint and closed-loop servo

- Implement `PtpServo`, complete `PtpReg`, and compose them with `PtpPort` and
  `PtpPhc` in `PtpEndpoint`.
- Create a cocotb TimeTransmitter model that supplies independently controlled
  clock offset, oscillator drift, forward/reverse delay, residence correction,
  queue jitter, message rate, reordering, loss, duplicates, and malformed
  traffic.
- Test acquisition with/without initial step, PI convergence, clamp and
  anti-windup, path-delay outlier rejection, source/domain changes, Sync and
  Announce timeout, holdover aging, link reset, reacquisition, and fatal math
  faults.
- Establish stable default gains only from a sweep over oscillator error,
  Sync intervals, and jitter; record settling time and overshoot.

Exit criterion: the endpoint meets a written simulation error/settling bound
and never updates the PHC from an incomplete, invalid, or mismatched exchange.

### Phase 5: `EthMacTop` composition and compatibility

- Implement `EthMacPtpEndpoint` around the unchanged `EthMacTop` with raw
  bypass on EtherType `0x88F7` and taps on the physical interface.
- Extend the current EthMac loopback test with PTP traffic mixed with random
  primary traffic, bypass/primary contention, pause, receive backpressure,
  bad CRC, FIFO drops, and link resets.
- Confirm PTP transmit priority is only at frame boundaries and that actual
  wire timestamps make preceding primary-frame length irrelevant to E2E math.
- Run the existing EthMacCore, IpV4Engine, UdpEngine, and RoCEv2 focused suites
  unchanged.

Exit criterion: autonomous synchronization works through the real MAC
pipeline, application traffic is unmodified, and every dropped PTP event is
observable in a counter.

### Phase 6: 7-series 1 Gb/s integration and control plane

- Add `GigEthGtx7Ptp.vhd` without changing `GigEthGtx7` or its DCP.
- Add PTP at AXI-Lite base + `0x2000`, expose direct PHC time, PPS, lock,
  holdover, and time-valid outputs, and keep the existing Ethernet/DRP maps.
- Add the PyRogue package after register offsets are frozen and test a focused
  import plus register-description consistency.
- Calibrate GMII-to-connector ingress/egress latency against a hardware PTP
  source/analyzer. Repeat link and system reset enough times to characterize
  latency modes rather than reporting a single result.
- Interoperate with a linuxptp or instrument TimeTransmitter. No `ptp4l` runs
  on or controls the FPGA endpoint.

Exit criterion: repeatable hardware lock, holdover, and reacquisition results
meet the selected MAC- and connector-plane error budgets, and all calibration
constants have recorded provenance.

### Phase 7: 7-series 10 Gb/s integration

- Add `TenGigEthGtx7Ptp.vhd` using the same endpoint and the XGMII tap.
- Verify 0.8 ns lane correction, 156.25 MHz PHC increment, PCS/PMA latency and
  reset variation, and the new sibling's AXI-Lite map.
- Do not modify or regenerate the 10GBASE-R IP unless hardware measurements
  show the existing core has an unmanageable latency mode.

Exit criterion: the common protocol/servo tests pass unchanged and hardware
results isolate XGMII/PCS latency from endpoint algorithm error.

### Phase 8: High Accuracy/White Rabbit feasibility and integration

- Select or implement a deterministic-latency 1000BASE-X PHY that exposes the
  recovered clock and all required latency/phase observability.
- Add a generic SyncE clock actuator interface and target-specific adapter for
  the selected external PLL/DPLL, tunable oscillator, or on-chip transceiver
  DPLL.
- Add fine phase measurement, calibration data, asymmetry calculations, and
  High Accuracy/White Rabbit link state and signaling.
- Compare interoperability and calibration behavior with current upstream
  `wr-cores` and a known White Rabbit switch/node.

Exit criterion: frequency syntonization, phase/time lock, calibrated link
delay, reset repeatability, and interoperability meet the selected High
Accuracy/White Rabbit target.

### Later extensions

- One-step Sync receive, followed separately by one-step Sync insertion and
  correction-field updates.
- One- and two-level VLAN parsing in `EthMacRxBypass` and the PTP frame builder.
- Transparent- and boundary-clock assistance, including residence time.
- UDP/IPv4 and UDP/IPv6 checksum-aware in-flight modification.
- External timestamp inputs and programmable periodic outputs.
- Full BMCA, management, multi-domain, unicast, and security features beyond
  the configured-TimeTransmitter endpoint.
- Vendor CMAC/100 GbE timestamp ports in `Caui4Core`.
- XLGMII/40 GbE only after that datapath itself is implemented and tested.

## Accuracy budget and initial engineering objectives

Accuracy must be reported at a named reference plane. The design can prove
exact arithmetic at the MAC interface in simulation; connector- or fiber-plane
accuracy is a hardware measurement.

| Contribution | Expected ordinary-PTP behavior |
| --- | --- |
| PHC arithmetic | Q32 nominal increment contributes less than 0.02 ppb representation error at 156.25 MHz. Rate-addend resolution is also below 0.1 ppb. |
| GMII capture | SFD is synchronous to the 125 MHz GMII clock. The MAC-plane event is tied to a specified edge; connector error is dominated by PCS/PMA latency/calibration rather than an arbitrary software timestamp. |
| XGMII capture | Start-lane/SFD position gives 0.8 ns byte resolution even though the PHC advances every 6.4 ns. |
| Fixed PHY latency | Removed by measured ingress/egress calibration if it is stable. Reset-dependent modes become residual error unless detected and calibrated separately. |
| Path asymmetry | Ordinary E2E PTP assumes symmetric delay unless `delayAsymmetry` is configured. An unknown asymmetry appears directly as time error. |
| Packet-delay variation | Median/filtering rejects isolated outliers but cannot remove persistent asymmetric queueing in ordinary switches. A direct link or timing-aware network will perform better. |
| Holdover | Time error grows approximately with the uncompensated oscillator frequency error. A 10 ppm residual produces about 10 us of error per second; the last learned rate should reduce but cannot guarantee this without oscillator characterization. |

A reasonable first hardware engineering objective is less than 250 ns
steady-state error at a calibrated connector on a direct link, with less than
1 us peak error outside acquisition and fault transitions. This is deliberately
looser than the MAC timestamp granularity and must be replaced by measured
percentiles, temperature range, and reset-to-reset results before it becomes a
requirement. Ordinary switched Ethernet should be described as sub-microsecond
to microsecond-class depending on queueing and asymmetry, not given the direct-
link guarantee.

## Verification matrix

At minimum, focused tests should cover:

- PHC: second rollover, nanosecond normalization, set/step/trim corner cases,
  coherent reads, PPS, and CDC under unrelated clocks.
- Capture: GMII and both XGMII start lanes, exact SFD edge, fractional offset,
  and timestamp behavior when `phyReady` changes.
- Association: timestamp/message arrival in either order, multiple outstanding
  sequence IDs, duplicates, sequence wrap, primary/bypass arbitration,
  backpressure, pause, underflow, filtered or CRC-bad RX frames, tap/event FIFO
  full, orphan expiry, and counter wrap.
- Endpoint: message parsing, sequence/domain/identity rejection, two-step
  timestamp matching, correction-field arithmetic, offset/path-delay solution,
  Announce time properties, acquisition, bounded servo response, packet loss,
  holdover, and reacquisition.
- White Rabbit follow-on: recovered-clock loss, SyncE frequency lock, phase
  detector wrap, deterministic PHY latency, calibration/asymmetry application,
  and link-role transitions.
- Compatibility: existing EthMacCore, IpV4Engine, UdpEngine, and RoCEv2 suites
  remain unchanged when PTP is disabled.
- Hardware: reset-to-reset latency distribution, clock quality sensitivity,
  link partner interoperability, and comparison with a calibrated reference.

Likely local commands after implementation are:

```sh
make MODULES="$PWD" import
./.venv/bin/vsg -c vsg-linter.yml <edited-vhdl>
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/PtpCore
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/EthMacCore
```

## Open decisions

1. Replace the provisional direct-link accuracy objective with the required
   steady-state, peak, temperature, and holdover limits.
2. Decide whether one-step Sync receive is a Phase 4 release criterion or the
   first later extension.
3. Freeze exact register offsets, fixed-point gain formats, and safe default
   servo gains after the integer reference-model sweep.
4. Decide whether the first release must recognize a single `0x8100` VLAN tag;
   doing so requires changing the existing receive bypass classifier as well
   as both taps and the frame builder.
5. Decide whether 10/100 Mb/s `ethClkEn` operation is required. The first
   1000BASE-X path does not need it.
6. Determine how applications consume precise time: direct `phcClk` logic,
   PPS/event pulses, or a separately specified destination-domain replica.
7. Keep the future generic tagged timestamp API independent unless a second
   non-PTP user establishes concrete metadata requirements.

## Risks

- The keyed wire tap avoids invasive MAC metadata plumbing, but it duplicates
  partial header parsing and must remain aligned with the completed AXI frame.
  Dropped frames and orphan events must never be matched by arrival order.
- A tap event is created before the MAC has delivered final CRC/EOFE status.
  Protocol state must wait for both sides of the match and discard a bad frame.
- A precise MAC timestamp can still be inaccurate at the wire if PCS/PMA or
  transceiver latency is variable or uncalibrated.
- E2E PTP cannot distinguish real clock offset from unknown forward/reverse
  path asymmetry. A stable servo does not prove absolute accuracy.
- A fixed-point PI loop can oscillate, wind up, or converge too slowly if gains
  are selected without a sweep over Sync rate, oscillator error, loss, and
  packet-delay variation.
- One-step support affects packet data, correction fields, checksums, and FCS
  and should not be mixed into the initial two-step implementation.
- Hardware timestamps alone do not make an autonomous synchronized endpoint;
  message state, delay/offset arithmetic, and a stable clock servo are also
  required.
- Ordinary PTP can discipline a numerical PHC while the physical Ethernet
  clocks remain local. White Rabbit additionally changes the PHY and board
  clock architecture through SyncE and fine phase control.
- Changing exported record types or entity ports can create broad downstream
  source incompatibility even when new generics default to disabled.
- Duplicating an entire GT wrapper for PTP can drift from its legacy sibling.
  Keep the change narrow first, then extract a common PHY layer only when a
  second consumer demonstrates that the refactor is worthwhile.

## External reference points

- [IEEE 1588-2019](https://standards.ieee.org/ieee/1588/6825/) is the active
  base standard and defines the layer-2 mapping, message and correction-field
  semantics, time scales, and default profiles.
- [linuxptp default configuration](https://github.com/richardcochran/linuxptp/blob/master/configs/default.cfg)
  is the interoperability reference for common default intervals, two-step,
  E2E, domain, timeout, and delay-filter defaults. It is a peer/reference
  implementation; it is not required on the FPGA endpoint.
- [linuxptp message structures](https://github.com/richardcochran/linuxptp/blob/master/msg.h)
  and [port processing](https://github.com/richardcochran/linuxptp/blob/master/port.c)
  provide a reviewable primary implementation reference for field layout,
  out-of-order Sync/Follow_Up matching, correction application, and E2E
  Delay_Resp association.
- [IEEE 802.1 PTP multicast forwarding material](https://www.ieee802.org/1/files/public/docs2012/new-tc-messenger-tc-ptp-forwarding-1112-v03.pdf)
  records the PTP multicast group addresses used by the layer-2 transport.
- [AMD PG210 timestamping overview](https://docs.amd.com/r/4.1-English/pg210-25g-ethernet/Overview?contentId=yIDsTr9qHkVKk~H~J6r2sQ)
  is a useful vendor precedent for an 80-bit system timer, ingress timestamps,
  and tagged two-step egress timestamps.
- [White Rabbit Specification v2.0](https://white-rabbit.web.cern.ch/documents/WhiteRabbitSpec.v2.0.pdf)
  describes the combination of PTP, physical-layer syntonization using SyncE,
  precise phase, fixed-delay calibration, and link asymmetry compensation.
- [White Rabbit standardization](https://ohwr.org/projects/wr-std/) documents
  its generalization as the High Accuracy default profile in IEEE 1588-2019.
- [Current `wr-cores`](https://gitlab.com/ohwr/project/wr-cores) is the primary
  public implementation reference for a White Rabbit endpoint, PHY adapters,
  soft PLL, PPS generator, and associated embedded software boundary.
- [AMD XAPP589](https://docs.amd.com/go/en-US/xapp589-VCXO) and
  [XAPP1276](https://docs.amd.com/v/u/en-US/xapp1276-vcxo) describe all-digital
  VCXO replacement techniques using 7-series phase interpolators and newer
  transceiver fractional PLLs, respectively.
- [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) and
  [Corundum](https://github.com/corundum/corundum) are public implementation
  references for fractional PHCs, coherent time CDC, timestamp metadata, and
  host-facing integration. They are architectural references, not code to copy
  into SURF without a separate license and fit review.
