#-----------------------------------------------------------------------------
# Title      : PyRogue GigEthReg
#-----------------------------------------------------------------------------
# Description:
# PyRogue GigEthReg
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

from surf.ethernet import udp

class GigEthReg(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "PhyReadyCount",
            description  = "Count of PHY ready transitions",
            offset       =  0x00,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxPauseCount",
            description  = "Count of received pause frames",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxPauseCount",
            description  = "Count of transmitted pause frames",
            offset       =  0x08,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxCountEn",
            description  = "Count of received frames",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxOverflowCount",
            description  = "Count of receive FIFO overflow events",
            offset       =  0x10,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxCrcErrorCount",
            description  = "Count of received frames with CRC errors",
            offset       =  0x14,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxCountEn",
            description  = "Count of transmitted frames",
            offset       =  0x18,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxUnderRunCount",
            description  = "Count of transmit FIFO underrun events",
            offset       =  0x1C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxNotReadyCount",
            description  = "Count of transmit not-ready events",
            offset       =  0x20,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))


        self.add(pr.RemoteVariable(
            name         = "StatusVector",
            description  = "Ethernet MAC/PHY status vector bits",
            offset       =  0x100,
            bitSize      =  9,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "PhyStatus",
            description  = "PHY status register bits",
            offset       =  0x108,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MacAddress',
            description  = 'MacAddress (big-Endian configuration)',
            offset       = 0x200,
            bitSize      = 48,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'MAC_ADDRESS',
            description  = 'MacAddress (human readable)',
            mode         = 'RO',
            linkedGet    = udp.getMacValue,
            dependencies = [self.variables['MacAddress']],
        ))

        self.add(pr.RemoteVariable(
            name         = "PauseTime",
            description  = "Pause frame quanta value",
            offset       =  0x21C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "FilterEnable",
            description  = "Enable MAC address filtering",
            offset       =  0x228,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "PauseEnable",
            description  = "Enable flow control pause frames",
            offset       =  0x22C,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "RollOverEn",
            description  = "Enable counter rollover instead of saturation",
            offset       =  0xF00,
            bitSize      =  9,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteCommand(
            name         = "CounterReset",
            description  = "Reset all status counters",
            offset       =  0xFF4,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            function     = pr.RemoteCommand.touchOne
        ))

        self.add(pr.RemoteCommand(
            name         = "SoftReset",
            description  = "Issue a soft reset to the Ethernet MAC",
            offset       =  0xFF8,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            function     = pr.RemoteCommand.touchOne
        ))

        self.add(pr.RemoteCommand(
            name         = "HardReset",
            description  = "Issue a hard reset to the Ethernet MAC",
            offset       =  0xFFC,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            function     = pr.RemoteCommand.touchOne
        ))

    def countReset(self):
        self.CounterReset()
