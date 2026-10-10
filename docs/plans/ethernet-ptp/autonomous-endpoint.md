# Autonomous PTP endpoint contract

Implemented fixed-source, one-/two-step Layer-2 E2E TimeReceiver on GMII/XGMII.
Behavioral verification was authorized October 9, 2026; current results and
remaining acceptance belong in the [review record](rtl-review.md);
[historical milestones](history/verification.md) do not validate the current
source. This contract describes source behavior, not hardware-qualified accuracy.
Application scheduling, shared simulator timing and physical clock control are
future work.

## Composition and ownership

`EthMacPtpEndpoint` composes the unchanged `EthMacTop`, `PtpPrimaryGuard`, passive
`PtpRxTimestampTap`, passive `PtpTxTimestampTap`, and `PtpEndpoint`. All run in
one continuously running Ethernet/PHC clock domain. Use 125 MHz for full-rate
GMII or 156.25 MHz for XGMII; GMII 10/100 clock enables are unsupported.

The primary stream uses `EMAC_AXIS_CONFIG_C`. The guard reserves all untagged
EtherType `0x88F7` frames for the private PTP producer, draining application
attempts and counting them. It also rejects malformed/short initial SSI beats;
a legal primary frame presents a full first 16-byte beat with SOF. Other frames
retain their payload and sidebands through a registered ready/valid stage.

The port builds a 58-byte Delay_Req on an eight-byte SSI stream.
`PtpEndpoint.TX_AXIS_CONFIG_G` defaults to that format with a direct connection;
`EthMacPtpEndpoint` selects the MAC's native bypass configuration, enabling
an `AxiStreamResize` inside `PtpEndpoint`. Only system reset clears this stage. The
MAC owns padding, preamble, FCS, arbitration and pause. Its redundant RX bypass
is drained at native width: the passive atomic RX frontend supplies protocol
messages independently of hidden MAC CRC/FIFO drops.

The wrapper's `localMac` is authoritative for Ethernet configuration, the PTP
builder and readback. Its least significant octet is first on the wire. The
project must assign a unique deployed address; `MAC_ADDR_INIT_C` is only a
convenience default. Default PTP clock identity inserts `FFFE` into those MAC
octets in EUI-64 form, preserving the configured port number; software may
override clock identity without changing the Ethernet source MAC. A MAC change
restarts acquisition and updates both views coherently.

Delay_Req uses multicast `01:1B:19:00:00:00`, EtherType `0x88F7`, message type 1,
length 44, configured domain/minor version, zero correction/origin timestamp,
local identity, allocated sequence and log interval `0x7F`. Control is zero for
minor version 1 (2019 Layer-2), or one for selected minor version 0 (2008
compatibility). Its
58 meaningful bytes exclude preamble/padding/FCS; SSI SOF is set, final EOFE is
clear and every offered beat remains stable under backpressure. Bypass priority
is at frame boundaries; the TX tap observes actual transmission after MAC pause
or queueing. Tagged frames are outside this contract and require coordinated
classifier, frontend and builder changes.

`PtpEndpoint` structurally composes `PtpProtocolEngine`, `PtpServo`, `PtpPhc`,
`PtpEndpointControl` (formerly `PtpReg`), TX adaptation and the standard SURF
AXI-Lite crossbar. The controller owns global enable/commit/snapshot state,
registered restart/RX flush and IRQ events, plus combinational AXI reset.
Restart consumes the published apply strobe, and IRQ status consumes the
previous event stage; consolidation preserves their register hops. Each functional
core contains
its own AXI-Lite decode, configuration and snapshot storage in its existing
`RegType`/`comb`/`seq` structure. `PtpPhc` also owns manual phase normalization
and final command arbitration. Only shared active limits, measurements and
narrow lifecycle/status signals cross between these cores. All three cores
use their local AXI configuration, with no optional bypass. Measurement
handshakes and port status use package records.

The PHC-local arbiter retains manual/automatic ownership through acknowledgement.
Manual steering requires automatic control disabled; PPS enable is available
in either mode. A disabled servo drains measurements so packet processing and
protocol diagnostics continue under manual PHC ownership. RX overflow/link/
configuration cancellation remains separate from the PHC's own capture-abort
path, preventing a phase step from canceling itself. Held link loss cancels
old work once and permits subsequent frequency-only holdover control.

## RX message and capture boundary

A passive adapter binds capture and bytes at the first destination-MAC octet,
before any lossy queue. `PtpRxFrontend` validates the complete frame and publishes
one atomic decoded-message/capture record; the redundant MAC bypass is always
drained, including during logical restart. Aggregate MAC CRC/FIFO status is
diagnostic and cannot select or invalidate frontend records.

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

`PtpRxTimestampTap` structurally composes `PtpRxTimestampAdapter` and
`PtpRxFrontend` without added state or latency. The adapter handles GMII/XGMII
normalization; `PtpTxTimestampTap` reuses the same leaves for separate TX
completion. There is no combined
RX/TX timestamp-tap entity or separate RX timestamp/frame join.

| Boundary | Contract |
| --- | --- |
| Adapter to frontend | Eight-byte AXI/SSI format, contiguous low-byte keep, SOF/EOFE and last; a capture sidecar is meaningful on SOF. No ready: every valid beat is consumed. GMII contributes one byte, XGMII up to eight; termination after a full word may use a zero-byte final beat. |
| SOF capture | Q16 time, raw ticks/eighth-cycle phase, generation, active increment, validity/error from the same frame. Time-invalid observations can still bootstrap acquisition. |
| Frontend to protocol engine | One `PtpRxMessageType` valid/ready channel for Sync, Follow_Up, Delay_Resp and Announce, with capture, RX epoch, header and fixed body. No independent capture queue or raw RX port. |
| Protocol TX/completion | Delay_Req stream and keyed wire completion remain distinct, subject to reserved-key lifetime and exclusive primary-traffic rules. |

Sidecar and SOF share every enable/reset. Normalization/CRC sustain eight bytes
per cycle at XGMII line rate, including minimum gaps. GMII has phase zero;
XGMII normalizes `(startLane + 8)` byte times into ticks plus eighth-cycle phase.
RX and TX both retain that phase: ignoring lane-4 versus lane-0 differences can
bias nominal 10G delay by 1.6 ns. Capture arithmetic scales with the active PHC
increment and normalizes seconds carry/borrow; epoch underflow/overflow marks
an invalid capture. Direct capture at the message point avoids extrapolating
across a PHC command edge.

### Validation and bounded storage

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
- Outer EtherType `88 F7`, major version 2 with any minor version, and a supported
  RX message type. The byte-order convention remains distinct from `x"F788"`
  in the MAC bypass generic.
- `messageLength` covers the fixed body (44/44/54/64 bytes respectively), fits
  the received frame, and is at most 1500. Padding beyond that length is
  excluded from PTP decode, but included in CRC.
- Optional TLVs walk exactly to `messageLength`; reject odd value lengths,
  partial headers and values extending beyond it. Structurally valid unknown TLVs are skipped.
  Profile-specific TLV semantics and conformance fixtures remain a parser
  qualification task; the model checks boundary lengths, not full IEEE conformance.

`PtpProtocolEngine` owns configured destination/source/domain/transport-specific
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

Storage is bounded independently of frame termination: at most 78 prefix bytes,
saturating length counters, CRC and streaming TLV state, one SOF capture and a
configured complete-record queue (default four). The Python oracle holds four
trailing FCS bytes; RTL instead proves the declared body ends before the FCS.
The legacy 744-bit diagnostic packing gives 2,976 data bits for four records,
but omits capture increment/error and is not a lossless transport or device-area
estimate. See the [deferred FIFO option](#deferred-rx-fifo-optimization).

A completion finding the queue full **before the edge** discards the completion
and whole queue, advances RX epoch and increments overflow even if ready is high.
Malformed/unsupported frames do not enqueue and cannot cause queue overflow.
Otherwise the old head may retire before a valid completion enqueues; new records
do not fall through on arrival. Restart/generation changes discard partial and
queued work. RX overflow never steps the PHC or releases unknown TX wire keys.

The [registered timing contract](rtl-readability.md#registered-lifecycle-and-queue-boundaries)
is authoritative: a detection-edge old-head transfer can precede publication of
abort, and the consumer cancels pending work when that registered event arrives.
This supersedes the original reference model's immediate-abort timing. Pipeline
capture, completion, generation and abort together; an independent reset or CDC
would need coordinated invalidation before admitting new work. The current
physical producer boundary has no CDC.

## Time, arithmetic and lifecycle contracts

- PHC time is seconds48/nanoseconds32/fraction32. Captures retain Q16 fraction,
  generation32, unsteered ticks64, eighth-cycle phase, and the exact active Q32
  increment. The existing RX `toSlv()` layout remains 744 bits and omits
  capture increment/error; it is a legacy diagnostic/test packing, not a complete
  transport for endpoint records or a CDC interface.
- The timestamp plane is the first destination-MAC octet, with XGMII lane
  phase applied. Ingress is subtracted and egress added. Both are signed Q16
  **local PHC nanoseconds**, supplied by build-time latency generics. Egress
  excludes the single
  most-negative 64-bit value because the shared ingress adapter must negate it.
  E2E converts each latency to master-time units using that capture's increment
  and the qualified master-time/raw-tick ratio. A PHC rate change between t2 and
  t3 therefore cannot silently change the calibration plane.
- `PtpMath` provides signed128 multiplication/division, explicit overflow/divide
  errors, ready/valid output holding, and cancellation. Work takes 128 iterations.
  Division can round nearest with ties away from zero; the separately returned
  remainder always follows truncation toward zero. E2E, rate estimation, servo,
  and manual phase normalization own separate serialized engines.
- PHC command acceptance latches an immutable operand; commit is the following
  edge. SET specifies commit-edge time; PHASE applies after normal advancement;
  RATE changes the next increment. A discontinuity clears validity, suppresses
  PPS and captures, and advances generation. Invalid/stale commands acknowledge
  with error. Valid monotonic time rejects absolute sets and negative phase
  steps. Epoch/generation/tick exhaustion faults closed and requires system reset.
- A TX key is reserved before the first stream beat. Four ledger entries retain
  sequence/domain/identity/generation and physical fate. Responses and physical
  completion may arrive at the ledger in either order. Timeout or logical restart
  retires a request but cannot free an unknown wire fate. Known completions retain
  the key through `PACKET_LIFETIME_G`; a duplicate restarts that quarantine.
  Admission requires explicit MAC reset confirmation plus startup quarantine.
  Only confirmed physical reset can release an unknown fate. This bounded design
  can intentionally stop requesting when the MAC never resolves its queued work.
- Packet lifetime is an integration assumption about the maximum surviving
  network response lifetime. Set it conservatively; finite key reuse cannot
  protect against arbitrarily delayed/replayed traffic outside that bound.
- Port reset/configuration changes preserve the PHC and drain an already presented
  TX frame. System reset must reach the entire MAC/resize/endpoint pipeline.
  `regRst` cancels AXI responses only: configuration, accepted manual commands,
  PHC time and physical TX reservations survive.

## Port policy and numerical envelope

The fixed source accepts multicast destination `01:1B:19:00:00:00`, configured
sourcePortIdentity/domain, majorSdoId (formerly transportSpecific) zero, PTP
major version 2 with any minor version, one-step or two-step Sync, Follow_Up,
Delay_Resp and Announce. The non-isolated domain ignores minorSdoId;
messageTypeSpecific and received controlField are ignored. Reserved flag bits
(`0x9880`) are excluded from policy checks. Remaining flags and canonical timestamp checks
follow structural/FCS validation. There is no BMCA, one-step transmit insertion, UDP,
VLAN, Pdelay, security extension, or automatic upstream selection.

Four bounded associations select the mode independently for each Sync. After
masking reserved bits, flags `0x0000` select one-step: nanoseconds must be below 1,000,000,000, and the
Sync's originTimestamp and sign-extended correction complete the sample with
its own physical capture. Flags `0x0200` select two-step: Sync and
Follow_Up may arrive in either order, the Sync body is non-authoritative, and
the sample uses Follow_Up's preciseOriginTimestamp plus the widened signed
sum of both corrections. All 48 seconds bits and Q16 correction bits survive.
Other non-reserved Sync flags are rejected before association updates.

A one-step Sync colliding with a retained Follow_Up retires the association
without a sample. Follow_Up after a one-step Sync is rejected and counted
without changing its timestamp, correction, age or completion state. Conflicting
two-step Follow_Up and duplicate physical Sync (including a different step mode)
invalidate the association. Retired entries cannot complete again. A later
packet cannot revoke an already consumed measurement. Completed slots may
retire, while unfinished slots cannot be overwritten. Retention/expiry and
chronology checks bound replay protection; sequence wrap is not a session ID.
Mode state flushes with the existing associations on restart, source/configuration
changes, RX abort/epoch invalidation and PHC generation changes; AXI-only reset
preserves it. Distinct sequence IDs can alternate modes without reconfiguration. The private mode bit is qualified by `syncSeen`;
`followSeen` indicates an actual Follow_Up. Completion requires an unretired Sync
and either one-step mode or its Follow_Up; the unused one-step Follow_Up correction
is zero. Masked flags and canonical one-step nanoseconds are checked before slot
lookup/update, so malformed traffic cannot contaminate a retained association.
These collision rules are conservative implementation policy, not a claim that
IEEE 1588 mandates this exact handling. Completion follows full frame validation
and available processing capacity; RX waits while rate processing or a measurement
stalls, and later collisions cannot revoke consumed samples.

The correctionField encoding `0x7fffffffffffffff` is an overflow indication
(IEEE 1588-2019 13.3.2.9), not a finite correction. The local receiver policy
retires the affected Sync/Follow_Up key, including when the overflowing half
arrives first. Finite duplicates cannot revive that retained key. A matching
Delay_Resp with this encoding retires its request without accepting its advertised
interval; unresolved TX ownership and the normal quarantine remain intact.
Identity/domain/provenance checks precede retirement, so foreign traffic cannot
invalidate an unrelated request. Already consumed measurements are not revoked.
Other signed values, including `-1` and both finite wire bounds, remain arithmetic
inputs; existing chronological and path-delay validity checks still apply.

Both receive modes share the existing registered measurement,
backpressure and child-cancellation contracts. Corrected remote time
and raw capture time must both advance. Four completed Syncs supply the nearest
eligible t2 for an actual t3. E2E computes a delay only with a fresh, qualified
rate ratio and matching-generation complete timestamps; negative/excessive path
delay and arithmetic errors are rejected before publication.

The rate estimator uses corrected master elapsed time over raw local tick/phase
elapsed time, independent of PHC validity or steering. It requires two qualified
intervals after a configurable minimum span, bounds oscillator deviation to
±200 ppm, and applies a quarter-weight IIR after the first estimate. Only an
accepted interval renews ratio freshness.

Delay_Req intervals use a seeded nonzero LFSR and a bounded three-point schedule
(0.5, 1, 1.5 times the effective mean). Only a matched Delay_Resp can update the
advertised minimum interval; the slower local setting wins. Log intervals
−10 through +22 are decoded, `0x7F` uses fallback, and other values count a
rejection and use fallback. Known Sync/Announce intervals give three-period
receipt timeouts, capped by configured `SyncTimeout` (twice that for Announce).
A configured-source grandmaster or PTP-timescale change cancels old acquisition. Announce metadata
is exposed, including all 30 body octets; UTC/leap flags never step the PHC.

The three-point schedule is a known departure from IEEE 1588-2019
9.5.11.2(c)(1)'s default multicast uniform distribution. The selected sdoId=000
also reserves domains 128–255, which configuration does not yet prohibit.
The correction overflow encoding `0x7fffffffffffffff` still follows ordinary
arithmetic and needs explicit receiver policy. These and configured-port/profile
requirements remain in the [specification audit](../../../tests/ethernet/PtpCore/specification-coverage.md#remaining-normative-work).

The servo uses the median of only populated delay samples (up to five), then
local-minus-master offset = forward − filteredDelay − asymmetry. While invalid,
an allowed large phase correction can acquire the epoch. Otherwise a qualified
rate command establishes validity, including the no-step case. The PI loop uses
raw elapsed time, Q2.30 gains, Q16 ppb frequency/slew/final clamps, conditional
integration, and a bumpless initial frequency estimate. Only acknowledged rate
commands update the last good frequency. Stale or canceled work cannot publish
an automatic command. Holdover removes phase slew, preserves frequency, and
expires validity after a raw-tick age limit. A servo fault requires system reset.

Default gains are Kp = 0.25 ppb/ns and Ki = 0.0625 ppb/(ns·s); frequency/slew/final
limits are 100,000/50,000/150,000 ppb. Default delay/source/sample age limits are
frequency-derived: Delay_Req 1 s, Sync timeout 3 s, association 2 s, delay age 4 s,
holdover 64 s, exchange 2 s, minimum rate span 0.5 s, ratio age 4 s, and sample
interval 1/64–2 s. Step threshold is 20 µs; lock is eight samples within 100 ns;
unlock is three beyond 1 µs. Qualification counters retain progress in the
neutral hysteresis band and reset when the opposite threshold is crossed.
Maximum path delay is 1 ms.

Two existing implementation limits still lack a documented design rationale:
`PtpProtocolEngine` requires an association timeout of at least 2048 raw clock cycles,
and `PtpServo` caps the configurable actuator limit at 200,000 ppb. Inspection
of their introducing commit (`dc18c9ba2`) found no additional justification.
The association floor needs a complete operation/latency budget; the 128-step
math engine alone does not establish it. The actuator cap needs an explicit
control/actuator rationale and qualification. It is separate from both the
independently documented ±200 ppm oscillator qualification envelope and the
default 150,000 ppb total correction setting. Naming these limits does not
establish their sufficiency or hardware suitability.

Independent rational PI sweeps cover ±100 ppm, initial ±10 µs, and Sync periods
1/8, 1/4 and 1 s. For those cases, peak error is below 12 µs and every sampled
error after 120 s is below 100 ns. Separate estimator sweeps include ±100 ns
packet delay variation. These are stated model cases, not a hardware accuracy
guarantee or a combined arbitrary-jitter stability proof. The physical endpoint
regressions accelerate packet intervals with exact fractional correction fields;
they verify state/command composition rather than long-duration default settling.

## Arithmetic units and sign conventions

The Q32 PHC nominal increment represents 8 ns exactly at 125 MHz; its 6.4 ns
representation at 156.25 MHz has less than 0.02 ppb nominal rate error. Q16-only
increment rounding would be approximately 1 ppm without residual arithmetic.
Captured correction arithmetic uses Q16 nanoseconds; gains use unsigned Q2.30
(values below 4), with signed128 checked intermediates and nearest rounding,
ties away from zero where selected. Parser log-interval acceptance is not a
claim that one gain set tracks the entire range.

For equal-rate clocks, the explanatory E2E equations are:

```text
forward = t2 - (t1 + cSync)
reverse = (t4 - cDelay) - t3
meanDelay = (forward + reverse) / 2
localMinusMaster = forward - meanDelay - delayAsymmetry
rateAddendQ32 = round(nominalAddendQ32 * rateCommandPpbQ16
                     / (1_000_000_000 * 2^16))
```

Here `t1`/`cSync` use the selected receive-mode origin and correction; `t2` is
local Sync RX, `t3` local Delay_Req TX and `t4` remote Delay_Resp receive time.
Positive local-minus-master offset calls for negative phase/frequency correction.
`delayAsymmetry` means half the forward-minus-reverse physical path difference;
it is distinct from ingress/egress calibration. The implemented E2E uses the
qualified master-time/raw-tick ratio and each capture's calibration conversion,
not an equal-rate assumption. The uncorrected error is approximately half the
oscillator error times RX-to-TX separation: 100 ppm over 10 ms gives 500 ns.
Bootstrap therefore estimates rate independently of already-valid path delay.
Do not constrain the individual cross-clock differences to a network-delay
range before their potentially large epoch offsets cancel.

### Fixed-point width audit

The October 2026 source audit sizes stored values from the accepted configuration
and interface ranges, including standalone clock-frequency generics. It does not
assume that every Sync arrives one second apart or that every offset is small.
The first reduction preserves all fractional bits, register/command formats,
rounding points, overflow rejection and the 128-iteration arithmetic schedule.
Behavioral equivalence is assessed through the [width acceptance checks](rtl-review.md#fixed-point-width-acceptance).

| Quantity | Bound and implementation decision |
| --- | --- |
| Stored servo frequency, candidate frequency, slew and bootstrap | Each is clamped to at most +/-200,000 ppb. With 16 fractional bits, `200000 * 2^16 < 2^34`: **35 signed bits** suffice. `RatePpbType` replaces four signed128 registers. |
| Sum/difference of two clamped rate terms | Can reach +/-400,000 ppb before clamping. Explicit **36-bit** arithmetic preserves the carry/sign before saturation and anti-windup decisions. |
| Tracking offset and gain product | Tracking admission requires the offset to fit signed64 Q16 ns; Kp/Ki are unsigned32 Q2.30. Their exact product fits **signed96**. The shared engine still publishes signed128 because other operations need the wider contract. |
| Elapsed sample time | Validated timeouts are nonzero and below `2^62` raw ticks. For any positive `CLK_FREQ_G`, nominal Q32 ns/tick is at most `1e9 * 2^32`. Thus the rounded interval in Q32 seconds is below `2^94`: **95 signed bits** suffice for `interval`, formerly signed128. |
| Integral update | Multiplying the offset/gain product by the permitted interval can exceed signed128 before the existing 62-bit rounded shift. Retain checked128 overflow rejection; a narrower engine or an earlier rounding shift could change which samples are rejected or change the PI result. |
| Rate-to-PHC conversion | The clamped signed35 rate times the nominal increment fits signed97 for all positive clock-frequency generics. At 125 MHz, the exact nominal increment is `2^35`, so signed70 suffices for this product. The shared engine retains its wider interface. |
| Epoch and manual phase adjustment | A full 48-bit seconds epoch expressed in Q16 ns needs about 95 signed bits. The software phase operand and measurement/normalization interfaces accept signed128; phase division must retain that public input range and its quotient-fit checks. |
| E2E and raw-rate estimation | Raw ticks/phase, unsigned64 ratios, correction fields and calibration conversions have separate bounds. The E2E tick-span/ratio product can exceed signed128 and is checked. Do not infer smaller operands merely from the subsequently qualified oscillator or path-delay range. |

The narrow servo state relies on the existing coordinated configuration contract:
the endpoint applies a candidate only after all banks vote valid. Changing the
actuator cap or timeout policy requires revisiting these bounds. The cap remains
an implementation policy awaiting qualification, as recorded above; this audit
does not establish its physical suitability.

`PtpMath` now stores the low 128 bits of its product and shifted multiplicand,
with two sticky flags in place of their previous 256-bit registers. A 129-bit
addition detects carry. A shifted-out high bit contributes to product overflow
only when a subsequent multiplier bit selects that partial product. Because
the engine multiplies unsigned magnitudes, all partial products are nonnegative:
discarded high bits cannot cancel later. The final sign-dependent range check
still distinguishes `-2^127` from the overflowing positive `+2^127`, and the low
result bits on overflow are preserved. Division retains its widened remainder,
nearest-rounding option and truncation remainder semantics.

These changes remove 405 declared state bits from the servo and 254 from each
multiply-capable math instance before synthesis optimization. These are source
width counts, not measured FPGA savings; constant divide-only instances may
already prune multiplication logic. LUT/FF/DSP use and critical paths require
Vivado evidence. Operation-specific multiplier/divider widths or DSP mapping
remain later options after behavioral acceptance and a measured resource need.

### Deferred floating-point servo option

Floating-point arithmetic is a future option for the message-rate PI servo's
gain, proportional and integral calculations. It could simplify experiments
with controller equations and scaling. The current implementation remains
fixed point; this is an investigation idea, not an implementation commitment
or an expected accuracy improvement.

An experiment should convert already-formed, bounded offset and elapsed-time
values to floating point and keep frequency corrections separate from the
nominal clock increment. Evaluate binary64 first rather than assuming binary32
has sufficient precision. Floating point provides approximately constant
relative precision, so its absolute resolution depends on magnitude: a small
integral update can disappear when added to a large retained state. Form epoch
differences in integer/fixed point before conversion; converting large absolute
timestamps first can lose the small difference the controller needs.

Integer/fixed-point arithmetic remains the preferred choice for the rest of
the timing chain: PHC accumulation, timestamp capture and subtraction, correction
fields, E2E delay and raw-rate estimation, phase normalization, and final PHC
commands. These paths benefit from explicit absolute resolution, exact counters
and predictable rounding/overflow behavior. A floating-point servo would still
return a bounded fixed-point correction through the existing command interface,
with explicit conversion, rounding, saturation and non-finite-result handling.

Compare any prototype with the appropriately sized fixed-point baseline for
numerical error, small accumulated corrections, acquisition/holdover behavior,
FPGA resources and latency. Message-rate computation offers time to serialize
operations, but does not establish a resource or precision advantage. Existing
configuration, cancellation and command-acknowledgement contracts must remain
intact; behavioral evaluation remains subject to the current verification pause.

## AXI-Lite register map

The [register map](register-map.md) defines the implemented four-bank ABI,
PyRogue hierarchy, commit/snapshot completion semantics, strobes and the current development layout.
`AXIL_BASE_ADDR_G` sets the aligned 16 KiB base on the endpoint/MAC composition;
the crossbar receives full addresses without local address stripping.

Configuration is stored in local shadows, frozen and validated by coordinated
commit, then applied by all banks on one edge. An accepted commit returns OKAY
before its result is known; software polls completion and checks ConfigError.
One snapshot strobe captures all local diagnostic banks with a common sequence.
AXI-only reset cancels bus responses but preserves accepted operations and active
state. See the [ownership record](register-map.md#register-ownership) for implementation and
verification details.

IRQ bits remain PHC fault, discontinuity, command error and servo fault. The last
exchange remains diagnostic after restart; compare its generation and sequences
before treating it as current. Local-MAC changes restart acquisition and rederive
the EUI-64 identity unless override is active, preserving the configured port
number. Calibration remains elaboration-time.

Static register-schema checks compare software fields with local RTL decode,
including overlap and bank bounds. They do not establish live Rogue transport
behavior; runtime and hardware acceptance remain separate.

## Optional snapshot CDC

`PtpPhcRead` is a separately instantiated request/response snapshot mailbox using
SURF asynchronous FIFOs and reset synchronizers. It is not a continuously
advancing replica, and it is not implicitly connected to the endpoint's local
AXI snapshots. Either read or PHC reset cancels both mailbox directions; a read
reset never resets the clock itself. Requests survive a stopped peer clock after
reset recovery: each FIFO write waits for acknowledgement rather than assuming
that deasserted full proves the peer domain is ready. Consumers accept only
`readValid` responses in their current reset session.


## Deferred RX FIFO optimization

Consider replacing `PtpRxFrontend`'s manual `r.queue` with a synchronous SURF
FIFO using distributed RAM and `FWFT_EN_G => true`. RX currently defaults to
four records; TX observation selects two and is always ready in
`EthMacPtpEndpoint`. A nominal 16-entry RAM for both is a candidate, matching
the public `Fifo` wrapper's minimum address width, not a protocol requirement.
No RTL or depth change is selected yet; resource/timing benefits need synthesis
evidence, and usable capacity must account for backend/FWFT buffering.

A replacement must retain atomic message/capture storage, stable registered
outputs, and explicit flush/generation/epoch and abort timing. Preserve the
pre-edge-full discard-all policy unless deliberately revising its contract.
Add lossless record packing: the existing verification `toSlv` omits
`capture.increment` and `capture.error`. Larger queues preserve capture times
but can increase backlog age; retain stale-record rejection. Revisit queue
capacity and interface latency tests when implementing, following the current
verification authorization and acceptance record.


Validation history is retained in [historical evidence](history/verification.md);
all current acceptance and device/interoperability gates belong in the
[review record](rtl-review.md#outstanding-acceptance).
