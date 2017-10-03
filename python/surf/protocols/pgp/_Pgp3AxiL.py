#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _pgp2baxi Module
#-----------------------------------------------------------------------------
# File       : _pgp2baxi.py
# Created    : 2016-09-29
# Last update: 2016-09-29
#-----------------------------------------------------------------------------
# Description:
# PyRogue _pgp2baxi Module
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

class Pgp3AxiL(pr.Device):
    def __init__(self, 
                 description = "Configuration and status a PGP 3 link",
                 channels = 4,
                 writeEn = False,
                 errorCountBits = 4,
                 statusCountBits = 32,
                 **kwargs):
        super().__init__(description=description, **kwargs)

        def addErrorCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                bitSize = errorCountBits,
                mode = 'RO',
                bitOffset = 0,
                base = pr.UInt,
                disp = '{:d}',
                **ecvkwargs))


        self.add(pr.RemoteCommand(
            name        = 'CountReset', 
            offset      = 0x00, 
            bitSize     = 1, 
            bitOffset   = 0, 
            function    = pr.BaseCommand.toggle,
        ))
        
        self.add(pr.RemoteVariable(
            name        = "Loopback", 
            description = "GT Loopback Mode",
            offset      = 0x08, 
            bitSize     = 3, 
            bitOffset   = 0, 
            mode        = "RW" if writeEn else 'RO', 
            base        = pr.UInt,
        ))
        
        self.add(pr.RemoteVariable(
            name        = "AutoStatus", 
            description = "Auto Status Send Enable (PPI)",
            offset      = 0x04, 
            bitSize     = 1, 
            bitOffset   = 0, 
            mode        = "RW", 
            base        = pr.Bool,
        ))


        ####################
        # RX
        ###################
        self.add(pr.RemoteVariable(
            name        = "RxPhyActive",       
            offset      = 0x10, 
            bitSize     = 1, 
            bitOffset   = 0, 
            mode        = "RO",
            base        = pr.Bool, 
            description = "RX Phy is Ready",
        ))
        
        
        self.add(pr.RemoteVariable(
            name        = "RxLocalLinkReady", 
            offset      = 0x10, 
            bitSize     = 1, 
            bitOffset   = 1, 
            mode        = "RO", 
            base        = pr.Bool, 
            description = "Rx Local Link Ready",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxRemLinkReady",   
            offset      = 0x10, 
            bitSize     = 1, 
            bitOffset   = 2, 
            mode        = "RO", 
            base        = pr.Bool, 
            description = "Rx Remote Link Ready",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxRemPause",       
            offset      = 0x20, 
            bitSize     = channels, 
            bitOffset   = 16, 
            mode        = "RO", 
            base        = pr.UInt,
            disp        = '{:#_b}',
            description = "RX Remote Pause Asserted",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxRemOverflow",    
            offset      = 0x20, 
            bitSize     = channels, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt,
            disp        = '{:#_b}',            
            description = "Received remote overflow flag",
        ))

        self.add(pr.RemoteVariable(
            name        = "RxClockFreqRaw",    
            offset      = 0x2C, 
            bitSize     = 32, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt,
            hidden      = True,
            pollInterval = 5,
        ))


        self.add(pr.LinkVariable(
            name         = "RxClockFrequency", 
            units        = "MHz", 
            dependencies = [self.RxClockFreqRaw], 
            linkedGet    = lambda: self.RxClockFreqRaw.value() * 1.0e-6,
            disp         = '{:0.3f}',
        ))
        

        self.add(pr.RemoteVariable(
            name        = "RxFrameCount",    
            offset      = 0x24, 
            bitSize     = statusCountBits, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt, 
        ))

        addErrorCountVar(
            name = 'RxFrameErrorCount',
            offset = 0x28,
        )

        addErrorCountVar(
            name   = "RxCellErrorCount", 
            offset = 0x14, 
        )

        addErrorCountVar(
            name = "RxLinkDownCount",
            offset = 0x18
        )

        addErrorCountVar(
            name = 'RxLinkErrorCount',
            offset = 0x1C,
        )
        
        for i in range(16):
            addErrorCountVar(
                name = f'RxRemOverflowCount[{i}]',
                offset = 0x40+(i*4),
                hidden = (i >= channels)
            )

        addErrorCountVar(
            name = 'RxOpCodeCount',
            offset = 0x30)

        self.add(pr.RemoteVariable(
            name = 'RxOpCodeDataLastRaw',
            offset = 0x34,
            bitSize = 56,
            base = pr.UInt,
            hidden = True,
        ))

        self.add(pr.RemoteVariable(
            name = 'RxOpCodeNumLastRaw',
            offset = 0x34,
            bitOffset = 56,            
            bitSize = 3,
            hidden = True,
        ))

        self.add(pr.LinkVariable(
            name = 'RxOpCodeLast',
            dependencies = [self.RxOpCodeDataLastRaw, self.RxOpCodeNumLastRaw],
            linkedGet = lambda: f'{self.RxOpCodeNumLastRaw.value()} - {self.RxOpCodeDataLastRaw.value():x}'))

        self.add(pr.RemoteVariable(
            name = 'PhyRxValid',
            offset = 0x108,
            bitOffset = 2,
            bitSize = 1))

        self.add(pr.RemoteVariable(
            name = 'PhyRxData',
            offset = 0x100,
            bitOffset = 64))

        self.add(pr.RemoteVariable(
            name = 'PhyRxHeader',
            offset = 0x108,
            bitOffset = 0,
            bitSize = 2))

        self.add(pr.RemoteVariable(
            name = 'EbRxValid',
            offset = 0x118,
            bitOffset = 2,
            bitSize = 1))

        self.add(pr.RemoteVariable(
            name = 'EbRxData',
            offset = 0x110,
            bitOffset = 64))

        self.add(pr.RemoteVariable(
            name = 'EbRxHeader',
            offset = 0x118,
            bitOffset = 0,
            bitSize = 2))

        self.add(pr.RemoteVariable(
            name = 'GearboxAligned',
            offset = 0x120,
            bitSize = 1))

        self.add(pr.RemoteVariable(
            name = 'GearboxAlignCnt',
            offset = 0x120,
            bitOffset = 8,
            bitSize = 8))
        
        ################
        # TX
        ################
        self.add(pr.RemoteVariable(
            name = 'FlowControlDisable',
            offset = 0x80,
            bitOffset = 0,
            bitSize = 1,
            base = pr.Bool,
            mode = 'RW' if writeEn else 'RO'))

        self.add(pr.RemoteVariable(
            name = 'TxDisable',
            offset = 0x80,
            bitOffset = 1,
            bitSize = 1,
            base = pr.Bool,
            mode = 'RW' if writeEn else 'RO'))
        
        self.add(pr.RemoteVariable(
            name        = "TxPhyActive",       
            offset      = 0x84, 
            bitSize     = 1, 
            bitOffset   = 1, 
            mode        = "RO", 
            base        = pr.Bool, 
            description = "TX Phy is Ready",
        ))

        self.add(pr.RemoteVariable(
            name = 'TxLinkReady',
            offset = 0x84,
            bitOffset = 0,
            bitSize = 1,
            mode = 'RO',
            base = pr.Bool))
        
        

        self.add(pr.RemoteVariable(
            name        = "TxLocPause",       
            offset      = 0x8C, 
            bitSize     = channels, 
            bitOffset   = 16, 
            mode        = "RO", 
            base        = pr.UInt,
            disp        = '{:#_b}',            
            description = "Tx Local Pause Asserted",
        ))

        self.add(pr.RemoteVariable(
            name        = "TxLocOverflow",    
            offset      = 0x8C, 
            bitSize     = channels,
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt,
            disp        = '{:#_b}',            
            description = "Received local overflow flag",
        ))

        self.add(pr.RemoteVariable(
            name        = "TxClockFreqRaw",    
            offset      = 0x9C, 
            bitSize     = 32, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt,
            hidden      = True,
            pollInterval = 5,
        ))

        self.add(pr.LinkVariable(
            name         = "TxClockFrequency", 
            units        = "MHz", 
            dependencies = [self.TxClockFreqRaw], 
            linkedGet    = lambda: self.TxClockFreqRaw.value() * 1.0e-6,
            disp         = '{:0.3f}',
        ))        
        
        self.add(pr.RemoteVariable(
            name        = "TxFrameCount",    
            offset      = 0x90, 
            bitSize     = statusCountBits, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt, 
        ))        

        addErrorCountVar(
            name = 'TxFrameErrorCount',
            offset = 0x94)

        for i in range(16):
            addErrorCountVar(
                name = f'TxLocOverflowCount[{i}]',
                offset = 0xB0 + (i*4),
                hidden = (i >= channels))
       
        addErrorCountVar(
            name = 'TxOpCodeCount',
            offset = 0xA0)

        self.add(pr.RemoteVariable(
            name = 'TxOpCodeDataLastRaw',
            offset = 0xA4,
            bitSize = 56,
            base = pr.UInt,
            hidden = True,
        ))

        self.add(pr.RemoteVariable(
            name = 'TxOpCodeNumLastRaw',
            offset = 0xA4,
            bitOffset = 56,            
            bitSize = 3,
            hidden = True,
        ))

        self.add(pr.LinkVariable(
            name = 'TxOpCodeLast',
            dependencies = [self.TxOpCodeDataLastRaw, self.TxOpCodeNumLastRaw],
            linkedGet = lambda: f'{self.TxOpCodeNumLastRaw.value()} - {self.TxOpCodeDataLastRaw.value():x}'))

    def countReset(self):
        self.CountReset()
