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


class PtpPhc(pr.Device):
    """PHC-local operands, command status, policy and time snapshots.

    Manual steering requires parent ServoEnable committed low; PPS commands
    remain available. Poll CommandBusy and check CommandError. Multiword
    snapshots are captured by the parent Snapshot command.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'Monotonic',
            description = 'Reject backward phase steps and absolute sets while PHC time is valid.',
            offset      = 0x004,
            bitOffset   = 3,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Seconds',
            description = 'PHC seconds snapshot.',
            offset      = 0x008,
            bitOffset   = 0,
            bitSize     = 48,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Nanoseconds',
            description = 'Canonical nanoseconds snapshot, below one billion.',
            offset      = 0x010,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Fraction',
            description = 'Fractional nanoseconds snapshot, Q32.',
            offset      = 0x014,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Generation',
            description = 'PHC time-generation snapshot.',
            offset      = 0x018,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TimeValid',
            description = 'PHC validity snapshot.',
            offset      = 0x01C,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PhcCommand',
            description = 'Write bit 7 to submit; kind bits 2:0: 0 set, 1 phase, 2 rate, 3 validity, 4 PPS; bit 3 is validity/PPS value.',
            offset      = 0x020,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CommandBusy',
            description = 'A manual command is normalizing, queued, or awaiting PHC acknowledgement.',
            offset      = 0x024,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CommandAck',
            description = 'Sticky completion of the most recently submitted manual command.',
            offset      = 0x024,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CommandError',
            description = 'Most recently completed manual command failed; cleared on new submission.',
            offset      = 0x024,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SetSeconds',
            description = 'Absolute set-time seconds shadow; target names the PHC commit edge.',
            offset      = 0x028,
            bitOffset   = 0,
            bitSize     = 48,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SetNanoseconds',
            description = 'Absolute set nanoseconds shadow, below one billion.',
            offset      = 0x030,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SetFraction',
            description = 'Absolute set fractional nanoseconds shadow, Q32.',
            offset      = 0x034,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Phase',
            description = 'Signed Q16 nanosecond phase delta; applied to normally advanced commit-edge time.',
            offset      = 0x038,
            bitOffset   = 0,
            bitSize     = 128,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RateAddend',
            description = 'Signed Q32 nanoseconds per cycle added to the nominal increment.',
            offset      = 0x048,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'NominalAddend',
            description = 'Build-time nominal Q32 nanoseconds per clock cycle.',
            offset      = 0x050,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AppliedRateAddend',
            description = 'Snapshot of the applied signed Q32 rate addend.',
            offset      = 0x058,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Ticks',
            description = 'Snapshot of unsteered cycles; phase/set commands do not change this counter.',
            offset      = 0x060,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PhcFault',
            description = 'Fatal epoch/generation/tick exhaustion; system reset is required.',
            offset      = 0x068,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ClockFrequency',
            description = 'Build-time clock frequency in Hz; timer values use cycles of this clock.',
            offset      = 0x080,
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
            name        = 'ActiveMonotonic',
            description = 'Committed monotonic policy.',
            offset      = 0x084,
            bitOffset   = 3,
            bitSize     = 1,
            mode        = 'RO',
        ))
