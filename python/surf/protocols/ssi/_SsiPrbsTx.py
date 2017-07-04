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
        memBase     =  None,
        offset      =  0x00,
        hidden      =  False,
        expand      =  True,
    ):
        super().__init__(
            name        = name,
            description = description,
            memBase     = memBase,
            offset      = offset,
            hidden      = hidden,
            expand      = expand,
        )

        ##############################
        # Variables
        ##############################

        self.addVariable(   
            name         = "AxiEn",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TxEn",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "Busy",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "Overflow",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "OneShot",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "WO",
        )

        self.addVariable(   
            name         = "FwCnt",
            description  = "",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PacketLength",
            description  = "",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "tDest",
            description  = "",
            offset       =  0x08,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "tId",
            description  = "",
            offset       =  0x08,
            bitSize      =  8,
            bitOffset    =  8,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DataCount",
            description  = "",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "EventCount",
            description  = "",
            offset       =  0x10,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "RandomData",
            description  = "",
            offset       =  0x14,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        ##############################
        # Commands
        ##############################

        @self.command(name="C_OneShot", description="",)
        def C_OneShot():        
            self.OneShot.set(1)
