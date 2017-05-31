#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Adc32Rf45 Module
#-----------------------------------------------------------------------------
# File       : Adc32Rf45.py
# Created    : 2017-05-28
#-----------------------------------------------------------------------------
# Description:
# PyRogue Adc32Rf45 Module
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

class Adc32Rf45(pr.Device):
    def __init__(   self,       
                    name        = "Adc32Rf45",
                    description = "Adc32Rf45 Module",
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, )

        ##############################
        # Variables
        ##############################

        self.addVariable(   name         = "GlobalReg_0x0000",
                            description  = "ADC Control Registers",
                            offset       =  0x00,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "GlobalReg_0x0002",
                            description  = "ADC Control Registers",
                            offset       =  0x08,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "GlobalReg_0x0003",
                            description  = "ADC Control Registers",
                            offset       =  0x0C,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "GlobalReg_0x0004",
                            description  = "ADC Control Registers",
                            offset       =  0x10,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "GlobalReg_0x0010",
                            description  = "ADC Control Registers",
                            offset       =  0x40,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "GlobalReg_0x0011",
                            description  = "ADC Control Registers",
                            offset       =  0x44,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "GlobalReg_0x0012",
                            description  = "ADC Control Registers",
                            offset       =  0x48,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MasterReg_0x0020",
                            description  = "ADC Control Registers",
                            offset       =  0x80,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MasterReg_0x0032",
                            description  = "ADC Control Registers",
                            offset       =  0xC8,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MasterReg_0x0039",
                            description  = "ADC Control Registers",
                            offset       =  0xE4,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MasterReg_0x003C",
                            description  = "ADC Control Registers",
                            offset       =  0xF0,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MasterReg_0x003D",
                            description  = "ADC Control Registers",
                            offset       =  0xF4,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MasterReg_0x005A",
                            description  = "ADC Control Registers",
                            offset       =  0x168,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MasterReg_0x0057",
                            description  = "ADC Control Registers",
                            offset       =  0x15C,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MasterReg_0x0058",
                            description  = "ADC Control Registers",
                            offset       =  0x160,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

# Select maste page
#   dev.GlobalReg_0x0012.set(0x04)

# Select ADC page
#   dev.GlobalReg_0x0011.set(0xff)

# Select the offset corrector page channel A
#   dev.GlobalReg_0x0004.set(0x61)
#   dev.GlobalReg_0x0003.set(0x00)
#   dev.GlobalReg_0x0002.set(0x00)

# Select the offset corrector page channel B
#   dev.GlobalReg_0x0004.set(0x61)
#   dev.GlobalReg_0x0003.set(0x01)
#   dev.GlobalReg_0x0002.set(0x00)

# Select the offset corrector page channel A
#   dev.GlobalReg_0x0004.set(0x61)
#   dev.GlobalReg_0x0003.set(0x00)
#   dev.GlobalReg_0x0002.set(0x05)

# Select the offset corrector page channel B
#   dev.GlobalReg_0x0004.set(0x61)
#   dev.GlobalReg_0x0003.set(0x01)
#   dev.GlobalReg_0x0002.set(0x05)

# Select the main digital page channel A
#   dev.GlobalReg_0x0004.set(0x68)
#   dev.GlobalReg_0x0003.set(0x00)
#   dev.GlobalReg_0x0002.set(0x00)

# Select the main digital page channel B
#   dev.GlobalReg_0x0004.set(0x68)
#   dev.GlobalReg_0x0003.set(0x01)
#   dev.GlobalReg_0x0002.set(0x00)

# Select the JESD digital page
#   dev.GlobalReg_0x0004.set(0x69)
#   dev.GlobalReg_0x0003.set(0x00)
#   dev.GlobalReg_0x0002.set(0x00)
