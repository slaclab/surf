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
    def __init__(   self,       
        name        = "SsiPrbsRx",
        description = "SsiPrbsRx",
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
            name         = "MissedPacketCnt",
            description  = "Number of missed packets",
            offset       =  0x00,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "LengthErrCnt",
            description  = "Number of packets that were the wrong length",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "EofeErrCnt",
            description  = "Number of EOFE errors",
            offset       =  0x08,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "DataBusErrCnt",
            description  = "Number of data bus errors",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "WordStrbErrCnt",
            description  = "Number of word errors",
            offset       =  0x10,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "BitStrbErrCnt",
            description  = "Number of bit errors",
            offset       =  0x14,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "RxFifoOverflowCnt",
            description  = "",
            offset       =  0x18,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "RxFifoPauseCnt",
            description  = "",
            offset       =  0x1C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "TxFifoOverflowCnt",
            description  = "",
            offset       =  0x20,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "TxFifoPauseCnt",
            description  = "",
            offset       =  0x24,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "Dummy",
            description  = "",
            offset       =  0x28,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "Status",
            description  = "",
            offset       =  0x1C0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "PacketLength",
            description  = "",
            offset       =  0x1C4,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "PacketRate",
            description  = "",
            offset       =  0x1C8,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "BitErrCnt",
            description  = "",
            offset       =  0x1CC,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "WordErrCnt",
            description  = "",
            offset       =  0x1D0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "RolloverEnable",
            description  = "",
            offset       =  0x3C0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CntRst",
            description  = "Status counter reset",
            offset       =  0x3FC,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "WO",
        )

