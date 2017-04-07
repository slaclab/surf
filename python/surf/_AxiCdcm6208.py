#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AxiCdcm6208 Module
#-----------------------------------------------------------------------------
# File       : AxiCdcm6208.py
# Created    : 2017-04-04
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
    def __init__(self, name="AxiCdcm6208", description="AxiCdcm6208 Module", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        for i in range(21):
            self.add(pr.Variable(   name         = "Cdcm6208_%.*i" % (2, i),
                                    description  = "Cdcm6208 Control Registers %.*i" % (2, i),
                                    offset       =  0x00 + (i * 0x04),
                                    bitSize      =  16,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        self.add(pr.Variable(   name         = "SEL_REF",
                                description  = "Indicates Reference Selected for PLL:0 SEL_REF 0 => Primary 1 => Secondary",
                                offset       =  0x54,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "LOS_REF",
                                description  = "Loss of reference input: 0 => Reference input present 1 => Loss of reference input.",
                                offset       =  0x54,
                                bitSize      =  1,
                                bitOffset    =  0x01,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "PLL_UNLOCK",
                                description  = "Indicates unlock status for PLL (digital):0 => PLL locked 1 => PLL unlocked",
                                offset       =  0x54,
                                bitSize      =  1,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "DIE_REVISION",
                                description  = "Indicates the silicon die revision (Read only): 2:0 DIE_REVISION 00X --> Engineering Prototypes 010 --> Production Materia",
                                offset       =  0xA0,
                                bitSize      =  3,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "VCO_VERSION",
                                description  = "Indicates the device version (Read only):5:3 VCO_VERSION 000 => CDCM6208V1 001 => CDCM6208V2",
                                offset       =  0xA0,
                                bitSize      =  3,
                                bitOffset    =  0x03,
                                base         = "hex",
                                mode         = "RO",
                            ))

