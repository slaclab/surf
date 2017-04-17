#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue DAC38J84 Module
#-----------------------------------------------------------------------------
# File       : Dac38J84.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue DAC38J84 Module
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

class Dac38J84(pr.Device):
    def __init__(   self,       
                    name        = "Dac38J84",
                    description = "DAC38J84 Module",
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                    numTxLanes  =  2,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, )

        ##############################
        # Variables
        ##############################

        self.addVariables(  name         = "DacReg",
                            description  = "DAC Registers[125:0]",
                            offset       =  0x00,
                            bitSize      =  16,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            number       =  126,
                            stride       =  4,
                        )

        self.addVariable(   name         = "LaneBufferDelay",
                            description  = "Lane Buffer Delay",
                            offset       =  0x1C,
                            bitSize      =  5,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "Temperature",
                            description  = "Temperature",
                            offset       =  0x1D,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariables(  name         = "LinkErrCnt",
                            description  = "Link Error Count",
                            offset       =  0x104,
                            bitSize      =  16,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "ReadFifoEmpty",
                            description  = "ReadFifoEmpty",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "ReadFifoUnderflow",
                            description  = "ReadFifoUnderflow",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  0x01,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "ReadFifoFull",
                            description  = "ReadFifoFull",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  0x02,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "ReadFifoOverflow",
                            description  = "ReadFifoOverflow",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  0x03,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "DispErr",
                            description  = "DispErr",
                            offset       =  0x191,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "NotitableErr",
                            description  = "NotitableErr",
                            offset       =  0x191,
                            bitSize      =  1,
                            bitOffset    =  0x01,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "CodeSyncErr",
                            description  = "CodeSyncErr",
                            offset       =  0x191,
                            bitSize      =  1,
                            bitOffset    =  0x02,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "FirstDataMatchErr",
                            description  = "FirstDataMatchErr",
                            offset       =  0x191,
                            bitSize      =  1,
                            bitOffset    =  0x03,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "ElasticBuffOverflow",
                            description  = "ElasticBuffOverflow",
                            offset       =  0x191,
                            bitSize      =  1,
                            bitOffset    =  0x04,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "LinkConfigErr",
                            description  = "LinkConfigErr",
                            offset       =  0x191,
                            bitSize      =  1,
                            bitOffset    =  0x05,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "FrameAlignErr",
                            description  = "FrameAlignErr",
                            offset       =  0x191,
                            bitSize      =  1,
                            bitOffset    =  0x06,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "MultiFrameAlignErr",
                            description  = "MultiFrameAlignErr",
                            offset       =  0x191,
                            bitSize      =  1,
                            bitOffset    =  0x07,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariable(   name         = "Serdes1pllAlarm",
                            description  = "Serdes1pllAlarm",
                            offset       =  0x1B0,
                            bitSize      =  1,
                            bitOffset    =  0x02,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "Serdes0pllAlarm",
                            description  = "Serdes0pllAlarm",
                            offset       =  0x1B0,
                            bitSize      =  1,
                            bitOffset    =  0x03,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "SysRefAlarms",
                            description  = "SysRefAlarms",
                            offset       =  0x1B1,
                            bitSize      =  4,
                            bitOffset    =  0x04,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "LaneLoss",
                            description  = "LaneLoss",
                            offset       =  0x1B4,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "LaneAlarm",
                            description  = "LaneAlarm",
                            offset       =  0x1B5,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "ID",
                            description  = "Serials and IDs",
                            offset       =  0x1FC,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "EnableTx",
                            description  = "EnableTx",
                            offset       =  0x0C,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "InitJesd",
                            description  = "InitJesd",
                            offset       =  0x128,
                            bitSize      =  5,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        ##############################
        # Commands
        ##############################

        self.addCommand(    name         = "ClearAlarms",
                            description  = "Clear all the DAC alarms",
                            function     = """\
                                           self.DacReg[100].set(0)
                                           self.DacReg[101].set(0)
                                           self.DacReg[102].set(0)
                                           self.DacReg[103].set(0)
                                           self.DacReg[104].set(0)
                                           self.DacReg[105].set(0)
                                           self.DacReg[106].set(0)
                                           self.DacReg[107].set(0)
                                           self.DacReg[108].set(0)
                                           """
                        )

        self.addCommand(    name         = "InitDac",
                            description  = "Initialization sequence for the DAC JESD core",
                            function     = """\
                                           self.EnableTx.set(0)
                                           self.InitJesd.set(30)
                                           self.InitJesd.set(1)
                                           self.EnableTx.set(1)
                                           """
                        )

