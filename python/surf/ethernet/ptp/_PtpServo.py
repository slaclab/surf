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


class PtpServo(pr.Device):
    """Servo-local gains, limits, acquisition policy and filter diagnostics.

    Configuration is activated by the parent CommitConfig command. Shared
    protocol age/path-delay limits are owned by the Port child. Snapshot
    values are captured by the parent Snapshot command.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'AllowStep',
            description = 'Permit a wide acquisition phase correction while PHC time is invalid.',
            offset      = 0x004,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxDelayAge',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x060,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'HoldoverTimeout',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x068,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MinSampleTicks',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x070,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxSampleTicks',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x078,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Kp',
            description = 'Unsigned Q2.30 gain shadow; units ppb/ns for Kp and ppb/(ns*s) for Ki.',
            offset      = 0x020,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Ki',
            description = 'Unsigned Q2.30 gain shadow; units ppb/ns for Kp and ppb/(ns*s) for Ki.',
            offset      = 0x024,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxFrequencyPpb',
            description = 'Unsigned whole-ppb clamp shadow; activate with CommitConfig.',
            offset      = 0x028,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxSlewPpb',
            description = 'Unsigned whole-ppb clamp shadow; activate with CommitConfig.',
            offset      = 0x02C,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxRatePpb',
            description = 'Unsigned whole-ppb clamp shadow; activate with CommitConfig.',
            offset      = 0x030,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'StepThreshold',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x038,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LockThreshold',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x040,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'UnlockThreshold',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x048,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LockCount',
            description = 'Qualification count shadow; activate with CommitConfig.',
            offset      = 0x050,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'UnlockCount',
            description = 'Qualification count shadow; activate with CommitConfig.',
            offset      = 0x054,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DelayAsymmetry',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x080,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Offset',
            description = 'Snapshot of local-minus-master offset after filtered delay and asymmetry, signed Q16 ns.',
            offset      = 0x100,
            bitOffset   = 0,
            bitSize     = 128,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FilteredDelay',
            description = 'Snapshot of populated-sample median path delay, signed Q16 ns.',
            offset      = 0x110,
            bitOffset   = 0,
            bitSize     = 128,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RateCommand',
            description = 'Snapshot of the servo final rate command, signed Q16 ppb.',
            offset      = 0x120,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ServoRejected',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x200,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SnapshotSequence',
            description = 'Sequence captured with this bank; matches the endpoint sequence after completion.',
            offset      = 0x3FC,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveKp',
            description = 'Committed proportional gain in Q2.30.',
            offset      = 0x094,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveKi',
            description = 'Committed integral gain in Q2.30.',
            offset      = 0x098,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AssociationTimeout',
            description = 'Read-only shared raw-tick association limit owned by Port.',
            offset      = 0x0A0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SyncTimeout',
            description = 'Read-only shared raw-tick Sync receipt limit owned by Port.',
            offset      = 0x0A8,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxPathDelay',
            description = 'Read-only shared positive Q16 nanosecond delay limit owned by Port.',
            offset      = 0x0B0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'State',
            description = 'Current disabled/acquisition/tracking/locked/holdover/fault state.',
            offset      = 0x090,
            bitOffset   = 0,
            bitSize     = 3,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'FilterCount',
            description = 'Number of populated delay-filter samples.',
            offset      = 0x090,
            bitOffset   = 4,
            bitSize     = 3,
            mode        = 'RO',
        ))
