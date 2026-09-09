# Autonomous endpoint implementation

Status: the original simulation milestone is complete. The current
[RTL readability cleanup](rtl-readability.md) awaits maintainer VHDL approval;
regressions must remain stopped until approval. This milestone
builds on the committed [RX proof](rx-rtl-proof.md) and covers an autonomous
fixed-source, two-step Layer-2 E2E TimeReceiver on GMII and XGMII. It does not
qualify a board, transceiver, physical clock domain crossing, or accuracy budget.
The implemented contracts here supersede the larger plan's provisional module
names and register map. Application scheduling and shared simulator timing
services remain subsequent milestones.

## Composition and ownership

`EthMacPtpEndpoint` composes the unchanged `EthMacTop`, `PtpPrimaryGuard`, passive
RX adapter/frontend, passive `PtpTxTimestampTap`, and `PtpEndpoint`. All run in
one continuously running Ethernet/PHC clock domain. Use 125 MHz for full-rate
GMII or 156.25 MHz for XGMII; GMII 10/100 clock enables are unsupported.

The primary stream uses `EMAC_AXIS_CONFIG_C`. The guard reserves all untagged
EtherType `0x88F7` frames for the private PTP producer, draining application
attempts and counting them. It also rejects malformed/short initial SSI beats;
a legal primary frame presents a full first 16-byte beat with SOF. Other frames
retain their payload and sidebands through a registered ready/valid stage.

The port builds a 58-byte Delay_Req on an eight-byte SSI stream. A SURF
`AxiStreamResize` widens it to the MAC's native bypass configuration. The
MAC owns padding, preamble, FCS, arbitration and pause. Its redundant RX bypass
is drained at native width: the passive atomic RX frontend supplies protocol
messages independently of hidden MAC CRC/FIFO drops.

`PtpEndpoint` composes `PtpPort`, `PtpServo`, `PtpPhc`, a small `PtpReg`
coordinator and the standard SURF AXI-Lite crossbar. Each functional core contains
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

## Time, arithmetic and lifecycle contracts

- PHC time is seconds48/nanoseconds32/fraction32. Captures retain Q16 fraction,
  generation32, unsteered ticks64, eighth-cycle phase, and the exact active Q32
  increment. The existing RX `toSlv()` layout remains 744 bits and omits the new
  increment field; it is a legacy diagnostic/test packing, not a complete
  transport for endpoint records or a CDC interface.
- The timestamp plane is the first destination-MAC octet, with XGMII lane
  phase applied. Ingress is subtracted and egress added. Both are signed Q16
  **local PHC nanoseconds**, supplied by build-time latency generics in ABI v1. Egress excludes the single
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
sourcePortIdentity/domain, transportSpecific zero, PTP v2.0/v2.1, two-step Sync,
Follow_Up, Delay_Resp and Announce. Flag/control and canonical timestamp checks
follow structural/FCS validation. There is no BMCA, one-step Sync support, UDP,
VLAN, Pdelay, security extension, or automatic upstream selection.

Four bounded Sync/Follow_Up slots support either order. Conflicting Follow_Up
and duplicate physical Sync invalidate the association; completed slots may
retire, while unfinished slots cannot be overwritten. Corrected remote time
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

Independent rational PI sweeps cover ±100 ppm, initial ±10 µs, and Sync periods
1/8, 1/4 and 1 s. For those cases, peak error is below 12 µs and every sampled
error after 120 s is below 100 ns. Separate estimator sweeps include ±100 ns
packet delay variation. These are stated model cases, not a hardware accuracy
guarantee or a combined arbitrary-jitter stability proof. The physical endpoint
regressions accelerate packet intervals with exact fractional correction fields;
they verify state/command composition rather than long-duration default settling.

## AXI-Lite ABI v2

The [register map](register-map.md) defines the implemented four-bank ABI,
PyRogue hierarchy, commit/snapshot completion semantics, strobes and v1 migration.
`AXIL_BASE_ADDR_G` sets the aligned 4 KiB base on the endpoint/MAC composition;
the crossbar receives full addresses without local address stripping.

Configuration is stored in local shadows, frozen and validated by coordinated
commit, then applied by all banks on one edge. An accepted commit returns OKAY
before its result is known; software polls completion and checks ConfigError.
One snapshot strobe captures all local diagnostic banks with a common sequence.
AXI-only reset cancels bus responses but preserves accepted operations and active
state. See the [ownership record](register-ownership.md) for implementation and
verification details.

IRQ bits remain PHC fault, discontinuity, command error and servo fault. The last
exchange remains diagnostic after restart; compare its generation and sequences
before treating it as current. Local-MAC changes restart acquisition and rederive
the EUI-64 identity unless override is active, preserving the configured port
number. Calibration remains elaboration-time.

PyRogue is not installed on this machine. Static schema checks compare every
software field start/access mode with local RTL decode, and check overlap and
bank bounds; they do not constitute a live Rogue transport test.

## Optional snapshot CDC

`PtpPhcRead` is a separately instantiated request/response snapshot mailbox using
SURF asynchronous FIFOs and reset synchronizers. It is not a continuously
advancing replica, and it is not implicitly connected to the endpoint's local
AXI snapshots. Either read or PHC reset cancels both mailbox directions; a read
reset never resets the clock itself. Requests survive a stopped peer clock after
reset recovery: each FIFO write waits for acknowledgement rather than assuming
that deasserted full proves the peer domain is ready. Consumers accept only
`readValid` responses in their current reset session.

## Validation and handoff

The distributed-register refactor is being revalidated; current results are
tracked in [register-ownership.md](register-ownership.md). The following records
the earlier autonomous endpoint milestone.

- **The original autonomous milestone passed 101 distinct pytest cases.** This
  includes 84 pure reference cases and 17 parameterized RTL cases; some RTL cases
  contain more than one cocotb scenario. The two PHY closed-loop cases also pass
  independent absolute-phase checks after acquisition and reacquisition.
- Baseline: 60 reference cases and seven cocotb scenarios for the RX proof.
- New focused arithmetic/PHC/E2E/ledger/servo/reference run: 31 pytest cases pass.
  PHC cases also exercise independent-clock snapshot cancellation, a stopped
  PHC peer clock, and validity/PPS revocation coincident with seconds rollover. The ledger uses narrow sequences to force wrap and retirement.
- Register/PHC test passes shadow atomicity, alignment/strobes, command operand
  latching, backpressure, register-only reset, snapshots, identity changes and IRQ.
- XGMII +100 ppm with initial phase step and GMII −100 ppm without a step pass
  acquisition, lock, holdover expiry and reacquisition. At both lock checkpoints,
  PHC time compared directly with independent simulated master time has absolute
  error below 100 ns; generation counts also confirm the intended step policy.
  These two cases took 800.50 s with two workers on this machine.
- Physical adversarial port tests pass Follow_Up reordering, duplicate/conflicting
  keys, foreign source, invalid timestamps, completed-slot retirement, Sync
  timeout, grandmaster/timescale-change abort, Announce metadata, and every TX beat held
  across port reset and drained afterward.
- VSG and Python lint pass. Generic GHDL synthesis passes PHC, arithmetic, E2E,
  ledger, port, servo, registers, endpoint, primary guard and TX timestamp tap.
  The TX builder uses static slices after GHDL rejected its variable part select.
- The subsequent SURF style pass aligns declarations, record initializers and
  port maps, expands dense statements, and preserves the VHDL token sequence and
  comment text in all 22 PTP sources. Repository VSG and HDL import pass; the
  31-case arithmetic/PHC/E2E/ledger/servo/register/reference regression passes
  again after formatting (47.31 s).
- Optional `PtpPhcRead` generic synthesis is blocked in the existing SURF
  `SimpleDualPortRam.vhd` conditional write-enable assignment: GHDL reports a
  27-versus-1 vector-width mismatch for the 209-bit response FIFO with byte
  writes disabled. Mailbox simulation passes. This feature does not alter the
  shared RAM primitive; its device synthesis/CDC qualification remains open.
- Real-MAC lifecycle tests pass on both GMII and XGMII: primary payload, PTP
  identity guard, pause/port restart, retired late completion and fresh recovery.
  The pair took 1217.69 s with two workers during concurrent verification work.
- All 65 existing RX/reference/MAC-association pytest cases pass after integration.
- PyRogue syntax and 99 register fields were checked for address-bit overlap;
  a live PyRogue import/transport test remains unavailable on this machine.

### Review-gate disposition

| Review finding | Local evidence / remaining boundary |
| --- | --- |
| R3: RX frame identity after hidden MAC drops | Atomic message/capture RX replaces the disproved queue association; physical and real-MAC loss tests pass. |
| R4: generations, raw timers, reset/CDC | PHC cycle model, generation cancellation, stopped-peer snapshot sessions and register-only reset are implemented/tested; physical CDC qualification remains. |
| R5: oscillator-error bootstrap | Independent raw-tick estimator and rate-corrected E2E/calibration models, leaf RTL scoreboards and physical closed-loop cases; see the stated envelope above. |
| R6: persistent TX fate | Bounded keyed ledger, forced wrap/quarantine tests, stalled beat preservation and actual paused MAC requests on both PHYs. |
| R7: numerical encodings and timing | Q-format contracts, serialized checked engines, independent PI sweeps and command scoreboard; generic synthesis passes, device path/resource budgets remain open. |
| R8: timed events | Subsequent application timing milestone; no scheduler is implemented here. |
| R9: profile and interoperability | Concrete fixed-source parser/policy and adversarial packet fixtures exist; pinned external-master/packet-capture interoperability fixture remains open. |
| R10: hardware qualification | Select board, GT path, instrument and part; no hardware accuracy or family-wide timing claim follows from these simulations. |

Reproduce focused or full regressions using the [test index](../../../tests/ethernet/PtpCore/README.md).
Keep generated HDL, waveforms and simulator logs outside this plan directory.
Device synthesis/implementation must still measure PHC/capture/CRC and control
paths, resources, clock constraints and physical reset/CDC behavior. Then select
one board/GT sibling integration and calibrate its latency plane. Application
scheduling, cross-process timing simulation, interoperability against an external
PTP master, and live PyRogue transport testing are separate follow-on work.
