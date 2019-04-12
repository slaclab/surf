#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Pca9535 Module
#-----------------------------------------------------------------------------
# File       : Pca9535.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue Pca9535 Module
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

class Pca9535(pr.Device):
    def __init__(   self,       
        name        = "Pca9535",
        description = "Pca9535 Module",
        **kwargs):
        
        super().__init__(name=name,description=description,**kwargs)

        self.addRemoteVariables(       
            name        = 'Input', 
            description = 'Input Port',
            offset      = (0x00 << 2), 
            number      =  2, 
            bitSize     =  8, 
            bitOffset   =  0, 
            stride      =  4,
            mode        = "RO", 
            pollInterval = 1,
        ) 

        self.addRemoteVariables(       
            name        = 'Output', 
            description = 'Output Port',
            offset      = (0x02 << 2), 
            number      =  2, 
            bitSize     =  8, 
            bitOffset   =  0, 
            stride      =  4,
            mode        = "RW", 
        )      

        self.addRemoteVariables(       
            name        = 'Polarity', 
            description = 'Polarity Inversion Port',
            offset      = (0x04 << 2), 
            number      =  2, 
            bitSize     =  8, 
            bitOffset   =  0, 
            stride      =  4,
            mode        = "RW", 
        )  

        self.addRemoteVariables(       
            name        = 'Config', 
            description = 'Configuration Port',
            offset      = (0x06 << 2), 
            number      =  2, 
            bitSize     =  8, 
            bitOffset   =  0, 
            stride      =  4,
            mode        = "RW", 
        )
        