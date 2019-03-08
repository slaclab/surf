#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Version Module
#-----------------------------------------------------------------------------
# File       : AxiVersion.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Version Module
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

class AxiStreamBatcherEventBuilder(pr.Device):
    def __init__(self,       
            name         = "AxiStreamBatcherEventBuilder",
            description  = "AxiStreamBatcherEventBuilder Container",
            numberSlaves = 1,
            tickUnit     = 'TBD',
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

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

        self.addRemoteVariables(   
            name         = 'NullCnt',
            description  = 'Increments every time a null frame is received',
            offset       = 0x100,
            bitSize      = 32,
            mode         = 'RO',
            number       = numberSlaves,
            stride       = 4,
            pollInterval = 1,
        )   

        self.addRemoteVariables(   
            name         = 'TimeoutDropCnt',
            description  = 'Increments every time a timeout slave channel drop event happens',
            offset       = 0x200,
            bitSize      = 32,
            mode         = 'RO',
            number       = numberSlaves,
            stride       = 4,
            pollInterval = 1,
        )           
        
        self.add(pr.RemoteVariable(   
            name         = 'Timeout',
            description  = 'Sets the timer\'s timeout duration.  Setting to 0x0 (default) bypasses the timeout feature',
            offset       = 0xFF0,
            bitSize      = 32,
            mode         = 'RW',
            units        = tickUnit,
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
            name         = "CntRst",                 
            description  = "Counter Reset",
            mode         = 'WO',
            offset       = 0xFFC,
            hidden       = True,
        ))  
        
    def hardReset(self):
        self.CntRst.set(0x1)

    def softReset(self):
        self.CntRst.set(0x1)

    def countReset(self):
        self.CntRst.set(0x1)
