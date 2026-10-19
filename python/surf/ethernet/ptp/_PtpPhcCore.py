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


class PtpPhcCore(pr.Device):
    """Shared PHC subsystem: control bank at 0x000 and PHC bank at 0x1000.

    Owner selects which path may steer the clock: the AXI bank (Phc manual
    commands) or the external command client. Owner and Phc.Monotonic are
    shadows; CommitConfig drains accepted commands, then applies both on one
    edge. Inside PtpEndpoint the endpoint coordinates commits and snapshots
    (ExternalCoordination=1), so use the endpoint's CommitConfig and Snapshot.
    The selector cannot separate two software agents writing this bank; the
    integration must give diagnostics read-only access.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'Version',
            description = 'PHC core register ABI version: major in upper 16 bits, minor in lower 16 bits.',
            offset      = 0x000,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Owner',
            description = 'Clock owner shadow: 0 AXI bank, 1 external command client. Activate with CommitConfig.',
            offset      = 0x004,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CommandMask',
            description = 'Supported command kinds: one bit each for set, phase, rate, validity and PPS.',
            offset      = 0x008,
            bitOffset   = 0,
            bitSize     = 5,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExternalCommand',
            description = 'External command admission is present in this build.',
            offset      = 0x008,
            bitOffset   = 8,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExternalCoordination',
            description = 'An enclosing coordinator owns commits and snapshots; local submissions return SLVERR.',
            offset      = 0x008,
            bitOffset   = 9,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ManagementCrossing',
            description = 'AXI-Lite crosses from an independent management clock.',
            offset      = 0x008,
            bitOffset   = 10,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PhysicalSteering',
            description = 'Physical clock actuator control is present (always 0 in this core).',
            offset      = 0x008,
            bitOffset   = 11,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'CommitConfig',
            description = 'Submit a local commit; poll ConfigBusy/ConfigSequence, then check ConfigError. SLVERR when busy, during a manual command, or under enclosing coordination.',
            offset      = 0x03C,
            bitSize     = 1,
            function    = pr.BaseCommand.createTouch(1),
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConfigError',
            description = 'The last local commit failed validation; no setting changed.',
            offset      = 0x040,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConfigBusy',
            description = 'A local or enclosing transaction is in progress; command admission is closed.',
            offset      = 0x040,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveOwner',
            description = 'Committed clock owner: 0 AXI bank, 1 external command client.',
            offset      = 0x044,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CommandIdle',
            description = 'No manual command is in progress and the PHC command slot is free.',
            offset      = 0x044,
            bitOffset   = 4,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConfigSequence',
            description = 'Saturating count of completed local commits, successful or invalid.',
            offset      = 0x048,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IrqStatus',
            description = 'Sticky events: bit 0 PHC fault, 1 discontinuity, 2 command error.',
            offset      = 0x04C,
            bitOffset   = 0,
            bitSize     = 3,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IrqMask',
            description = 'Enable corresponding sticky events on the IRQ output.',
            offset      = 0x050,
            bitOffset   = 0,
            bitSize     = 3,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IrqClear',
            description = 'Write-one-to-clear event mask; a concurrent new event wins.',
            offset      = 0x054,
            bitOffset   = 0,
            bitSize     = 3,
            mode        = 'WO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'Snapshot',
            description = 'Capture PHC time, rate and ticks on one edge; SLVERR when pending or under enclosing coordination.',
            offset      = 0x100,
            bitSize     = 1,
            function    = pr.BaseCommand.createTouch(1),
        ))

        self.add(pr.RemoteVariable(
            name        = 'SnapshotSequence',
            description = 'Last published snapshot sequence, local or enclosing.',
            offset      = 0x104,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SnapshotBusy',
            description = 'An accepted local snapshot is awaiting capture or publication.',
            offset      = 0x108,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(PtpPhc(name="Phc", offset=0x1000))
