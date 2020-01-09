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
        
        self.add(pr.RemoteCommand(   
            name         = 'CntRst',
            description  = "Counter Reset",
            offset       = 0x0,
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        ))        
        
        def addPair(name,offset,bitSize,units,bitOffset,description,function,pollInterval = 0,):
            self.add(pr.RemoteVariable(  
                name         = ("Raw"+name), 
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
                dependencies = [self.variables["Raw"+name]],
            ))        
        
        #############################################
        # Create block / variable combinations
        #############################################
        
        for i in range(numberLanes):
        
            self.add(pr.RemoteVariable(
                name         = f'FrameCnt[{i}]', 
                description  = 'Increments every time a tValid + tLast + tReady detected',
                offset       = (i*0x40 + 0x04), 
                bitSize      = 64, 
                mode         = 'RO',
                pollInterval = 1,
            ))        
        
            self.add(pr.RemoteVariable(
                name         = f'FrameRate[{i}]',       
                description  = "Current Frame Rate",
                offset       = (i*0x40 + 0x0C), 
                bitSize      = 32, 
                bitOffset    = 0, 
                mode         = "RO",
                base         = pr.Int, 
                units        = 'Hz', 
                pollInterval = 1,
            ))     

            self.add(pr.RemoteVariable(
                name         = f'FrameRateMax[{i}]',       
                description  = "Max Frame Rate",
                offset       = (i*0x40 + 0x10), 
                bitSize      = 32, 
                bitOffset    = 0, 
                mode         = "RO",
                base         = pr.Int, 
                units        = 'Hz', 
                pollInterval = 1,
            )) 

            self.add(pr.RemoteVariable(
                name         = f'FrameRateMin[{i}]',       
                description  = "Min Frame Rate",
                offset       = (i*0x40 + 0x14), 
                bitSize      = 32, 
                bitOffset    = 0, 
                mode         = "RO",
                base         = pr.Int, 
                units        = 'Hz', 
                pollInterval = 1,
            ))
            
            addPair(
                name         = f'Bandwidth[{i}]',       
                description  = "Current Bandwidth",
                offset       = (i*0x40 + 0x18), 
                bitSize      = 64, 
                bitOffset    = 0, 
                function     = self.convMbps,
                units        = 'Mbps', 
                pollInterval = 1,
            )

            addPair(
                name         = f'BandwidthMax[{i}]',       
                description  = "Max Bandwidth",
                offset       = (i*0x40 + 0x20), 
                bitSize      = 64, 
                bitOffset    = 0, 
                function     = self.convMbps,
                units        = 'Mbps', 
                pollInterval = 1,
            )

            addPair(
                name         = f'BandwidthMin[{i}]',       
                description  = "Min Bandwidth",
                offset       = (i*0x40 + 0x28), 
                bitSize      = 64, 
                bitOffset    = 0, 
                function     = self.convMbps,
                units        = 'Mbps', 
                pollInterval = 1,
            )

            self.add(pr.RemoteVariable(
                name         = f'FrameSize[{i}]',
                description  = 'Current Frame Size. Note: Only valid for non-interleaved AXI stream frames',
                offset       = (i*0x40 + 0x30),
                bitSize      = 32,
                bitOffset    = 0,
                mode         = 'RO',
                base         = pr.Int,
                units        = 'Byte',
                pollInterval = 1,
            ))

            self.add(pr.RemoteVariable(
                name         = f'FrameSizeMax[{i}]',
                description  = 'Max Frame Size. Note: Only valid for non-interleaved AXI stream frames',
                offset       = (i*0x40 + 0x34),
                bitSize      = 32,
                bitOffset    = 0,
                mode         = 'RO',
                base         = pr.Int,
                units        = 'Byte',
                pollInterval = 1,
            ))

            self.add(pr.RemoteVariable(
                name         = f'FrameSizeMin[{i}]',
                description  = 'Min Frame Size. Note: Only valid for non-interleaved AXI stream frames',
                offset       = (i*0x40 + 0x38),
                bitSize      = 32,
                bitOffset    = 0,
                mode         = 'RO',
                base         = pr.Int,
                units        = 'Byte',
                pollInterval = 1,
            ))

    @staticmethod
    def convMbps(var):
        return var.dependencies[0].value() * 8e-6
        
    def hardReset(self):
        self.CntRst()

    def initialize(self):
        self.CntRst()

    def countReset(self):
        self.CntRst()
