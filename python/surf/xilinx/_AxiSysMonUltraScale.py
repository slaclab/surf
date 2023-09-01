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

class AxiSysMonUltraScale(pr.Device):
    def __init__(
            self,
            description    = "AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185)",
            XIL_DEVICE_G   = "ULTRASCALE",
            simpleViewList = None,
            pollInterval   = 5,
            **kwargs):
        super().__init__(description=description, **kwargs)

        self.simpleViewList = simpleViewList

        def addPair(name, offset, bitSize, units, bitOffset, description, function, pollInterval=0):
            self.add(pr.RemoteVariable(
                name         = ("Raw"+name),
                offset       = offset,
                bitSize      = bitSize,
                bitOffset    = bitOffset,
                mode         = 'RO',
                description  = description,
                pollInterval = pollInterval,
                hidden       = True,
            ))
            self.add(pr.LinkVariable(
                name         = name,
                mode         = 'RO',
                units        = units,
                linkedGet    = function,
                typeStr      = "Float32",
                dependencies = [self.variables["Raw"+name]],
            ))

        if XIL_DEVICE_G == "ULTRASCALE":
            self.convTemp = self.convTempSYSMONE1
            self.convSetTemp = self.convSetTempSYSMONE1
        elif XIL_DEVICE_G == "ULTRASCALE_PLUS":
            self.convTemp = self.convTempSYSMONE4
            self.convSetTemp = self.convSetTempSYSMONE4
        else:
            raise Exception('AxiSysMonUltraScale: Device {} not supported'.format(XIL_DEVICE_G))

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "SR",
            description  = "Status Register",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "AOSR",
            description  = "Alarm Output Status Register",
            offset       =  0x08,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "CONVSTR",
            description  = "CONVST Register",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "WO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "SYSMONRR",
            description  = "SYSMON Hard Macro Reset Register",
            offset       =  0x10,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "WO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "GIER",
            description  = "Global Interrupt Enable Register",
            offset       =  0x5C,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "IPISR",
            description  = "IP Interrupt Status Register",
            offset       =  0x60,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "IPIER",
            description  = "IP Interrupt Enable Register",
            offset       =  0x68,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            hidden       =  True,
        ))

        ###############################################

        addPair(
            name         = 'Temperature',
            offset       = 0x400,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "degC",
            function     = self.convTemp,
            pollInterval = pollInterval,
            description  = "Temperature's ADC value",
        )

        addPair(
            name         = 'VccInt',
            offset       = 0x404,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "VCCINT's ADC value",
        )

        addPair(
            name         = 'VccAux',
            offset       = 0x408,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "VCCAUX's ADC value",
        )

        addPair(
            name         = 'VpVn',
            offset       = 0x40C,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convAuxVoltage,
            pollInterval = pollInterval,
            description  = "VP/VN's ADC value",
        )

        addPair(
            name         = 'Vrefp',
            offset       = 0x410,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "VREFP's ADC value",
        )

        addPair(
            name         = 'Vrefn',
            offset       = 0x414,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "VREFN's ADC value",
        )

        addPair(
            name        = 'VccBram',
            offset      = 0x418,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "VBRAM's ADC value",
        )

        addPair(
            name        = 'SupplyOffset',
            offset      = 0x420,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "Supply Offset",
        )

        addPair(
            name        = 'AdcOffset',
            offset      = 0x424,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "ADC Offset",
        )

        addPair(
            name        = 'GainError',
            offset      = 0x428,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "",
            function    = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "Gain Offset",
        )

        for i in range(16):
            addPair(
                name         = f'VauxpVauxn[{i}]',
                offset       = 0x440+(4*i),
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convAuxVoltage,
                pollInterval = pollInterval,
                description  = "VAUXP_VAUXN's ADC values",
            )

        addPair(
            name         = 'MaxTemperature',
            offset       = 0x480,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "degC",
            function     = self.convTemp,
            pollInterval = pollInterval,
            description  = "maximum temperature measurement",
        )

        addPair(
            name         = 'MaxVccInt',
            offset       = 0x484,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "maximum VCCINT measurement",
        )

        addPair(
            name         = 'MaxVccAux',
            offset       = 0x488,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "maximum VCCAUX measurement",
        )

        addPair(
            name         = 'MaxVccBram',
            offset       = 0x48C,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "maximum VBRAM measurement",
        )

        addPair(
            name         = 'MinTemperature',
            offset       = 0x490,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "degC",
            function     = self.convTemp,
            pollInterval = pollInterval,
            description  = "minimum temperature measurement",
        )

        addPair(
            name         = 'MinVccInt',
            offset       = 0x494,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "minimum VCCINT measurement",
        )

        addPair(
            name         = 'MinVccAux',
            offset       = 0x498,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "minimum VCCAUX measurement",
        )

        addPair(
            name         = 'MinVccBram',
            offset       = 0x49C,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = "minimum VBRAM measurement",
        )

        self.add(pr.RemoteVariable(
            name         = "I2cAddress",
            description  = "I2C Address",
            offset       =  0x4E0,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "FlagRegister",
            description  = "Flag Register",
            offset       =  0x4FC,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RO",
            hidden       =  True,
        ))

#        self.addRemoteVariables(
#            name         = "Configuration",
#            description  = "Configuration Registers",
#            offset       =  0x500,
#            bitSize      =  32,
#            bitOffset    =  0x00,
#            mode         = "RW",
#            number       =  4,
#            stride       =  4,
#            hidden       =  True,
#        )

        self.add(pr.RemoteVariable(
            name         = "SequenceReg8",
            description  = "Sequence Register 8",
            offset       =  0x518,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "SequenceReg9",
            description  = "Sequence Register 9",
            offset       =  0x51C,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            hidden       =  True,
        ))

        self.addRemoteVariables(
            name         = "SequenceReg_7_0",
            description  = "Sequence Register [7:0]",
            offset       =  0x520,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            number       =  8,
            stride       =  4,
            hidden       =  True,
        )

#        self.addRemoteVariables(
#            name         = "AlarmThresholdReg_8_0",
#            description  = "Alarm Threshold Register [8:0]",
#            offset       =  0x540,
#            bitSize      =  32,
#            bitOffset    =  0x00,
#            mode         = "RW",
#            number       =  9,
#            stride       =  4,
#            hidden       =  True,
#       )

        self.add(pr.RemoteVariable(
            name         = "OTThresholdDisable",
            description  = "Set 1 to disable OT threshold",
            offset       =  0x504,
            bitSize      =  1,
            bitOffset    =  0x0,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "OTAutomaticShutdown",
            description  = "OT_AUTOMATIC_SHUTDOWN, set to 0x3 to enable (defatul 125 degC)",
            offset       =  0x54C,
            bitSize      =  4,
            bitOffset    =  0x0,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "OTUpperThresholdRaw",
            description  = "UPPER_OT threshold",
            offset       =  0x54C,
            bitSize      =  12,
            bitOffset    =  0x4,
            mode         = "RW",
        ))

        self.add(pr.LinkVariable(
            name         = "OTUpperThreshold",
            mode         = 'RW',
            units        = 'degC',
            linkedGet    = self.convTemp,
            linkedSet    = self.convSetTemp,
            typeStr      = "Float32",
            dependencies = [self.variables["OTUpperThresholdRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name         = "OTLowerThresholdRaw",
            description  = "LOWER_OT threshold",
            offset       =  0x55C,
            bitSize      =  12,
            bitOffset    =  0x4,
            mode         = "RW",
        ))

        self.add(pr.LinkVariable(
            name         = "OTLowerThreshold",
            mode         = 'RW',
            units        = 'degC',
            linkedGet    = self.convTemp,
            linkedSet    = self.convSetTemp,
            typeStr      = "Float32",
            dependencies = [self.variables["OTLowerThresholdRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name         = "AlarmThresholdReg12",
            description  = "Alarm Threshold Register 12",
            offset       =  0x570,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            hidden       =  True,
        ))

        self.addRemoteVariables(
            name         = "AlarmThresholdReg_25_16",
            description  = "Alarm Threshold Register [25:16]",
            offset       =  0x580,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            number       =  8,
            stride       =  4,
            hidden       =  True,
        )

        self.addRemoteVariables(
            name         = "Vuser",
            description  = "VUSER[4:0] supply monitor measurement",
            offset       =  0x600,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        self.addRemoteVariables(
            name         = "MaxVuser",
            description  = "Maximum VUSER[4:0] supply monitor measurement",
            offset       =  0x680,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        self.addRemoteVariables(
            name         = "MinVuser",
            description  = "Minimum VUSER[4:0] supply monitor measurement",
            offset       =  0x6A0,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        # Default to simple view
        self.simpleView()


    @staticmethod
    def convTempSYSMONE1(dev, var):
        value   = var.dependencies[0].get(read=False)
        fpValue = value*(501.3743/4096.0)
        fpValue -= 273.6777
        return round(fpValue,3)

    @staticmethod
    def convSetTempSYSMONE1(dev, var, value):
        fpValue = (value + 273.6777)*(4096.0/501.3743)
        intValue = round(fpValue)
        var.dependencies[0].set(intValue, write=True)

    @staticmethod
    def convTempSYSMONE4(dev, var):
        value   = var.dependencies[0].get(read=False)
        fpValue = value*(509.3140064/4096.0)
        fpValue -= 280.23087870
        return round(fpValue,3)

    @staticmethod
    def convSetTempSYSMONE4(dev, var, value):
        fpValue = (value + 280.23087870)*(4096.0/509.3140064)
        intValue = round(fpValue)
        var.dependencies[0].set(intValue, write=True)

    @staticmethod
    def convCoreVoltage(var):
        value   = var.dependencies[0].value()
        fpValue = value*(732.0E-6)
        return round(fpValue,3)

    @staticmethod
    def convAuxVoltage(var):
        return round(var.dependencies[0].value() * 244e-6,3)

    def simpleView(self):
        if self.simpleViewList is not None:
            # Hide all the variable
            self.hideVariables(hidden=True)
            # Then unhide the most interesting ones
            vars = self.simpleViewList
            self.hideVariables(hidden=False, variables=vars)
