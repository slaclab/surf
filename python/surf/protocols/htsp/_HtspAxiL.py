#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

import surf.ethernet.udp as udp

class HtspAxiL(pr.Device):
    def __init__(self,
                 description     = "Configuration and status a PGP ETH link",
                 numVc           = 4,
                 phyLane         = 4,
                 writeEn         = False,
                 **kwargs):
        super().__init__(description=description, **kwargs)

        statusCntSize = 12
        writeAccess = 'RW' if writeEn else 'RO'

        # statusIn(15 downto 0)  => pgpRxOut.remRxPause,
        for i in range(numVc):
            self.add(pr.RemoteVariable(
                name         = f'RemotePauseCnt[{i}]',
                mode         = 'RO',
                offset       = 4*0 + (4*i),
                bitSize      = statusCntSize,
                pollInterval = 1,
            ))

        # statusIn(31 downto 16) => pgpTxOut.locPause,
        for i in range(numVc):
            self.add(pr.RemoteVariable(
                name         = f'LocalPauseCnt[{i}]',
                mode         = 'RO',
                offset       = 4*16 + (4*i),
                bitSize      = statusCntSize,
                pollInterval = 1,
            ))

        # statusIn(47 downto 32) => pgpTxOut.locOverflow,
        for i in range(numVc):
            self.add(pr.RemoteVariable(
                name         = f'LocalOverflowCnt[{i}]',
                mode         = 'RO',
                offset       = 4*32 + (4*i),
                bitSize      = statusCntSize,
                pollInterval = 1,
            ))

        # statusIn(48)           => pgpTxOut.frameTx,
        self.add(pr.RemoteVariable(
            name         = 'FrameTxCnt',
            mode         = 'RO',
            offset       = 4*48,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(49)           => pgpTxOut.frameTxErr,
        self.add(pr.RemoteVariable(
            name         = 'FrameTxErrCnt',
            mode         = 'RO',
            offset       = 4*49,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(50)           => pgpTxOut.frameRx,
        self.add(pr.RemoteVariable(
            name         = 'FrameRxCnt',
            mode         = 'RO',
            offset       = 4*50,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(51)           => pgpTxOut.frameRxErr,
        self.add(pr.RemoteVariable(
            name         = 'FrameRxErrCnt',
            mode         = 'RO',
            offset       = 4*51,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(52)           => pgpTxOut.phyTxActive,
        self.add(pr.RemoteVariable(
            name         = 'PhyTxActiveCnt',
            mode         = 'RO',
            offset       = 4*52,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(53)           => pgpRxOut.phyRxActive,
        self.add(pr.RemoteVariable(
            name         = 'PhyRxActiveCnt',
            mode         = 'RO',
            offset       = 4*53,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(54)           => pgpTxOut.linkReady,
        self.add(pr.RemoteVariable(
            name         = 'TxLinkReadyCnt',
            mode         = 'RO',
            offset       = 4*54,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(55)           => pgpRxOut.linkReady,
        self.add(pr.RemoteVariable(
            name         = 'LocalRxLinkReadyCnt',
            mode         = 'RO',
            offset       = 4*55,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(56)           => pgpRxOut.linkDown,
        self.add(pr.RemoteVariable(
            name         = 'LinkDownCnt',
            mode         = 'RO',
            offset       = 4*56,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(57)           => pgpRxOut.remRxLinkReady,
        self.add(pr.RemoteVariable(
            name         = 'RemoteRxLinkReadyCnt',
            mode         = 'RO',
            offset       = 4*57,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(58)           => pgpTxOut.opCodeReady,
        self.add(pr.RemoteVariable(
            name         = 'TxOpCodeEnCnt',
            mode         = 'RO',
            offset       = 4*58,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(59)           => pgpRxOut.opCodeEn,
        self.add(pr.RemoteVariable(
            name         = 'RxOpCodeEnCnt',
            mode         = 'RO',
            offset       = 4*59,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(60)           => pgpRst,
        self.add(pr.RemoteVariable(
            name         = 'PgpRstCnt',
            mode         = 'RO',
            offset       = 4*60,
            bitSize      = statusCntSize,
            pollInterval = 1,
        ))

        # statusIn(15 downto 0)  => pgpRxOut.remRxPause,
        self.add(pr.RemoteVariable(
            name         = 'RemotePause',
            mode         = 'RO',
            offset       = 0x100,
            bitSize      = numVc,
            bitOffset    = 0,
            pollInterval = 1,
        ))

        # statusIn(31 downto 16) => pgpTxOut.locPause,
        self.add(pr.RemoteVariable(
            name         = 'LocalPause',
            mode         = 'RO',
            offset       = 0x100,
            bitSize      = numVc,
            bitOffset    = 16,
            pollInterval = 1,
        ))

        # statusIn(52)           => pgpTxOut.phyTxActive,
        self.add(pr.RemoteVariable(
            name         = 'PhyTxActive',
            mode         = 'RO',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 52,
            pollInterval = 1,
        ))

        # statusIn(53)           => pgpRxOut.phyRxActive,
        self.add(pr.RemoteVariable(
            name         = 'PhyRxActive',
            mode         = 'RO',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 53,
            pollInterval = 1,
        ))

        # statusIn(54)           => pgpTxOut.linkReady,
        self.add(pr.RemoteVariable(
            name         = 'TxLinkReady',
            mode         = 'RO',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 54,
            pollInterval = 1,
        ))

        # statusIn(55)           => pgpRxOut.linkReady,
        self.add(pr.RemoteVariable(
            name         = 'LocalRxLinkReady',
            mode         = 'RO',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 55,
            pollInterval = 1,
        ))

        # statusIn(57)           => pgpRxOut.remRxLinkReady,
        self.add(pr.RemoteVariable(
            name         = 'RemoteRxLinkReady',
            mode         = 'RO',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 57,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'PgpClkFreq',
            mode         = 'RO',
            offset       = 0x110,
            bitSize      = 32,
            disp         = '{:d}',
            units        = 'Hz',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxMinPayloadSize',
            mode         = 'RO',
            offset       = 0x114,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            units        = 'Bytes',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxMaxPayloadSize',
            mode         = 'RO',
            offset       = 0x114,
            bitSize      = 16,
            bitOffset    = 16,
            disp         = '{:d}',
            units        = 'Bytes',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxMinPayloadSize',
            mode         = 'RO',
            offset       = 0x118,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            units        = 'Bytes',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxMaxPayloadSize',
            mode         = 'RO',
            offset       = 0x118,
            bitSize      = 16,
            bitOffset    = 16,
            disp         = '{:d}',
            units        = 'Bytes',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Loopback',
            mode         = writeAccess,
            offset       = 0x130,
            bitSize      = 3,
            bitOffset    = 0,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxDisable',
            mode         = writeAccess,
            offset       = 0x130,
            bitSize      = 1,
            bitOffset    = 8,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxFlowCntlDis',
            mode         = writeAccess,
            offset       = 0x130,
            bitSize      = 1,
            bitOffset    = 9,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxReset',
            mode         = writeAccess,
            offset       = 0x130,
            bitSize      = 1,
            bitOffset    = 10,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxPolarity',
            mode         = writeAccess,
            offset       = 0x138,
            bitSize      = phyLane,
            bitOffset    = 0,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxPolarity',
            mode         = writeAccess,
            offset       = 0x138,
            bitSize      = phyLane,
            bitOffset    = 16,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxNullInterval',
            mode         = writeAccess,
            offset       = 0x13C,
            bitSize      = 32,
            disp         = '{:d}',
        ))

        for i in range(phyLane):
            self.add(pr.RemoteVariable(
                name         = f'TxDiffCtrl[{i}]',
                mode         = writeAccess,
                offset       = 256 + 64 + (4*i),
                bitSize      = 5,
                bitOffset    = 0,
            ))

        for i in range(phyLane):
            self.add(pr.RemoteVariable(
                name         = f'TxPreCursor[{i}]',
                mode         = writeAccess,
                offset       = 256 + 64 + (4*i),
                bitSize      = 5,
                bitOffset    = 8,
            ))

        for i in range(phyLane):
            self.add(pr.RemoteVariable(
                name         = f'TxPostCursor[{i}]',
                mode         = writeAccess,
                offset       = 256 + 64 + (4*i),
                bitSize      = 5,
                bitOffset    = 16,
            ))

        self.add(pr.RemoteVariable(
            name         = 'LocalMacRaw',
            description  = 'Local MAC Address (big-Endian configuration)',
            mode         = 'RO',
            offset       = 0x1C0,
            bitSize      = 48,
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = "LocalMac",
            description  = "Local MAC Address (human readable)",
            mode         = 'RO',
            linkedGet    = udp.getMacValue,
            dependencies = [self.variables["LocalMacRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name         = 'RemoteMacRaw',
            description  = 'Remote MAC Address (big-Endian configuration)',
            mode         = 'RO',
            offset       = 0x1C8,
            bitSize      = 48,
            pollInterval = 1,
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = "RemoteMac",
            description  = "Remote MAC Address (human readable)",
            mode         = 'RO',
            linkedGet    = udp.getMacValue,
            dependencies = [self.variables["RemoteMacRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name         = 'BroadcastMacRaw',
            description  = 'Broadcast MAC Address (big-Endian configuration)',
            mode         = writeAccess,
            offset       = 0x1D0,
            bitSize      = 48,
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = "BroadcastMac",
            description  = "Broadcast MAC Address (human readable)",
            mode         = writeAccess,
            linkedGet    = udp.getMacValue,
            linkedSet    = udp.setMacValue,
            dependencies = [self.variables["BroadcastMacRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name         = 'EtherType',
            mode         = writeAccess,
            offset       = 0x1D8,
            bitSize      = 16,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RollOverEn',
            description  = 'Status Counter Rollover enable bit vector',
            mode         = 'RW',
            offset       = 0x1F0,
            bitSize      = 60,
            hidden       = True,
        ))

        self.add(pr.RemoteCommand(
            name         = 'CountReset',
            description  = 'Status counter reset',
            offset       = 0x1FC,
            bitSize      = 1,
            function     = pr.BaseCommand.touchOne
        ))

    def countReset(self):
        self.CountReset()
