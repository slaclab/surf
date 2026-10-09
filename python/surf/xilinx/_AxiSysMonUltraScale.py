#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import functools
import pyrogue as pr


# Two's complement value of a bits-wide unsigned code
def _signExtend(code, bits):
    if code & (1 << (bits - 1)):
        return code - (1 << bits)
    return code


class AxiSysMonUltraScale(pr.Device):
    def __init__(
            self,
            description    = "AXI-Lite System Management for Xilinx Ultra Scale (Refer to PG185)",
            XIL_DEVICE_G   = "ULTRASCALE",
            simpleViewList = None,
            pollInterval   = 5,
            vuserFullScale = [3.0, 3.0, 3.0, 3.0],
            zynq           = False,
            **kwargs):
        super().__init__(description=description, **kwargs)

        if simpleViewList is not None:
            self.simpleViewList = simpleViewList[:]
            self.simpleViewList.append('enable')

        def addPair(name, offset, bitSize, units, bitOffset, description, function, pollInterval=0, disp='{:1.3f}', typeStr="Float32"):
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
                typeStr      = typeStr,
                dependencies = [self.variables["Raw"+name]],
            ))

        def addFlag(name, offset, bitOffset, description):
            self.add(pr.RemoteVariable(
                name         = name,
                description  = description,
                offset       = offset,
                bitSize      = 1,
                bitOffset    = bitOffset,
                base         = pr.Bool,
                mode         = 'RO',
                pollInterval = pollInterval,
                overlapEn    = True,
            ))

        if XIL_DEVICE_G == "ULTRASCALE":
            self.convTemp = self.convTempRefSYSMONE1
            self.convSetTemp = self.convSetTempRefSYSMONE1
        elif XIL_DEVICE_G == "ULTRASCALE_PLUS":
            self.convTemp = self.convTempRefSYSMONE4
            self.convSetTemp = self.convSetTempRefSYSMONE4
        else:
            raise Exception('AxiSysMonUltraScale: Device {} not supported'.format(XIL_DEVICE_G))

        # SYSMONE1 has no PS, so the PS supplies exist only on SYSMONE4 (Zynq UltraScale+)
        if zynq and XIL_DEVICE_G != "ULTRASCALE_PLUS":
            raise Exception('AxiSysMonUltraScale: zynq requires XIL_DEVICE_G ULTRASCALE_PLUS, got {}'.format(XIL_DEVICE_G))

        # VUSER full scale is 3 V for an HP bank and 6 V for an HR or HD bank; the device cannot report it
        if not isinstance(vuserFullScale, (list, tuple)) or len(vuserFullScale) != 4 or any(v not in (3.0, 6.0) for v in vuserFullScale):
            raise Exception('AxiSysMonUltraScale: vuserFullScale needs 4 entries of 3.0 or 6.0, got {}'.format(vuserFullScale))

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name        = "SR",
            description = """
                Status Register (PG185 v1.3 Table 2-3, offset 0x04, page 14,
                Read Only).""",
            offset      =  0x04,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RO",
            hidden      =  True,
        ))

        self.add(pr.RemoteVariable(
            name        = "AOSR",
            description = """
                Alarm Output Status Register (PG185 v1.3 Table 2-3, offset 0x08,
                page 14, Read Only).""",
            offset      =  0x08,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RO",
            hidden      =  True,
        ))

        self.add(pr.RemoteVariable(
            name        = "CONVSTR",
            description = """
                CONVST Register, write only (PG185 v1.3 Table 2-3, offset 0x0C,
                page 15). Bit[0] starts an ADC conversion in event-driven sampling
                mode; Bit[17:2] set the wait cycles for the temperature update.""",
            offset      =  0x0C,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "WO",
            hidden      =  True,
            groups      = "NoConfig",
        ))

        self.add(pr.RemoteVariable(
            name        = "SYSMONRR",
            description = """
                SYSMON Hard Macro Reset Register, write only; reading returns an
                undefined value (PG185 v1.3 Table 2-3, offset 0x10, page 15).""",
            offset      =  0x10,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "WO",
            hidden      =  True,
            groups      = "NoConfig",
        ))

        self.add(pr.RemoteVariable(
            name        = "GIER",
            description = """
                Global Interrupt Enable Register (PG185 v1.3 Table 2-3, offset
                0x5C, page 15).""",
            offset      =  0x5C,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RW",
            hidden      =  True,
            groups      = "NoConfig",
        ))

        self.add(pr.RemoteVariable(
            name        = "IPISR",
            description = """
                IP Interrupt Status Register (PG185 v1.3 Table 2-3, offset 0x60,
                page 15, Read Only).""",
            offset      =  0x60,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RO",
            hidden      =  True,
        ))

        self.add(pr.RemoteVariable(
            name        = "IPIER",
            description = """
                IP Interrupt Enable Register (PG185 v1.3 Table 2-3, offset 0x68,
                page 15).""",
            offset      =  0x68,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RW",
            hidden      =  True,
            groups      = "NoConfig",
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
            description  = """
                On-chip temperature sensor measurement (DRP 00h, Read Only; PG185
                v1.3 Table 2-3 offset 0x400). MSB justified in the 16-bit register
                (UG580 v1.10.1 Table 3-1, page 48). This model reads the 12 MSBs and
                selects the transfer function from the REF flag (Ref, bit 9 of
                Flag Register 0), read with every conversion. REF = 1 (on-chip
                reference) applies UG580 v1.10.1
                Equation 2-7, page 40 (SYSMONE1) or
                Equation 2-11, page 41 (SYSMONE4). REF = 0 (external reference)
                applies
                Equation 2-5, page 40 (SYSMONE1) or
                Equation 2-9, page 40 (SYSMONE4). The Zynq UltraScale+ PS SYSMON
                always uses the on-chip reference (UG580 v1.10.1, page 14).""",
        )

        addPair(
            name         = 'VccInt',
            offset       = 0x404,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                VCCINT measured by the on-chip supply sensor (DRP 01h, Read
                Only; PG185 v1.3 offset 0x404). MSB justified in the 16-bit
                register (UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer
                function: UG580 v1.10.1 Figure 2-11, page 42; 3 V full scale, so
                1 LSB = 3V/4096 for the 12-bit code read here.""",
        )

        addPair(
            name         = 'VccAux',
            offset       = 0x408,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                VCCAUX measured by the on-chip supply sensor (DRP 02h, Read
                Only; PG185 v1.3 offset 0x408). MSB justified in the 16-bit
                register (UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer
                function: UG580 v1.10.1 Figure 2-11, page 42; 3 V full scale, so
                1 LSB = 3V/4096 for the 12-bit code read here.""",
        )

        addPair(
            name         = 'VpVn',
            offset       = 0x40C,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convAuxVoltage,
            pollInterval = pollInterval,
            description  = """
                Result of the conversion on the dedicated analog input VP/VN (DRP
                03h; PG185 v1.3 offset 0x40C). MSB justified in the 16-bit register
                (UG580 v1.10.1 Table 3-1, page 48). PG185 lists 0x40C as read/write
                (a write resets the SYSMON hard macro); this model only reads it.
                Decoded on the unipolar scale, 0 V to 1 V (UG580 v1.10.1 Figure 2-1,
                page 30), so 1 LSB = 1V/4096 for the 12-bit code. A bipolar setting
                yields two's complement codes (Figure 2-2, page 31) that this decode
                does not handle.""",
        )

        addPair(
            name         = 'Vrefp',
            offset       = 0x410,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                VREFP measured by the on-chip supply sensor (DRP 04h, Read
                Only; PG185 v1.3 offset 0x410). MSB justified in the 16-bit
                register (UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer
                function: UG580 v1.10.1 Figure 2-11, page 42; 3 V full scale, so
                1 LSB = 3V/4096 for the 12-bit code read here.""",
        )

        addPair(
            name         = 'Vrefn',
            offset       = 0x414,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convSignedCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                VREFN conversion result (DRP 05h, Read Only; PG185 v1.3 offset 0x414).
                Measured in bipolar mode with two's complement output coding
                (UG580 v1.10.1 Figure 2-2, page 31) so small positive and negative
                offsets around 0 V can be measured. The supply sensor is used, so
                1 LSB = 3V/4096 for the 12-bit code and the decoded range is -1.5 V
                to +1.4993 V (UG580 v1.10.1 Table 3-1, page 48). MSB justified in
                the 16-bit register.""",
        )

        addPair(
            name         = 'VccBram',
            offset       = 0x418,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                VCCBRAM measured by the on-chip supply sensor (DRP 06h, Read
                Only; PG185 v1.3 offset 0x418). MSB justified in the 16-bit
                register (UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer
                function: UG580 v1.10.1 Figure 2-11, page 42; 3 V full scale, so
                1 LSB = 3V/4096 for the 12-bit code read here.""",
        )

        addPair(
            name         = 'SupplyOffset',
            offset       = 0x420,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "LSB",
            function     = self.convSignedOffset,
            pollInterval = pollInterval,
            disp         = '{:d}',
            typeStr      = "int",
            description  = """
                Calibration coefficient for the supply sensor offset (DRP 08h,
                Read Only; PG185 v1.3 offset 0x420). SYSMONE1 only: not used for
                SYSMONE4, so the contents are invalid when XIL_DEVICE_G is
                ULTRASCALE_PLUS (UG580 v1.10.1 Table 3-1, page 48; Calibration
                Coefficients Definition, pages 53-54). The offset correction is a
                10-bit two's complement number, MSB justified in the 16-bit
                register, decoded here as a signed LSB count (the supply sensor
                LSB is about 2.93 mV). Example: register 0xFF80 reads -2.""",
        )

        addPair(
            name         = 'AdcOffset',
            offset       = 0x424,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "LSB",
            function     = self.convSignedOffset,
            pollInterval = pollInterval,
            disp         = '{:d}',
            typeStr      = "int",
            description  = """
                Calibration coefficient for the ADC offset (DRP 09h, Read Only;
                PG185 v1.3 offset 0x424). SYSMONE1 only: not used for SYSMONE4, so
                the contents are invalid when XIL_DEVICE_G is ULTRASCALE_PLUS
                (UG580 v1.10.1 Table 3-1, page 48; Calibration Coefficients
                Definition, pages 53-54). The offset correction is a 10-bit
                two's complement number, MSB justified in the 16-bit register,
                decoded here as a signed LSB count (the ADC LSB is about 977 uV,
                1V/1024). Example: register 0xFF80 reads -2.""",
        )

        addPair(
            name         = 'GainError',
            offset       = 0x428,
            bitSize      = 7,
            bitOffset    = 0,
            units        = "%",
            function     = self.convGain,
            pollInterval = pollInterval,
            disp         = '{:1.1f}',
            description  = """
                Calibration coefficient for the ADC gain error (DRP 0Ah, Read Only;
                PG185 v1.3 offset 0x428). SYSMONE1 only: not used for SYSMONE4, so
                the contents are invalid when XIL_DEVICE_G is ULTRASCALE_PLUS
                (UG580 v1.10.1 Table 3-1, page 48). The seven LSBs, bits [6:0],
                hold sign and magnitude: bit 6 = 1 means positive, bits [5:0] are
                the magnitude in 0.1 % steps (range +/-6.3 %), decoded as signed
                percent (UG580 v1.10.1 Gain Coefficients, page 54).""",
        )

        if zynq:
            addPair(
                name         = 'VccPsIntLp',
                offset       = 0x434,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    VCC_PSINTLP measured by the on-chip supply sensor (DRP 0Dh, Read
                    Only; PG185 v1.3 offset 0x434, page 16; UG580 v1.10.1 Table
                    3-1, page 48). Zynq UltraScale+ only (PG185 v1.3 Table 2-3 note
                    10): this variable exists only when zynq=True. MSB justified in
                    the 16-bit register. Supply sensor transfer function: UG580
                    v1.10.1 Figure 2-11, page 42; 3 V full scale, so 1 LSB = 3V/4096
                    for the 12-bit code read here.""",
            )

            addPair(
                name         = 'VccPsIntFp',
                offset       = 0x438,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    VCC_PSINTFP measured by the on-chip supply sensor (DRP 0Eh, Read
                    Only; PG185 v1.3 offset 0x438, page 16; UG580 v1.10.1 Table
                    3-1, page 48). Zynq UltraScale+ only (PG185 v1.3 Table 2-3 note
                    10): this variable exists only when zynq=True. MSB justified in
                    the 16-bit register. Supply sensor transfer function: UG580
                    v1.10.1 Figure 2-11, page 42; 3 V full scale, so 1 LSB = 3V/4096
                    for the 12-bit code read here. PG185 v1.3 spells the
                    supply VCC_PSINFP.""",
            )

            addPair(
                name         = 'VccPsAux',
                offset       = 0x43C,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    VCC_PSAUX measured by the on-chip supply sensor (DRP 0Fh, Read
                    Only; PG185 v1.3 offset 0x43C, page 16; UG580 v1.10.1 Table
                    3-1, page 48). Zynq UltraScale+ only (PG185 v1.3 Table 2-3 note
                    10): this variable exists only when zynq=True. MSB justified in
                    the 16-bit register. Supply sensor transfer function: UG580
                    v1.10.1 Figure 2-11, page 42; 3 V full scale, so 1 LSB = 3V/4096
                    for the 12-bit code read here.""",
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
                description  = f"""
                    Result of the conversion on auxiliary analog input VAUXP[{i}]/
                    VAUXN[{i}] (DRP {0x10 + i:02X}h, Read Only; PG185 v1.3 offset
                    0x{0x440 + 4*i:03X}). MSB justified in the 16-bit register (UG580
                    v1.10.1 Table 3-1, page 48). Decoded on the unipolar scale, 0 V to
                    1 V (UG580 v1.10.1 Figure 2-1, page 30), so 1 LSB = 1V/4096 for
                    the 12-bit code. A bipolar setting yields two's complement codes
                    (Figure 2-2, page 31) that this decode does not handle.""",
            )

        addPair(
            name         = 'MaxTemperature',
            offset       = 0x480,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "degC",
            function     = self.convTemp,
            pollInterval = pollInterval,
            description  = """
                Maximum temperature measurement recorded since power-up or the last
                SYSMON reset (DRP 20h, Read Only; PG185 v1.3 offset 0x480; UG580
                v1.10.1 Table 3-1, page 48). Decoded like Temperature: the 12 MSBs
                with the equation selected by the REF flag (Ref, bit 9 of Flag
                Register 0). REF = 1 (on-chip reference) applies UG580 v1.10.1
                Equation 2-7, page 40 (SYSMONE1) or
                Equation 2-11, page 41 (SYSMONE4). REF = 0 (external reference)
                applies
                Equation 2-5, page 40 (SYSMONE1) or
                Equation 2-9, page 40 (SYSMONE4). The Zynq UltraScale+ PS SYSMON
                always uses the on-chip reference (UG580 v1.10.1, page 14).""",
        )

        addPair(
            name         = 'MaxVccInt',
            offset       = 0x484,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                Maximum VCCINT measurement recorded since power-up or the last
                SYSMON reset (DRP 21h, Read Only; PG185 v1.3 offset 0x484;
                UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer function:
                UG580 v1.10.1 Figure 2-11, page 42, so 1 LSB = 3V/4096 for the
                12-bit code.""",
        )

        addPair(
            name         = 'MaxVccAux',
            offset       = 0x488,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                Maximum VCCAUX measurement recorded since power-up or the last
                SYSMON reset (DRP 22h, Read Only; PG185 v1.3 offset 0x488;
                UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer function:
                UG580 v1.10.1 Figure 2-11, page 42, so 1 LSB = 3V/4096 for the
                12-bit code.""",
        )

        addPair(
            name         = 'MaxVccBram',
            offset       = 0x48C,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                Maximum VCCBRAM measurement recorded since power-up or the last
                SYSMON reset (DRP 23h, Read Only; PG185 v1.3 offset 0x48C;
                UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer function:
                UG580 v1.10.1 Figure 2-11, page 42, so 1 LSB = 3V/4096 for the
                12-bit code.""",
        )

        if zynq:
            addPair(
                name         = 'MaxVccPsIntLp',
                offset       = 0x4A0,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    Maximum VCC_PSINTLP measurement recorded since power-up or the last
                    SYSMON reset (DRP 28h, Read Only; PG185 v1.3 offset 0x4A0,
                    page 17; UG580 v1.10.1 Table 3-1, page 49). Zynq UltraScale+
                    only (PG185 v1.3 Table 2-3 note 10): this variable exists only
                    when zynq=True. Supply sensor transfer function: UG580 v1.10.1
                    Figure 2-11, page 42, so 1 LSB = 3V/4096 for the 12-bit code.""",
            )

            addPair(
                name         = 'MaxVccPsIntFp',
                offset       = 0x4A4,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    Maximum VCC_PSINTFP measurement recorded since power-up or the last
                    SYSMON reset (DRP 29h, Read Only; PG185 v1.3 offset 0x4A4,
                    page 18; UG580 v1.10.1 Table 3-1, page 49). Zynq UltraScale+
                    only (PG185 v1.3 Table 2-3 note 10): this variable exists only
                    when zynq=True. Supply sensor transfer function: UG580 v1.10.1
                    Figure 2-11, page 42, so 1 LSB = 3V/4096 for the 12-bit code.""",
            )

            addPair(
                name         = 'MaxVccPsAux',
                offset       = 0x4A8,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    Maximum VCC_PSAUX measurement recorded since power-up or the last
                    SYSMON reset (DRP 2Ah, Read Only; PG185 v1.3 offset 0x4A8,
                    page 18; UG580 v1.10.1 Table 3-1, page 49). Zynq UltraScale+
                    only (PG185 v1.3 Table 2-3 note 10): this variable exists only
                    when zynq=True. Supply sensor transfer function: UG580 v1.10.1
                    Figure 2-11, page 42, so 1 LSB = 3V/4096 for the 12-bit code.""",
            )

        addPair(
            name         = 'MinTemperature',
            offset       = 0x490,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "degC",
            function     = self.convTemp,
            pollInterval = pollInterval,
            description  = """
                Minimum temperature measurement recorded since power-up or the last
                SYSMON reset (DRP 24h, Read Only; PG185 v1.3 offset 0x490; UG580
                v1.10.1 Table 3-1, page 48). Decoded like Temperature: the 12 MSBs
                with the equation selected by the REF flag (Ref, bit 9 of Flag
                Register 0). REF = 1 (on-chip reference) applies UG580 v1.10.1
                Equation 2-7, page 40 (SYSMONE1) or
                Equation 2-11, page 41 (SYSMONE4). REF = 0 (external reference)
                applies
                Equation 2-5, page 40 (SYSMONE1) or
                Equation 2-9, page 40 (SYSMONE4). The Zynq UltraScale+ PS SYSMON
                always uses the on-chip reference (UG580 v1.10.1, page 14).""",
        )

        addPair(
            name         = 'MinVccInt',
            offset       = 0x494,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                Minimum VCCINT measurement recorded since power-up or the last
                SYSMON reset (DRP 25h, Read Only; PG185 v1.3 offset 0x494;
                UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer function:
                UG580 v1.10.1 Figure 2-11, page 42, so 1 LSB = 3V/4096 for the
                12-bit code.""",
        )

        addPair(
            name         = 'MinVccAux',
            offset       = 0x498,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                Minimum VCCAUX measurement recorded since power-up or the last
                SYSMON reset (DRP 26h, Read Only; PG185 v1.3 offset 0x498;
                UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer function:
                UG580 v1.10.1 Figure 2-11, page 42, so 1 LSB = 3V/4096 for the
                12-bit code.""",
        )

        addPair(
            name         = 'MinVccBram',
            offset       = 0x49C,
            bitSize      = 12,
            bitOffset    = 4,
            units        = "V",
            function     = self.convCoreVoltage,
            pollInterval = pollInterval,
            description  = """
                Minimum VCCBRAM measurement recorded since power-up or the last
                SYSMON reset (DRP 27h, Read Only; PG185 v1.3 offset 0x49C;
                UG580 v1.10.1 Table 3-1, page 48). Supply sensor transfer function:
                UG580 v1.10.1 Figure 2-11, page 42, so 1 LSB = 3V/4096 for the
                12-bit code.""",
        )

        if zynq:
            addPair(
                name         = 'MinVccPsIntLp',
                offset       = 0x4B0,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    Minimum VCC_PSINTLP measurement recorded since power-up or the last
                    SYSMON reset (DRP 2Ch, Read Only; PG185 v1.3 offset 0x4B0,
                    page 18; UG580 v1.10.1 Table 3-1, page 49). Zynq UltraScale+
                    only (PG185 v1.3 Table 2-3 note 10): this variable exists only
                    when zynq=True. Supply sensor transfer function: UG580 v1.10.1
                    Figure 2-11, page 42, so 1 LSB = 3V/4096 for the 12-bit code.""",
            )

            addPair(
                name         = 'MinVccPsIntFp',
                offset       = 0x4B4,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    Minimum VCC_PSINTFP measurement recorded since power-up or the last
                    SYSMON reset (DRP 2Dh, Read Only; PG185 v1.3 offset 0x4B4,
                    page 18; UG580 v1.10.1 Table 3-1, page 49). Zynq UltraScale+
                    only (PG185 v1.3 Table 2-3 note 10): this variable exists only
                    when zynq=True. Supply sensor transfer function: UG580 v1.10.1
                    Figure 2-11, page 42, so 1 LSB = 3V/4096 for the 12-bit code.""",
            )

            addPair(
                name         = 'MinVccPsAux',
                offset       = 0x4B8,
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = self.convCoreVoltage,
                pollInterval = pollInterval,
                description  = """
                    Minimum VCC_PSAUX measurement recorded since power-up or the last
                    SYSMON reset (DRP 2Eh, Read Only; PG185 v1.3 offset 0x4B8,
                    page 18; UG580 v1.10.1 Table 3-1, page 49). Zynq UltraScale+
                    only (PG185 v1.3 Table 2-3 note 10): this variable exists only
                    when zynq=True. Supply sensor transfer function: UG580 v1.10.1
                    Figure 2-11, page 42, so 1 LSB = 3V/4096 for the 12-bit code.""",
            )

        self.add(pr.RemoteVariable(
            name        = "I2cAddress",
            description = """
                VP/VN measurement captured at power-up and used for I2C address
                decoding (DRP 38h; PG185 v1.3 offset 0x4E0). D[15:12] determines the
                default I2C address when I2C_OR is Low (UG580 v1.10.1 Table 3-1,
                page 49; Table 3-20, page 75).""",
            offset      =  0x4E0,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RO",
            hidden      =  True,
        ))

        self.add(pr.RemoteVariable(
            name        = "FlagRegister",
            description = """
                Flag Register 0 (DRP 3Fh; PG185 v1.3 offset 0x4FC): ALM[2:0], OT,
                ALM[6:3], REF, JTGR and JTGD status bits (UG580 v1.10.1 Figure 3-5,
                page 51; Table 3-2, page 52). Figures 3-1 and 3-2 (pages 45-46)
                label 3Eh and 3Fh the other way round. Decoded into Alm0 to Alm6,
                Ot, Ref, Jtgr and Jtgd.""",
            offset      =  0x4FC,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RO",
            hidden      =  True,
            overlapEn   =  True,
        ))

        addFlag(
            name        = 'Alm0',
            offset      = 0x4FC,
            bitOffset   = 0,
            description = """
                ALM[0] alarm output status, bit 0 of Flag Register 0 (DRP 3Fh; PG185
                v1.3 offset 0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2,
                page 52). Watches the temperature upper (50h) and lower (54h)
                thresholds (UG580 v1.10.1 Table 4-12, page 90).""",
        )

        addFlag(
            name        = 'Alm1',
            offset      = 0x4FC,
            bitOffset   = 1,
            description = """
                ALM[1] alarm output status, bit 1 of Flag Register 0 (DRP 3Fh; PG185
                v1.3 offset 0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2,
                page 52). Watches the VCCINT upper (51h) and lower (55h)
                thresholds (UG580 v1.10.1 Table 4-12, page 90).""",
        )

        addFlag(
            name        = 'Alm2',
            offset      = 0x4FC,
            bitOffset   = 2,
            description = """
                ALM[2] alarm output status, bit 2 of Flag Register 0 (DRP 3Fh; PG185
                v1.3 offset 0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2,
                page 52). Watches the VCCAUX upper (52h) and lower (56h)
                thresholds (UG580 v1.10.1 Table 4-12, page 90).""",
        )

        addFlag(
            name        = 'Ot',
            offset      = 0x4FC,
            bitOffset   = 3,
            description = """
                OT status, bit 3 of Flag Register 0 (DRP 3Fh; PG185 v1.3 offset
                0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2, page 52).
                Reports the over-temperature (OT) logic output. The OT upper
                threshold is 53h and the OT lower threshold 57h (UG580 v1.10.1
                Table 4-12, page 90; Thermal Management, pages 91-92).""",
        )

        addFlag(
            name        = 'Alm3',
            offset      = 0x4FC,
            bitOffset   = 4,
            description = """
                ALM[3] alarm output status, bit 4 of Flag Register 0 (DRP 3Fh; PG185
                v1.3 offset 0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2,
                page 52). Watches the VCCBRAM upper (58h) and lower (5Ch)
                thresholds (UG580 v1.10.1 Table 4-12, page 90).""",
        )

        addFlag(
            name        = 'Alm4',
            offset      = 0x4FC,
            bitOffset   = 5,
            description = """
                ALM[4] alarm output status, bit 5 of Flag Register 0 (DRP 3Fh; PG185
                v1.3 offset 0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2,
                page 52). Watches the VCC_PSINTLP upper (59h) and lower (5Dh)
                thresholds (UG580 v1.10.1 Table 4-12, pages 90-91, note 2). Only
                meaningful for the Zynq UltraScale+ PS supplies; created on every
                device.""",
        )

        addFlag(
            name        = 'Alm5',
            offset      = 0x4FC,
            bitOffset   = 6,
            description = """
                ALM[5] alarm output status, bit 6 of Flag Register 0 (DRP 3Fh; PG185
                v1.3 offset 0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2,
                page 52). Watches the VCC_PSINTFP upper (5Ah) and lower (5Eh)
                thresholds (UG580 v1.10.1 Table 4-12, pages 90-91, note 2). Only
                meaningful for the Zynq UltraScale+ PS supplies; created on every
                device.""",
        )

        addFlag(
            name        = 'Alm6',
            offset      = 0x4FC,
            bitOffset   = 7,
            description = """
                ALM[6] alarm output status, bit 7 of Flag Register 0 (DRP 3Fh; PG185
                v1.3 offset 0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2,
                page 52). Watches the VCC_PSAUX upper (5Bh) and lower (5Fh)
                thresholds (UG580 v1.10.1 Table 4-12, pages 90-91, note 2). Only
                meaningful for the Zynq UltraScale+ PS supplies; created on every
                device.""",
        )

        addFlag(
            name        = 'Ref',
            offset      = 0x4FC,
            bitOffset   = 9,
            description = """
                REF flag, bit 9 of Flag Register 0 (DRP 3Fh; PG185 v1.3 offset
                0x4FC; UG580 v1.10.1 Figure 3-5, page 51; Table 3-2, page 52).
                1 means the SYSMON ADC uses the on-chip (internal) reference, 0
                means the external reference. Temperature, MaxTemperature,
                MinTemperature, OTUpperThreshold and OTLowerThreshold read this
                bit with every conversion to select their equation.""",
        )

        addFlag(
            name        = 'Jtgr',
            offset      = 0x4FC,
            bitOffset   = 10,
            description = """
                JTGR flag, bit 10 of Flag Register 0 (DRP 3Fh; PG185 v1.3 offset
                0x4FC; UG580 v1.10.1 Figure 3-5, page 51). 1 when the bitstream
                setting BITSTREAM.GENERAL.JTAG_SYSMON = STATUSONLY restricts JTAG
                access to the SYSMON to read only (UG580 v1.10.1 Table 3-2,
                page 52).""",
        )

        addFlag(
            name        = 'Jtgd',
            offset      = 0x4FC,
            bitOffset   = 11,
            description = """
                JTGD flag, bit 11 of Flag Register 0 (DRP 3Fh; PG185 v1.3 offset
                0x4FC; UG580 v1.10.1 Figure 3-5, page 51). 1 when the bitstream
                setting BITSTREAM.GENERAL.JTAG_SYSMON = DISABLE disables all JTAG
                access to the SYSMON (UG580 v1.10.1 Table 3-2, page 52).""",
        )

        self.add(pr.RemoteVariable(
            name        = "FlagRegister1",
            description = """
                Flag Register 1 (DRP 3Eh): ALM[11:8] status bits (UG580 v1.10.1
                Table 3-1, page 49; Figure 3-5, page 51). PG185 v1.3 Table 2-3
                has no row for this register; offset 0x4F8 follows the
                0x400 + 4*DRP rule of the other status registers. Figures 3-1 and
                3-2 (pages 45-46) label 3Eh and 3Fh the other way round. Decoded
                into Alm8 to Alm11.""",
            offset      =  0x4F8,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RO",
            hidden      =  True,
            overlapEn   =  True,
        ))

        addFlag(
            name        = 'Alm8',
            offset      = 0x4F8,
            bitOffset   = 0,
            description = """
                ALM[8] alarm output status, bit 0 of Flag Register 1 (DRP 3Eh;
                offset 0x4F8; UG580 v1.10.1 Figure 3-5, page 51). Watches the
                VUSER0 upper (60h) and lower (68h) thresholds (UG580
                v1.10.1 Table 4-12, page 90).""",
        )

        addFlag(
            name        = 'Alm9',
            offset      = 0x4F8,
            bitOffset   = 1,
            description = """
                ALM[9] alarm output status, bit 1 of Flag Register 1 (DRP 3Eh;
                offset 0x4F8; UG580 v1.10.1 Figure 3-5, page 51). Watches the
                VUSER1 upper (61h) and lower (69h) thresholds (UG580
                v1.10.1 Table 4-12, page 90).""",
        )

        addFlag(
            name        = 'Alm10',
            offset      = 0x4F8,
            bitOffset   = 2,
            description = """
                ALM[10] alarm output status, bit 2 of Flag Register 1 (DRP 3Eh;
                offset 0x4F8; UG580 v1.10.1 Figure 3-5, page 51). Watches the
                VUSER2 upper (62h) and lower (6Ah) thresholds (UG580
                v1.10.1 Table 4-12, page 90).""",
        )

        addFlag(
            name        = 'Alm11',
            offset      = 0x4F8,
            bitOffset   = 3,
            description = """
                ALM[11] alarm output status, bit 3 of Flag Register 1 (DRP 3Eh;
                offset 0x4F8; UG580 v1.10.1 Figure 3-5, page 51). Watches the
                VUSER3 upper (63h) and lower (6Bh) thresholds (UG580
                v1.10.1 Table 4-12, pages 90-91).""",
        )

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
            name        = "SequenceReg8",
            description = """
                Sequence Register 8 = SEQCHSEL0 (DRP 46h): bits [3:0] enable
                VUSER3..VUSER0 (CHSEL_USER3..0) in the automatic channel sequencer
                (UG580 v1.10.1 Tables 4-1 and 4-2, pages 81-82; PG185 v1.3 Table 2-3,
                offset 0x518, page 18, sequencer channel selection Vuser0-3).""",
            offset      =  0x518,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RW",
            hidden      =  True,
            groups      = "NoConfig",
        ))

        self.add(pr.RemoteVariable(
            name        = "SequenceReg9",
            description = """
                Sequence Register 9 = SEQAVG0 (DRP 47h): bits [3:0] enable
                averaging for VUSER3..VUSER0 (AVG_USER3..0). The sample count (16,
                64 or 256) comes from AVG1/AVG0 in configuration register 0
                (UG580 v1.10.1 Table 4-5, page 83; PG185 v1.3 Table 2-3, offset
                0x51C, page 18).""",
            offset      =  0x51C,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RW",
            hidden      =  True,
            groups      = "NoConfig",
        ))

        self.addRemoteVariables(
            name         = "SequenceReg_7_0",
            description  = """
                Sequence Registers 0 to 7 (PG185 v1.3 Table 2-3, offset 0x520 +
                4*i, page 19), mapped to the DRP registers by index: 0 = SEQCHSEL1
                (48h) and 1 = SEQCHSEL2 (49h) channel selection, 2 = SEQAVG1 (4Ah)
                and 3 = SEQAVG2 (4Bh) averaging enable, 4 = SEQINMODE0 (4Ch) and
                5 = SEQINMODE1 (4Dh) analog-input mode, 6 = SEQACQ0 (4Eh) and
                7 = SEQACQ1 (4Fh) acquisition time (UG580 v1.10.1 Table 4-1,
                page 81).""",
            offset       =  0x520,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            number       =  8,
            stride       =  4,
            hidden       =  True,
            groups       = "NoConfig",
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
            name        = "OTThresholdDisable",
            description = """
                OT bit of configuration register 1 (DRP 41h; PG185 v1.3
                Configuration Register 1, offset 0x504; UG580 v1.10.1 Table 3-5,
                page 55). Set 1 to disable the Over-Temperature (OT) signal. It also
                disables automatic shutdown regardless of the setting of the OT
                upper register 53h (UG580 v1.10.1 Thermal Management, page 91).""",
            offset      =  0x504,
            bitSize     =  1,
            bitOffset   =  0x0,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "OTAutomaticShutdown",
            description = """
                Four LSBs of the OT upper alarm register (DRP 53h; PG185 v1.3
                Alarm Threshold Register 3, offset 0x54C). 0011b makes the device
                use the user threshold in [15:4] instead of the 125 C default and
                arms automatic shutdown. Automatic shutdown additionally requires
                set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE
                [current_design] in the XDC, and OTThresholdDisable (DRP 41h OT
                bit) disables it regardless. 0000h in the whole register keeps the
                125 C default (UG580 v1.10.1 Thermal Management, pages 91-92;
                PG185 v1.3 Table 2-3 note 9).""",
            offset      =  0x54C,
            bitSize     =  4,
            bitOffset   =  0x0,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "OTUpperThresholdRaw",
            description = """
                Bits [15:4] of the OT upper alarm register (DRP 53h; PG185 v1.3
                offset 0x54C): 12-bit threshold code, MSB justified; used by the
                hardware only when OTAutomaticShutdown = 0011b (UG580 v1.10.1
                Thermal Management, pages 91-92).""",
            offset      =  0x54C,
            bitSize     =  12,
            bitOffset   =  0x4,
            mode        = "RW",
            groups      = "NoConfig",
        ))

        self.add(pr.LinkVariable(
            name         = "OTUpperThreshold",
            description  = """
                Over-temperature upper threshold in degrees C decoded from bits
                [15:4] of DRP 53h with the REF-selected equation. REF = 1
                (on-chip reference) applies UG580 v1.10.1
                Equation 2-7, page 40 (SYSMONE1) or
                Equation 2-11, page 41 (SYSMONE4); REF = 0 (external reference)
                applies
                Equation 2-5, page 40 (SYSMONE1) or
                Equation 2-9, page 40 (SYSMONE4). The Zynq UltraScale+ PS SYSMON
                always uses the on-chip reference (UG580 v1.10.1, page 14).
                When the whole register is 0000h (the default,
                including preconfiguration) the hardware uses its 125 C default
                and this variable reports 125.0 regardless of REF. A written threshold is used only
                when [3:0] = 0011b (OTAutomaticShutdown); otherwise the reported
                value is the stored code decoded, not the active threshold. 0011b
                also arms automatic shutdown, which additionally requires
                BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE in the XDC, and
                OTThresholdDisable overrides both. Setting this variable writes
                bits [15:4] only, reads REF from hardware first, and merges [3:0]
                from the last value read, so
                read the register before setting it (UG580 v1.10.1 Thermal
                Management, pages 91-92).""",
            mode         = 'RW',
            units        = 'degC',
            linkedGet    = self.convOtUpperThreshold,
            linkedSet    = self.convSetTemp,
            disp         = '{:1.3f}',
            typeStr      = "Float32",
            dependencies = [self.variables["OTUpperThresholdRaw"], self.variables["OTAutomaticShutdown"]],
        ))

        self.add(pr.RemoteVariable(
            name        = "OTLowerThresholdRaw",
            description = """
                Bits [15:4] of the OT lower alarm register (DRP 57h; PG185 v1.3
                Alarm Threshold Register 7, offset 0x55C): 12-bit threshold code,
                MSB justified. The OT alarm resets, and the device can be
                reconfigured after shutdown, once the temperature falls below this
                threshold (UG580 v1.10.1 Thermal Management, pages 91-92).""",
            offset      =  0x55C,
            bitSize     =  12,
            bitOffset   =  0x4,
            mode        = "RW",
            groups      = "NoConfig",
        ))

        self.add(pr.LinkVariable(
            name         = "OTLowerThreshold",
            description  = """
                Over-temperature lower threshold in degrees C (DRP 57h; PG185 v1.3
                Alarm Threshold Register 7, offset 0x55C). The OT alarm resets, and
                the device can be reconfigured after shutdown, once the temperature
                falls below this threshold (UG580 v1.10.1 Thermal Management,
                pages 91-92). Plain decode of bits [15:4] with the REF-selected
                equation. REF = 1 (on-chip reference) applies UG580 v1.10.1
                Equation 2-7, page 40 (SYSMONE1) or
                Equation 2-11, page 41 (SYSMONE4); REF = 0 (external reference)
                applies
                Equation 2-5, page 40 (SYSMONE1) or
                Equation 2-9, page 40 (SYSMONE4). The Zynq UltraScale+ PS SYSMON
                always uses the on-chip reference (UG580 v1.10.1, page 14).
                Setting this variable reads REF from hardware first and writes
                the nearest code.""",
            mode         = 'RW',
            units        = 'degC',
            linkedGet    = self.convTemp,
            linkedSet    = self.convSetTemp,
            disp         = '{:1.3f}',
            typeStr      = "Float32",
            dependencies = [self.variables["OTLowerThresholdRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name        = "AlarmThresholdReg12",
            description = """
                Alarm Threshold Register 12: VCCBRAM lower alarm threshold (DRP
                5Ch; ALM[3]; UG580 v1.10.1 Table 4-12, page 90; PG185 v1.3 Table 2-3,
                offset 0x570, page 19), 10-bit MSB justified. UG580 v1.10.1
                Figure 3-1, page 45 (SYSMONE1) draws 58h-5Fh as reserved, while
                Figure 3-2, page 46 (SYSMONE4) and Table 4-12 list 5Ch.""",
            offset      =  0x570,
            bitSize     =  32,
            bitOffset   =  0x00,
            mode        = "RW",
            hidden      =  True,
            groups      = "NoConfig",
        ))

        self.addRemoteVariables(
            name         = "AlarmThresholdReg_25_16",
            description  = """
                VUSER0 to VUSER3 upper alarm thresholds (DRP 60h to 63h; ALM[8] to
                ALM[11]; PG185 v1.3 Alarm Threshold Registers 16 to 19, offsets
                0x580 to 0x58C; UG580 v1.10.1 Table 4-12, page 90), 10-bit MSB
                justified; index i maps to VUSERi. The name is historical: only
                these four registers exist and 0x590 to 0x59C are reserved.""",
            offset       =  0x580,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            number       =  4,
            stride       =  4,
            hidden       =  True,
            groups       = "NoConfig",
        )

        self.addRemoteVariables(
            name         = "AlarmThresholdReg_25_22",
            description  = """
                VUSER0 to VUSER3 lower alarm thresholds (DRP 68h to 6Bh; ALM[8] to
                ALM[11]; PG185 v1.3 Alarm Threshold Registers 22 to 25, offsets
                0x5A0 to 0x5AC, page 20; UG580 v1.10.1 Table 4-12, pages 90-91),
                10-bit MSB justified raw codes; index i maps to VUSERi. The PG185
                v1.3 description text calls them alarm threshold registers 14 to
                17; the name follows the Register Name column (22 to 25). 0x590 to
                0x59C stay reserved.""",
            offset       =  0x5A0,
            bitSize      =  32,
            bitOffset    =  0x00,
            mode         = "RW",
            number       =  4,
            stride       =  4,
            hidden       =  True,
            groups       = "NoConfig",
        )

        for i in range(4):
            addPair(
                name         = f'Vuser[{i}]',
                offset       = 0x600+(4*i),
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = functools.partial(self.convUserVoltage, fullScale=vuserFullScale[i]),
                pollInterval = pollInterval,
                description  = f"""
                    VUSER{i} supply monitor measurement in volts (DRP {0x80 + i:02X}h,
                    Read Only; PG185 v1.3 offset 0x{0x600 + 4*i:03X}; UG580 v1.10.1
                    Table 3-1, pages 49-50). The 10-bit result is MSB justified in
                    the 16-bit register and this model reads the 12 MSBs. The full
                    scale is vuserFullScale[{i}]: 3 V for an HP I/O bank (UG580
                    v1.10.1 Equation 2-16, page 43) or 6 V for an HR bank (SYSMONE1)
                    or HD bank (SYSMONE4) (Equation 2-19, page 43); 1 LSB = full
                    scale/4096 for the 12-bit code.""",
            )

        for i in range(4):
            addPair(
                name         = f'MaxVuser[{i}]',
                offset       = 0x680+(4*i),
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = functools.partial(self.convUserVoltage, fullScale=vuserFullScale[i]),
                pollInterval = pollInterval,
                description  = f"""
                    Maximum VUSER{i} measurement in volts recorded since power-up or
                    the last SYSMON reset (DRP {0xA0 + i:02X}h, Read Only; PG185 v1.3
                    offset 0x{0x680 + 4*i:03X}; UG580 v1.10.1 Table 3-1, page 50), on
                    the same scale as Vuser[{i}]: vuserFullScale[{i}], 3 V for HP
                    (Equation 2-16, page 43) or 6 V for HR / HD banks (Equation
                    2-19, page 43).""",
            )

        for i in range(4):
            addPair(
                name         = f'MinVuser[{i}]',
                offset       = 0x6A0+(4*i),
                bitSize      = 12,
                bitOffset    = 4,
                units        = "V",
                function     = functools.partial(self.convUserVoltage, fullScale=vuserFullScale[i]),
                pollInterval = pollInterval,
                description  = f"""
                    Minimum VUSER{i} measurement in volts recorded since power-up or
                    the last SYSMON reset (DRP {0xA8 + i:02X}h, Read Only; PG185 v1.3
                    offset 0x{0x6A0 + 4*i:03X}; UG580 v1.10.1 Table 3-1, page 50), on
                    the same scale as Vuser[{i}]: vuserFullScale[{i}], 3 V for HP
                    (Equation 2-16, page 43) or 6 V for HR / HD banks (Equation
                    2-19, page 43).""",
            )

        # Ref is declared after the temperature variables, so it is attached last and keeps the code at dependencies[0]
        for name in ('Temperature', 'MaxTemperature', 'MinTemperature', 'OTUpperThreshold', 'OTLowerThreshold'):
            self.variables[name].addDependency(self.Ref)

        # Default to simple view
        if simpleViewList is not None:
            self.simpleView()

    @staticmethod
    def convTempSYSMONE1(dev, var, read):
        value   = var.dependencies[0].get(read=read)
        fpValue = value*(501.3743/4096.0)
        fpValue -= 273.6777
        return fpValue

    @staticmethod
    def convSetTempSYSMONE1(dev, var, value, write):
        fpValue = (value + 273.6777)*(4096.0/501.3743)
        intValue = round(fpValue)
        var.dependencies[0].set(intValue, write=write)

    @staticmethod
    def convTempSYSMONE4(dev, var, read):
        value   = var.dependencies[0].get(read=read)
        fpValue = value*(509.3140064/4096.0)
        fpValue -= 280.23087870
        return fpValue

    @staticmethod
    def convSetTempSYSMONE4(dev, var, value, write):
        fpValue = (value + 280.23087870)*(4096.0/509.3140064)
        intValue = round(fpValue)
        var.dependencies[0].set(intValue, write=write)

    @staticmethod
    def convTempExtSYSMONE1(dev, var, read):
        value   = var.dependencies[0].get(read=read)
        fpValue = value*(502.9098/4096.0)
        fpValue -= 273.8195
        return fpValue

    @staticmethod
    def convSetTempExtSYSMONE1(dev, var, value, write):
        fpValue = (value + 273.8195)*(4096.0/502.9098)
        intValue = round(fpValue)
        var.dependencies[0].set(intValue, write=write)

    @staticmethod
    def convTempExtSYSMONE4(dev, var, read):
        value   = var.dependencies[0].get(read=read)
        fpValue = value*(507.5921310/4096.0)
        fpValue -= 279.42657680
        return fpValue

    @staticmethod
    def convSetTempExtSYSMONE4(dev, var, value, write):
        fpValue = (value + 279.42657680)*(4096.0/507.5921310)
        intValue = round(fpValue)
        var.dependencies[0].set(intValue, write=write)

    @staticmethod
    def convTempRefSYSMONE1(dev, var, read):
        # Ref is always the last dependency; 1 means the on-chip reference
        if var.dependencies[-1].get(read=read):
            return dev.convTempSYSMONE1(dev, var, read=read)
        return dev.convTempExtSYSMONE1(dev, var, read=read)

    @staticmethod
    def convSetTempRefSYSMONE1(dev, var, value, write):
        # The reference is always read from hardware, also while a configuration is loaded with write=False
        if var.dependencies[-1].get(read=True):
            dev.convSetTempSYSMONE1(dev, var, value, write)
        else:
            dev.convSetTempExtSYSMONE1(dev, var, value, write)

    @staticmethod
    def convTempRefSYSMONE4(dev, var, read):
        # Ref is always the last dependency; 1 means the on-chip reference
        if var.dependencies[-1].get(read=read):
            return dev.convTempSYSMONE4(dev, var, read=read)
        return dev.convTempExtSYSMONE4(dev, var, read=read)

    @staticmethod
    def convSetTempRefSYSMONE4(dev, var, value, write):
        # The reference is always read from hardware, also while a configuration is loaded with write=False
        if var.dependencies[-1].get(read=True):
            dev.convSetTempSYSMONE4(dev, var, value, write)
        else:
            dev.convSetTempExtSYSMONE4(dev, var, value, write)

    @staticmethod
    def convOtUpperThreshold(dev, var, read):
        hi = var.dependencies[0].get(read=read)
        # Both fields live in the 0x54C register, so [3:0] comes from the shadow filled by the read above (read=False) and no second bus transaction is issued
        lo = var.dependencies[1].get(read=False)
        if hi == 0 and lo == 0:
            # Register 53h at 0000h makes the hardware apply its 125 C default
            return 125.0
        # Ref must be refreshed here because the conversion below runs with read=False
        var.dependencies[-1].get(read=read)
        return dev.convTemp(dev, var, read=False)

    @staticmethod
    def convCoreVoltage(var, read):
        return var.dependencies[0].get(read=read) * (3.0/4096.0)

    @staticmethod
    def convSignedCoreVoltage(var, read):
        return _signExtend(var.dependencies[0].get(read=read), 12) * (3.0/4096.0)

    @staticmethod
    def convSignedOffset(var, read):
        # The 12-bit [15:4] field holds 10-bit MSB justified data plus two averaging bits, so the arithmetic shift yields the 10-bit two's complement LSB count
        return _signExtend(var.dependencies[0].get(read=read), 12) >> 2

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

    @staticmethod
    def convUserVoltage(var, read, fullScale):
        return var.dependencies[0].get(read=read) * (fullScale/4096.0)

    def simpleView(self):
        # Hide all the variable
        self.hideVariables(hidden=True)
        # Then unhide the most interesting ones
        vars = self.simpleViewList
        self.hideVariables(hidden=False, variables=vars)
