# Distributed PTP register ownership

Status: register ownership implemented. The subsequent [RTL readability
cleanup](rtl-readability.md) is awaiting maintainer VHDL approval; regressions
are prohibited until that approval. Earlier focused results below precede it. The endpoint now
uses four local AXI banks and [ABI v2](register-map.md). AXI-Lite logic is inside
`PtpPhc`, `PtpPort` and `PtpServo`, sharing each core's existing state record
and register process. Standalone direct interfaces remain available. No v1 compatibility decoder is retained.

## Problem and intended ownership

Before this refactor, `PtpReg` owned configuration for every subsystem, manual PHC command
preparation (including a `PtpMath` instance), and snapshots of PHC, servo,
Announce, exchange and counter state. `PtpEndpoint` consequently routes wide
diagnostic records and many individual status signals to a central register
block. A local diagnostic consequently required edits outside its owner.

The implementation distributes AXI-Lite decode, shadow/active configuration and
snapshot storage to the functional owners. `AxiLiteCrossbar` at `PtpEndpoint`
routes one external AXI-Lite interface to four local endpoints:

| Owner | Register responsibilities |
| --- | --- |
| Endpoint control | ABI/capabilities, endpoint and automatic-control enables, coordinated commit and snapshot commands/completion, restart policy, aggregate status and IRQ |
| PHC | Set/phase/rate operands, manual command submission/completion, monotonic and PPS policy, time/rate/raw-tick snapshots, clock constants and faults |
| Port | Source/domain/local identity, MAC-derived identity, request and association timers, rate-estimator limits, path-delay acceptance limit, calibration readback, Announce/exchange snapshots, ledger status and protocol/RX counters |
| Servo | Step policy, gains, frequency/slew limits, delay-age/holdover/sample limits, asymmetry, lock thresholds/counters, filter/offset/rate snapshots and servo diagnostics |

AXI logic belongs directly in each functional core's VHDL module and uses the existing
SURF endpoint helpers. Keep numerical/physical helpers such as `PtpMath`,
`PtpE2e`, and the timestamp adapters free of AXI. The port presents its ledger
diagnostics; a separate bus endpoint for every internal helper is unnecessary.
RX counters may enter port management from the physical frontend in the enclosing
MAC composition. They need not pass through endpoint control.

Move manual phase normalization with PHC register ownership. The PHC management
boundary should also own final manual/servo command arbitration through
acknowledgement. Endpoint control supplies steering permission and independent
restart/cancellation policy. Preserve the distinction between an automatic
command's own capture invalidation and an external cause that cancels it.

## Coordination contracts that must survive

Local register storage does not imply independently applying every write.

1. **Atomic configuration.** Each owner keeps shadows and active settings. A
   central commit request freezes candidate settings, collects local validation
   results and either applies all candidates on one common edge or applies none.
   Writes after candidate capture must not change the values being validated.
   Define busy, rejection and completion behavior before changing the bus map.
   Preserve the current exclusion between commit and an accepted manual command.
2. **Shared settings have one owner.** For example, the port owns
   `associationTimeout`, `syncTimeout` and `maxPathDelay`, which the servo also
   consumes. Export their active values through a small explicit shared record;
   do not create independently writable copies. Local validation of a candidate
   must use the corresponding frozen shared candidate when it depends on it.
   Replace the broad `PtpConfigType` distribution with subsystem configuration
   records and these explicit dependencies.
3. **Coherent diagnostics.** Endpoint control broadcasts one snapshot capture
   strobe on a qualified edge, deferring while PHC capture is invalidated. Each
   owner stores its own data on that edge. A common snapshot sequence identifies
   the set and completion is exposed only after every bank has captured it.
   AXI read latency then cannot mix PHC and servo values from different samples.
   A simultaneous configuration apply must have a documented old/new-state
   priority across all banks. All participants currently share one clock.
4. **Reset domains.** Register-only reset clears crossbar and slave bus state,
   while active configuration, accepted commands and PHC time survive. Specify
   what happens to an accepted commit/snapshot operation whose AXI response is
   canceled; bus reset must not partially apply a configuration. Port restart
   continues to preserve PHC time, drain presented TX frames and retain unknown
   wire ownership. System reset still reaches the complete physical TX pipeline.
5. **Interrupts.** Local sources expose narrow event/status signals. Central
   sticky status, masking and aggregation can remain small. Preserve event-wins
   priority for simultaneous W1C and fault events.

The coordinator should exchange candidates' validity, apply/snapshot controls,
completion and narrow summary signals. It should not regain ownership of the
wide diagnostic payloads through a new central record.

## Implemented composition and ABI

- `PtpPort` owns `PtpPortConfigType`, MAC-derived identity, shared active
  limits and local diagnostics. RX counters terminate here.
- `PtpServo` owns `PtpServoConfigType` and diagnostics, consuming the port's
  authoritative `PtpSharedConfigType`.
- `PtpPhc` owns its register map, manual operands, phase normalization,
  snapshots and final manual/automatic command arbitration.
- All three cores merge register state into the existing `RegType` and update
  it in their single `comb`/`seq` pair. There are no separate AXI management
  wrappers or PHC register entity. All three cores always use their local AXI
  banks, with no optional configuration bypass. Standalone PHC and servo
  fixtures configure the real banks through AXI and prepare/apply strobes.
- `PtpReg` now stores only global enable shadows/candidates, commit and snapshot
  transaction state, completion sequences and IRQ masks/status. It sees local
  validation votes, narrow summary signals and events, never wide payloads.

The crossbar uses `genAxiLiteConfig(4, AXIL_BASE_ADDR_G, 12, 10)` and direct
record connections. `AXIL_BASE_ADDR_G` propagates through `EthMacPtpEndpoint`
and physical test wrappers; no process rewrites upper address bits. The base
must be 4 KiB aligned. Register-only reset reaches both crossbar and local bus
state. The focused register fixture instantiates the same cores/crossbar with
optional direct prepare/apply controls for frozen-candidate checks and snapshot
inhibition for reset recovery. Manual command immutability is checked while the
real PHC performs serialized phase normalization; no test-only command gate
enters production RTL.

The [ABI v2 map](register-map.md) defines exact offsets and access semantics.
The previous mixed-owner offsets are deliberately revised. PyRogue preserves
field names under `Phc`, `Port` and `Servo` children. Version is `0x00020000`.
Commit submission is asynchronous: invalid candidate validation completes through
ConfigError/ConfigSequence rather than changing an already returned AXI response.
The complete timing, snapshot sequence and reset-recovery contracts are in the
map. There are currently no validation rules requiring a servo candidate to
compare its own fields with a port candidate: the port validates shared values
once, and the common apply edge installs their authoritative active copy.

## Validation before the readability cleanup

These results do not validate the subsequent interface/control-flow changes.
See [the review record](rtl-readability.md) for build-only validation and the
maintainer approval gate.

- Nine focused pytest cases pass after folding the banks into the functional
  cores: both zero/nonzero AXI bases, four static software/RTL schema checks,
  two PHC clock/reset configurations and the servo regression.
- The register tests cover unrelated-high-address rejection, every bank's
  error/strobe behavior, local validation rejecting all candidates, shadow
  mutation after prepare, authoritative shared limits, common snapshot sequence
  and capture edge, immutable phase commands and register-reset recovery.
- An accepted commit survives AXI reset during preparation and completes once;
  an accepted snapshot survives reset while capture is inhibited. Software
  recovers completion through the surviving sequence registers.
- All PTP VHDL passes the repository VSG rules; changed Python passes flake8.
  Ruckus/GHDL import passes. Generic synthesis passes for `PtpReg`, `PtpPhc`,
  `PtpPort`, `PtpServo` and `PtpEndpoint`, with local AXI enabled in the cores.
- The updated SVG has been rendered and visually checked.
- Final GMII/XGMII autonomous endpoint, real-MAC lifecycle and port regressions
  were stopped at the maintainer's request before completion. They do not count
  as passing validation of the folded cores.
- No Vivado/VCS, physical timing/CDC or live Rogue transport qualification is
  implied. The previously documented optional snapshot FIFO synthesis issue
  remains outside this refactor.

Tests and models are indexed in [the test README](../../../tests/ethernet/PtpCore/README.md).
The [implementation record](autonomous-endpoint.md) retains the original endpoint
milestone evidence separately from this refactor's results.

The [interface record review](interface-records.md) documents the directional
PHC command channel, separate commit/snapshot broadcasts, and named diagnostics
now used between the local register owners. Register offsets are unchanged.
