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

class AxiStreamMonitoring(pr.Device):
    def __init__(self,       
            name        = "AxiStreamMonitoring",
            description = "AxiStreamMonitoring Container",
            numberLanes = 1,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        def addPair(name,offset,bitSize,units,bitOffset,description,function,pollInterval = 0,):
            self.add(pr.RemoteVariable(  
                name         = (name+"Raw"), 
                offset       = offset, 
                bitSize      = bitSize, 
                bitOffset    = bitOffset,
                base         = pr.UInt, 
                mode         = 'RO', 
                description  = description,
                pollInterval = pollInterval,
                hidden       = True,
            ))
            self.add(pr.LinkVariable(
                name         = name, 
                mode         = 'RO', 
                units        = units,
                linkedGet    = function,
                disp         = '{:1.1f}',
                dependencies = [self.variables[name+"Raw"]],
            ))        
        
        #############################################
        # Create block / variable combinations
        #############################################
        
        for i in range(numberLanes):
            self.add(pr.RemoteVariable(
                name         = ('FrameRate[%d]'%i),       
                description  = "Current Frame Rate",
                offset       = (16 + i*48), 
                bitSize      = 32, 
                bitOffset    = 0, 
                mode         = "RO",
                base         = pr.Int, 
                units        = 'Hz', 
                pollInterval = 1,
            ))     

            self.add(pr.RemoteVariable(
                name         = ('FrameRateMax[%d]'%i),       
                description  = "Max Frame Rate",
                offset       = (20 + i*48), 
                bitSize      = 32, 
                bitOffset    = 0, 
                mode         = "RO",
                base         = pr.Int, 
                units        = 'Hz', 
                pollInterval = 1,
            )) 

            self.add(pr.RemoteVariable(
                name         = ('FrameRateMin[%d]'%i),       
                description  = "Min Frame Rate",
                offset       = (24 + i*48), 
                bitSize      = 32, 
                bitOffset    = 0, 
                mode         = "RO",
                base         = pr.Int, 
                units        = 'Hz', 
                pollInterval = 1,
            ))
            
            addPair(
                name         = ('Bandwidth[%d]'%i),       
                description  = "Current Bandwidth",
                offset       = (28 + i*48), 
                bitSize      = 64, 
                bitOffset    = 0, 
                function     = self.convMbps,
                units        = 'Mbps', 
                pollInterval = 1,
            )

            addPair(
                name         = ('BandwidthMax[%d]'%i),       
                description  = "Max Bandwidth",
                offset       = (36 + i*48), 
                bitSize      = 64, 
                bitOffset    = 0, 
                function     = self.convMbps,
                units        = 'Mbps', 
                pollInterval = 1,
            )

            addPair(
                name         = ('BandwidthMin[%d]'%i),       
                description  = "Min Bandwidth",
                offset       = (44 + i*48), 
                bitSize      = 64, 
                bitOffset    = 0, 
                function     = self.convMbps,
                units        = 'Mbps', 
                pollInterval = 1,
            )

    @staticmethod
    def convMbps(var):
        return var.dependencies[0].value() * 8e-6
        
    def countReset(self):
        self._rawWrite(offset=0x0,data=0x1)       