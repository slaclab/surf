#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue DAC38J84 Module
#-----------------------------------------------------------------------------
# File       : Dac38J84.py
# Created    : 2017-04-04
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
    def __init__(self, name="Dac38J84", description="DAC38J84 Module", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        for i in range(126):
            self.add(pr.Variable(   name         = "DacReg_%.*i" % (3, i),
                                    description  = "DAC Registers[125:0] %.*i" % (3, i),
                                    offset       =  0x00 + (i * 0x04),
                                    bitSize      =  16,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        self.add(pr.Variable(   name         = "LaneBufferDelay",
                                description  = "Lane Buffer Delay",
                                offset       =  0x1C,
                                bitSize      =  5,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "Temperature",
                                description  = "Temperature",
                                offset       =  0x1D,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        for i in range(2):
            self.add(pr.Variable(   name         = "LinkErrCnt_%i" % (i),
                                    description  = "Link Error Count",
                                    offset       =  0x104 + (i * 0x04),
                                    bitSize      =  16,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "ReadFifoEmpty_%i" % (i),
                                    description  = "ReadFifoEmpty",
                                    offset       =  0x190 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "ReadFifoUnderflow_%i" % (i),
                                    description  = "ReadFifoUnderflow",
                                    offset       =  0x190 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x01,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "ReadFifoFull_%i" % (i),
                                    description  = "ReadFifoFull",
                                    offset       =  0x190 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x02,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "ReadFifoOverflow_%i" % (i),
                                    description  = "ReadFifoOverflow",
                                    offset       =  0x190 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x03,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "DispErr_%i" % (i),
                                    description  = "DispErr",
                                    offset       =  0x191 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "NotitableErr_%i" % (i),
                                    description  = "NotitableErr",
                                    offset       =  0x191 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x01,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "CodeSyncErr_%i" % (i),
                                    description  = "CodeSyncErr",
                                    offset       =  0x191 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x02,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "FirstDataMatchErr_%i" % (i),
                                    description  = "FirstDataMatchErr",
                                    offset       =  0x191 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x03,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "ElasticBuffOverflow_%i" % (i),
                                    description  = "ElasticBuffOverflow",
                                    offset       =  0x191 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x04,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "LinkConfigErr_%i" % (i),
                                    description  = "LinkConfigErr",
                                    offset       =  0x191 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x05,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "FrameAlignErr_%i" % (i),
                                    description  = "FrameAlignErr",
                                    offset       =  0x191 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x06,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "MultiFrameAlignErr_%i" % (i),
                                    description  = "MultiFrameAlignErr",
                                    offset       =  0x191 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x07,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        self.add(pr.Variable(   name         = "Serdes1pllAlarm",
                                description  = "Serdes1pllAlarm",
                                offset       =  0x1B0,
                                bitSize      =  1,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "Serdes0pllAlarm",
                                description  = "Serdes0pllAlarm",
                                offset       =  0x1B0,
                                bitSize      =  1,
                                bitOffset    =  0x03,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "SysRefAlarms",
                                description  = "SysRefAlarms",
                                offset       =  0x1B1,
                                bitSize      =  4,
                                bitOffset    =  0x04,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "LaneLoss",
                                description  = "LaneLoss",
                                offset       =  0x1B4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "LaneAlarm",
                                description  = "LaneAlarm",
                                offset       =  0x1B5,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ID",
                                description  = "Serials and IDs",
                                offset       =  0x1FC,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "EnableTx",
                                description  = "EnableTx",
                                offset       =  0x0C,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "InitJesd",
                                description  = "InitJesd",
                                offset       =  0x128,
                                bitSize      =  5,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        ##############################
        # Commands
        ##############################

        self.add(pr.Command (   name         = "ClearAlarms",
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
                            ))

        self.add(pr.Command (   name         = "InitDac",
                                description  = "Initialization sequence for the DAC JESD core",
                                function     = """\
                                               self.EnableTx.set(0)
                                               self.InitJesd.set(30)
                                               self.InitJesd.set(1)
                                               self.EnableTx.set(1)
                                               """
                            ))

