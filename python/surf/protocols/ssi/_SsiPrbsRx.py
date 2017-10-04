#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue SsiPrbsRx
#-----------------------------------------------------------------------------
# File       : SsiPrbsRx.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue SsiPrbsRx
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class SsiPrbsRx(pr.Device):
    def __init__(self,       
                 name        = "SsiPrbsRx",
                 description = "SsiPrbsRx",
                 rxClkPeriod = 6.4e-9,
                 seedBits = 32,
                 **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(    
            name         = "MissedPacketCnt",
            description  = "Number of missed packets",
            offset       =  0x00,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "LengthErrCnt",
            description  = "Number of packets that were the wrong length",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "EofeErrCnt",
            description  = "Number of EOFE errors",
            offset       =  0x08,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataBusErrCnt",
            description  = "Number of data bus errors",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "WordStrbErrCnt",
            description  = "Number of word errors",
            offset       =  0x10,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "BitStrbErrCnt",
            description  = "Number of bit errors",
            offset       =  0x14,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "RxFifoOverflowCnt",
            description  = "",
            offset       =  0x18,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "RxFifoPauseCnt",
            description  = "",
            offset       =  0x1C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "TxFifoOverflowCnt",
            description  = "",
            offset       =  0x20,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "TxFifoPauseCnt",
            description  = "",
            offset       =  0x24,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Dummy",
            description  = "",
            offset       =  0x28,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Status",
            description  = "",
            offset       =  0x1C0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "PacketLength",
            description  = "",
            offset       =  0x1C4,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name = 'WordSize',
            offset = 0xF1 << 2,
            mode = 'RO',
            disp = '{:d}',
            hidden = False))

        self.add(pr.RemoteVariable(    
            name         = "PacketRateRaw",
            description  = "",
            offset       =  0x1C8,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.LinkVariable(
            name = 'PacketRate',
            dependencies = [self.PacketRateRaw],
            units = 'Frames/sec',
            disp = '{:0.1f}',
            linkedGet = lambda: 1.0/((self.PacketRateRaw.value()+1) * rxClkPeriod)))

        self.add(pr.LinkVariable(
            name = 'WordRate',
            dependencies = [self.PacketRate, self.PacketLength],
            units = 'Words/sec',
            disp = '{:0.1f}',
            linkedGet = lambda: self.PacketRate.value() * self.PacketLength.value()))

        self.add(pr.LinkVariable(
            name = 'BitRate',
            dependencies = [self.WordRate, self.WordSize],
            units = 'MBits/sec',
            disp = '{:0.1f}',
            linkedGet = lambda: self.WordRate.value() * self.WordSize.value() * 1e-6))
            
            

        self.add(pr.RemoteVariable(    
            name         = "BitErrCnt",
            description  = "",
            offset       =  0x1CC,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "WordErrCnt",
            description  = "",
            offset       =  0x1D0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "RolloverEnable",
            description  = "",
            offset       =  0x3C0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteCommand(    
            name         = "CountReset",
            description  = "Status counter reset",
            offset       =  0x3FC,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            function     = pr.BaseCommand.touchOne
        ))

    def countReset(self):
        self.CountReset()

