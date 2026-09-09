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

from ._PtpPhc import PtpPhc
from ._PtpPort import PtpPort
from ._PtpServo import PtpServo


class PtpEndpoint(pr.Device):
    """Distributed PTP register ABI v2, four 1 KiB banks in a 4 KiB aperture.

    Configuration variables in this device and Phc/Port/Servo children are
    shadows. CommitConfig prepares immutable candidates, validates all banks,
    then applies all or none. Poll ConfigBusy and ConfigSequence and check
    ConfigError; submission success alone is not commit success. Snapshot
    captures all local status banks on one edge with a common sequence.
    Register reset preserves accepted operations and active configuration.
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

        self.add(pr.RemoteCommand(
            name        = 'CommitConfig',
            description = 'Submit a coordinated commit; poll ConfigBusy/ConfigSequence, then check ConfigError. Busy submissions return SLVERR.',
            offset      = 0x03C,
            bitSize     = 1,
            function    = pr.BaseCommand.createTouch(1),
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConfigError',
            description = 'Validation of the last completed commit failed; no bank applied its candidate.',
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
            name        = 'ConfigBusy',
            description = 'Candidate preparation, validation or common-edge apply is in progress.',
            offset      = 0x040,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConfigSequence',
            description = 'Saturating completion count for both successful and invalid commits.',
            offset      = 0x048,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SnapshotBusy',
            description = 'An accepted snapshot is waiting for a qualified common capture edge.',
            offset      = 0x108,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(PtpPhc(name="Phc", offset=0x400))
        self.add(PtpPort(name="Port", offset=0x800))
        self.add(PtpServo(name="Servo", offset=0xC00))
