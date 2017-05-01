#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue SsiPrbsRateGen
#-----------------------------------------------------------------------------
# File       : SsiPrbsRateGen.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue SsiPrbsTx
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

class SsiPrbsTx(pr.Device):
    def __init__(   self,       
                    name        = "SsiPrbsRateGen",
                    description = "SsiPrbsRateGen",
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, )

        ##############################
        # Variables
        ##############################

        self.Command (      name         = "StatReset",
                            description  = "",
                            offset       =  0x00,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "WO",
                            function     = pr.Command.toggle
                        )

        self.addVariable(   name         = "PacketLength",
                            description  = "",
                            offset       =  0x04,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "Period",
                            description  = "",
                            offset       =  0x08,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "TxEn",
                            description  = "",
                            offset       =  0x0C,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.Command (      name         = "OneShot",
                            description  = "",
                            offset       =  0x0C,
                            bitSize      =  1,
                            bitOffset    =  0x01,
                            base         = "hex",
                            mode         = "WO",
                            function     = pr.Command.toggle
                        )

        self.addVariable(   name         = "Missed",
                            description  = "",
                            offset       =  0x10,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "FrameRate",
                            description  = "",
                            offset       =  0x14,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "FrameRateMax",
                            description  = "",
                            offset       =  0x18,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "FrameRateMin",
                            description  = "",
                            offset       =  0x1C,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "Bandewidth",
                            description  = "",
                            offset       =  0x20,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "BandewidthMax",
                            description  = "",
                            offset       =  0x24,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "BandwidthMin",
                            description  = "",
                            offset       =  0x28,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "BackPressureCnt",
                            description  = "",
                            offset       =  0x30,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "BackPressureTrans",
                            description  = "",
                            offset       =  0x34,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "int",
                            mode         = "RW",
                        )

