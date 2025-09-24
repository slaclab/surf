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

class HtspAxiLCtrl(pr.Device):
    def __init__(self, writeEn=False, **kwargs):
        super().__init__(**kwargs)

        mode = 'RW' if writeEn else 'RO'

        self.add(pr.RemoteCommand(
            name        = 'CountReset',
            description = "Status Counter Reset Command",
            offset      = 0x000,
            bitOffset   = 0,
            bitSize     = 1,
            function    = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteVariable(
            name      = 'WRITE_EN_G',
            offset    = 0x004,
            bitOffset = 0,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'NUM_VC_G',
            offset    = 0x004,
            bitOffset = 8,
            bitSize   = 8,
            disp      = '{:d}',
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'STATUS_CNT_WIDTH_G',
            offset    = 0x004,
            bitOffset = 16,
            bitSize   = 8,
            disp      = '{:d}',
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'ERROR_CNT_WIDTH_G',
            offset    = 0x004,
            bitOffset = 24,
            bitSize   = 8,
            disp      = '{:d}',
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HtspClkFreq',
            mode         = 'RO',
            offset       = 0x010,
            bitSize      = 32,
            disp         = '{:d}',
            units        = 'Hz',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Loopback',
            mode         = mode,
            offset       = 0x030,
            bitSize      = 3,
            bitOffset    = 0,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxDisable',
            mode         = mode,
            offset       = 0x030,
            bitSize      = 1,
            bitOffset    = 8,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxFlowCntlDis',
            mode         = mode,
            offset       = 0x030,
            bitSize      = 1,
            bitOffset    = 9,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxReset',
            mode         = mode,
            offset       = 0x030,
            bitSize      = 1,
            bitOffset    = 10,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxPolarity',
            mode         = mode,
            offset       = 0x038,
            bitSize      = 4,
            bitOffset    = 0,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxPolarity',
            mode         = mode,
            offset       = 0x038,
            bitSize      = 4,
            bitOffset    = 16,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxNullInterval',
            mode         = mode,
            offset       = 0x03C,
            bitSize      = 32,
            disp         = '{:d}',
        ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'TxDiffCtrl[{i}]',
                mode         = mode,
                offset       = 64 + (4*i),
                bitSize      = 5,
                bitOffset    = 0,
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'TxPreCursor[{i}]',
                mode         = mode,
                offset       = 64 + (4*i),
                bitSize      = 5,
                bitOffset    = 8,
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'TxPostCursor[{i}]',
                mode         = mode,
                offset       = 64 + (4*i),
                bitSize      = 5,
                bitOffset    = 16,
            ))

        self.add(pr.RemoteVariable(
            name         = 'LocalMacRaw',
            description  = 'Local MAC Address (big-Endian configuration)',
            mode         = mode,
            offset       = 0x0C0,
            bitSize      = 48,
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = "LocalMac",
            description  = "Local MAC Address (human readable)",
            mode         = mode,
            linkedGet    = udp.getMacValue,
            linkedSet    = udp.setMacValue,
            dependencies = [self.variables["LocalMacRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name         = 'RemoteMacRaw',
            description  = 'Remote MAC Address (big-Endian configuration)',
            mode         = 'RO',
            offset       = 0x0C8,
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
            mode         = mode,
            offset       = 0x0D0,
            bitSize      = 48,
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = "BroadcastMac",
            description  = "Broadcast MAC Address (human readable)",
            mode         = mode,
            linkedGet    = udp.getMacValue,
            linkedSet    = udp.setMacValue,
            dependencies = [self.variables["BroadcastMacRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name         = 'EtherType',
            mode         = mode,
            offset       = 0x0D8,
            bitSize      = 16,
        ))

    def countReset(self):
        self.CountReset()

class HtspAxiLRxStatus(pr.Device):
    def __init__(self,
                 numVc           = 1,
                 statusCountBits = 12,
                 errorCountBits  = 8,
                 **kwargs):
        super().__init__(**kwargs)

        devOffset = 0x400

        def addStatusCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                bitSize      = statusCountBits,
                mode         = 'RO',
                disp         = '{:d}',
                pollInterval = 1,
                **ecvkwargs))

        def addErrorCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                bitSize      = errorCountBits,
                mode         = 'RO',
                disp         = '{:d}',
                pollInterval = 1,
                **ecvkwargs))

        for i in range(numVc):
            addStatusCountVar(
                name   = f'RemPauseCnt[{i}]',
                offset = (0x400+(4*i)-devOffset),
            )

        addStatusCountVar(
            name   = 'FrameCnt',
            offset = (0x500-devOffset),
        )

        addStatusCountVar(
            name   = 'OpCodeEnCnt',
            offset = (0x504-devOffset),
        )

        statusList = [
            ['PhyRxActive',True],
            ['LinkReady',True],
            ['RemRxLinkReady',True],
            ['FrameError',False],
            ['LinkDown',False],
        ]

        for i in range(len(statusList)):
            addErrorCountVar(
                name   = (statusList[i][0]+'Cnt'),
                offset = (0x600+(4*i)-devOffset),
            )

        for i in range(len(statusList)):
            if statusList[i][1]:
                self.add(pr.RemoteVariable(
                    name         = statusList[i][0],
                    offset       = (0x710-devOffset),
                    bitOffset    = i,
                    bitSize      = 1,
                    base         = pr.Bool,
                    mode         = 'RO',
                    pollInterval = 1,
                ))

        self.add(pr.RemoteVariable(
            name         = 'RemLinkData',
            offset       = (0x720-devOffset),
            bitSize      = 128,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RemOpCodeData',
            offset       = (0x730-devOffset),
            bitSize      = 128,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RemRxPause',
            offset       = (0x740-devOffset),
            bitSize      = numVc,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxMinPayloadSize',
            mode         = 'RO',
            offset       = 0x750,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            units        = 'Bytes',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxMaxPayloadSize',
            mode         = 'RO',
            offset       = 0x750,
            bitSize      = 16,
            bitOffset    = 16,
            disp         = '{:d}',
            units        = 'Bytes',
            pollInterval = 1,
        ))

class HtspAxiLTxStatus(pr.Device):
    def __init__(self,
                 numVc           = 1,
                 statusCountBits = 12,
                 errorCountBits  = 8,
                 **kwargs):
        super().__init__(**kwargs)

        devOffset = 0x800

        def addStatusCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                bitSize      = statusCountBits,
                mode         = 'RO',
                disp         = '{:d}',
                pollInterval = 1,
                **ecvkwargs))

        def addErrorCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                bitSize      = errorCountBits,
                mode         = 'RO',
                disp         = '{:d}',
                pollInterval = 1,
                **ecvkwargs))

        for i in range(numVc):
            addStatusCountVar(
                name   = f'LocPauseCnt[{i}]',
                offset = (0x800+(4*i)-devOffset),
            )

        for i in range(numVc):
            addErrorCountVar(
                name   = f'LocOverflowCnt[{i}]',
                offset = (0x840+(4*i)-devOffset),
            )

        addStatusCountVar(
            name   = 'FrameCnt',
            offset = (0x900-devOffset),
        )

        addStatusCountVar(
            name   = 'OpCodeEnCnt',
            offset = (0x904-devOffset),
        )

        statusList = [
            ['phyTxActive',True],
            ['LinkReady',True],
            ['FrameError',False],
        ]

        for i in range(len(statusList)):
            addErrorCountVar(
                name   = (statusList[i][0]+'Cnt'),
                offset = (0xA00+(4*i)-devOffset),
            )

        for i in range(len(statusList)):
            if statusList[i][1]:
                self.add(pr.RemoteVariable(
                    name         = statusList[i][0],
                    offset       = (0xB10-devOffset),
                    bitOffset    = i,
                    bitSize      = 1,
                    base         = pr.Bool,
                    mode         = 'RO',
                    pollInterval = 1,
                ))

        self.add(pr.RemoteVariable(
            name         = 'LocLinkData',
            offset       = (0xB20-devOffset),
            bitSize      = 128,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LocOpCodeData',
            offset       = (0xB30-devOffset),
            bitSize      = 128,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LocTxPause',
            offset       = (0xB40-devOffset),
            bitSize      = numVc,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxMinPayloadSize',
            mode         = 'RO',
            offset       = 0xB50,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            units        = 'Bytes',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxMaxPayloadSize',
            mode         = 'RO',
            offset       = 0xB50,
            bitSize      = 16,
            bitOffset    = 16,
            disp         = '{:d}',
            units        = 'Bytes',
            pollInterval = 1,
        ))

class HtspAxiL(pr.Device):
    def __init__(self,
                 numVc           = 1,
                 statusCountBits = 12,
                 errorCountBits  = 8,
                 writeEn         = False,
                 **kwargs):
        super().__init__(**kwargs)

        self.add(HtspAxiLCtrl(
            name    = 'Ctrl',
            offset  = 0x000,
            writeEn = writeEn,
        ))

        self.add(HtspAxiLRxStatus(
            name            = 'RxStatus',
            offset          = 0x400,
            numVc           = numVc,
            statusCountBits = statusCountBits,
            errorCountBits  = errorCountBits,
        ))

        self.add(HtspAxiLTxStatus(
            name            = 'TxStatus',
            offset          = 0x800,
            numVc           = numVc,
            statusCountBits = statusCountBits,
            errorCountBits  = errorCountBits,
        ))
