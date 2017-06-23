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
                    debug       =  True,
                    numTxLanes  =  2,
                    expand      =  True,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, expand=expand)

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
                            hidden       =  not(debug),   
                            verify       =  False,   
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
                            offset       =  0x1C,
                            bitSize      =  8,
                            bitOffset    =  8,
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
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  8,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "NotitableErr",
                            description  = "NotitableErr",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  9,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "CodeSyncErr",
                            description  = "CodeSyncErr",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  10,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "FirstDataMatchErr",
                            description  = "FirstDataMatchErr",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  11,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "ElasticBuffOverflow",
                            description  = "ElasticBuffOverflow",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  12,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "LinkConfigErr",
                            description  = "LinkConfigErr",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  13,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "FrameAlignErr",
                            description  = "FrameAlignErr",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  14,
                            base         = "hex",
                            mode         = "RO",
                            number       =  numTxLanes,
                            stride       =  4,
                        )

        self.addVariables(  name         = "MultiFrameAlignErr",
                            description  = "MultiFrameAlignErr",
                            offset       =  0x190,
                            bitSize      =  1,
                            bitOffset    =  15,
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
                            offset       =  0x1B0,
                            bitSize      =  4,
                            bitOffset    =  12,
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
                            offset       =  0x1B4,
                            bitSize      =  8,
                            bitOffset    =  8,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "VendorId",
                            description  = "Vendor ID",
                            offset       =  0x1FC,
                            bitSize      =  2,
                            bitOffset    =  3,
                            base         = "hex",
                            mode         = "RO",
                        )
                        
        self.addVariable(   name         = "VersionId",
                            description  = "Version ID",
                            offset       =  0x1FC,
                            bitSize      =  3,
                            bitOffset    =  0,
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
        def clearAlarms(dev, cmd, arg): 
            dev.DacReg[100].set(0)
            dev.DacReg[101].set(0)
            dev.DacReg[102].set(0)
            dev.DacReg[103].set(0)
            dev.DacReg[104].set(0)
            dev.DacReg[105].set(0)
            dev.DacReg[106].set(0)
            dev.DacReg[107].set(0)
            dev.DacReg[108].set(0)
        self.addCommand(    name         = "ClearAlarms",
                            description  = "Clear all the DAC alarms",
                            function     = clearAlarms
                        )

        def initDac(dev, cmd, arg):         
            dev.EnableTx.set(0)
            dev.InitJesd.set(30)
            dev.InitJesd.set(1)
            dev.EnableTx.set(1)     
            # clearAlarms
            dev.DacReg[100].set(0)
            dev.DacReg[101].set(0)
            dev.DacReg[102].set(0)
            dev.DacReg[103].set(0)
            dev.DacReg[104].set(0)
            dev.DacReg[105].set(0)
            dev.DacReg[106].set(0)
            dev.DacReg[107].set(0)
            dev.DacReg[108].set(0)
            # Perform a sif_sync
            sifSync = (dev.DacReg[31].get()) | 0x2
            dev.DacReg[31].set(sifSync)
            dev.DacReg[31].set(sifSync&0xFFFD)
            
        self.addCommand(    name         = "Init",
                            description  = "Initialization sequence for the DAC JESD core",
                            function     = initDac
                        )

