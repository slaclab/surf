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

class Pgp4AxiLCtrl(pr.Device):
    def __init__(self,
                 description = "Configuration of PGP 4 link",
                 writeEn     = False,
                 **kwargs):
        super().__init__(description=description, **kwargs)

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
            name      = 'PGP_FEC_ENABLE_G',
            offset    = 0x004,
            bitOffset = 1,
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
            name        = 'SkipInterval',
            description = "TX skip k-code interval",
            offset      = 0x008,
            mode        = mode,
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = "Loopback",
            description = "GT Loopback Mode",
            offset      = 0x00C,
            bitOffset   = 0,
            bitSize     = 3,
            mode        = mode,
        ))

        self.add(pr.RemoteVariable(
            name      = 'FlowControlDisable',
            offset    = 0x00C,
            bitOffset = 3,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = mode,
        ))

        self.add(pr.RemoteVariable(
            name      = 'TxDisable',
            offset    = 0x00C,
            bitOffset = 4,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = mode,
        ))

        self.add(pr.RemoteVariable(
            name      = 'ResetTx',
            offset    = 0x00C,
            bitOffset = 5,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = mode,
        ))

        self.add(pr.RemoteVariable(
            name      = 'ResetRx',
            offset    = 0x00C,
            bitOffset = 6,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = mode,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxDiffCtrl',
            mode         = mode,
            offset       = 0x00C,
            bitOffset    = 8,
            bitSize      = 5,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxPreCursor',
            mode         = mode,
            offset       = 0x00C,
            bitOffset    = 16,
            bitSize      = 5,
        ))

        self.add(pr.RemoteVariable(
            name      = 'TxFecBypass',
            offset    = 0x00C,
            bitOffset = 22,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = mode,
        ))

        self.add(pr.RemoteVariable(
            name      = 'RxFecBypass',
            offset    = 0x00C,
            bitOffset = 23,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = mode,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxPostCursor',
            mode         = mode,
            offset       = 0x00C,
            bitOffset    = 24,
            bitSize      = 5,
        ))

        self.add(pr.RemoteVariable(
            name      = 'TxPolarity',
            offset    = 0x00C,
            bitOffset = 30,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = mode,
        ))

        self.add(pr.RemoteVariable(
            name      = 'RxPolarity',
            offset    = 0x00C,
            bitOffset = 31,
            bitSize   = 1,
            base      = pr.Bool,
            mode      = mode,
        ))

        if writeEn:
            self.add(pr.RemoteCommand(
                name         = 'FecInjectBitError',
                offset       = 0x010,
                bitSize      = 1,
                bitOffset    = 0,
                function     = lambda cmd: cmd.post(1),
            ))

    def countReset(self):
        self.CountReset()

class Pgp4AxiLRxStatus(pr.Device):
    def __init__(self,
                 description     = "RX Status of PGP 4 link",
                 numVc           = 4,
                 statusCountBits = 16,
                 errorCountBits  = 8,
                 **kwargs):
        super().__init__(description=description, **kwargs)

        devOffset = 0x400

        def addStatusCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                bitSize      = statusCountBits,
                mode         = 'RO',
                disp         = '{:d}',
                pollInterval = 1,
                **ecvkwargs))

        def addErrorCountVar(bitOffset=0, **ecvkwargs):
            self.add(pr.RemoteVariable(
                bitSize      = errorCountBits,
                mode         = 'RO',
                disp         = '{:d}',
                bitOffset    = bitOffset,
                pollInterval = 1,
                **ecvkwargs))

        for i in range(numVc):
            addStatusCountVar(
                name   = f'RemPauseCnt[{i}]',
                offset = (0x400+(4*i)-devOffset),
            )

        for i in range(numVc):
            addErrorCountVar(
                name   = f'RemOverflowCnt[{i}]',
                offset = (0x440+(4*i)-devOffset),
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
            ['PhyRxInit',False],
            ['GearboxAligned',True],
            ['LinkReady',True],
            ['RemRxLinkReady',True],
            ['FrameError',False],
            ['LinkDown',False],
            ['LinkError',False],
            ['EbOverflow',False],
            ['CellError',False],
            ['CellSofError',False],
            ['CellSeqError',False],
            ['CellVersionError',False],
            ['CellCrcModeError',False],
            ['CellCrcError',False],
            ['CellEofeError',False],
        ]

        fecList = [
            ['phyRxFecLock',True],
            ['phyRxFecCorInc',False],
            ['phyRxFecUnCorInc',False],
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

        for i in range(len(fecList)):
            addErrorCountVar(
                name      = (fecList[i][0]+'Cnt'),
                offset    = (0x600+(4*i)-devOffset),
                bitOffset = 16,
            )

        for i in range(len(fecList)):
            if fecList[i][1]:
                self.add(pr.RemoteVariable(
                    name         = fecList[i][0],
                    offset       = (0x710-devOffset),
                    bitOffset    = i+16,
                    bitSize      = 1,
                    base         = pr.Bool,
                    mode         = 'RO',
                    pollInterval = 1,
                ))

        self.add(pr.RemoteVariable(
            name         = 'RemLinkData',
            offset       = (0x720-devOffset),
            bitSize      = 48,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RemOpCodeData',
            offset       = (0x730-devOffset),
            bitSize      = 48,
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
            name         = "RxClockFreqRaw",
            offset       = (0x750-devOffset),
            bitSize      = 32,
            mode         = 'RO',
            hidden       = True,
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = "RxClockFrequency",
            units        = "MHz",
            mode         = 'RO',
            dependencies = [self.RxClockFreqRaw],
            linkedGet    = lambda read: self.RxClockFreqRaw.get(read=read) * 1.0e-6,
            disp         = '{:0.3f}',
        ))

class Pgp4AxiLTxStatus(pr.Device):
    def __init__(self,
                 description     = "TX Status of PGP 4 link",
                 numVc           = 4,
                 statusCountBits = 16,
                 errorCountBits  = 8,
                 **kwargs):
        super().__init__(description=description, **kwargs)

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
            bitSize      = 48,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LocOpCodeData',
            offset       = (0xB30-devOffset),
            bitSize      = 48,
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
            name         = "TxClockFreqRaw",
            offset       = (0xB50-devOffset),
            bitSize      = 32,
            mode         = 'RO',
            hidden       = True,
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = "TxClockFrequency",
            units        = "MHz",
            mode         = 'RO',
            dependencies = [self.TxClockFreqRaw],
            linkedGet    = lambda: self.TxClockFreqRaw.value() * 1.0e-6,
            disp         = '{:0.3f}',
        ))

class Pgp4AxiL(pr.Device):
    def __init__(self,
                 description     = "Configuration and status a PGP 4 link",
                 numVc           = 4,
                 statusCountBits = 16,
                 errorCountBits  = 8,
                 writeEn         = False,
                 **kwargs):
        super().__init__(description=description, **kwargs)

        self.add(Pgp4AxiLCtrl(
            name    = 'Ctrl',
            offset  = 0x000,
            writeEn = writeEn,
        ))

        self.add(Pgp4AxiLRxStatus(
            name            = 'RxStatus',
            offset          = 0x400,
            numVc           = numVc,
            statusCountBits = statusCountBits,
            errorCountBits  = errorCountBits,
        ))

        self.add(Pgp4AxiLTxStatus(
            name            = 'TxStatus',
            offset          = 0x800,
            numVc           = numVc,
            statusCountBits = statusCountBits,
            errorCountBits  = errorCountBits,
        ))
