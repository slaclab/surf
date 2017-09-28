#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue SsiPrbsTx
#-----------------------------------------------------------------------------
# File       : SsiPrbsTx.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue SsiPrbsTx
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

class SsiPrbsTx(pr.Device):
    def __init__(   self,       
            name        = "SsiPrbsTx",
            description = "SsiPrbsTx",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(    
            name         = "AxiEn",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "TxEn",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Busy",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Overflow",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteCommand(    
            name         = "OneShot",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = pr.UInt,
            function     = pr.BaseCommand.touchOne
        ))

        self.add(pr.RemoteVariable(    
            name         = "FwCnt",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "PacketLength",
            description  = "",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "tDest",
            description  = "",
            offset       =  0x08,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "tId",
            description  = "",
            offset       =  0x08,
            bitSize      =  8,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataCount",
            description  = "",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "EventCount",
            description  = "",
            offset       =  0x10,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "RandomData",
            description  = "",
            offset       =  0x14,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

