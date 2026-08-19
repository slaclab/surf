# Ethernet PTP Support

## Goal and status

Explore and stage reusable IEEE 1588 Precision Time Protocol support for the
SURF Ethernet stack. The first application is an autonomous FPGA endpoint that
receives PTP, exchanges the required delay messages, and disciplines its local
time without relying on Linux `ptp4l`. Rogue may configure and observe the
endpoint, but it is not in the timing loop.

Status: architecture planning. No RTL, register map, or public interface has
been selected or implemented.

## Current SURF architecture

- `ethernet/EthMacCore/rtl/EthMacTop.vhd` is the common MAC integration point.
  It joins asynchronous primary and bypass AXI Stream inputs, checksum and
  pause processing, GMII/XGMII export/import, receive filtering, and output
  FIFOs.
- The physical capture planes are the GMII and XGMII import/export leaves:
  `EthMacRxImportGmii`, `EthMacTxExportGmii`, `EthMacRxImportXgmii`, and
  `EthMacTxExportXgmii`. These leaves already identify the preamble/SFD or
  XGMII start control character and therefore have the best common location
  for MAC-level timestamp capture.
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

## Recommended product boundary

Build the capability in layers. Start with profile-neutral timing primitives,
then add a bounded FPGA-resident PTP TimeReceiver endpoint:

1. A disciplined PTP hardware clock (PHC) primitive with set time, atomic
   offset adjustment, fine frequency adjustment, coherent readout, and PPS.
2. Clock-domain-safe distribution of its current time to each Ethernet
   transmit and receive capture domain.
3. Ingress timestamps for received frames and selective, tagged egress
   timestamps for transmitted frames.
4. Signed, separately configurable ingress and egress latency corrections so
   a MAC capture time can be calibrated to a defined physical reference plane.
5. A stable metadata contract that lets application or software logic
   associate a timestamp with the correct frame.
6. A layer-2 PTP message parser/generator and endpoint state machine capable of
   receiving Sync/Follow_Up and Delay_Resp and transmitting timestamped
   Delay_Req messages.
7. A hardware or embedded-firmware servo interface that calculates offset and
   path delay and disciplines the local PHC. The timing loop must continue
   without Rogue or a host operating system.

The first endpoint can use a configured TimeTransmitter and fixed
TimeReceiver-only role instead of implementing full BMCA and every management
data set. Keep the packet/timestamp primitives usable independently so a later
ordinary clock, application-specific servo, or embedded CPU can reuse them.

The initial functional target should be IEEE 1588-2019-compatible two-step,
layer-2 PTP. Layer 2 aligns with the likely White Rabbit follow-on and avoids
requiring the IPv4/UDP stack for the first synchronized endpoint. Two-step
operation does not rewrite a frame already in flight and avoids immediate
correction-field, UDP-checksum, and FCS update logic. One-step and transparent-
clock support can build on the same clock and capture plane after the two-step
contract is stable.

## Proposed architectural layers

```text
FPGA PTP endpoint state machine and servo
          | PTP messages + timestamp request/tag or response
          v
PTP metadata association and CDC
          | local time + per-frame metadata
          v
EthMacTop and GMII/XGMII timestamp capture
          | calibrated MAC/PHY timestamp
          v
PCS/PMA, transceiver, and physical medium

Rogue / AXI-Lite control ---- configuration, status, diagnostics only
```

### Time representation

Use an exported 80-bit time-of-day representation matching common Ethernet
timestamp interfaces: 48-bit seconds and 32-bit nanoseconds. Carry at least 16
fractional-nanosecond bits in the PHC accumulator, correction arithmetic,
timestamp metadata, and time-distribution logic. The fractional field is
important for a future IEEE 1588 High Accuracy/White Rabbit implementation and
prevents the ordinary PTP servo from quantizing frequency correction to whole
nanoseconds. Define record types and packing helpers in one PTP package, with
init constants and unconstrained arrays where appropriate.

The PHC should expose these operations independently of AXI-Lite so it remains
composable:

- coherent `get time` snapshot;
- absolute `set time`;
- signed atomic time offset;
- signed fine frequency adjustment;
- PPS and optional external-event/per-out hooks.

An AXI-Lite wrapper and matching PyRogue device can then provide the control
plane. The endpoint must also expose direct RTL set/step/frequency-control
ports so its servo does not perform timing-critical operations through
AXI-Lite.

### FPGA endpoint and servo boundary

A synchronized PTP TimeReceiver is bidirectional even though its purpose is to
receive time. In the delay request-response mechanism it receives Sync and
Follow_Up, transmits Delay_Req with an egress timestamp, and receives
Delay_Resp. The first endpoint therefore needs both RX and TX timestamp paths.

Keep the following blocks separate and independently testable:

- PTP layer-2 frame classifier, parser, and message builder;
- protocol state and sequence/identity matching;
- timestamp capture and tag association;
- offset/path-delay calculation;
- clock servo and PHC actuator;
- configuration, monitoring, and fault/holdover status.

For the first milestone, support one configured upstream TimeTransmitter and a
fixed TimeReceiver role. Full Announce processing, BMCA, unicast negotiation,
security, multiple domains, and all management TLVs are later protocol scope.
The servo should have explicit acquisition, locked, holdover, and fault states
and configurable bounds on phase steps and frequency trim.

### Capture plane and calibration

Capture at SFD in the local GMII/XGMII clock domain. Document exactly which
clock edge and byte lane constitute time zero for each PHY type. XGMII must
handle both legal start-lane positions; GMII must honor `ethClkEn`, including
10/100 Mb/s operation if those modes are claimed.

The captured value is initially a MAC-interface timestamp. PCS/PMA,
transceiver, board, and PHY latency can be fixed, reset-dependent, or variable.
Apply explicit signed ingress/egress corrections and name the advertised
reference plane. Do not claim wire-level accuracy until latency stability is
measured on a concrete target.

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

### Frame-to-timestamp association

This is the main interface decision and should be prototyped before changing
`EthMacTop`:

- Preferred contract: timestamp every accepted ingress frame; request egress
  timestamps selectively with an operation plus a 16-bit tag on the first
  frame beat; return the same tag with the timestamp. This is profile-neutral
  and follows established Ethernet-MAC practice.
- The request/tag must follow the selected frame through the primary/bypass
  FIFOs, arbitration, checksum, pause, padding, and link-down/drop paths.
  A standalone pulse sampled before those stages is not sufficient.
- RX metadata must define what happens for CRC failures, filtered frames,
  FIFO-dropped frames, and the primary/bypass split. Timestamp order alone is
  not a safe association contract when frames can disappear.
- Do not overload existing `TDEST`, `TID`, or the four-bit Ethernet `TUSER`
  convention without a compatibility analysis. A dedicated metadata record
  and small ready/valid FIFO is the safer initial prototype.

Two implementation shapes should be evaluated with a small proof of concept:

1. Add an optional metadata plane through the existing MAC pipeline, guarded
   by a default-disabled generic.
2. Introduce a PTP-capable sibling/wrapper around the legacy MAC so
   `EthMacTop` retains its exact public entity interface.

The second shape is preferable if the first would force downstream users to
edit every direct `EthMacTop` instantiation. Avoid extending existing public
config/status records until source compatibility is understood.

## Phased implementation plan

### Phase 0: requirements and measurable contract

- Use two-step layer-2 PTP with a configured upstream TimeTransmitter for the
  initial endpoint unless a concrete application requires another profile.
- Select the first physical target and line rate. Prefer 1 GbE/1000BASE-X if
  White Rabbit compatibility is a near-term objective; retain an XGMII
  simulation target to prove the generic capture interfaces.
- State the target accuracy, timestamp reference plane, and allowed reset-to-
  reset variation.
- Document the target board's clock sources and determine whether a frequency
  and phase actuator is available or required for the claimed operating mode.
- Decide whether the first servo is pure RTL or small embedded firmware. Rogue
  remains outside the timing loop in either case.

Exit criterion: a short interface specification with timestamp format,
capture point, tag/association behavior, correction units/range, overflow
behavior, and reset semantics.

### Phase 1: PTP clock and time distribution

- Add a PTP package, core clock, AXI-Lite wrapper, and thin cocotb wrapper in a
  new `ethernet/PtpCore/` area.
- Support 48-bit seconds, 32-bit nanoseconds, fractional accumulation, PPS,
  absolute set, atomic offset, and frequency trim.
- Provide coherent CDC/time distribution into independent Ethernet domains;
  do not synchronize an 80-bit counter as unrelated bits.
- Add the matching `python/surf/ethernet/ptp/` PyRogue model only after the
  register layout is fixed.

Exit criterion: deterministic simulations prove rollover, atomic updates,
positive/negative frequency adjustment, monotonic behavior under normal trim,
PPS placement, and coherent multi-clock copies.

### Phase 2: leaf MAC timestamp capture

- Prototype RX and TX SFD capture at the XGMII leaves, including both start
  lanes, then at the GMII leaves.
- Apply signed ingress/egress latency offsets with fractional-nanosecond units
  defined by the package.
- Return TX tag/timestamp results through a ready/valid interface with explicit
  overflow reporting.
- Keep the existing non-PTP datapath bit-for-bit and cycle-compatible when PTP
  is disabled.

Exit criterion: cocotb drives a known time ramp and proves the exact timestamp
for varied frame lengths, back-to-back frames, both XGMII start alignments,
link-down recovery, reset, and GMII clock-enable cases.

### Phase 3: full `EthMacTop` metadata association

- Carry TX requests/tags through primary and bypass clock conversion and
  arbitration to the actual transmitted frame.
- Carry or associate RX timestamps through CRC handling, filtering, route
  selection, and output FIFOs without mismatches when a frame is dropped.
- Add counters for timestamp requests, completions, metadata FIFO overflow,
  orphaned metadata, and dropped timestamped frames.
- Integrate optional support into the first 10 GbE and 1 GbE core wrappers
  without changing legacy reset, AXI Stream, or AXI-Lite behavior.

Exit criterion: top-level randomized tests prove frame/tag/timestamp identity
under asynchronous clocks, backpressure, pause, primary/bypass contention,
bad CRC, filtering, FIFO drops, and link resets.

### Phase 4: autonomous FPGA PTP TimeReceiver

- Add a layer-2 PTP parser and message builder for Sync, Follow_Up, Delay_Req,
  and Delay_Resp.
- Implement sequence, domain, port identity, correction-field, and timestamp
  matching using fixed-point arithmetic with fractional nanoseconds.
- Implement a configured-TimeTransmitter TimeReceiver state machine, bounded
  timeouts, reacquisition, fault detection, and holdover.
- Connect an initial clock servo to the PHC direct-control interface. Keep its
  gains, limits, step/slew policy, and lock thresholds configurable.
- Export synchronized time, PPS, lock/holdover state, measured path delay,
  offset, and servo diagnostics to application logic.

Exit criterion: a cocotb PTP peer model introduces controlled offset, drift,
path delay, packet loss, and jitter; the endpoint acquires lock, maintains the
specified error bound, enters holdover on message loss, and reacquires without
metadata mismatches.

### Phase 5: control-plane integration and hardware validation

- Add PyRogue variables and commands mirroring the final PHC and calibration
  register maps.
- Provide one small integration example that sends and receives two-step PTP
  event traffic, demonstrates autonomous synchronization, and makes synchronized
  time/PPS available to application logic.
- Measure ingress/egress latency and reset variation against a reference PTP
  NIC or analyzer on the selected board.

Exit criterion: repeatable hardware results meet the Phase 0 accuracy budget
and identify calibrated fixed delay, residual jitter, and reset dependence.

### Phase 6: High Accuracy/White Rabbit feasibility and integration

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

- One-step Sync insertion and correction-field updates.
- Transparent- and boundary-clock assistance, including residence time.
- UDP/IPv4 and UDP/IPv6 checksum-aware in-flight modification.
- External timestamp inputs and programmable periodic outputs.
- Full BMCA, management, multi-domain, unicast, and security features beyond
  the configured-TimeTransmitter endpoint.
- Vendor CMAC/100 GbE timestamp ports in `Caui4Core`.
- XLGMII/40 GbE only after that datapath itself is implemented and tested.

## Verification matrix

At minimum, focused tests should cover:

- PHC: second rollover, nanosecond normalization, set/step/trim corner cases,
  coherent reads, PPS, and CDC under unrelated clocks.
- Capture: GMII and both XGMII start lanes, exact SFD edge, fractional offset,
  and timestamp behavior when `phyReady` changes.
- Association: multiple outstanding TX tags, primary/bypass arbitration,
  backpressure, pause, underflow, filtered or CRC-bad RX frames, metadata FIFO
  full, and counter wrap.
- Endpoint: message parsing, sequence/domain/identity rejection, two-step
  timestamp matching, correction-field arithmetic, offset/path-delay solution,
  acquisition, bounded servo response, packet loss, holdover, and reacquisition.
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

1. Confirm that two-step layer-2 PTP and the delay request-response mechanism
   are the correct initial profile and transport choices.
2. Which board/core and rate define the first hardware milestone?
3. Should the first autonomous servo be pure RTL or run as embedded firmware
   on a small soft processor?
4. What accuracy is required at the MAC, connector, and remote endpoint?
5. Must 10/100 Mb/s modes work in the first GMII release?
6. Is a new PTP-capable MAC wrapper acceptable, or must the exact
   `EthMacTop` entity gain optional ports?
7. What clock actuator is available on the first board, and does it expose a
   recovered Ethernet clock suitable for a later SyncE loop?

## Risks

- The timestamp math is straightforward; frame/metadata association across
  the current FIFO and bypass topology is the largest RTL integration risk.
- A precise MAC timestamp can still be inaccurate at the wire if PCS/PMA or
  transceiver latency is variable or uncalibrated.
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

## External reference points

- [IEEE 1588-2019](https://standards.ieee.org/ieee/1588/6825/) is the active
  base standard; the exact deployment profile still needs selection.
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
