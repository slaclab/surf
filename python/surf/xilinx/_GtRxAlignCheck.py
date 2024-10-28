#-----------------------------------------------------------------------------
# Title      : PyRogue Timing frame phase lock
#-----------------------------------------------------------------------------
# Description:
# PyRogue Timing frame phase lock
#-----------------------------------------------------------------------------
# This file is part of the 'LCLS Timing Core'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'LCLS Timing Core', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class GtRxAlignCheck(pr.Device):
    def __init__(   self,
            name        = "GtRxAlignCheck",
            description = "Timing frame phase lock",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "PhaseTarget",
            description  = "Timing frame phase lock target",
            offset       =  0x100,
            bitSize      =  7,
            bitOffset    =  0,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "Mask",
            description  = "Register Mask Value",
            offset       =  0x100,
            bitSize      =  7,
            bitOffset    =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ResetLen",
            description  = "Reset length",
            offset       =  0x100,
            bitSize      =  4,
            bitOffset    =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "LastPhase",
            description  = "Last timing frame phase seen",
            offset       =  0x104,
            bitSize      =  7,
            bitOffset    =  0,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "TxClkFreqRaw",
            offset       = 0x108,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            hidden       = True,
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = "TxClkFreq",
            units        = "MHz",
            mode         = 'RO',
            dependencies = [self.TxClkFreqRaw],
            linkedGet    = lambda read: self.TxClkFreqRaw.get(read=read) * 1.0e-6,
            disp         = '{:0.6f}',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxClkFreqRaw",
            offset       = 0x10C,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            hidden       = True,
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = "RxClkFreq",
            units        = "MHz",
            mode         = 'RO',
            dependencies = [self.RxClkFreqRaw],
            linkedGet    = lambda read: self.RxClkFreqRaw.get(read=read) * 1.0e-6,
            disp         = '{:0.6f}',
        ))

        self.add(pr.RemoteVariable(
            name         = "Locked",
            description  = 'If True, align checker successfully aligned the transceiver',
            offset       = 0x110,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            base         = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name         = "Override",
            description  = 'If set to True, the Align Checker will stop resetting the transceiver, regardless of the phase read-out from the DRP interface',
            offset       = 0x114,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW',
            base         = pr.Bool,
        ))

        self.add(pr.RemoteCommand(
            name         = "RstRetryCnt",
            description  = 'Reset the Retry Counter back to zero',
            offset       = 0x118,
            bitSize      = 1,
            bitOffset    = 0,
            function     = pr.RemoteCommand.touchOne
        ))

        self.add(pr.RemoteVariable(
            name         = "RetryCnt",
            description  = 'How many retries it took to align. Does not roll-over',
            offset       = 0x11C,
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RO',
            base         = pr.UInt,
        ))

        self.add(pr.RemoteVariable(
            name         = "RefClkFreqRaw",
            offset       = 0x120,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            hidden       = True,
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = "RefClkFreq",
            units        = "MHz",
            mode         = 'RO',
            dependencies = [self.RefClkFreqRaw],
            linkedGet    = lambda read: self.RefClkFreqRaw.get(read=read) * 1.0e-6,
            disp         = '{:0.6f}',
        ))

        self.add(pr.RemoteVariable(
            name         = "PhaseCount",
            description  = "Timing frame phase",
            offset       =  0x00,
            valueBits    = 8,
            valueStride  = 8,
            numValues    = 40,
            mode         = "RO",
            hidden       =  False,
        ))

        for i in range(40):
            self.add(pr.LinkVariable(
                name = f'PhaseHist[{i}]',
                guiGroup='Hist',
                disp = '{:d}',
                mode = 'RO',
                dependencies = [self.PhaseCount],
                linkedGet = lambda read, x=i: self.PhaseCount.get(read=read, index=x)))
