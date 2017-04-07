#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue LMK04828 Module
#-----------------------------------------------------------------------------
# File       : Lmk04828.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue LMK04828 Module
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

class Lmk04828(pr.Device):
    def __init__(self, name="Lmk04828", description="LMK04828 Module", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "LmkReg_0x0100",
                                description  = "LMK Registers",
                                offset       =  0x400,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0101",
                                description  = "LMK Registers",
                                offset       =  0x404,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0103",
                                description  = "LMK Registers",
                                offset       =  0x40C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0104",
                                description  = "LMK Registers",
                                offset       =  0x410,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0105",
                                description  = "LMK Registers",
                                offset       =  0x414,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0106",
                                description  = "LMK Registers",
                                offset       =  0x418,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0107",
                                description  = "LMK Registers",
                                offset       =  0x41C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0108",
                                description  = "LMK Registers",
                                offset       =  0x420,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0109",
                                description  = "LMK Registers",
                                offset       =  0x424,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x010B",
                                description  = "LMK Registers",
                                offset       =  0x42C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x010C",
                                description  = "LMK Registers",
                                offset       =  0x430,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x010D",
                                description  = "LMK Registers",
                                offset       =  0x434,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x010E",
                                description  = "LMK Registers",
                                offset       =  0x438,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x010F",
                                description  = "LMK Registers",
                                offset       =  0x43C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0110",
                                description  = "LMK Registers",
                                offset       =  0x440,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0111",
                                description  = "LMK Registers",
                                offset       =  0x444,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0113",
                                description  = "LMK Registers",
                                offset       =  0x44C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0114",
                                description  = "LMK Registers",
                                offset       =  0x450,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0115",
                                description  = "LMK Registers",
                                offset       =  0x454,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0116",
                                description  = "LMK Registers",
                                offset       =  0x458,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0117",
                                description  = "LMK Registers",
                                offset       =  0x45C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0118",
                                description  = "LMK Registers",
                                offset       =  0x460,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0119",
                                description  = "LMK Registers",
                                offset       =  0x464,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x011B",
                                description  = "LMK Registers",
                                offset       =  0x46C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x011C",
                                description  = "LMK Registers",
                                offset       =  0x470,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x011D",
                                description  = "LMK Registers",
                                offset       =  0x474,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x011E",
                                description  = "LMK Registers",
                                offset       =  0x478,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x011F",
                                description  = "LMK Registers",
                                offset       =  0x47C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0120",
                                description  = "LMK Registers",
                                offset       =  0x480,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0121",
                                description  = "LMK Registers",
                                offset       =  0x484,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0123",
                                description  = "LMK Registers",
                                offset       =  0x48C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0124",
                                description  = "LMK Registers",
                                offset       =  0x490,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0125",
                                description  = "LMK Registers",
                                offset       =  0x494,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0126",
                                description  = "LMK Registers",
                                offset       =  0x498,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0127",
                                description  = "LMK Registers",
                                offset       =  0x49C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0128",
                                description  = "LMK Registers",
                                offset       =  0x4A0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0129",
                                description  = "LMK Registers",
                                offset       =  0x4A4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x012B",
                                description  = "LMK Registers",
                                offset       =  0x4AC,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x012C",
                                description  = "LMK Registers",
                                offset       =  0x4B0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x012D",
                                description  = "LMK Registers",
                                offset       =  0x4B4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x012E",
                                description  = "LMK Registers",
                                offset       =  0x4B8,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x012F",
                                description  = "LMK Registers",
                                offset       =  0x4BC,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0130",
                                description  = "LMK Registers",
                                offset       =  0x4C0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0131",
                                description  = "LMK Registers",
                                offset       =  0x4C4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0133",
                                description  = "LMK Registers",
                                offset       =  0x4CC,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0134",
                                description  = "LMK Registers",
                                offset       =  0x4D0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0135",
                                description  = "LMK Registers",
                                offset       =  0x4D4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0136",
                                description  = "LMK Registers",
                                offset       =  0x4D8,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0137",
                                description  = "LMK Registers",
                                offset       =  0x4DC,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0138",
                                description  = "LMK Registers",
                                offset       =  0x4E0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0139",
                                description  = "LMK Registers",
                                offset       =  0x4E4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x013A",
                                description  = "LMK Registers",
                                offset       =  0x4E8,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x013B",
                                description  = "LMK Registers",
                                offset       =  0x4EC,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x013C",
                                description  = "LMK Registers",
                                offset       =  0x4F0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x013D",
                                description  = "LMK Registers",
                                offset       =  0x4F4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x013E",
                                description  = "LMK Registers",
                                offset       =  0x4F8,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x013F",
                                description  = "LMK Registers",
                                offset       =  0x4FC,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0140",
                                description  = "LMK Registers",
                                offset       =  0x500,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0141",
                                description  = "LMK Registers",
                                offset       =  0x504,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0142",
                                description  = "LMK Registers",
                                offset       =  0x508,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0143",
                                description  = "LMK Registers",
                                offset       =  0x50C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0144",
                                description  = "LMK Registers",
                                offset       =  0x510,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0145",
                                description  = "LMK Registers",
                                offset       =  0x514,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0146",
                                description  = "LMK Registers",
                                offset       =  0x518,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0147",
                                description  = "LMK Registers",
                                offset       =  0x51C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0148",
                                description  = "LMK Registers",
                                offset       =  0x520,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0149",
                                description  = "LMK Registers",
                                offset       =  0x524,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x014A",
                                description  = "LMK Registers",
                                offset       =  0x528,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x014B",
                                description  = "LMK Registers",
                                offset       =  0x52C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x014C",
                                description  = "LMK Registers",
                                offset       =  0x530,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x014D",
                                description  = "LMK Registers",
                                offset       =  0x534,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x014E",
                                description  = "LMK Registers",
                                offset       =  0x538,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x014F",
                                description  = "LMK Registers",
                                offset       =  0x53C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0150",
                                description  = "LMK Registers",
                                offset       =  0x540,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0151",
                                description  = "LMK Registers",
                                offset       =  0x544,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0152",
                                description  = "LMK Registers",
                                offset       =  0x548,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0153",
                                description  = "LMK Registers",
                                offset       =  0x54C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0154",
                                description  = "LMK Registers",
                                offset       =  0x550,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0155",
                                description  = "LMK Registers",
                                offset       =  0x554,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0156",
                                description  = "LMK Registers",
                                offset       =  0x558,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0157",
                                description  = "LMK Registers",
                                offset       =  0x55C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0158",
                                description  = "LMK Registers",
                                offset       =  0x560,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0159",
                                description  = "LMK Registers",
                                offset       =  0x564,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x015A",
                                description  = "LMK Registers",
                                offset       =  0x568,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x015B",
                                description  = "LMK Registers",
                                offset       =  0x56C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x015C",
                                description  = "LMK Registers",
                                offset       =  0x570,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x015D",
                                description  = "LMK Registers",
                                offset       =  0x574,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x015E",
                                description  = "LMK Registers",
                                offset       =  0x578,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x015F",
                                description  = "LMK Registers",
                                offset       =  0x57C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0160",
                                description  = "LMK Registers",
                                offset       =  0x580,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0161",
                                description  = "LMK Registers",
                                offset       =  0x584,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0162",
                                description  = "LMK Registers",
                                offset       =  0x588,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0163",
                                description  = "LMK Registers",
                                offset       =  0x58C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0164",
                                description  = "LMK Registers",
                                offset       =  0x590,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0165",
                                description  = "LMK Registers",
                                offset       =  0x594,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0166",
                                description  = "LMK Registers",
                                offset       =  0x598,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0167",
                                description  = "LMK Registers",
                                offset       =  0x59C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0168",
                                description  = "LMK Registers",
                                offset       =  0x5A0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0169",
                                description  = "LMK Registers",
                                offset       =  0x5A4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x016A",
                                description  = "LMK Registers",
                                offset       =  0x5A8,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "SyncBit",
                                description  = "SyncBit",
                                offset       =  0x50C,
                                bitSize      =  1,
                                bitOffset    =  0x05,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "EnableSync",
                                description  = "EnableSync",
                                offset       =  0x510,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "EnableSysRef",
                                description  = "EnableSysRef",
                                offset       =  0x4E4,
                                bitSize      =  2,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "ID_VNDR_LOWER",
                                description  = "ID_VNDR_LOWER",
                                offset       =  0x34,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ID_VNDR_UPPER",
                                description  = "ID_VNDR_UPPER",
                                offset       =  0x30,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ID_MASKREV",
                                description  = "ID_MASKREV",
                                offset       =  0x18,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ID_PROD_LOWER",
                                description  = "ID_PROD_LOWER",
                                offset       =  0x14,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ID_PROD_UPPER",
                                description  = "ID_PROD_UPPER",
                                offset       =  0x10,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ID_DEVICE_TYPE",
                                description  = "ID_DEVICE_TYPE",
                                offset       =  0x0C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x017D",
                                description  = "LMK Registers",
                                offset       =  0x5F4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x017C",
                                description  = "LMK Registers",
                                offset       =  0x5F0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0174",
                                description  = "LMK Registers",
                                offset       =  0x5D0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x0173",
                                description  = "LMK Registers",
                                offset       =  0x5CC,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x016E",
                                description  = "LMK Registers",
                                offset       =  0x5B8,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x016D",
                                description  = "LMK Registers",
                                offset       =  0x5B4,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x016C",
                                description  = "LMK Registers",
                                offset       =  0x5B0,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LmkReg_0x016B",
                                description  = "LMK Registers",
                                offset       =  0x5AC,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        ##############################
        # Commands
        ##############################

        self.add(pr.Command (   name         = "PwrDwnSysRef",
                                description  = "Powerdown the sysref lines",
                                function     = """\
                                               self.EnableSysRef.set(0)
                                               """
                            ))

        self.add(pr.Command (   name         = "PwrUpSysRef",
                                description  = "Powerup the sysref lines",
                                function     = """\
                                               self.EnableSysRef.set(3)
                                               """
                            ))

        self.add(pr.Command (   name         = "InitLmk",
                                description  = "Synchronise LMK internal counters. Warning this function will power off and power on all the system clocks",
                                function     = """\
                                               self.EnableSysRef.set(0)
                                               self.EnableSync.set(0)
                                               self.usleep.set(1000000)
                                               self.SyncBit.set(1)
                                               self.SyncBit.set(0)
                                               self.usleep.set(1000000)
                                               self.EnableSysRef.set(3)
                                               self.EnableSync.set(255)
                                               """
                            ))

