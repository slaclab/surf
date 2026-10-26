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


def _signExtend(code, bits):
    # Two's complement value of a bits-wide unsigned code
    if code & (1 << (bits - 1)):
        return code - (1 << bits)
    return code


def _tempFromCode(code):
    # UG480 Equation 2-6: temperature transfer function of the 12-bit code
    return code * (503.975/4096.0) - 273.15


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

        def addPair(name, offset, bitSize, units, bitOffset, description, function, pollInterval=0, disp='{:1.3f}', extraDependencies=()):
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
                description  = description,
                mode         = 'RO',
                units        = units,
                linkedGet    = function,
                disp         = disp,
                dependencies = [self.variables["Raw"+name]] + [self.variables[n] for n in extraDependencies],
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
                stored in this location (DRP 00h, Read Only). The data is MSB
                justified in the 16-bit register. The 12 MSBs correspond to the
                temperature sensor transfer function shown in Figure 2-9,
                page 25 of UG480 v1.11 (Equation 2-6).""",
        )

        addPair(
            name        = 'MaxTemperature',
            offset      = 0x280,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "degC",
            function    = self.convTemp,
            description = """
                Maximum temperature measurement recorded since power-up or
                the last XADC reset (DRP 20h, Read Only). The 12 MSBs follow
                the temperature sensor transfer function, Figure 2-9, page 25
                of UG480 v1.11.""",
        )

        addPair(
            name        = 'MinTemperature',
            offset      = 0x290,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "degC",
            function    = self.convTemp,
            description = """
                Minimum temperature measurement recorded since power-up or
                the last XADC reset (DRP 24h, Read Only). The 12 MSBs follow
                the temperature sensor transfer function, Figure 2-9, page 25
                of UG480 v1.11.""",
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
                The result of the on-chip VCCINT supply monitor measurement
                is stored at this location (DRP 01h, Read Only). The data is
                MSB justified in the 16-bit register. The 12 MSBs correspond
                to the supply sensor transfer function shown in Figure 2-10,
                page 26 of UG480 v1.11 (Equation 2-7, 1 LSB = 3V/4096).""",
        )

        addPair(
            name        = 'MaxVccInt',
            offset      = 0x284,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Maximum VCCINT measurement recorded since power-up or the
                last XADC reset (DRP 21h, Read Only). The 12 MSBs follow the
                supply sensor transfer function, Figure 2-10, page 26 of
                UG480 v1.11 (1 LSB = 3V/4096).""")

        addPair(
            name        = 'MinVccInt',
            offset      = 0x294,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Minimum VCCINT measurement recorded since power-up or the
                last XADC reset (DRP 25h, Read Only). The 12 MSBs follow the
                supply sensor transfer function, Figure 2-10, page 26 of
                UG480 v1.11 (1 LSB = 3V/4096).""")

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
                The result of the on-chip VCCAUX supply monitor measurement
                is stored at this location (DRP 02h, Read Only). The data is
                MSB justified in the 16-bit register. The 12 MSBs correspond
                to the supply sensor transfer function shown in Figure 2-10,
                page 26 of UG480 v1.11 (Equation 2-7, 1 LSB = 3V/4096).""",
        )

        addPair(
            name        = 'MaxVccAux',
            offset      = 0x288,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Maximum VCCAUX measurement recorded since power-up or the
                last XADC reset (DRP 22h, Read Only). The 12 MSBs follow the
                supply sensor transfer function, Figure 2-10, page 26 of
                UG480 v1.11 (1 LSB = 3V/4096).""",
        )

        addPair(
            name        = 'MinVccAux',
            offset      = 0x298,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Minimum VCCAUX measurement recorded since power-up or the
                last XADC reset (DRP 26h, Read Only). The 12 MSBs follow the
                supply sensor transfer function, Figure 2-10, page 26 of
                UG480 v1.11 (1 LSB = 3V/4096).""",
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
                The result of the on-chip VCCBRAM supply monitor measurement
                is stored at this location (DRP 06h, Read Only). The data is
                MSB justified in the 16-bit register. The 12 MSBs correspond
                to the supply sensor transfer function shown in Figure 2-10,
                page 26 of UG480 v1.11 (Equation 2-7, 1 LSB = 3V/4096).""",
        )

        addPair(
            name        = 'MaxVccBram',
            offset      = 0x28c,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Maximum VCCBRAM measurement recorded since power-up or the
                last XADC reset (DRP 23h, Read Only). The 12 MSBs follow the
                supply sensor transfer function, Figure 2-10, page 26 of
                UG480 v1.11 (1 LSB = 3V/4096).""",
        )

        addPair(
            name        = 'MinVccBram',
            offset      = 0x29c,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                Minimum VCCBRAM measurement recorded since power-up or the
                last XADC reset (DRP 27h, Read Only). The 12 MSBs follow the
                supply sensor transfer function, Figure 2-10, page 26 of
                UG480 v1.11 (1 LSB = 3V/4096).""",
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
            function    = self.convAuxVoltage,
            description = """
                The result of a conversion on the dedicated analog input
                channel VP/VN is stored in this register (DRP 03h, Read Only).
                The data is MSB justified in the 16-bit register. The 12 MSBs
                correspond to the transfer function shown in Figure 2-6,
                page 23 or Figure 2-7, page 23 of UG480 v1.11 depending on the
                analog input mode. The decode assumes unipolar input mode
                (0 V to 1 V, 1 LSB = 1V/4096); a bipolar setting yields two's
                complement codes that this decode does not handle.""",
        )

        addPair(
            name        = 'Vrefp',
            offset      = 0x210,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convCoreVoltage,
            description = """
                The result of a conversion on the reference input VREFP is
                stored in this register (DRP 04h, Read Only). The data is MSB
                justified in the 16-bit register. The supply sensor is used
                when measuring VREFP, so the 12 MSBs correspond to the supply
                sensor transfer function shown in Figure 2-10, page 26 of
                UG480 v1.11 (1 LSB = 3V/4096).""",
        )

        addPair(
            name        = 'Vrefn',
            offset      = 0x214,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "V",
            function    = self.convSignedCoreVoltage,
            description = """
                The result of a conversion on the reference input VREFN is
                stored in this register (DRP 05h, Read Only). This channel is
                measured in bipolar mode with a two's complement output coding
                as shown in Figure 2-3, page 19 of UG480 v1.11, so small
                positive and negative offsets around 0 V can be measured. The
                supply sensor is used, so 1 LSB = 3V/4096 and the decoded range
                is -1.5 V to +1.4993 V. The data is MSB justified in the 16-bit
                register.""",
        )

        for ch in auxChannels:
            self.add(pr.RemoteVariable(
                name        = f'AuxRaw[{ch}]',
                offset      =  0x240 + ch*4,
                bitSize     =  12,
                bitOffset   =  4,
                base        = pr.UInt,
                mode        = "RO",
                description = f'Raw 12-bit ADC code for auxiliary analog input channel {ch} (VAUXP[{ch}]/VAUXN[{ch}]), MSB justified (DRP {0x10+ch:02X}h, Read Only)',
            ))

            self.add(pr.LinkVariable(
                name=f'Aux[{ch}]',
                description=(f'Auxiliary analog input channel {ch} (VAUXP[{ch}]/VAUXN[{ch}]) voltage in volts, 1 LSB = 1V/4096. '
                         'Assumes unipolar input mode (0 V to 1 V, Figure 2-2, page 18 of UG480 v1.11); '
                         "a bipolar setting yields two's complement codes (Figure 2-3, page 19) that this decode does not handle"),
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
                    The result of a conversion on the PS supply VCCPINT is
                    stored in this register (DRP 0Dh, Zynq Only and Read Only). The
                    data is MSB justified in the 16-bit register. The supply sensor
                    is used, so the 12 MSBs correspond to the supply sensor transfer
                    function shown in Figure 2-10, page 26 of UG480 v1.11
                    (1 LSB = 3V/4096).""",
            )

            addPair(
                name        = 'MaxVccpInt',
                offset      = 0x2a0,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Maximum VCCPINT measurement recorded since power-up or
                    the last XADC reset (DRP 28h, Zynq Only and Read Only).
                    Supply sensor transfer function, Figure 2-10, page 26 of
                    UG480 v1.11 (1 LSB = 3V/4096).""",
            )

            addPair(
                name        = 'MinVccpInt',
                offset      = 0x2b0,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Minimum VCCPINT measurement recorded since power-up or
                    the last XADC reset (DRP 2Ch, Zynq Only and Read Only).
                    Supply sensor transfer function, Figure 2-10, page 26 of
                    UG480 v1.11 (1 LSB = 3V/4096).""",
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
                    The result of a conversion on the PS supply VCCPAUX is
                    stored in this register (DRP 0Eh, Zynq Only and Read Only). The
                    data is MSB justified in the 16-bit register. The supply sensor
                    is used, so the 12 MSBs correspond to the supply sensor transfer
                    function shown in Figure 2-10, page 26 of UG480 v1.11
                    (1 LSB = 3V/4096).""",
            )

            addPair(
                name        = 'MaxVccpAux',
                offset      = 0x2a4,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Maximum VCCPAUX measurement recorded since power-up or
                    the last XADC reset (DRP 29h, Zynq Only and Read Only).
                    Supply sensor transfer function, Figure 2-10, page 26 of
                    UG480 v1.11 (1 LSB = 3V/4096).""",
            )

            addPair(
                name        = 'MinVccpAux',
                offset      = 0x2b4,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Minimum VCCPAUX measurement recorded since power-up or
                    the last XADC reset (DRP 2Dh, Zynq Only and Read Only).
                    Supply sensor transfer function, Figure 2-10, page 26 of
                    UG480 v1.11 (1 LSB = 3V/4096).""",
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
                    The result of a conversion on the PS supply VCCO_DDR (the PS DDR I/O supply, spelled VCCDDRO in PG091) is
                    stored in this register (DRP 0Fh, Zynq Only and Read Only). The
                    data is MSB justified in the 16-bit register. The supply sensor
                    is used, so the 12 MSBs correspond to the supply sensor transfer
                    function shown in Figure 2-10, page 26 of UG480 v1.11
                    (1 LSB = 3V/4096).""",
            )

            addPair(
                name        = 'MaxVccpDdr',
                offset      = 0x2a8,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Maximum VCCO_DDR measurement recorded since power-up or
                    the last XADC reset (DRP 2Ah, Zynq Only and Read Only).
                    Supply sensor transfer function, Figure 2-10, page 26 of
                    UG480 v1.11 (1 LSB = 3V/4096).""",
            )

            addPair(
                name        = 'MinVccpDdr',
                offset      = 0x2b8,
                bitSize     = 12,
                bitOffset   = 4,
                units       = "V",
                function    = self.convCoreVoltage,
                description = """
                    Minimum VCCO_DDR measurement recorded since power-up or
                    the last XADC reset (DRP 2Eh, Zynq Only and Read Only).
                    Supply sensor transfer function, Figure 2-10, page 26 of
                    UG480 v1.11 (1 LSB = 3V/4096).""",
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

        addPair(
            name        = 'SupplyOffsetA',
            offset      = 0x220,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "LSB",
            function    = self.convSignedOffset,
            disp        = '{:d}',
            description = """
                Calibration coefficient for the supply sensor offset using ADC A, applied to supply sensor measurements
                (DRP 08h, Read Only). The 12-bit two's complement correction
                is MSB justified in the 16-bit register and decoded as a signed
                LSB count, see the "XADC Calibration Coefficients" section and
                Figure 3-3 (page 33) of UG480 v1.11.""",
        )

        addPair(
            name        = 'AdcOffsetA',
            offset      = 0x224,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "LSB",
            function    = self.convSignedOffset,
            disp        = '{:d}',
            description = """
                Calibration coefficient for the ADC A offset error
                (DRP 09h, Read Only). The 12-bit two's complement correction
                is MSB justified in the 16-bit register and decoded as a signed
                LSB count, see the "XADC Calibration Coefficients" section and
                Figure 3-3 (page 33) of UG480 v1.11.""",
        )

        addPair(
            name        = 'AdcGainA',
            offset      = 0x228,
            bitSize     = 7,
            bitOffset   = 0,
            units       = "%",
            function    = self.convGain,
            disp        = '{:1.1f}',
            description = """
                Calibration coefficient for ADC A gain error (DRP 0Ah,
                Read Only). Bits [6:0] hold the gain correction: bit 6 = 1 means
                positive and bits [5:0] are the magnitude in 0.1 % steps (range
                +/-6.3 %), decoded as signed percent. See "XADC Calibration
                Coefficients" section and Figure 3-3 (page 33) of UG480
                v1.11.""",
        )

        addPair(
            name        = 'SupplyOffsetB',
            offset      = 0x2c0,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "LSB",
            function    = self.convSignedOffset,
            disp        = '{:d}',
            description = """
                Calibration coefficient for the supply sensor offset using ADC B, applied to supply sensor measurements
                (DRP 30h, Read Only). The 12-bit two's complement correction
                is MSB justified in the 16-bit register and decoded as a signed
                LSB count, see the "XADC Calibration Coefficients" section and
                Figure 3-3 (page 33) of UG480 v1.11.
                Address C_BASEADDR + 0x2C0 per PG091 Table 2-3.""",
        )

        addPair(
            name        = 'AdcOffsetB',
            offset      = 0x2c4,
            bitSize     = 12,
            bitOffset   = 4,
            units       = "LSB",
            function    = self.convSignedOffset,
            disp        = '{:d}',
            description = """
                Calibration coefficient for the ADC B offset error
                (DRP 31h, Read Only). The 12-bit two's complement correction
                is MSB justified in the 16-bit register and decoded as a signed
                LSB count, see the "XADC Calibration Coefficients" section and
                Figure 3-3 (page 33) of UG480 v1.11.
                Address C_BASEADDR + 0x2C4 per PG091 Table 2-3.""",
        )

        addPair(
            name        = 'AdcGainB',
            offset      = 0x2c8,
            bitSize     = 7,
            bitOffset   = 0,
            units       = "%",
            function    = self.convGain,
            disp        = '{:1.1f}',
            description = """
                Calibration coefficient for ADC B gain error (DRP 32h,
                Read Only). Bits [6:0] hold the gain correction: bit 6 = 1 means
                positive and bits [5:0] are the magnitude in 0.1 % steps (range
                +/-6.3 %), decoded as signed percent. See "XADC Calibration
                Coefficients" section and Figure 3-3 (page 33) of UG480
                v1.11.
                Address C_BASEADDR + 0x2C8 per PG091 Table 2-3.""",
        )

        self.add(pr.RemoteVariable(
            name        = 'JTGD',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 11,
            base        = pr.Bool,
            mode        = 'RO',
            description = 'JTAG disabled flag: 1 indicates JTAG access has been disabled by BitGen option',
        ))

        self.add(pr.RemoteVariable(
            name        = 'JTGR',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 10,
            base        = pr.Bool,
            mode        = 'RO',
            description = 'JTAG read-only flag: 1 indicates JTAG read-only access via BitGen option',
        ))

        self.add(pr.RemoteVariable(
            name        = 'REF',
            offset      = 0x2fc,
            bitSize     = 1,
            bitOffset   = 9,
            base        = pr.UInt,
            mode        = 'RO',
            description = 'Voltage reference select: 1=internal reference, 0=external reference',
        ))


        self.add(pr.RemoteVariable(
            name        = 'RawOT_LimitCtrl',
            offset      = 0x34c,
            bitSize     = 4,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            description = """
                Low four bits of the OT upper alarm register 53h; 0011b
                enables automatic over-temperature shutdown (UG480 v1.11
                Thermal Management).""",
            hidden      = True,
        ))

        addPair(
            name              = 'OT_Limit',
            description       = """
                Effective over-temperature shutdown threshold in degrees C
                from the OT upper alarm register 53h (Read Only). The 12 MSBs
                hold the threshold code per UG480 v1.11 Equation 4-2
                (temperature transfer function, Figure 2-9, page 25). Bits
                [3:0] = 0011b enable automatic shutdown, which on 7 series
                also requires set_property BITSTREAM.CONFIG.OVERTEMPPOWERDOWN
                ENABLE [current_design] in the XDC. A register value of 0000h
                (the default, including before configuration) means the 125 C
                default threshold applies, which this variable reports as
                125.0.""",
            offset            = 0x34c,
            bitSize           = 12,
            bitOffset         = 4,
            units             = "degC",
            function          = self.convOtLimit,
            extraDependencies = ('RawOT_LimitCtrl',),
        )

        # Default to simple view
        if simpleViewList is not None:
            self.simpleView()

    @staticmethod
    def convTemp(dev, var, read):
        return _tempFromCode(var.dependencies[0].get(read=read))

    @staticmethod
    def getTemp(var, read):
        return _tempFromCode(var.dependencies[0].get(read=read))

    @staticmethod
    def setTemp(var, value, write):
        # Round to the nearest code and clamp to the 12-bit range
        code = round((value + 273.15) * (4096.0/503.975))
        code = min(max(code, 0), 4095)
        var.dependencies[0].set(code, write=write)

    @staticmethod
    def convOtLimit(var, read):
        hi = var.dependencies[0].get(read=read)
        # Bits [3:0] share one block with bits [15:4], so this returns the
        # shadow filled by the read just issued, with no second transaction
        lo = var.dependencies[1].get(read=False)
        if hi == 0 and lo == 0:
            # Register 53h at 0000h: hardware applies its 125 C default
            return 125.0
        return _tempFromCode(hi)

    @staticmethod
    def convCoreVoltage(var, read):
        return var.dependencies[0].get(read=read) * (3.0/4096.0)

    @staticmethod
    def convSignedCoreVoltage(var, read):
        return _signExtend(var.dependencies[0].get(read=read), 12) * (3.0/4096.0)

    @staticmethod
    def convSignedOffset(var, read):
        return _signExtend(var.dependencies[0].get(read=read), 12)

    @staticmethod
    def convGain(var, read):
        code = var.dependencies[0].get(read=read)
        mag  = code & 0x3F
        if mag == 0:
            return 0.0
        return (mag if code & 0x40 else -mag) / 10.0

    @staticmethod
    def convAuxVoltage(var, read):
        return var.dependencies[0].get(read=read) * (1.0/4096.0)

    def simpleView(self):
        # Hide all the variable
        self.hideVariables(hidden=True)
        # Then unhide the most interesting ones
        vars = self.simpleViewList
        self.hideVariables(hidden=False, variables=vars)
