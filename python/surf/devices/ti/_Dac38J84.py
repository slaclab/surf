#-----------------------------------------------------------------------------
# Title      : PyRogue DAC38J84 Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue DAC38J84 Module
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import time

class Dac38J84(pr.Device):
    def __init__(self,
                 numTxLanes  =  2,
                 debug       =  True,
                 **kwargs):

        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.addRemoteVariables(
            name         = "DacReg",
            description  = "DAC Registers[125:0]",
            offset       = 0x00,
            bitSize      = 16,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       = 126,
            stride       = 4,
            hidden       = not(debug),
            verify       = False, # DO NOT Verify all registers by default
            overlapEn    = True,
        )

        # Do verify the READ-WRITE registers
        for i in range(0, 7):
            self.DacReg[i]._verify = True
        for i in range(12, 26):
            self.DacReg[i]._verify = True
        for i in range(34, 39):
            self.DacReg[i]._verify = True
        for i in range(50, 53):
            self.DacReg[i]._verify = True
        for i in range(59, 64):
            self.DacReg[i]._verify = True
        for i in range(95, 98):
            self.DacReg[i]._verify = True

        self.add(pr.RemoteVariable(
            name         = "LaneBufferDelay",
            description  = "Lane Buffer Delay",
            offset       =  0x1C,
            bitSize      =  5,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "Temperature",
            description  = "Temperature",
            offset       =  0x1C,
            bitSize      =  8,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.addRemoteVariables(
            name         = "LinkErrCnt",
            description  = "Link Error Count",
            offset       =  0x104,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "ReadFifoEmpty",
            description  = "ReadFifoEmpty",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "ReadFifoUnderflow",
            description  = "ReadFifoUnderflow",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "ReadFifoFull",
            description  = "ReadFifoFull",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "ReadFifoOverflow",
            description  = "ReadFifoOverflow",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "DispErr",
            description  = "DispErr",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "NotitableErr",
            description  = "NotitableErr",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  9,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "CodeSyncErr",
            description  = "CodeSyncErr",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "FirstDataMatchErr",
            description  = "FirstDataMatchErr",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "ElasticBuffOverflow",
            description  = "ElasticBuffOverflow",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "LinkConfigErr",
            description  = "LinkConfigErr",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "FrameAlignErr",
            description  = "FrameAlignErr",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(
            name         = "MultiFrameAlignErr",
            description  = "MultiFrameAlignErr",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numTxLanes,
            stride       =  4,
            overlapEn    = True,
        )

        self.add(pr.RemoteVariable(
            name         = "Serdes1pllAlarm",
            description  = "Serdes1pllAlarm",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "Serdes0pllAlarm",
            description  = "Serdes0pllAlarm",
            offset       =  0x1B0,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "SysRefAlarms",
            description  = "SysRefAlarms",
            offset       =  0x1B0,
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "LaneLoss",
            description  = "LaneLoss",
            offset       =  0x1B4,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "LaneAlarm",
            description  = "LaneAlarm",
            offset       =  0x1B4,
            bitSize      =  8,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "VendorId",
            description  = "Vendor ID",
            offset       =  0x1FC,
            bitSize      =  2,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "VersionId",
            description  = "Version ID",
            offset       =  0x1FC,
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "EnableTx",
            description  = "EnableTx",
            offset       =  0x0C,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "InitJesd",
            description  = "InitJesd",
            offset       =  0x128,
            bitSize      =  4,
            bitOffset    =  0x01,
            base         = pr.UInt,
            mode         = "RW",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "JesdRstN",
            description  = "JesdRstN",
            offset       =  0x128,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            overlapEn    = True,
        ))

        ##############################
        # Commands
        ##############################
        @self.command(name="ClearAlarms", description="Clear all the DAC alarms",)
        def ClearAlarms():
            self.DacReg[100].set(0)
            self.DacReg[101].set(0)
            self.DacReg[102].set(0)
            self.DacReg[103].set(0)
            self.DacReg[104].set(0)
            self.DacReg[105].set(0)
            self.DacReg[106].set(0)
            self.DacReg[107].set(0)
            self.DacReg[108].set(0)
            self.DacReg[109].set(0)

        @self.command(name="Init", description="Initialization sequence for the DAC JESD core",)
        def Init():
            self.writeBlocks(force=True)
            self.EnableTx.set(0)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.ClearAlarms()
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[59].set( self.DacReg[59].value() )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[37].set( self.DacReg[37].value() )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[60].set( self.DacReg[60].value() | 0x0200 )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[60].set( self.DacReg[60].value() & 0xFDFF )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[62].set( self.DacReg[62].value() )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[76].set( self.DacReg[76].value() )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[77].set( self.DacReg[77].value() )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[75].set( self.DacReg[75].value() )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[77].set( self.DacReg[77].value() )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[78].set( self.DacReg[78].value() )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[0].set(  self.DacReg[0].value()  )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[74].set( (self.DacReg[74].value() & 0xFFE0) | 0x1E )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[74].set( (self.DacReg[74].value() & 0xFFE0) | 0x1E )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[74].set( (self.DacReg[74].value() & 0xFFE0) | 0x1F )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.DacReg[74].set( (self.DacReg[74].value() & 0xFFE0) | 0x01 )
            time.sleep(0.010) # TODO: Optimize this timeout
            self.EnableTx.set(1)
            time.sleep(0.010) # TODO: Optimize this timeout
