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


class PtpPort(pr.Device):
    """Port-local identity, timers, source/exchange snapshots and counters.

    Shared association/path-delay limits have this single writable owner.
    Calibration values are signed Q16 local PHC nanoseconds at elaboration.
    Configuration is activated by the parent CommitConfig command.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

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

        self.add(pr.RemoteVariable(
            name        = 'DelayInterval',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x080,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SyncTimeout',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x088,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AssociationTimeout',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x090,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxExchange',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x098,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MinRateSpan',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x0A0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxRateAge',
            description = 'Configuration shadow in unsteered clock cycles; activate with CommitConfig.',
            offset      = 0x0A8,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LfsrSeed',
            description = 'Delay_Req schedule seed shadow; zero becomes one on restart.',
            offset      = 0x0B0,
            bitOffset   = 0,
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxPathDelay',
            description = 'Signed Q16 nanoseconds configuration shadow; activate with CommitConfig.',
            offset      = 0x0B8,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RW',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'IngressLatency',
            description = 'Build-time signed Q16 local-PHC nanoseconds at the calibrated reference plane.',
            offset      = 0x0D0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'EgressLatency',
            description = 'Build-time signed Q16 local-PHC nanoseconds at the calibrated reference plane.',
            offset      = 0x0D8,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'GrandmasterIdentity',
            description = 'Snapshot of grandmaster identity advertised by the configured source.',
            offset      = 0x130,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AnnounceFlags',
            description = 'Snapshot of PTP timescale, UTC-offset validity, leap and traceability flags.',
            offset      = 0x138,
            bitOffset   = 0,
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CurrentUtcOffset',
            description = 'Announce UTC-offset snapshot; never applied as a PHC leap step.',
            offset      = 0x13C,
            bitOffset   = 0,
            bitSize     = 16,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxAccepted',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x200,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxDropped',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x204,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOverflow',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x208,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PortRejected',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x20C,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SyncCompleted',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x210,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DelayCompleted',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x214,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RequestTimeout',
            description = 'Saturating diagnostic counter snapshot; reset by system reset.',
            offset      = 0x218,
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
            name        = 'PacketLifetime',
            description = 'Build-time maximum packet lifetime and TX-key quarantine in raw clock cycles.',
            offset      = 0x0C0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AnnounceBody',
            description = 'Snapshot of all 30 Announce body octets, first wire byte in the most significant bits.',
            offset      = 0x140,
            bitOffset   = 0,
            bitSize     = 240,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeT1',
            description = 'Last accepted exchange preciseOriginTimestamp: seconds48 then nanoseconds32.',
            offset      = 0x160,
            bitOffset   = 0,
            bitSize     = 80,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeT2',
            description = 'Last accepted calibrated RX capture: seconds48, nanoseconds32, fraction16.',
            offset      = 0x170,
            bitOffset   = 0,
            bitSize     = 96,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeT3',
            description = 'Last accepted calibrated TX capture: seconds48, nanoseconds32, fraction16.',
            offset      = 0x180,
            bitOffset   = 0,
            bitSize     = 96,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeT4',
            description = 'Last accepted Delay_Resp receiveTimestamp: seconds48 then nanoseconds32.',
            offset      = 0x190,
            bitOffset   = 0,
            bitSize     = 80,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeSyncCorrection',
            description = 'Sum of accepted Sync and Follow_Up corrections, signed Q16 nanoseconds.',
            offset      = 0x1A0,
            bitOffset   = 0,
            bitSize     = 128,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeDelayCorrection',
            description = 'Accepted Delay_Resp correction, signed Q16 nanoseconds.',
            offset      = 0x1B0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
            base        = pr.Int,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeGeneration',
            description = 'PHC generation of the last accepted four-timestamp exchange.',
            offset      = 0x1B8,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeSyncSequence',
            description = 'Sync sequence of the last accepted exchange.',
            offset      = 0x1BC,
            bitOffset   = 0,
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExchangeDelaySequence',
            description = 'Delay_Req sequence of the last accepted exchange.',
            offset      = 0x1BC,
            bitOffset   = 16,
            bitSize     = 16,
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
            name        = 'ActiveAssociationTimeout',
            description = 'Committed raw-tick association limit shared with the servo.',
            offset      = 0x0E0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveSyncTimeout',
            description = 'Committed raw-tick Sync receipt limit shared with the servo.',
            offset      = 0x0E8,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ActiveMaxPathDelay',
            description = 'Committed positive Q16 nanosecond path-delay limit shared with the servo.',
            offset      = 0x0F0,
            bitOffset   = 0,
            bitSize     = 64,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Active',
            description = 'Current protocol session activity.',
            offset      = 0x044,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AnnounceValid',
            description = 'Current configured-source Announce metadata validity.',
            offset      = 0x044,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RatioValid',
            description = 'Raw-clock/master rate ratio is qualified and fresh.',
            offset      = 0x044,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RO',
        ))
