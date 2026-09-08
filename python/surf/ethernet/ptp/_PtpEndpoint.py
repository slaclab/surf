#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr


class PtpEndpoint(pr.Device):
    """Register map for PtpReg version 1.

    Configuration variables are shadows. CommitConfig validates and activates
    them together, restarting protocol/servo acquisition while preserving PHC
    time and unresolved MAC wire keys. Snapshot freezes all multiword status.
    Steering commands require ServoEnable committed low; PPS remains available.
    Poll CommandBusy and check
    CommandError before issuing another. Ingress/egress latency are build-time
    constants in this version, reported in signed Q16 local-PHC nanoseconds.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'Version',
            description = 'Register ABI version: major in upper 16 bits, minor in lower 16 bits.',
            offset      = 0x000,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Enable',
            description = 'Enable fixed-source port after CommitConfig.',
            offset      = 0x004,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ServoEnable',
            description = 'Enable automatic clock control after CommitConfig.',
            offset      = 0x004,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AllowStep',
            description = 'Permit a wide acquisition phase correction while PHC time is invalid.',
            offset      = 0x004,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Monotonic',
            description = 'Reject backward phase steps and absolute sets while PHC time is valid.',
            offset      = 0x004,
            bitOffset   = 3,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IdentityOverride',
            description = 'Use LocalIdentity instead of deriving EUI-64 from the shared MAC; the configured port number is preserved.',
            offset      = 0x004,
            bitOffset   = 4,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DomainNumber',
            description = 'Configured PTP domain shadow.',
            offset      = 0x008,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MinorVersion',
            description = 'Transmitted PTP minor version, 0 or 1.',
            offset      = 0x008,
            bitOffset   = 8,
            bitSize     = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LocalIdentity',
            description = 'Local clockIdentity/portNumber shadow, network significance; low word at lowest address.',
            offset      = 0x010,
            bitOffset   = 0,
            bitSize     = 80,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SourceIdentity',
            description = 'Only this upstream sourcePortIdentity is accepted; no BMCA.',
            offset      = 0x020,
            bitOffset   = 0,
            bitSize     = 80,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LocalMac',
            description = 'Shared SURF MAC address, first wire octet in least significant byte.',
            offset      = 0x030,
            bitOffset   = 0,
            bitSize     = 48,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'CommitConfig',
            description = 'Write one to validate and atomically activate all configuration shadows; invalid commits return SLVERR.',
            offset      = 0x03C,
            bitSize     = 1,
            function    = pr.BaseCommand.createTouch(1),
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConfigError',
            description = 'The most recent configuration commit was rejected.',
            offset      = 0x040,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveEnable',
            description = 'Committed port enable.',
            offset      = 0x044,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveServoEnable',
            description = 'Committed servo enable.',
            offset      = 0x044,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PortActive',
            description = 'A fresh configured Sync source is established.',
            offset      = 0x044,
            bitOffset   = 4,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ServoState',
            description = '0 disabled, 1 acquiring, 2 tracking, 3 locked, 4 holdover, 5 fault.',
            offset      = 0x044,
            bitOffset   = 8,
            bitSize     = 3,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'FilterCount',
            description = 'Number of populated median-filter samples, zero through five.',
            offset      = 0x044,
            bitOffset   = 12,
            bitSize     = 3,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AnnounceValid',
            description = 'Configured source Announce time properties are fresh.',
            offset      = 0x044,
            bitOffset   = 16,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IrqStatus',
            description = 'Sticky events: bit 0 PHC fault, 1 discontinuity, 2 command error, 3 servo fault.',
            offset      = 0x04C,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IrqMask',
            description = 'Enable corresponding sticky events on the IRQ output.',
            offset      = 0x050,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IrqClear',
            description = 'Write-one-to-clear event mask; a concurrent new event wins.',
            offset      = 0x054,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'WO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'Snapshot',
            description = 'Freeze PHC, measurement, Announce and counters together; waits through a PHC discontinuity.',
            offset      = 0x100,
            bitSize     = 1,
            function    = pr.BaseCommand.createTouch(1),
        ))

        self.add(pr.RemoteVariable(
            name        = 'SnapshotSequence',
            description = 'Saturating count of completed snapshots; multiword read data remains stable until the next snapshot.',
            offset      = 0x104,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Seconds',
            description = 'PHC seconds snapshot.',
            offset      = 0x108,
            bitOffset   = 0,
            bitSize     = 48,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Nanoseconds',
            description = 'Canonical nanoseconds snapshot, below one billion.',
            offset      = 0x110,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Fraction',
            description = 'Fractional nanoseconds snapshot, Q32.',
            offset      = 0x114,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Generation',
            description = 'PHC time-generation snapshot.',
            offset      = 0x118,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TimeValid',
            description = 'PHC validity snapshot.',
            offset      = 0x11C,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PhcCommand',
            description = 'Write bit 7 to submit; kind bits 2:0: 0 set, 1 phase, 2 rate, 3 validity, 4 PPS; bit 3 is validity/PPS value.',
            offset      = 0x120,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CommandBusy',
            description = 'A manual command is normalizing, queued, or awaiting PHC acknowledgement.',
            offset      = 0x124,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CommandAck',
            description = 'Sticky completion of the most recently submitted manual command.',
            offset      = 0x124,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CommandError',
            description = 'Most recently completed manual command failed; cleared on new submission.',
            offset      = 0x124,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SetSeconds',
            description = 'Absolute set-time seconds shadow; target names the PHC commit edge.',
            offset      = 0x128,
            bitOffset   = 0,
            bitSize     = 48,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SetNanoseconds',
            description = 'Absolute set nanoseconds shadow, below one billion.',
            offset      = 0x130,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SetFraction',
            description = 'Absolute set fractional nanoseconds shadow, Q32.',
            offset      = 0x134,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Phase',
            description = 'Signed Q16 nanosecond phase delta; applied to normally advanced commit-edge time.',
            offset      = 0x138,
            bitOffset   = 0,
            bitSize     = 128,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RateAddend',
            description = 'Signed Q32 nanoseconds per cycle added to the nominal increment.',
            offset      = 0x148,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'NominalAddend',
            description = 'Build-time nominal Q32 nanoseconds per clock cycle.',
            offset      = 0x150,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AppliedRateAddend',
            description = 'Snapshot of the applied signed Q32 rate addend.',
            offset      = 0x158,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Ticks',
            description = 'Snapshot of unsteered cycles; phase/set commands do not change this counter.',
            offset      = 0x160,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PhcFault',
            description = 'Fatal epoch/generation/tick exhaustion; system reset is required.',
            offset      = 0x168,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DelayInterval',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x200,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SyncTimeout',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x208,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AssociationTimeout',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x210,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxDelayAge',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x218,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'HoldoverTimeout',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x220,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxExchange',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x228,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MinRateSpan',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x230,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxRateAge',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x238,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MinSampleTicks',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x240,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxSampleTicks',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x248,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LfsrSeed',
            description = 'Delay_Req schedule seed shadow; zero becomes one on restart.',
            offset      = 0x250,
            bitOffset   = 0,
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Kp',
            description = 'Unsigned Q2.30 gain shadow; units ppb/ns for Kp and ppb/(ns*s) for Ki.',
            offset      = 0x300,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Ki',
            description = 'Unsigned Q2.30 gain shadow; units ppb/ns for Kp and ppb/(ns*s) for Ki.',
            offset      = 0x304,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxFrequencyPpb',
            description = 'Unsigned whole-ppb clamp shadow; activate with CommitConfig.',
            offset      = 0x308,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxSlewPpb',
            description = 'Unsigned whole-ppb clamp shadow; activate with CommitConfig.',
            offset      = 0x30C,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxRatePpb',
            description = 'Unsigned whole-ppb clamp shadow; activate with CommitConfig.',
            offset      = 0x310,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'StepThreshold',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x318,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LockThreshold',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x320,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'UnlockThreshold',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x328,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LockCount',
            description = 'Qualification count shadow; activate with CommitConfig.',
            offset      = 0x330,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'UnlockCount',
            description = 'Qualification count shadow; activate with CommitConfig.',
            offset      = 0x334,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxPathDelay',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x400,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DelayAsymmetry',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x408,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'IngressLatency',
            description = 'Build-time signed Q16 local-PHC nanoseconds at the calibrated reference plane.',
            offset      = 0x410,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'EgressLatency',
            description = 'Build-time signed Q16 local-PHC nanoseconds at the calibrated reference plane.',
            offset      = 0x418,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Offset',
            description = 'Snapshot of local-minus-master offset after filtered delay and asymmetry, signed Q16 ns.',
            offset      = 0x500,
            bitOffset   = 0,
            bitSize     = 128,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FilteredDelay',
            description = 'Snapshot of populated-sample median path delay, signed Q16 ns.',
            offset      = 0x510,
            bitOffset   = 0,
            bitSize     = 128,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RateCommand',
            description = 'Snapshot of the servo final rate command, signed Q16 ppb.',
            offset      = 0x520,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'GrandmasterIdentity',
            description = 'Snapshot of grandmaster identity advertised by the configured source.',
            offset      = 0x530,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AnnounceFlags',
            description = 'Snapshot of PTP timescale, UTC-offset validity, leap and traceability flags.',
            offset      = 0x538,
            bitOffset   = 0,
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CurrentUtcOffset',
            description = 'Announce UTC-offset snapshot; never applied as a PHC leap step.',
            offset      = 0x53C,
            bitOffset   = 0,
            bitSize     = 16,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxAccepted',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x600,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxDropped',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x604,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOverflow',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x608,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PortRejected',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x60C,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SyncCompleted',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x610,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DelayCompleted',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x614,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RequestTimeout',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x618,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ServoRejected',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x61C,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxStartupQuarantine',
            description = 'Startup packet-lifetime quarantine is active.',
            offset      = 0x048,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MacResetConfirmed',
            description = 'The ledger has observed the required MAC reset confirmation.',
            offset      = 0x048,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxReserved',
            description = 'Number of reserved Delay_Req wire keys, including retirement quarantine.',
            offset      = 0x048,
            bitOffset   = 8,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxUnknown',
            description = 'Reservations whose physical TX outcome remains unknown; logical restart retains them.',
            offset      = 0x048,
            bitOffset   = 16,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveLocalIdentity',
            description = 'Committed local port identity used by newly allocated requests.',
            offset      = 0x060,
            bitOffset   = 0,
            bitSize     = 80,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveSourceIdentity',
            description = 'Committed upstream source port identity.',
            offset      = 0x070,
            bitOffset   = 0,
            bitSize     = 80,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ClockFrequency',
            description = 'Build-time clock frequency in Hz; timer values use cycles of this clock.',
            offset      = 0x380,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PacketLifetime',
            description = 'Build-time maximum packet lifetime and TX-key quarantine in raw clock cycles.',
            offset      = 0x384,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AnnounceBody',
            description = 'Snapshot of all 30 Announce body octets, first wire byte in the most significant bits.',
            offset      = 0x540,
            bitOffset   = 0,
            bitSize     = 240,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeT1',
            description = 'Last accepted exchange preciseOriginTimestamp: seconds48 then nanoseconds32.',
            offset      = 0x560,
            bitOffset   = 0,
            bitSize     = 80,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeT2',
            description = 'Last accepted calibrated RX capture: seconds48, nanoseconds32, fraction16.',
            offset      = 0x570,
            bitOffset   = 0,
            bitSize     = 96,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeT3',
            description = 'Last accepted calibrated TX capture: seconds48, nanoseconds32, fraction16.',
            offset      = 0x580,
            bitOffset   = 0,
            bitSize     = 96,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeT4',
            description = 'Last accepted Delay_Resp receiveTimestamp: seconds48 then nanoseconds32.',
            offset      = 0x590,
            bitOffset   = 0,
            bitSize     = 80,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeSyncCorrection',
            description = 'Sum of accepted Sync and Follow_Up corrections, signed Q16 nanoseconds.',
            offset      = 0x5A0,
            bitOffset   = 0,
            bitSize     = 128,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeDelayCorrection',
            description = 'Accepted Delay_Resp correction, signed Q16 nanoseconds.',
            offset      = 0x5B0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeGeneration',
            description = 'PHC generation of the last accepted four-timestamp exchange.',
            offset      = 0x5B8,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeSyncSequence',
            description = 'Sync sequence of the last accepted exchange.',
            offset      = 0x5BC,
            bitOffset   = 0,
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeDelaySequence',
            description = 'Delay_Req sequence of the last accepted exchange.',
            offset      = 0x5BC,
            bitOffset   = 16,
            bitSize     = 16,
            mode        = 'RO',
        ))
