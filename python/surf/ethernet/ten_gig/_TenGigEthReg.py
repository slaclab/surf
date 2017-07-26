#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue TenGigEthReg
#-----------------------------------------------------------------------------
# File       : TenGigEthReg.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue TenGigEthReg
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

class TenGigEthReg(pr.Device):
    def __init__(   self,       
            name        = "TenGigEthReg",
            description = "TenGigEthReg",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.addRemoteVariables(   
            name         = "StatusCounters",
            description  = "Status Counters",
            offset       =  0x00,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  19,
            stride       =  4,
        )

        self.add(pr.RemoteVariable(   
            name         = "StatusVector",
            description  = "Status Vector",
            offset       =  0x100,
            bitSize      =  19,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(   
            name         = "PhyStatus",
            description  = "PhyStatus",
            offset       =  0x108,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(   
            name         = "MacAddress",
            description  = "MAC Address (big-Endian)",
            offset       =  0x200,
            bitSize      =  48,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(   
            name         = "PauseTime",
            description  = "PauseTime",
            offset       =  0x21C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(   
            name         = "FilterEnable",
            description  = "FilterEnable",
            offset       =  0x228,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(   
            name         = "PauseEnable",
            description  = "PauseEnable",
            offset       =  0x22C,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(   
            name         = "pma_pmd_type",
            description  = "pma_pmd_type",
            offset       =  0x230,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "pma_loopback",
            description  = "pma_loopback",
            offset       =  0x234,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "pma_reset",
            description  = "pma_reset",
            offset       =  0x238,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "pcs_loopback",
            description  = "pcs_loopback",
            offset       =  0x23C,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "pcs_reset",
            description  = "pcs_reset",
            offset       =  0x240,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "RollOverEn",
            description  = "RollOverEn",
            offset       =  0xF00,
            bitSize      =  19,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "CounterReset",
            description  = "CounterReset",
            offset       =  0xFF4,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "WO",
        ))

        self.add(pr.RemoteVariable(   
            name         = "SoftReset",
            description  = "SoftReset",
            offset       =  0xFF8,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "WO",
        ))

        self.add(pr.RemoteVariable(   
            name         = "HardReset",
            description  = "HardReset",
            offset       =  0xFFC,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "WO",
        ))

