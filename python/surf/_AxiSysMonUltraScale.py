#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185 and UG580)
#-----------------------------------------------------------------------------
# File       : AxiSysMonUltraScale.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185 and UG580)
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

class AxiSysMonUltraScale(pr.Device):
    def __init__(self, name="AxiSysMonUltraScale", description="AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185 and UG580)", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "SR",
                                description  = "Status Register",
                                offset       =  0x04,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "AOSR",
                                description  = "Alarm Output Status Register",
                                offset       =  0x08,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "CONVSTR",
                                description  = "CONVST Register",
                                offset       =  0x0C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "WO",
                            ))

        self.add(pr.Variable(   name         = "SYSMONRR",
                                description  = "SYSMON Hard Macro Reset Register",
                                offset       =  0x10,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "WO",
                            ))

        self.add(pr.Variable(   name         = "GIER",
                                description  = "Global Interrupt Enable Register",
                                offset       =  0x5C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "IPISR",
                                description  = "IP Interrupt Status Register",
                                offset       =  0x60,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "IPIER",
                                description  = "IP Interrupt Enable Register",
                                offset       =  0x68,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "Temperature",
                                description  = "Temperature's ADC value",
                                offset       =  0x400,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "VCCINT",
                                description  = "VCCINT's ADC value",
                                offset       =  0x404,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "VCCAUX",
                                description  = "VCCAUX's ADC value",
                                offset       =  0x408,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "VP_VN",
                                description  = "VP/VN's ADC value",
                                offset       =  0x40C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "VREFP",
                                description  = "VREFP's ADC value",
                                offset       =  0x410,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "VREFN",
                                description  = "VREFN's ADC value",
                                offset       =  0x414,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "VBRAM",
                                description  = "VBRAM's ADC value",
                                offset       =  0x418,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "SupplyOffset",
                                description  = "Supply Offset",
                                offset       =  0x420,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ADCOffset",
                                description  = "ADC Offset",
                                offset       =  0x424,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "GainError",
                                description  = "Gain Error",
                                offset       =  0x428,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        for i in range(16):
            self.add(pr.Variable(   name         = "VAUXP_VAUXN_%.*i" % (2, i),
                                    description  = "VAUXP_VAUXN's ADC values",
                                    offset       =  0x440 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        self.add(pr.Variable(   name         = "MaxTemp",
                                description  = "maximum temperature measurement",
                                offset       =  0x480,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "MaxVCCINT",
                                description  = "maximum VCCINT measurement",
                                offset       =  0x484,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "MaxVCCAUX",
                                description  = "maximum VCCAUX measurement",
                                offset       =  0x488,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "MaxVBRAM",
                                description  = "maximum VBRAM measurement",
                                offset       =  0x48C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "MinTemp",
                                description  = "minimum temperature measurement",
                                offset       =  0x490,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "MinVCCINT",
                                description  = "minimum VCCINT measurement",
                                offset       =  0x494,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "MinVCCAUX",
                                description  = "minimum VCCAUX measurement",
                                offset       =  0x498,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "MinVBRAM",
                                description  = "minimum VBRAM measurement",
                                offset       =  0x49C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "I2C_Address",
                                description  = "I2C Address",
                                offset       =  0x4E0,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "FlagRegister",
                                description  = "Flag Register",
                                offset       =  0x4FC,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        for i in range(4):
            self.add(pr.Variable(   name         = "ConfigurationRegister_%i" % (i),
                                    description  = "Configuration Registers",
                                    offset       =  0x500 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        self.add(pr.Variable(   name         = "SequenceRegister8",
                                description  = "Sequence Register 8",
                                offset       =  0x518,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "SequenceReg9",
                                description  = "Sequence Register 9",
                                offset       =  0x51C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        for i in range(8):
            self.add(pr.Variable(   name         = "SequenceReg_7_0_%i" % (i),
                                    description  = "Sequence Register [7:0]",
                                    offset       =  0x520 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        for i in range(9):
            self.add(pr.Variable(   name         = "AlarmThresholdReg_8_0_%i" % (i),
                                    description  = "Alarm Threshold Register [8:0]",
                                    offset       =  0x540 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        self.add(pr.Variable(   name         = "AlarmThresholdReg12",
                                description  = "Alarm Threshold Register 12",
                                offset       =  0x570,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "AlarmThresholdReg16",
                                description  = "Alarm Threshold Register 16",
                                offset       =  0x580,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        for i in range(8):
            self.add(pr.Variable(   name         = "AlarmThresholdReg_25_16_%i" % (i),
                                    description  = "Alarm Threshold Register [25:16]",
                                    offset       =  0x580 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "VUSER_%i" % (i),
                                    description  = "VUSER[4:0] supply monitor measurement",
                                    offset       =  0x600 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "MAX_VUSER_%i" % (i),
                                    description  = "Maximum VUSER[4:0] supply monitor measurement",
                                    offset       =  0x680 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "MIN_VUSER_%i" % (i),
                                    description  = "Minimum VUSER[4:0] supply monitor measurement",
                                    offset       =  0x6A0 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

