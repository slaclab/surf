#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI4 Memory Tester Module
#-----------------------------------------------------------------------------
# File       : AxiMemTester.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI4 Memory Tester Module
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

class AxiMemTester(pr.Device):
    def __init__(   self,       
            name        = "AxiMemTester",
            description = "AXI4 Memory Tester Module",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)  

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(    
            name         = "Passed",
            description  = "Passed Memory Test",
            offset       =  0x100,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Failed",
            description  = "Failed Memory Test",
            offset       =  0x104,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "WriteTimer",
            description  = "Write Timer",
            offset       =  0x108,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ReadTimer",
            description  = "Read Timer",
            offset       =  0x10C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "StartAddress",
            description  = "Start Address",
            offset       =  0x110,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "StopAddress",
            description  = "Stop Address",
            offset       =  0x118,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ADDR_WIDTH_C",
            description  = "AXI4 Address Bus Width (units of bits)",
            offset       =  0x120,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DATA_BYTES_C",
            description  = "AXI4 Data Bus Width (units of bits)",
            offset       =  0x124,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ID_BITS_C",
            description  = "AXI4 ID Bus Width (units of bits)",
            offset       =  0x128,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "WrErrResp",
            description  = "AXI4 Bus Write Error Response",
            offset       =  0x12C,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            mode         = "RO",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "RdErrResp",
            description  = "AXI4 Bus Read Error Response",
            offset       =  0x12C,
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.Bool,
            mode         = "RO",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "RdErrData",
            description  = "Read Data Error",
            offset       =  0x12C,
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.Bool,
            mode         = "RO",
        ))
        
        for i in range(32):
            self.add(pr.RemoteVariable(
                name        = f'RdData[{i:d}]',
                description = f'Readback Data Word {i:d}',
                offset      = 0x130 + (i*4),
                bitSize     = 32,
                bitOffset   = 0,
                base        = pr.UInt,
                mode        = 'RO',
            ))
        
        for i in range(32):
            self.add(pr.RemoteVariable(
                name        = f'RandomData[{i:d}]',
                description = f'Random Data Pattern Word {i:d}',
                offset      = 0x1B0 + (i*4),
                bitSize     = 32,
                bitOffset   = 0,
                base        = pr.UInt,
                mode        = 'RO',
            ))

