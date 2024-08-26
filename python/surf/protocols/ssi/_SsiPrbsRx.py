#-----------------------------------------------------------------------------
# Description:
# PyRogue SsiPrbsRx
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

class SsiPrbsRx(pr.Device):
    def __init__(self,
                 rxClkPeriod = 6.4e-9,
                 seedBits = 32,
                 **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "MissedPacketCnt",
            description  = "Number of missed packets",
            offset       =  0x00,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "LengthErrCnt",
            description  = "Number of packets that were the wrong length",
            offset       =  0x04,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "EofeErrCnt",
            description  = "Number of EOFE errors",
            offset       =  0x08,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "DataBusErrCnt",
            description  = "Number of data bus errors",
            offset       =  0x0C,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "WordStrbErrCnt",
            description  = "Number of word errors",
            offset       =  0x10,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        # self.add(pr.RemoteVariable(
            # name         = "BitStrbErrCnt",
            # description  = "Number of bit errors",
            # offset       =  0x14,
            # bitSize      =  32,
            # mode         = "RO",
            # pollInterval = 1,
        # ))

        self.add(pr.RemoteVariable(
            name         = "RxFifoOverflowCnt",
            description  = "Number of times the RX FIFO has overflowed",
            offset       =  0x18,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxFifoPauseCnt",
            description  = "Number of times the RX FIFO has paused",
            offset       =  0x1C,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxFifoOverflowCnt",
            description  = "Number of times the TX FIFO has overflowed",
            offset       =  0x20,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxFifoPauseCnt",
            description  = "Number of times the TX FIFO has paused",
            offset       =  0x24,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "Dummy",
            description  = "Writable register that does nothing",
            offset       =  0x28,
            bitSize      =  32,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "Status",
            description  = "Current status of several internal values",
            offset       =  0x70,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "PacketLength",
            description  = "",
            offset       =  0x74,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name = 'WordSize',
            offset = 0xF8,
            mode = 'RO',
            disp = '{:d}',
            hidden = False))

        self.add(pr.RemoteVariable(
            name         = "PacketRateRaw",
            description  = "",
            offset       =  0x78,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name = 'PacketRate',
            dependencies = [self.PacketRateRaw],
            units = 'Frames/sec',
            disp = '{:0.1f}',
            linkedGet = lambda read: 1.0/((self.PacketRateRaw.get(read=read)+1) * rxClkPeriod)))

        self.add(pr.LinkVariable(
            name = 'WordRate',
            dependencies = [self.PacketRate, self.PacketLength],
            units = 'Words/sec',
            disp = '{:0.1f}',
            linkedGet = lambda read: self.PacketRate.get(read=read) * self.PacketLength.get(read=read)))

        self.add(pr.LinkVariable(
            name = 'BitRate',
            dependencies = [self.WordRate, self.WordSize],
            units = 'MBits/sec',
            disp = '{:0.1f}',
            linkedGet = lambda read: self.WordRate.get(read=read) * self.WordSize.get(read=read) * 1e-6))

        # self.add(pr.RemoteVariable(
            # name         = "BitErrCnt",
            # description  = "",
            # offset       =  0x1CC,
            # bitSize      =  32,
            # mode         = "RO",
            # pollInterval = 1,
        # ))

        self.add(pr.RemoteVariable(
            name         = "WordErrCnt",
            description  = "",
            offset       =  0x80,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "FrameCnt",
            description  = "",
            offset       =  0x84,
            bitSize      =  32,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RolloverEnable",
            description  = "",
            offset       =  0xF0,
            bitSize      =  32,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "BypassErrorChecking",
            description  = "Used to bypass the error checking",
            offset       =  0xF4,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteCommand(
            name         = "CountReset",
            description  = "Status counter reset",
            offset       =  0xFC,
            bitSize      =  1,
            function     = pr.BaseCommand.touchOne
        ))

    def countReset(self):
        self.CountReset()
