# PTP development register map

The endpoint occupies a 32 KiB aperture. Set the 32 KiB-aligned
`AXIL_BASE_ADDR_G` on `PtpEndpoint` or `EthMacPtpEndpoint` to the board address.
`ptpEndpointAxilConfig` in `PtpRegisterPkg` configures the SURF crossbar; full
addresses reach it unchanged. Addresses below are offsets from that base.
Local bank decoders use twelve address bits, expressed as three-digit hex
literals in the AXI register helpers; bank-local offsets are unchanged.
`0x1000`–`0x1FFF` and `0x6000`–`0x7FFF` are unmapped and return DECERR.

| Bank | Offset | RTL owner | PyRogue path |
| --- | --- | --- | --- |
| Endpoint | `0x000` | `PtpEndpointControl` | `PtpEndpoint` |
| Protocol engine | `0x2000` | `PtpProtocolReg` inside `PtpProtocolEngine` | `PtpEndpoint.ProtocolEngine` |
| Servo | `0x3000` | `PtpServo` | `PtpEndpoint.Servo` |
| PHC core control | `0x4000` | `PtpPhcControl` inside `PtpPhcCore` | `PtpEndpoint.PhcCore` |
| PHC | `0x5000` | `PtpPhc` inside `PtpPhcCore` | `PtpEndpoint.PhcCore.Phc` |

The PHC core is the same 8 KiB subsystem used standalone, documented in the
[PHC subsystem contract](phc.md). Its local offsets are the endpoint offsets
below minus `0x4000`. Inside the endpoint it runs under enclosing coordination:
use the endpoint's CommitConfig and Snapshot, not its local submissions.

Word-backed registers retain their addresses, widths, defaults and field strobes.
Reads/writes can wait for bounded initialization or candidate copying. Port and
servo prepare completion is explicit; ConfigBusy remains high through sequential
validation. Snapshot capture freezes common pre-edge state; SnapshotBusy remains
high until every bank is ready and the common publish edge advances all sequences.
Previous snapshot values remain readable during copying. See
[bank timing and shared-service bounds](interfaces.md#configuration-and-snapshots).

## Register ownership

| Owner | Register responsibilities |
| --- | --- |
| Endpoint control | ABI version, port enable, coordinated commit and snapshot commands/completion, restart policy, aggregate status and IRQ |
| PHC core control | Identity/capabilities, clock owner (AXI or servo), owner/command status and PHC event IRQ |
| PHC | Set/phase/rate operands, manual command submission/completion, monotonic and PPS policy, time/rate/raw-tick snapshots, clock constants and faults |
| Port | Source/domain/local identity, MAC-derived identity, request and association timers, rate-estimator limits, path-delay acceptance limit, calibration readback, Announce/exchange snapshots, ledger status and protocol/RX counters |
| Servo | Step policy, gains, frequency/slew limits, delay-age/holdover/sample limits, asymmetry, lock thresholds/counters, filter/offset/rate snapshots and servo diagnostics |

AXI logic belongs to each functional core and uses the existing SURF endpoint
helpers. The protocol engine delegates its bank to `PtpProtocolReg`. Keep
numerical/physical helpers such as `PtpMath`,
`PtpE2e`, and the timestamp adapters free of AXI. The port presents its ledger
diagnostics; a separate bus endpoint for every internal helper is unnecessary.
RX counters may enter port management from the physical frontend in the enclosing
MAC composition. They need not pass through endpoint control.

Manual operands, phase normalization and owner-gated admission belong to
`PtpPhc`, with accepted ownership retained through acknowledgement. The
committed owner belongs to `PtpPhcControl`; endpoint control supplies lifecycle
policy. A command's own capture invalidation must not cancel that command.

- `PtpProtocolReg` owns `PtpPortConfigType`, MAC-derived identity, shared active
  limits and diagnostic snapshot/publication storage inside `PtpProtocolEngine`.
  RX counters terminate here; policy and flow publish live diagnostics.
- `PtpServo` owns `PtpServoConfigType` and diagnostics, consuming the port's
  authoritative `PtpSharedConfigType`.
- `PtpPhc` owns its register map, manual operands, phase normalization,
  snapshots and final manual/external command admission. `PtpPhcControl`
  owns the committed clock owner and drains commands before changing it.
- PHC and servo retain register state in their existing `RegType`/`comb`/`seq`
  pair; protocol management has its own two-process `PtpProtocolReg` owner.
  All three cores always use their local AXI banks, with no optional configuration
  bypass. Standalone PHC and servo fixtures configure the real banks through AXI and prepare/apply strobes.
- `PtpEndpointControl` (formerly `PtpReg`) stores the port-enable shadow and
  candidate, commit/snapshot transactions, completion sequences and IRQ
  masks/status. It also owns the registered restart/RX-flush/event stages and
  combinational AXI reset. It sees local validation and preparation votes,
  including the PHC core's command drain, and narrow status signals, never
  wide diagnostic payloads.

Shared `associationTimeout`, `syncTimeout` and `maxPathDelay` have one writable
owner in the protocol engine and reach Servo as active `PtpSharedConfigType`
values. The engine validates them once; there are currently no cross-candidate
servo validation rules. Any future such rule must use the same frozen candidate
cohort. The coordinator exchanges scalar votes and narrow summaries, never wide
snapshot payloads. Independent validation inputs are not positional bank votes.
Sticky IRQ aggregation retains event-wins priority against concurrent W1C.

The register fixture uses the production cores/crossbar/controller, with explicit
prepare/apply override and snapshot inhibition for candidate/reset checks.
It tests command immutability while the real PHC performs phase normalization;
no test-only command gate is part of production RTL. The old mixed-owner map and
optional configuration bypass are not retained.

## Software naming

`PtpProtocolEngine` in `_PtpProtocolEngine.py` is exported from
`surf.ethernet.ptp` and instantiated as `PtpEndpoint.ProtocolEngine`, replacing
`PtpEndpoint.Port`. The composite device remains `PtpEndpoint`; root registers
map to `PtpEndpointControl`. Register offsets/fields and package `PtpPort*Type`
records are unchanged. The direct test entry point is `PtpProtocolEngineWrapper`
(formerly `PtpPortWrapper`). Historical checks retain their original entity
names. Hardware-backed models describe
registers; application orchestration belongs outside these devices.

## Transactions and reset

Configuration registers read back shadows. A write of one to `CommitConfig`
submits a transaction; an OKAY AXI response acknowledges submission, not successful
validation. Software records `ConfigSequence`, submits, polls `ConfigBusy` and
waits for the sequence to advance, then checks `ConfigError`. Busy submissions
and submissions during an accepted manual command return SLVERR. Local invalid
settings complete with `ConfigError=1`, advancing the sequence without applying
any bank. The previous error remains visible until completion.

PREPARE freezes all local and endpoint shadows and closes PHC command
admission. VALIDATE waits for preparation completion, including acknowledgement
of every accepted PHC command, before checking the frozen PHC owner, port and
servo candidates and manual-command exclusion. APPLY activates all candidates
on one common edge and restarts protocol/servo acquisition. Shadow edits after
PREPARE affect a subsequent commit. Shared association/Sync age and maximum path
limits have one writable owner in ProtocolEngine; Servo exposes read-only active copies.
PHC monotonic policy lives in Phc, the clock owner in PhcCore and
phase-step permission in Servo.

Snapshot submission is separate from commit. A pending request waits until
there is no commit in progress and PHC capture is qualified. All banks then
capture their pre-edge diagnostic values and the same next snapshot sequence.
Result banks are pinned and changing scalars copied from that frozen cohort.
After all banks report ready, one common publication edge exposes the cohort
and advances endpoint/local sequences. Previous snapshot data remains readable
while copying; SnapshotBusy includes that interval.
Poll `SnapshotSequence` before reading multiword values; local bank sequences
at `0x23FC`, `0x33FC`, `0x4104` and `0x53FC` must match. If snapshot capture coincides with
acceptance of a new commit, it captures the old configuration cohort before
PREPARE. A snapshot deferred across APPLY captures the subsequent cohort.
These counters saturate; system reset is required to regain distinguishable
sequence values after exhaustion.

`regRst` cancels the crossbar/slave bus state and outstanding AXI responses.
Accepted commit, snapshot and manual-command operations survive, as do shadows,
active configuration, PHC time and TX reservations. Software recovers completion
through status after bus reset. `portRst` cancels acquisition while preserving
PHC time and physical TX ownership. System reset must reach the full MAC/endpoint
TX pipeline. Manual steering is rejected while PhcCore.ActiveOwner selects the
servo; PPS control remains allowed. PHC command operands stay latched through target backpressure
and acknowledgement.

Unmapped addresses and writes to read-only fields return DECERR. Standard SURF
register helpers ignore address bits `[1:0]`, so all four byte addresses within
a word select the same register; there is no explicit alignment-error response.
Register writes use SURF helper strobe
semantics: strobes must cover every byte of the addressed field slice. Narrow
fields permit byte writes; partial 32-bit field writes and all-zero strobes
return DECERR without changing that field. For a multiword register, each word
is independently written to shadows; atomic activation requires CommitConfig.
Multiword numerical fields are least-significant-word first. Wire timestamps
and identities retain network significance within their numerical value.

## Development status

This map is still under development; there is no released ABI compatibility
contract. `Version` is `0x00030001`. Version 3.0 moved the clock owner and the
PHC bank into the shared PHC core at `0x4000`/`0x5000` and grew the endpoint
window to 32 KiB; 3.1 restores `ServoEnable` as servo run/stop, separate from
the PHC owner, and adds build-time PHC control modes (`CONTROL_MODE_G`) whose
`PhcCore` capability bits describe the compiled command paths. In an
`"EXTERNAL"` build the `Phc` set/phase/rate operand words (`0x5028`–`0x504F`)
are absent and return DECERR, and only PPS commands are accepted from AXI. Fields within each bank keep their local
offsets. Software should use the updated PyRogue children or the offsets below.

## PtpEndpoint fields

| Aperture offset | Field | Bits | Access | Meaning |
| --- | --- | --- | --- | --- |
| `0x000` | `Version` | 31:0 | RO | Register ABI version: major in upper 16 bits, minor in lower 16 bits. |
| `0x004` | `Enable` | 0 | RW | Enable fixed-source port after CommitConfig. |
| `0x004` | `ServoEnable` | 1 | RW | Run the servo after CommitConfig. It steers only while `PhcCore.ActiveOwner` selects it; stopping it never grants AXI steering. |
| `0x03C` | `CommitConfig` | 0 | WO | Submit a coordinated commit; poll ConfigBusy/ConfigSequence, then check ConfigError. Busy submissions return SLVERR. |
| `0x040` | `ConfigError` | 0 | RO | Validation of the last completed commit failed; no bank applied its candidate. |
| `0x040` | `ConfigBusy` | 1 | RO | Candidate preparation, validation or common-edge apply is in progress. |
| `0x044` | `ActiveEnable` | 0 | RO | Committed port enable. |
| `0x044` | `ActiveServoEnable` | 1 | RO | Committed servo run request. |
| `0x044` | `PortActive` | 4 | RO | A fresh configured Sync source is established. |
| `0x044` | `ServoState` | 10:8 | RO | 0 disabled, 1 acquiring, 2 tracking, 3 locked, 4 holdover, 5 fault. |
| `0x044` | `FilterCount` | 14:12 | RO | Number of populated median-filter samples, zero through five. |
| `0x044` | `AnnounceValid` | 16 | RO | Configured source Announce time properties are fresh. |
| `0x048` | `ConfigSequence` | 31:0 | RO | Saturating completion count for both successful and invalid commits. |
| `0x04C` | `IrqStatus` | 31:0 | RO | Sticky events: bit 0 PHC fault, 1 discontinuity, 2 command error, 3 servo fault. |
| `0x050` | `IrqMask` | 31:0 | RW | Enable corresponding sticky events on the IRQ output. |
| `0x054` | `IrqClear` | 31:0 | WO | Write-one-to-clear event mask; a concurrent new event wins. |
| `0x100` | `Snapshot` | 0 | WO | Freeze PHC, measurement, Announce and counters together; waits through a PHC discontinuity. |
| `0x104` | `SnapshotSequence` | 31:0 | RO | Saturating count of completed snapshots; multiword read data remains stable until the next snapshot. |
| `0x108` | `SnapshotBusy` | 0 | RO | An accepted snapshot is awaiting capture, frozen-bank copy or common publication. |

## PtpPhcCore fields

Endpoint offsets; subtract `0x4000` for a standalone core.

| Aperture offset | Field | Bits | Access | Meaning |
| --- | --- | --- | --- | --- |
| `0x4000` | `Version` | 31:0 | RO | PHC core register ABI version: major in upper 16 bits, minor in lower 16 bits. |
| `0x4004` | `Owner` | 0 | RW | Clock owner: 0 AXI bank, 1 external command client. A CommitConfig shadow when OwnerSelectable; read-only (fixed source) otherwise. |
| `0x4008` | `CommandMask` | 4:0 | RO | AXI-submittable command kinds: one bit each for set, phase, rate, validity and PPS. |
| `0x4008` | `ExternalCommand` | 8 | RO | External command admission is present in this build. |
| `0x4008` | `ExternalCoordination` | 9 | RO | An enclosing coordinator owns commits and snapshots; local submissions return SLVERR. |
| `0x4008` | `ManagementCrossing` | 10 | RO | AXI-Lite crosses from an independent management clock. |
| `0x4008` | `PhysicalSteering` | 11 | RO | Physical clock actuator control is present (always 0 in this core). |
| `0x4008` | `ManualCommand` | 12 | RO | Manual set/phase/rate/validity steering and its operands are present in this build. |
| `0x4008` | `OwnerSelectable` | 13 | RO | Owner is a runtime-selectable commit setting (SELECTABLE build); otherwise it is fixed. |
| `0x403C` | `CommitConfig` | 0 | WO | Submit a local commit; poll ConfigBusy/ConfigSequence, then check ConfigError. SLVERR when busy, during a manual command, or under enclosing coordination. |
| `0x4040` | `ConfigError` | 0 | RO | The last local commit failed validation; no setting changed. |
| `0x4040` | `ConfigBusy` | 1 | RO | A local or enclosing transaction is in progress; command admission is closed. |
| `0x4044` | `ActiveOwner` | 0 | RO | Committed clock owner: 0 AXI bank, 1 external command client. |
| `0x4044` | `CommandIdle` | 4 | RO | No manual command is in progress and the PHC command slot is free. |
| `0x4048` | `ConfigSequence` | 31:0 | RO | Saturating count of completed local commits, successful or invalid. |
| `0x404C` | `IrqStatus` | 2:0 | RO | Sticky events: bit 0 PHC fault, 1 discontinuity, 2 command error. |
| `0x4050` | `IrqMask` | 2:0 | RW | Enable corresponding sticky events on the IRQ output. |
| `0x4054` | `IrqClear` | 2:0 | WO | Write-one-to-clear event mask; a concurrent new event wins. |
| `0x4100` | `Snapshot` | 0 | WO | Capture PHC time, rate and ticks on one edge; SLVERR when pending or under enclosing coordination. |
| `0x4104` | `SnapshotSequence` | 31:0 | RO | Last published snapshot sequence, local or enclosing. |
| `0x4108` | `SnapshotBusy` | 0 | RO | An accepted local snapshot is awaiting capture or publication. |

## PtpPhc fields

| Aperture offset | Field | Bits | Access | Meaning |
| --- | --- | --- | --- | --- |
| `0x5004` | `Monotonic` | 3 | RW | Reject backward phase steps and absolute sets while PHC time is valid. |
| `0x5008` | `Seconds` | 47:0 | RO | PHC seconds snapshot. |
| `0x5010` | `Nanoseconds` | 31:0 | RO | Canonical nanoseconds snapshot, below one billion. |
| `0x5014` | `Fraction` | 31:0 | RO | Fractional nanoseconds snapshot, Q32. |
| `0x5018` | `Generation` | 31:0 | RO | PHC time-generation snapshot. |
| `0x501C` | `TimeValid` | 0 | RO | PHC validity snapshot. |
| `0x5020` | `PhcCommand` | 7:0 | WO | Write bit 7 to submit; kind bits 2:0: 0 set, 1 phase, 2 rate, 3 validity, 4 PPS; bit 3 is validity/PPS value. |
| `0x5024` | `CommandBusy` | 0 | RO | A manual command is normalizing, queued, or awaiting PHC acknowledgement. |
| `0x5024` | `CommandAck` | 1 | RO | Sticky completion of the most recently submitted manual command. |
| `0x5024` | `CommandError` | 2 | RO | Most recently completed manual command failed; cleared on new submission. |
| `0x5028` | `SetSeconds` | 47:0 | RW | Absolute set-time seconds shadow; target names the PHC commit edge. |
| `0x5030` | `SetNanoseconds` | 31:0 | RW | Absolute set nanoseconds shadow, below one billion. |
| `0x5034` | `SetFraction` | 31:0 | RW | Absolute set fractional nanoseconds shadow, Q32. |
| `0x5038` | `Phase` | 127:0 | RW | Signed Q16 nanosecond phase delta; applied to normally advanced commit-edge time. |
| `0x5048` | `RateAddend` | 63:0 | RW | Signed Q32 nanoseconds per cycle added to the nominal increment. |
| `0x5050` | `NominalAddend` | 63:0 | RO | Build-time nominal Q32 nanoseconds per clock cycle. |
| `0x5058` | `AppliedRateAddend` | 63:0 | RO | Snapshot of the applied signed Q32 rate addend. |
| `0x5060` | `Ticks` | 63:0 | RO | Snapshot of unsteered cycles; phase/set commands do not change this counter. |
| `0x5068` | `PhcFault` | 0 | RO | Fatal epoch/generation/tick exhaustion; system reset is required. |
| `0x5080` | `ClockFrequency` | 31:0 | RO | Build-time clock frequency in Hz; timer values use cycles of this clock. |
| `0x5084` | `ActiveMonotonic` | 3 | RO | Committed monotonic policy. |
| `0x53FC` | `SnapshotSequence` | 31:0 | RO | Sequence captured with this bank; matches the endpoint sequence after completion. |

## PtpProtocolEngine fields

Live activity/validity and ledger reads use the same registered diagnostic state
as the port status output. Activity reflects accepted/canceled protocol state;
ratio and Announce validity are sampled at each clock edge, and ledger status
is sampled from the ledger. These observations do not gate immediate protocol
cancellation. Announce, exchange and counter snapshots retain the common
pre-edge capture contract, including direct sampling of RX and ledger timeout
counters on that edge. Offsets, access modes and reset values are unchanged.

| Aperture offset | Field | Bits | Access | Meaning |
| --- | --- | --- | --- | --- |
| `0x2004` | `IdentityOverride` | 4 | RW | Use LocalIdentity instead of deriving EUI-64 from the shared MAC; the configured port number is preserved. |
| `0x2008` | `DomainNumber` | 7:0 | RW | Configured PTP domain shadow; candidate validation accepts 0–127 for non-isolated sdoId=000 and rejects 128–255. |
| `0x2008` | `MinorVersion` | 11:8 | RW | Transmitted PTP minor version: 0 selects 2008 Delay_Req control=1; 1 selects 2019 Layer-2 control=0. RX accepts any minor with major=2. |
| `0x2010` | `LocalIdentity` | 79:0 | RW | Local clockIdentity/portNumber shadow, network significance; low word at lowest address. |
| `0x2020` | `SourceIdentity` | 79:0 | RW | Only this upstream sourcePortIdentity is accepted; no BMCA. |
| `0x2030` | `LocalMac` | 47:0 | RO | Shared SURF MAC address, first wire octet in least significant byte. |
| `0x2044` | `Active` | 0 | RO | Current protocol session activity. |
| `0x2044` | `AnnounceValid` | 1 | RO | Current configured-source Announce metadata validity. |
| `0x2044` | `RatioValid` | 2 | RO | Raw-clock/master rate ratio is qualified and fresh. |
| `0x2048` | `TxStartupQuarantine` | 0 | RO | Startup packet-lifetime quarantine is active. |
| `0x2048` | `MacResetConfirmed` | 1 | RO | The ledger has observed the required MAC reset confirmation. |
| `0x2048` | `TxReserved` | 15:8 | RO | Number of reserved Delay_Req wire keys, including retirement quarantine. |
| `0x2048` | `TxUnknown` | 23:16 | RO | Reservations whose physical TX outcome remains unknown; logical restart retains them. |
| `0x2060` | `ActiveLocalIdentity` | 79:0 | RO | Committed local port identity used by newly allocated requests. |
| `0x2070` | `ActiveSourceIdentity` | 79:0 | RO | Committed upstream source port identity. |
| `0x2080` | `DelayInterval` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x2088` | `SyncTimeout` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x2090` | `AssociationTimeout` | 63:0 | RW | Raw-cycle shadow; must be at least MinimumAssociationTicks. Activate with CommitConfig. |
| `0x2098` | `MaxExchange` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x20A0` | `MinRateSpan` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x20A8` | `MaxRateAge` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x20B0` | `LfsrSeed` | 15:0 | RW | Delay_Req schedule seed shadow; zero becomes one on restart. |
| `0x20B8` | `MaxPathDelay` | 63:0 | RW | Signed Q16 nanoseconds configuration shadow; activate with CommitConfig. |
| `0x20C0` | `PacketLifetime` | 63:0 | RO | Build-time maximum packet lifetime and TX-key quarantine in raw clock cycles. |
| `0x20D0` | `IngressLatency` | 63:0 | RO | Build-time signed Q16 local-PHC nanoseconds at the calibrated reference plane. |
| `0x20D8` | `EgressLatency` | 63:0 | RO | Build-time signed Q16 local-PHC nanoseconds at the calibrated reference plane. |
| `0x20E0` | `ActiveAssociationTimeout` | 63:0 | RO | Committed raw-tick association limit shared with the servo. |
| `0x20E8` | `ActiveSyncTimeout` | 63:0 | RO | Committed raw-tick Sync receipt limit shared with the servo. |
| `0x20F0` | `ActiveMaxPathDelay` | 63:0 | RO | Committed positive Q16 nanosecond path-delay limit shared with the servo. |
| `0x20F8` | `MinimumAssociationTicks` | 31:0 | RO | Shared-service minimum: 70,347,776 raw ticks; smaller association candidates are invalid. |
| `0x2130` | `GrandmasterIdentity` | 63:0 | RO | Snapshot of grandmaster identity advertised by the configured source. |
| `0x2138` | `AnnounceFlags` | 15:0 | RO | Snapshot of PTP timescale, UTC-offset validity, leap and traceability flags. |
| `0x213C` | `CurrentUtcOffset` | 15:0 | RO | Announce UTC-offset snapshot; never applied as a PHC leap step. |
| `0x2140` | `AnnounceBody` | 239:0 | RO | Snapshot of all 30 Announce body octets, first wire byte in the most significant bits. |
| `0x2160` | `ExchangeT1` | 79:0 | RO | Last accepted exchange preciseOriginTimestamp: seconds48 then nanoseconds32. |
| `0x2170` | `ExchangeT2` | 95:0 | RO | Last accepted calibrated RX capture: seconds48, nanoseconds32, fraction16. |
| `0x2180` | `ExchangeT3` | 95:0 | RO | Last accepted calibrated TX capture: seconds48, nanoseconds32, fraction16. |
| `0x2190` | `ExchangeT4` | 79:0 | RO | Last accepted Delay_Resp receiveTimestamp: seconds48 then nanoseconds32. |
| `0x21A0` | `ExchangeSyncCorrection` | 127:0 | RO | Sum of accepted Sync and Follow_Up corrections, signed Q16 nanoseconds. |
| `0x21B0` | `ExchangeDelayCorrection` | 63:0 | RO | Accepted Delay_Resp correction, signed Q16 nanoseconds. |
| `0x21B8` | `ExchangeGeneration` | 31:0 | RO | PHC generation of the last accepted four-timestamp exchange. |
| `0x21BC` | `ExchangeSyncSequence` | 15:0 | RO | Sync sequence of the last accepted exchange. |
| `0x21BC` | `ExchangeDelaySequence` | 31:16 | RO | Delay_Req sequence of the last accepted exchange. |
| `0x2200` | `RxAccepted` | 31:0 | RO | Saturating diagnostic counter snapshot; reset by system reset. |
| `0x2204` | `RxDropped` | 31:0 | RO | Saturating diagnostic counter snapshot; reset by system reset. |
| `0x2208` | `RxOverflow` | 31:0 | RO | Saturating diagnostic counter snapshot; reset by system reset. |
| `0x220C` | `PortRejected` | 31:0 | RO | Saturating diagnostic counter snapshot; events accumulate one clock after rejection. Reset by system reset. |
| `0x2210` | `SyncCompleted` | 31:0 | RO | Saturating diagnostic counter snapshot; reset by system reset. |
| `0x2214` | `DelayCompleted` | 31:0 | RO | Saturating diagnostic counter snapshot; reset by system reset. |
| `0x2218` | `RequestTimeout` | 31:0 | RO | Saturating diagnostic counter snapshot; reset by system reset. |
| `0x23FC` | `SnapshotSequence` | 31:0 | RO | Sequence captured with this bank; matches the endpoint sequence after completion. |

## PtpServo fields

| Aperture offset | Field | Bits | Access | Meaning |
| --- | --- | --- | --- | --- |
| `0x3004` | `AllowStep` | 2 | RW | Permit a wide acquisition phase correction while PHC time is invalid. |
| `0x3020` | `Kp` | 31:0 | RW | Unsigned Q2.30 gain shadow; units ppb/ns for Kp and ppb/(ns*s) for Ki. |
| `0x3024` | `Ki` | 31:0 | RW | Unsigned Q2.30 gain shadow; units ppb/ns for Kp and ppb/(ns*s) for Ki. |
| `0x3028` | `MaxFrequencyPpb` | 31:0 | RW | Unsigned whole-ppb clamp shadow; activate with CommitConfig. |
| `0x302C` | `MaxSlewPpb` | 31:0 | RW | Unsigned whole-ppb clamp shadow; activate with CommitConfig. |
| `0x3030` | `MaxRatePpb` | 31:0 | RW | Unsigned whole-ppb clamp shadow; activate with CommitConfig. |
| `0x3038` | `StepThreshold` | 63:0 | RW | Signed Q16 nanoseconds configuration shadow; activate with CommitConfig. |
| `0x3040` | `LockThreshold` | 63:0 | RW | Signed Q16 nanoseconds configuration shadow; activate with CommitConfig. |
| `0x3048` | `UnlockThreshold` | 63:0 | RW | Signed Q16 nanoseconds configuration shadow; activate with CommitConfig. |
| `0x3050` | `LockCount` | 7:0 | RW | Qualification count shadow; activate with CommitConfig. |
| `0x3054` | `UnlockCount` | 7:0 | RW | Qualification count shadow; activate with CommitConfig. |
| `0x3060` | `MaxDelayAge` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x3068` | `HoldoverTimeout` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x3070` | `MinSampleTicks` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x3078` | `MaxSampleTicks` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
| `0x3080` | `DelayAsymmetry` | 63:0 | RW | Signed Q16 nanoseconds configuration shadow; activate with CommitConfig. |
| `0x3090` | `State` | 2:0 | RO | Current disabled/acquisition/tracking/locked/holdover/fault state. |
| `0x3090` | `FilterCount` | 6:4 | RO | Number of populated delay-filter samples. |
| `0x3094` | `ActiveKp` | 31:0 | RO | Committed proportional gain in Q2.30. |
| `0x3098` | `ActiveKi` | 31:0 | RO | Committed integral gain in Q2.30. |
| `0x30A0` | `AssociationTimeout` | 63:0 | RO | Read-only shared raw-tick association limit owned by Port. |
| `0x30A8` | `SyncTimeout` | 63:0 | RO | Read-only shared raw-tick Sync receipt limit owned by Port. |
| `0x30B0` | `MaxPathDelay` | 63:0 | RO | Read-only shared positive Q16 nanosecond delay limit owned by Port. |
| `0x3100` | `Offset` | 127:0 | RO | Snapshot of local-minus-master offset after filtered delay and asymmetry, signed Q16 ns. |
| `0x3110` | `FilteredDelay` | 127:0 | RO | Snapshot of populated-sample median path delay, signed Q16 ns. |
| `0x3120` | `RateCommand` | 63:0 | RO | Snapshot of the servo final rate command, signed Q16 ppb. |
| `0x3200` | `ServoRejected` | 31:0 | RO | Saturating diagnostic counter snapshot; reset by system reset. |
| `0x33FC` | `SnapshotSequence` | 31:0 | RO | Sequence captured with this bank; matches the endpoint sequence after completion. |

## PtpMacPort fields

The timing-port bank (`PtpMacPortReg` in `PtpMacPortEthMac`; PyRogue
`PtpMacPort`) is a 4 KiB bank outside the endpoint aperture. `GigEthPtp`
generates it only for `MAC_MODE_G = "TIMING_PORT"`, at `PORT_OFFSET_G`
(default `0x1000`); tapped builds return DECERR there. Offsets are bank-local.
It is read-only apart from `OccupancyClear`: an RTL controller owns the
control levels, so `SoftwareControl` reads 0 and writes to other offsets
return DECERR. The bus shares `clk` with the port; its reset cancels responses
only. Counters are the port's saturating `PtpMacPortCountersType` and clear
only at system reset ([counting rule](timing-port.md#3-receive-transaction)).

| Bank offset | Field | Bits | Access | Meaning |
| --- | --- | --- | --- | --- |
| `0x000` | `AbiVersion` | 7:0 | RO | Timing-port record ABI version (PTP_MAC_PORT_ABI_VERSION_C). |
| `0x000` | `PhyType` | 11:8 | RO | MAC interface: 1 GMII, 2 XGMII. |
| `0x000` | `Plane` | 15:12 | RO | Capture plane: 1 MAC/DMAC pins. |
| `0x000` | `TimingMode` | 16 | RO | Timing-mode MAC present. |
| `0x000` | `OneStep` | 17 | RO | One-step TX supported. |
| `0x000` | `SoftwareControl` | 18 | RO | Control levels are writable here; 0 when an RTL controller owns the port. |
| `0x000` | `TokenBits` | 31:24 | RO | Internal MAC token width. |
| `0x004` | `TxTableDepth` | 7:0 | RO | TX table entries. |
| `0x004` | `RxTableDepth` | 15:8 | RO | RX table entries. |
| `0x004` | `MaxFrameBytes` | 31:16 | RO | Ethernet byte limit, FCS excluded. |
| `0x008` | `CookieBits` | 7:0 | RO | TX request cookie width. |
| `0x010` | `AdmissionOpen` | 0 | RO | New TX requests and RX starts are admitted. |
| `0x010` | `DrainIdle` | 1 | RO | Every table entry is released. |
| `0x010` | `CancelRequest` | 2 | RO | Forced-abort cancel step is requested. |
| `0x010` | `AbortDone` | 3 | RO | Forced abort has completed. |
| `0x010` | `TransportGeneration` | 31:16 | RO | Live transport generation; 0 never admits traffic. |
| `0x014` | `FaultGeneration` | 0 | RO | Sticky: transport generation exhausted; admission closed until system reset. |
| `0x014` | `FaultClockEnable` | 1 | RO | Sticky: ethClkEn was observed low. |
| `0x014` | `FaultTokenProtocol` | 2 | RO | Sticky: a MAC event named an unexpected token; the frame was discarded uncounted. |
| `0x018` | `OpenAdmission` | 0 | RO | Controller level: open admission. |
| `0x018` | `DrainRequest` | 1 | RO | Controller level: graceful drain. |
| `0x018` | `AbortRequest` | 2 | RO | Controller level: forced abort. |
| `0x018` | `CancelAck` | 3 | RO | Controller level: cancel acknowledged. |
| `0x020` | `TxOccupancy` | 7:0 | RO | Owned TX table entries. |
| `0x020` | `TxOccupancyMax` | 15:8 | RO | Largest TX occupancy since system reset or OccupancyClear. |
| `0x020` | `RxOccupancy` | 23:16 | RO | Owned RX table entries. |
| `0x020` | `RxOccupancyMax` | 31:24 | RO | Largest RX occupancy since system reset or OccupancyClear; RxTableDepth means a start may have been refused. |
| `0x024` | `OccupancyClear` | 0 | WO | Restart TxOccupancyMax and RxOccupancyMax from the current occupancy. |
| `0x040` | `RxDelivered` | 31:0 | RO | Saturating: RX frames delivered to the controller. |
| `0x044` | `RxDropped` | 31:0 | RO | Saturating: tokened RX frames dropped by a MAC stage, length check or abort, plus starts refused for want of a table entry. |
| `0x048` | `RxLost` | 31:0 | RO | Saturating: RX starts the import leaf abandoned before emitting any beat. |
| `0x04C` | `TxSent` | 31:0 | RO | Saturating: TX completions SENT. |
| `0x050` | `TxWireError` | 31:0 | RO | Saturating: TX completions WIRE_ERR. |
| `0x054` | `TxDiscarded` | 31:0 | RO | Saturating: TX completions DISCARDED. |
| `0x058` | `TxFlushed` | 31:0 | RO | Saturating: TX completions FLUSHED. |
| `0x05C` | `TxRejected` | 31:0 | RO | Saturating: TX stream frames consumed without admission (no SOF or request context); they receive no completion. |

See [historical register checks](../../docs/plans/ethernet-ptp/history/verification.md#early-endpoint-and-ownership-milestones)
and [current acceptance](../../docs/plans/ethernet-ptp/acceptance.md#outstanding-acceptance). Cycle-level
broadcast contracts and record ownership are in the [timing guide](interfaces.md).
