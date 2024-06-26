#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiXadc
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiXadc
# Auto created from ../surf/xilinx/7Series/xadc/yaml/AxiXadc.yaml
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class Xadc(pr.Device):
    def __init__(self,
                 description = "AXI-Lite XADC for Xilinx 7 Series (Refer to PG091 & PG019)",
                 auxChannels = 0,
                 zynq        = False,
                 simpleViewList = ["Temperature", "VccInt", "VccAux", "VccBram"],
                 pollInterval = 5,
                 **kwargs):
        super().__init__(description=description, **kwargs)

        if isinstance(auxChannels, int):
            auxChannels = list(range(auxChannels))

        if simpleViewList is not None:
            self.simpleViewList = simpleViewList[:]
            self.simpleViewList.append('enable')

        def addPair(name, offset, bitSize, units, bitOffset, description, function, pollInterval=0):
            self.add(pr.RemoteVariable(
                name         = ("Raw"+name),
                offset       = offset,
                bitSize      = bitSize,
                bitOffset    = bitOffset,
                base         = pr.UInt,
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
                disp         = '{:1.3f}',
                dependencies = [self.variables["Raw"+name]],
            ))

        addPair(
            name         = 'Temperature',
            offset       = 0x200,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "degC",
            function     = self.convTemp,
            pollInterval = pollInterval,
            description  = """
                The result of the on-chip temperature sensor measurement is
                stored in this location. The data is MSB justified in the
                16-bit register (Read Only).  The 12 MSBs correspond to the
                temperature sensor transfer function shown in Figure 2-8,
                page 31 of UG480 (v1.2) """,
        )

        addPair(
            name        = 'MaxTemperature',
            offset      = 0x280,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "degC",
            function    = self.convTemp,
            description = """
                Maximum temperature measurement recorded since
                power-up or the last AxiXadc reset (Read Only).""",
        )

        addPair(
            name        = 'MinTemperature',
            offset      = 0x290,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "degC",
            function    = self.convTemp,
            description = """
                Minimum temperature measurement recorded since power-up
                or the last AxiXadc reset (Read Only).""",
        )

        self.add(pr.RemoteVariable(
            name        = 'OverTemperatureAlarm',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.Bool,
            mode        = 'RO',
            description = "Over Temperature Alarm Tripped",
        ))

        self.add(pr.RemoteVariable(
            name        = 'UserTemperatureAlarm',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RO',
            description = "Temperature Alarm Tripped",
        ))

        addPair(
            name        = 'VccInt',
            offset      = 0x204,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            pollInterval = pollInterval,
            description = """
                The result of the on-chip VccInt supply monitor measurement
                is stored at this location. The data is MSB justified in the
                16-bit register (Read Only). The 12 MSBs correspond to the
                supply sensor transfer function shown in Figure 2-9,
                page 32 of UG480 (v1.2)     """,
        )

        addPair(
            name        = 'MaxVccInt',
            offset      = 0x284,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Maximum VccInt measurement recorded since power-up
                or the last AxiXadc reset (Read Only).""")

        addPair(
            name        = 'MinVccInt',
            offset      = 0x294,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Minimum VccInt measurement recorded since power-up
                or the last AxiXadc reset (Read Only).""")

        self.add(pr.RemoteVariable(
            name        = 'VccIntAlarm',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.Bool,
            mode        = 'RO',
            description = "VccInt Alarm Tripped",
        ))

        addPair(
            name        = 'VccAux',
            offset      = 0x208,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            pollInterval = pollInterval,
            description = """
                The result of the on-chip VccAux supply monitor measurement
                is stored at this location. The data is MSB justified in the
                16-bit register (Read Only). The 12 MSBs correspond to the
                supply sensor transfer function shown in Figure 2-9,
                page 32 of UG480 (v1.2)""",
        )

        addPair(
            name        = 'MaxVccAux',
            offset      = 0x288,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Maximum VccAux measurement recorded since power-up
                or the last AxiXadc reset (Read Only).""",
        )

        addPair(
            name        = 'MinVccAux',
            offset      = 0x298,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Minimum VccAux measurement recorded since power-up
                or the last AxiXadc reset (Read Only).""",
        )

        self.add(pr.RemoteVariable(
            name        = 'VccAuxAlarm',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 2,
            base        = pr.Bool,
            mode        = 'RO',
            description = "VccAux Alarm Tripped",
        ))

        addPair(
            name        = 'VccBram',
            offset      = 0x218,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            pollInterval = pollInterval,
            description = """
                The result of the on-chip VccBram supply monitor measurement
                is stored at this location. The data is MSB justified in the
                16-bit register (Read Only). The 12 MSBs correspond to the
                supply sensor transfer function shown in Figure 2-9,
                page 32 of UG480 (v1.2)""",
        )

        addPair(
            name        = 'MaxVccBram',
            offset      = 0x28c,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Maximum VccBram measurement recorded since power-up
                or the last AxiXadc reset (Read Only).""",
        )

        addPair(
            name        = 'MinVccBram',
            offset      = 0x29c,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Minimum VccBram measurement recorded since power-up
                or the last AxiXadc reset (Read Only).""",
        )

        self.add(pr.RemoteVariable(
            name        = 'VccBramAlarm',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 4,
            base        = pr.Bool,
            mode        = 'RO',
            description = "VccBram Alarm Tripped",
        ))

        addPair(
            name        = 'Vin',
            offset      = 0x20c,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                The result of a conversion on the dedicated analog input
                channel is stored in this register. The data is MSB justified
                in the 16-bit register (Read Only). The 12 MSBs correspond to the
                transfer function shown in Figure 2-5, page 29 or
                Figure 2-6, page 29 of UG480 (v1.2) depending on analog input mode
                settings.""",
        )

        addPair(
            name        = 'Vrefp',
            offset      = 0x210,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                The result of a conversion on the reference input VrefP is
                stored in this register. The 12 MSBs correspond to the ADC
                transfer function shown in Figure 2-9  of UG480 (v1.2). The data is MSB
                justified in the 16-bit register (Read Only). The supply sensor is used
                when measuring VrefP.""",
        )

        addPair(
            name        = 'Vrefn',
            offset      = 0x214,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                The result of a conversion on the reference input VREFN is
                stored in this register (Read Only). This channel is measured in bipolar
                mode with a 2's complement output coding as shown in
                Figure 2-2, page 25. By measuring in bipolar mode, small
                positive and negative at: offset around 0V (VrefN) can be
                measured. The supply sensor is also used to measure
                VrefN, thus 1 LSB = 3V/4096. The data is MSB justified in
                the 16-bit register.      """,
        )

        for ch in auxChannels:
            self.add(pr.RemoteVariable(
                name         = f'AuxRaw[{ch}]',
                offset       =  0x240 + ch*4,
                bitSize      =  12,
                bitOffset    =  4,
                base         = pr.UInt,
                mode         = "RO",
                description = """
                The results of the conversions on auxiliary analog input
                channels are stored in this register. The data is MSB
                justified in the 16-bit register (Read Only). The 12 MSBs correspond to
                the transfer function shown in Figure 2-1, page 24 or
                Figure 2-2, page 25 of UG480 (v1.2) depending on analog input mode
                settings.""",
            ))

            self.add(pr.LinkVariable(
                name=f'Aux[{ch}]',
                units='V',
                disp='{:1.3f}',
                mode='RO',
                variable=self.AuxRaw[ch],
                linkedGet=self.convAuxVoltage))

            self.simpleViewList.append(f'Aux[{ch}]')

        if (zynq):
            addPair(
                name        = 'VccpInt',
                offset      = 0x234,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    The result of a conversion on the PS supply, VccpInt is
                    stored in this register. The 12 MSBs correspond to the ADC
                    transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is
                    MSB justified in the 16-bit register (Zynq Only and Read Only).
                    The supply sensor is used when measuring VccpInt.""",
            )

            addPair(
                name        = 'MaxVccpInt',
                offset      = 0x20,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Maximum VccpInt measurement recorded since power-up
                    or the last AxiXadc reset (Zynq Only and Read Only).""",
            )

            addPair(
                name        = 'MinVccpInt',
                offset      = 0x2b0,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Minimum VccpInt measurement recorded since power-up
                    or the last AxiXadc reset (Zynq Only and Read Only).""",
            )

            self.add(pr.RemoteVariable(
                name        = 'VccpIntAlarm',
                offset      = 0x2fc,
                bitSize     = 1,
                bitOffset   = 5,
                base        = pr.Bool,
                mode        = 'RO',
                description = "VccpInt Alarm Tripped",
            ))

            addPair(
                name        = 'VccpAux',
                offset      = 0x238,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    The result of a conversion on the PS supply, VccpAux is
                    stored in this register. The 12 MSBs correspond to the ADC
                    transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is
                    MSB justified in the 16-bit register (Zynq Only and Read Only).
                    The supply sensor is used when measuring VccpAux.""",
            )

            addPair(
                name        = 'MaxVccpAux',
                offset      = 0x2a4,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Maximum VccpAux measurement recorded since power-up
                    or the last AxiXadc reset (Zynq Only and Read Only).""",
            )

            addPair(
                name        = 'MinVccpAux',
                offset      = 0x2b4,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Minimum VccpAux measurement recorded since power-up
                    or the last AxiXadc reset (Zynq Only and Read Only).""",
            )

            self.add(pr.RemoteVariable(
                name        = 'VccpAuxAlarm',
                offset      = 0x2fc,
                bitSize     = 1,
                bitOffset   = 6,
                base        = pr.Bool,
                mode        = 'RO',
                description = "VccpAux Alarm Tripped",
            ))

            addPair(
                name        = 'VccpDdr',
                offset      = 0x23c,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    The result of a conversion on the PS supply, VccpDdr is
                    stored in this register. The 12 MSBs correspond to the ADC
                    transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is
                    MSB justified in the 16-bit register (Zynq Only and Read Only).
                    The supply sensor is used when measuring VccpDdr.""",
            )

            addPair(
                name        = 'MaxVccpDdr',
                offset      = 0x2a8,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Maximum VccpDdr measurement recorded since power-up
                    or the last AxiXadc reset (Zynq Only and Read Only).""",
            )

            addPair(
                name        = 'MinVccpDdr',
                offset      = 0x2b8,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Minimum VccpDdr measurement recorded since power-up
                    or the last AxiXadc reset (Zynq Only and Read Only).""",
            )

            self.add(pr.RemoteVariable(
                name        = 'VccpDdrAlarm',
                offset      = 0x2fc,
                bitSize     = 1,
                bitOffset   = 7,
                base        = pr.Bool,
                mode        = 'RO',
                description = "VccpDdr Alarm Tripped",
            ))

        self.add(pr.RemoteVariable(
            name        = 'SupplyOffsetA',
            offset      = 0x220,
            bitSize     = 12,
            bitOffset   = 4,
            base        = pr.UInt,
            mode        = 'RO',
            description = """
                The calibration coefficient for the supply sensor offset
                using ADC A is stored at this location (Read Only).""",
        ))

        self.add(pr.RemoteVariable(
            name        = 'AdcOffsetA',
            offset      = 0x224,
            bitSize     = 12,
            bitOffset   = 4,
            base        = pr.UInt,
            mode        = 'RO',
            description = """
                The calibration coefficient for the ADC A offset is stored at
                this location (Read Only).""",
        ))

        self.add(pr.RemoteVariable(
            name        = 'AdcGainA',
            offset      = 0x228,
            bitSize     = 12,
            bitOffset   = 4,
            base        = pr.UInt,
            mode        = 'RO',
            description = """
                The calibration coefficient for the ADC A gain error is
                stored at this location (Read Only).""",
        ))

        self.add(pr.RemoteVariable(
            name        = 'JTGD',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 11,
            base        = pr.Bool,
            mode        = 'RO',
            description = """
                A logic 1 indicates that the JTAG_AxiXadc BitGen option has
                been used to disable all JTAG access. See DRP JTAG Interface for more information.""",
        ))

        self.add(pr.RemoteVariable(
            name        = 'JTGR',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 10,
            base        = pr.Bool,
            mode        = 'RO',
            description = """
                A logic 1 indicates that the JTAG_AxiXadc BitGen option has
                been used to disable all JTAG access. See DRP JTAG Interface
                for more information.""",
        ))

        self.add(pr.RemoteVariable(
            name        = 'REF',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 9,
            base        = pr.UInt,
            mode        = 'RO',
            description = """
                When this bit is a logic 1, the ADC is using the internal
                voltage reference. When this bit is a logic 0, the external
                reference is being used.""",
        ))


        addPair(
            name         = 'OT_Limit',
            description  = '',
            offset       = 0x34c,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "degC",
            function     = self.convTemp,
        )

        # Default to simple view
        if simpleViewList is not None:
            self.simpleView()

    @staticmethod
    def convTemp(dev, var, read):
        value   = var.dependencies[0].get(read=read)
        fpValue = value*(503.975/4096.0)
        fpValue -= 273.15
        return (fpValue)

    @staticmethod
    def getTemp(var, read):
        value = var.depdendencies[0].get(read=read)
        fpValue = value*(503.975/4096.0)
        fpValue -= 273.15
        return (fpValue)

    @staticmethod
    def setTemp(var, value, write):
        ivalue = int((int(value) + 273.15)*(4096/503.975))
        var.depdendencies[0].set(ivalue, write=write)

    @staticmethod
    def convCoreVoltage(var, read):
        value   = var.dependencies[0].get(read=read)
        fpValue = value*(732.0E-6)
        return fpValue

    @staticmethod
    def convAuxVoltage(var, read):
        return var.dependencies[0].get(read=read) * 244e-6

    def simpleView(self):
        # Hide all the variable
        self.hideVariables(hidden=True)
        # Then unhide the most interesting ones
        vars = self.simpleViewList
        self.hideVariables(hidden=False, variables=vars)
