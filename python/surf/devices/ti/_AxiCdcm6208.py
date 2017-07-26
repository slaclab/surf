#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AxiCdcm6208 Module
#-----------------------------------------------------------------------------
# File       : AxiCdcm6208.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AxiCdcm6208 Module
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

class AxiCdcm6208(pr.Device):
    def __init__(   self,       
        name        = "AxiCdcm6208",
        description = "AxiCdcm6208 Module",
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

        ####################################################################################
        ## Commented out because causes a "Segmentation fault" when "ReadAll()" is performed
        ####################################################################################
#        self.addRemoteVariables(   
#            name         = "Cdcm6208",
#            description  = "Cdcm6208 Control Registers",
#            offset       =  0x00,
#            bitSize      =  16,
#            bitOffset    =  0x00,
#            base         = pr.UInt,
#            mode         = "RW",
#            number       =  21,
#            stride       =  4,
#        )

        self.add(pr.RemoteVariable(    
            name         = "SEL_REF",
            description  = "Indicates Reference Selected for PLL:0 SEL_REF 0 => Primary 1 => Secondary",
            offset       =  0x54,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "LOS_REF",
            description  = "Loss of reference input: 0 => Reference input present 1 => Loss of reference input.",
            offset       =  0x54,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "PLL_UNLOCK",
            description  = "Indicates unlock status for PLL (digital):0 => PLL locked 1 => PLL unlocked",
            offset       =  0x54,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DIE_REVISION",
            description  = "Indicates the silicon die revision (Read only): 2:0 DIE_REVISION 00X --> Engineering Prototypes 010 --> Production Materia",
            offset       =  0xA0,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "VCO_VERSION",
            description  = "Indicates the device version (Read only):5:3 VCO_VERSION 000 => CDCM6208V1 001 => CDCM6208V2",
            offset       =  0xA0,
            bitSize      =  3,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RO",
        ))

