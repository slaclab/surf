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

from ._PtpPhcCore import PtpPhcCore
from ._PtpProtocolEngine import PtpProtocolEngine
from ._PtpServo import PtpServo


class PtpEndpoint(pr.Device):
    """Development PTP register map in a 32 KiB aperture.

    Endpoint control at 0x0000, ProtocolEngine at 0x2000, Servo at 0x3000 and
    the shared PhcCore (control 0x4000, Phc 0x5000). Configuration variables
    here and in the children, including ServoEnable and (in a SELECTABLE
    build) PhcCore.Owner, are shadows. The servo steers only when it is both
    enabled and the PHC owner. CommitConfig prepares immutable candidates, drains PHC
    commands, validates all banks, then applies all or none. Poll ConfigBusy
    and ConfigSequence and check ConfigError; submission success alone is not
    commit success. Snapshot captures all local status banks on one edge with
    a common sequence. Register reset preserves accepted operations and active
    configuration.
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
            description = 'Run the servo after CommitConfig. It steers only while PhcCore.ActiveOwner selects it; stopping it never grants AXI steering.',
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
            description = 'Committed servo run request.',
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
            description = 'An accepted snapshot is awaiting capture, frozen-bank copy or common publication.',
            offset      = 0x108,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(PtpProtocolEngine(name="ProtocolEngine", offset=0x2000))
        self.add(PtpServo(name="Servo", offset=0x3000))
        self.add(PtpPhcCore(name="PhcCore", offset=0x4000))
