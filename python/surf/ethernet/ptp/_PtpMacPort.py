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


class PtpMacPort(pr.Device):
    """Timing-port bank (PtpMacPortReg): capability, status, occupancy and counters.

    Read-only view of a port driven by an RTL controller such as
    PtpMacPortEndpoint. Counters saturate and clear only at system reset;
    compare successive reads. OccupancyClear restarts both high-water marks
    from the current occupancy. Present only in timing-port builds; tapped
    builds return DECERR at this address.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'AbiVersion',
            description = 'Timing-port record ABI version (PTP_MAC_PORT_ABI_VERSION_C).',
            offset      = 0x000,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PhyType',
            description = 'MAC interface: 1 GMII, 2 XGMII.',
            offset      = 0x000,
            bitOffset   = 8,
            bitSize     = 4,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Plane',
            description = 'Capture plane: 1 MAC/DMAC pins.',
            offset      = 0x000,
            bitOffset   = 12,
            bitSize     = 4,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TimingMode',
            description = 'Timing-mode MAC present.',
            offset      = 0x000,
            bitOffset   = 16,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'OneStep',
            description = 'One-step TX supported.',
            offset      = 0x000,
            bitOffset   = 17,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SoftwareControl',
            description = 'Control levels are writable here; 0 when an RTL controller owns the port.',
            offset      = 0x000,
            bitOffset   = 18,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TokenBits',
            description = 'Internal MAC token width.',
            offset      = 0x000,
            bitOffset   = 24,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxTableDepth',
            description = 'TX table entries.',
            offset      = 0x004,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxTableDepth',
            description = 'RX table entries.',
            offset      = 0x004,
            bitOffset   = 8,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxFrameBytes',
            description = 'Ethernet byte limit, FCS excluded.',
            offset      = 0x004,
            bitOffset   = 16,
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CookieBits',
            description = 'TX request cookie width.',
            offset      = 0x008,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AdmissionOpen',
            description = 'New TX requests and RX starts are admitted.',
            offset      = 0x010,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DrainIdle',
            description = 'Every table entry is released.',
            offset      = 0x010,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CancelRequest',
            description = 'Forced-abort cancel step is requested.',
            offset      = 0x010,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AbortDone',
            description = 'Forced abort has completed.',
            offset      = 0x010,
            bitOffset   = 3,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TransportGeneration',
            description = 'Live transport generation; 0 never admits traffic.',
            offset      = 0x010,
            bitOffset   = 16,
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'FaultGeneration',
            description = 'Sticky: transport generation exhausted; admission closed until system reset.',
            offset      = 0x014,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'FaultClockEnable',
            description = 'Sticky: ethClkEn was observed low.',
            offset      = 0x014,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'FaultTokenProtocol',
            description = 'Sticky: a MAC event named an unexpected token; the frame was discarded uncounted.',
            offset      = 0x014,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'OpenAdmission',
            description = 'Controller level: open admission.',
            offset      = 0x018,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DrainRequest',
            description = 'Controller level: graceful drain.',
            offset      = 0x018,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AbortRequest',
            description = 'Controller level: forced abort.',
            offset      = 0x018,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CancelAck',
            description = 'Controller level: cancel acknowledged.',
            offset      = 0x018,
            bitOffset   = 3,
            bitSize     = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxOccupancy',
            description = 'Owned TX table entries.',
            offset      = 0x020,
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxOccupancyMax',
            description = 'Largest TX occupancy since system reset or OccupancyClear.',
            offset      = 0x020,
            bitOffset   = 8,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOccupancy',
            description = 'Owned RX table entries.',
            offset      = 0x020,
            bitOffset   = 16,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOccupancyMax',
            description = 'Largest RX occupancy since system reset or OccupancyClear; RxTableDepth means a start may have been refused.',
            offset      = 0x020,
            bitOffset   = 24,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'OccupancyClear',
            description = 'Restart TxOccupancyMax and RxOccupancyMax from the current occupancy.',
            offset      = 0x024,
            bitSize     = 1,
            function    = pr.BaseCommand.createTouch(1),
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxDelivered',
            description = 'Saturating: RX frames delivered to the controller.',
            offset      = 0x040,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxDropped',
            description = 'Saturating: tokened RX frames dropped by a MAC stage, length check or abort, plus starts refused for want of a table entry.',
            offset      = 0x044,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxLost',
            description = 'Saturating: RX starts the import leaf abandoned before emitting any beat.',
            offset      = 0x048,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxSent',
            description = 'Saturating: TX completions SENT.',
            offset      = 0x04C,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxWireError',
            description = 'Saturating: TX completions WIRE_ERR.',
            offset      = 0x050,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxDiscarded',
            description = 'Saturating: TX completions DISCARDED.',
            offset      = 0x054,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxFlushed',
            description = 'Saturating: TX completions FLUSHED.',
            offset      = 0x058,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxRejected',
            description = 'Saturating: TX stream frames consumed without admission (no SOF or request context); they receive no completion.',
            offset      = 0x05C,
            bitOffset   = 0,
            bitSize     = 32,
            mode        = 'RO',
        ))
