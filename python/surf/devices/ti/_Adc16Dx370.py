#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue ADC16Dx370 Module
#-----------------------------------------------------------------------------
# File       : Adc16Dx370.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue ADC16Dx370 Module
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
import time

class Adc16Dx370(pr.Device):
    def __init__( self,       
        name        = "Adc16Dx370",
        description = "ADC16Dx370 Module",
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

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0000",
            description  = "ADC Control Registers",
            offset       =  0x00,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0002",
            description  = "ADC Control Registers",
            offset       =  0x08,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0003",
            description  = "ADC Control Registers",
            offset       =  0x0C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0004",
            description  = "ADC Control Registers",
            offset       =  0x0F,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0005",
            description  = "ADC Control Registers",
            offset       =  0x14,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0006",
            description  = "ADC Control Registers",
            offset       =  0x18,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x000C",
            description  = "ADC Control Registers",
            offset       =  0x30,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x000D",
            description  = "ADC Control Registers",
            offset       =  0x34,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0010",
            description  = "ADC Control Registers",
            offset       =  0x40,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0012",
            description  = "ADC Control Registers",
            offset       =  0x48,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0013",
            description  = "ADC Control Registers",
            offset       =  0x4C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0014",
            description  = "ADC Control Registers",
            offset       =  0x50,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0015",
            description  = "ADC Control Registers",
            offset       =  0x54,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0019",
            description  = "ADC Control Registers",
            offset       =  0x64,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(     
            name         = "AdcReg_0x003B",
            description  = "ADC Control Registers",
            offset       =  0xEC,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x003C",
            description  = "ADC Control Registers",
            offset       =  0xF0,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x003D",
            description  = "ADC Control Registers",
            offset       =  0xF4,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0047",
            description  = "ADC Control Registers",
            offset       =  0x11C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0060",
            description  = "ADC Control Registers",
            offset       =  0x180,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0061",
            description  = "ADC Control Registers",
            offset       =  0x184,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0062",
            description  = "ADC Control Registers",
            offset       =  0x188,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0063",
            description  = "ADC Control Registers",
            offset       =  0x18C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0070",
            description  = "ADC Control Registers",
            offset       =  0x1C0,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ID_DEVICE_TYPE",
            description  = "ID_DEVICE_TYPE",
            offset       =  0x0C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ID_PROD_UPPER",
            description  = "ID_PROD_UPPER",
            offset       =  0x10,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ID_PROD_LOWER",
            description  = "ID_PROD_LOWER",
            offset       =  0x14,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ID_MASKREV",
            description  = "ID_MASKREV",
            offset       =  0x18,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ID_VNDR_UPPER",
            description  = "ID_VNDR_UPPER",
            offset       =  0x30,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ID_VNDR_LOWER",
            description  = "ID_VNDR_LOWER",
            offset       =  0x34,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Clock_ready",
            description  = "Clock_ready",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Calibration_done",
            description  = "Calibration_done",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "PLL_lock",
            description  = "PLL_lock",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Aligned_to_sysref",
            description  = "Aligned_to_sysref",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Realigned_to_sysref",
            description  = "Realigned_to_sysref",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Sync_form_FPGA",
            description  = "Sync_form_FPGA",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Link_active",
            description  = "Link_active",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = pr.UInt,
            mode         = "RO",
        ))

        ##############################
        # Commands
        ##############################

        @self.command(description="PowerDown",)
        def PowerDown():         
            self.AdcReg_0x0002.set(3)
            
        @self.command(description="PowerUp",)
        def PowerUp():         
            self.AdcReg_0x0002.set(0)  

        @self.command(description="CalibrateAdc",)
        def CalibrateAdc():         
            self.PowerDown.set(1)    
            time.sleep(1.0)
            self.PowerUp.set(1)   
