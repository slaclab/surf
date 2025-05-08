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

class EventFrameSequencerMux(pr.Device):
    def __init__(
            self,
            numberSlaves = 1,
            **kwargs):
        super().__init__(**kwargs)

        self.addRemoteVariables(
            name         = 'DataCnt',
            description  = 'Increments every time a data frame is received',
            offset       = 0x000,
            bitSize      = 32,
            mode         = 'RO',
            number       = numberSlaves,
            stride       = 4,
            pollInterval = 1,
        )

        self.add(pr.RemoteVariable(
            name         = 'SeqCnt',
            description  = 'Increments every time there is a frame sent',
            offset       = 0xFBC,
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TransactionCnt',
            description  = 'Increments every time a transition frame is received',
            offset       = 0xFC0,
            bitSize      = 32,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TRANS_TDEST_G',
            description  = 'TRANS_TDEST_G generic value',
            offset       = 0xFC4,
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Bypass',
            description  = 'Mask to bypass a channel',
            offset       = 0xFD0,
            bitSize      = numberSlaves,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'NUM_SLAVES_G',
            description  = 'NUM_SLAVES_G generic value',
            offset       = 0xFF4,
            bitSize      = 8,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = "State",
            description  = "current state of FSM (for debugging)",
            offset       =  0xFF4,
            bitSize      =  1,
            bitOffset    =  8,
            mode         = "RO",
            pollInterval = 1,
            enum         = {
                0x0: 'IDLE_S',
                0x1: 'MOVE_S',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = "BlowoffExt",
            description  = "Status of external blowoff input",
            offset       =  0xFF4,
            bitSize      =  1,
            bitOffset    =  16,
            base         = pr.Bool,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "Blowoff",
            description  = "Blows off the inbound AXIS stream (for debugging)",
            offset       =  0xFF8,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteCommand(
            name         = "CntRst",
            description  = "",
            offset       = 0xFFC,
            bitSize      = 1,
            bitOffset    = 0,
            function     = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteCommand(
            name         = "TimerRst",
            description  = "",
            offset       = 0xFFC,
            bitSize      = 1,
            bitOffset    = 1,
            function     = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteCommand(
            name         = "HardRst",
            description  = "",
            offset       = 0xFFC,
            bitSize      = 1,
            bitOffset    = 2,
            function     = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteCommand(
            name         = "SoftRst",
            description  = "",
            offset       = 0xFFC,
            bitSize      = 1,
            bitOffset    = 3,
            function     = pr.BaseCommand.toggle,
        ))

    def hardReset(self):
        self.HardRst()

    def initialize(self):
        self.SoftRst()

    def countReset(self):
        self.CntRst()
