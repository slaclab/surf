# PTP development register map

The endpoint exposes four 4 KiB banks in a 16 KiB aperture. Set the 16 KiB-aligned
`AXIL_BASE_ADDR_G` on `PtpEndpoint` or `EthMacPtpEndpoint` to the board address.
`genAxiLiteConfig(4, AXIL_BASE_ADDR_G, 14, 12)` configures the existing SURF
crossbar; full addresses reach it unchanged. Addresses below are offsets from
that base. Local bank decoders use twelve address bits, expressed as three-digit hex
literals in the AXI register helpers. Bank-local offsets are unchanged.

| Bank | Offset | RTL owner | PyRogue path |
| --- | --- | --- | --- |
| Endpoint | `0x000` | `PtpReg` | `PtpEndpoint` |
| PHC | `0x1000` | `PtpPhc` | `PtpEndpoint.Phc` |
| Port | `0x2000` | `PtpPort` | `PtpEndpoint.Port` |
| Servo | `0x3000` | `PtpServo` | `PtpEndpoint.Servo` |

## Transactions and reset

Configuration registers read back shadows. A write of one to `CommitConfig`
submits a transaction; an OKAY AXI response acknowledges submission, not successful
validation. Software records `ConfigSequence`, submits, polls `ConfigBusy` and
waits for the sequence to advance, then checks `ConfigError`. Busy submissions
and submissions during an accepted manual command return SLVERR. Local invalid
settings complete with `ConfigError=1`, advancing the sequence without applying
any bank. The previous error remains visible until completion.

PREPARE freezes all local and endpoint shadows. VALIDATE checks the frozen
port/servo candidates and manual-command exclusion. APPLY activates all candidates
on one common edge and restarts protocol/servo acquisition. Shadow edits after
PREPARE affect a subsequent commit. Shared association/Sync age and maximum path
limits have one writable owner in Port; Servo exposes read-only active copies.
PHC monotonic policy lives in Phc; phase-step permission lives in Servo.

Snapshot submission is separate from commit. A pending request waits until
there is no commit in progress and PHC capture is qualified. All banks then
capture their pre-edge diagnostic values and the same next snapshot sequence.
The endpoint publishes that sequence on the same edge, after local capture.
Poll `SnapshotSequence` before reading multiword values; local bank sequences
at `0x13FC`, `0x23FC`, and `0x33FC` must match. If snapshot capture coincides with
acceptance of a new commit, it captures the old configuration cohort before
PREPARE. A snapshot deferred across APPLY captures the subsequent cohort.
These counters saturate; system reset is required to regain distinguishable
sequence values after exhaustion.

`regRst` cancels the crossbar/slave bus state and outstanding AXI responses.
Accepted commit, snapshot and manual-command operations survive, as do shadows,
active configuration, PHC time and TX reservations. Software recovers completion
through status after bus reset. `portRst` cancels acquisition while preserving
PHC time and physical TX ownership. System reset must reach the full MAC/endpoint
TX pipeline. Manual steering is rejected with ServoEnable active; PPS control
remains allowed. PHC command operands stay latched through target backpressure
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
contract. The existing `Version` register value (`0x00020000`) is retained while
the layout evolves. The bank spacing is now 4 KiB, with PHC, Port and Servo at
`0x1000`, `0x2000` and `0x3000`. Software should use the updated PyRogue children
or the offsets below. Fields within each bank keep their existing local offsets.
The endpoint window occupies 16 KiB and must be aligned accordingly.

## PtpEndpoint fields

| Aperture offset | Field | Bits | Access | Meaning |
| --- | --- | --- | --- | --- |
| `0x000` | `Version` | 31:0 | RO | Register ABI version: major in upper 16 bits, minor in lower 16 bits. |
| `0x004` | `Enable` | 0 | RW | Enable fixed-source port after CommitConfig. |
| `0x004` | `ServoEnable` | 1 | RW | Enable automatic clock control after CommitConfig. |
| `0x03C` | `CommitConfig` | 0 | WO | Submit a coordinated commit; poll ConfigBusy/ConfigSequence, then check ConfigError. Busy submissions return SLVERR. |
| `0x040` | `ConfigError` | 0 | RO | Validation of the last completed commit failed; no bank applied its candidate. |
| `0x040` | `ConfigBusy` | 1 | RO | Candidate preparation, validation or common-edge apply is in progress. |
| `0x044` | `ActiveEnable` | 0 | RO | Committed port enable. |
| `0x044` | `ActiveServoEnable` | 1 | RO | Committed servo enable. |
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
| `0x108` | `SnapshotBusy` | 0 | RO | An accepted snapshot is waiting for a qualified common capture edge. |

## PtpPhc fields

| Aperture offset | Field | Bits | Access | Meaning |
| --- | --- | --- | --- | --- |
| `0x1004` | `Monotonic` | 3 | RW | Reject backward phase steps and absolute sets while PHC time is valid. |
| `0x1008` | `Seconds` | 47:0 | RO | PHC seconds snapshot. |
| `0x1010` | `Nanoseconds` | 31:0 | RO | Canonical nanoseconds snapshot, below one billion. |
| `0x1014` | `Fraction` | 31:0 | RO | Fractional nanoseconds snapshot, Q32. |
| `0x1018` | `Generation` | 31:0 | RO | PHC time-generation snapshot. |
| `0x101C` | `TimeValid` | 0 | RO | PHC validity snapshot. |
| `0x1020` | `PhcCommand` | 7:0 | WO | Write bit 7 to submit; kind bits 2:0: 0 set, 1 phase, 2 rate, 3 validity, 4 PPS; bit 3 is validity/PPS value. |
| `0x1024` | `CommandBusy` | 0 | RO | A manual command is normalizing, queued, or awaiting PHC acknowledgement. |
| `0x1024` | `CommandAck` | 1 | RO | Sticky completion of the most recently submitted manual command. |
| `0x1024` | `CommandError` | 2 | RO | Most recently completed manual command failed; cleared on new submission. |
| `0x1028` | `SetSeconds` | 47:0 | RW | Absolute set-time seconds shadow; target names the PHC commit edge. |
| `0x1030` | `SetNanoseconds` | 31:0 | RW | Absolute set nanoseconds shadow, below one billion. |
| `0x1034` | `SetFraction` | 31:0 | RW | Absolute set fractional nanoseconds shadow, Q32. |
| `0x1038` | `Phase` | 127:0 | RW | Signed Q16 nanosecond phase delta; applied to normally advanced commit-edge time. |
| `0x1048` | `RateAddend` | 63:0 | RW | Signed Q32 nanoseconds per cycle added to the nominal increment. |
| `0x1050` | `NominalAddend` | 63:0 | RO | Build-time nominal Q32 nanoseconds per clock cycle. |
| `0x1058` | `AppliedRateAddend` | 63:0 | RO | Snapshot of the applied signed Q32 rate addend. |
| `0x1060` | `Ticks` | 63:0 | RO | Snapshot of unsteered cycles; phase/set commands do not change this counter. |
| `0x1068` | `PhcFault` | 0 | RO | Fatal epoch/generation/tick exhaustion; system reset is required. |
| `0x1080` | `ClockFrequency` | 31:0 | RO | Build-time clock frequency in Hz; timer values use cycles of this clock. |
| `0x1084` | `ActiveMonotonic` | 3 | RO | Committed monotonic policy. |
| `0x13FC` | `SnapshotSequence` | 31:0 | RO | Sequence captured with this bank; matches the endpoint sequence after completion. |

## PtpPort fields

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
| `0x2008` | `DomainNumber` | 7:0 | RW | Configured PTP domain shadow. |
| `0x2008` | `MinorVersion` | 11:8 | RW | Transmitted PTP minor version, 0 or 1. |
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
| `0x2090` | `AssociationTimeout` | 63:0 | RW | Configuration shadow in unsteered clock cycles; activate with CommitConfig. |
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
| `0x220C` | `PortRejected` | 31:0 | RO | Saturating diagnostic counter snapshot; reset by system reset. |
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

The [ownership and verification record](register-ownership.md) describes the refactor and validation.
