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

from surf.devices import transceivers

class LeapXcvrUpperRxPage01(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.addRemoteVariables(
            name         = 'RxPwrRaw',
            description  = 'Rx input power',
            offset       = (206 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 24, # BYTE206:BYTE229
            stride       = 4,
            hidden       = True,
        )

        for i in range(12):
            self.add(pr.LinkVariable(
                name         = f'InputOpticalPowerMonitor[{11-i}]',
                mode         = 'RO',
                disp         = '{:1.1f}',
                units        = 'dBm',
                description  = 'Per-channel RX input optical power monitor in dBm',
                linkedGet    = transceivers.getOpticalPwr,
                dependencies = [self.RxPwrRaw[2*i+0],self.RxPwrRaw[2*i+1]],
            ))

class LeapXcvrUpperPage00(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'PowerClass',
            offset      = (129 << 2),
            bitSize     = 3,
            bitOffset   = 5,
            mode        = 'RO',
            description = 'Module power class (000=Class 0 up to 1W, 110=>6W Class 5 for 12-channel devices)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxCdrPresence',
            offset      = (129 << 2),
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RO',
            description = 'TX CDR presence: coded 1 if TX CDR (clock and data recovery) is provided',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxCdrPresence',
            offset      = (129 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RO',
            description = 'RX CDR presence: coded 1 if RX CDR is provided',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConnectorCable',
            offset      = (130 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'Connector/cable type code (e.g., 33h = optical transceiver with optical connector)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxTemperature',
            offset      = (132 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            units       = 'degC',
            disp        = '{:d}',
            description = 'Maximum recommended operating case temperature in degrees C',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MinPerChannelBitRate',
            offset      = (133 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'Minimum per-channel bit rate in units of 100 Mb/s',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxPerChannelBitRate',
            offset      = (134 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'Maximum per-channel bit rate in units of 100 Mb/s',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LaserWavelengthMsb',
            offset      = (135 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Nominal laser wavelength MSB (wavelength in nm = value / 20)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LaserWavelengthLsb',
            offset      = (136 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Nominal laser wavelength LSB (wavelength in nm = value / 20)',
        ))

        self.add(pr.LinkVariable(
            name         = 'LaserWavelength',
            mode         = 'RO',
            disp         = '0x{:x}',
            typeStr      = 'UInt16',
            description  = 'Nominal laser wavelength (raw value; wavelength in nm = value / 20)',
            linkedGet    = self._getLsbMsb,
            dependencies = [self.LaserWavelengthLsb, self.LaserWavelengthMsb],
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxWavelengthDeviationMsb',
            offset      = (137 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Maximum wavelength deviation MSB (tolerance in nm = value / 200)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxWavelengthDeviationLsb',
            offset      = (138 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Maximum wavelength deviation LSB (tolerance in nm = value / 200)',
        ))

        self.add(pr.LinkVariable(
            name         = 'MaxWavelengthDeviation',
            mode         = 'RO',
            disp         = '0x{:x}',
            typeStr      = 'UInt16',
            description  = 'Maximum wavelength deviation from nominal (raw value; tolerance in nm = value / 200)',
            linkedGet    = self._getLsbMsb,
            dependencies = [self.MaxWavelengthDeviationLsb, self.MaxWavelengthDeviationMsb],
        ))

        name = [
            'SupportForTxFault',
            'SupportForRxFault',
            'SupportForTxLos',
            'SupportForRxLos',
            'SupportForTxSquelch',
            'SupportForRxSquelch',
            'SupportForTxCdrLos',
            'SupportForRxCdrLos',
        ]
        desc = [
            'Coded 1 if TX Fault Flag is supported',
            'Coded 1 if RX Fault Flag is supported',
            'Coded 1 if TX Loss of Signal Flag is supported',
            'Coded 1 if RX Loss of Signal Flag is supported',
            'Coded 1 if TX Squelch is supported',
            'Coded 1 if RX Squelch is supported',
            'Coded 1 if TX CDR Loss of Sync Flag is supported',
            'Coded 1 if RX CDR Loss of Sync Flag is supported',
        ]
        for i in range(8):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (139 << 2),
                bitSize     = 1,
                bitOffset   = (7-i),
                mode        = 'RO',
                description = desc[i],
            ))

        name = [
            'SupportForTxBiasMonitor',
            'SupportForTxLopMonitor',
            'SupportForRxInputPowerMonitor',
            'SupportForRxInputPowerFormat',
            'SupportForCaseTempMonitor',
            'SupportForInteralTempMonitor',
            'SupportForPeakTempMonitor',
            'SupportForElapsedTimeMonitor',
        ]
        desc = [
            'Coded 1 if TX Bias Monitor is supported',
            'Coded 1 if TX Light Output Power Monitor is supported',
            'Coded 1 if individual RX Input Power Monitors are supported',
            'Coded 1 if RX Input Power is reported as Pave (0 = OMA)',
            'Coded 1 if Case Temperature Monitor is supported',
            'Coded 1 if Internal Temperature Monitor is supported',
            'Coded 1 if Peak Temperature Monitor is supported',
            'Coded 1 if Elapsed PowerOn Operating Time Monitor is supported',
        ]
        for i in range(8):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (140 << 2),
                bitSize     = 1,
                bitOffset   = (7-i),
                mode        = 'RO',
                description = desc[i],
            ))

        name = [
            'BerMonitor',
            'Vcc3p3TxMonitor',
            'Vcc3p3RxMonitor',
            'VccHiTxMonitor',
            'VccHiRxMonitor',
            'TecCurrentMonitor',
            'Reserved',
            'Reserved',
        ]
        desc = [
            'Coded 1 if BER Monitor is supported',
            'Coded 1 if Internal Vcc3.3-TX Monitor is supported',
            'Coded 1 if Internal Vcc3.3-RX Monitor is supported',
            'Coded 1 if Internal VccHI-TX Monitor is supported',
            'Coded 1 if Internal VccHI2-RX Monitor is supported',
            'Coded 1 if TEC Current Monitor is supported',
        ]
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (141 << 2),
                bitSize     = 1,
                bitOffset   = (7-i),
                mode        = 'RO',
                description = desc[i],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxChannelDisableCapabilities',
            offset      = (142 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RO',
            description = 'TX channel disable control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxChannelOutputDisableCapabilities',
            offset      = (142 << 2),
            bitSize     = 2,
            bitOffset   = 4,
            mode        = 'RO',
            description = 'TX channel output disable control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxSquelchDisableCapabilities',
            offset      = (142 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RO',
            description = 'TX squelch disable control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxPolarityFlipMode',
            offset      = (142 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            description = 'TX polarity flip mode: coded 1 if TX channel polarity flip control is provided',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxMarginMode',
            offset      = (142 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'TX margin mode: coded 1 if TX margin mode is provided',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxInputEqualizationControl',
            offset      = (143 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RO',
            description = 'TX input equalization control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxRateSelectControl',
            offset      = (143 << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'TX rate/application select control capabilities (00=not provided, 01=global)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxChannelDisableCapabilities',
            offset      = (144 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RO',
            description = 'RX channel disable control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxChannelOutputDisableCapabilities',
            offset      = (144 << 2),
            bitSize     = 2,
            bitOffset   = 4,
            mode        = 'RO',
            description = 'RX channel output disable control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxSquelchDisableCapabilities',
            offset      = (144 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RO',
            description = 'RX squelch disable control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxPolarityFlipMode',
            offset      = (144 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            description = 'RX polarity flip mode: coded 1 if RX channel polarity flip control is provided',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxMarginMode',
            offset      = (144 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'RX margin mode: coded 1 if RX margin mode is provided',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputAmplitudeControl',
            offset      = (145 << 2),
            bitSize     = 2,
            bitOffset   = 4,
            mode        = 'RO',
            description = 'RX output amplitude control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputDeEmphasisControl',
            offset      = (145 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RO',
            description = 'RX output de-emphasis control capabilities (00=not provided, 01=global, 10=individual)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxRateSelectControl',
            offset      = (145 << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'RX rate/application select control capabilities (00=not provided, 01=global)',
        ))

        name = [
            'FedControl',
            'JtagControl',
            'AcJtagControl',
            'Bist',
            'TecTemperatureControl',
            'SleepModeSetControl',
            'CdrBypassControl',
        ]
        desc = [
            'Coded 1 if FEC control is provided',
            'Coded 1 if JTAG control is provided',
            'Coded 1 if AC-JTAG control is provided',
            'Coded 1 if BIST is provided',
            'Coded 1 if TEC temperature control is provided',
            'Coded 1 if sleep mode set control is provided',
            'Coded 1 if per-channel CDR bypass control is provided',
        ]
        for i in range(7):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (146 << 2),
                bitSize     = 1,
                bitOffset   = (6-i),
                mode        = 'RO',
                description = desc[i],
            ))

        self.add(pr.RemoteVariable(
            name        = 'DeviceTechnology',
            offset      = (147 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RO',
            description = 'Device technology type code (upper 4 bits of byte 147)',
        ))

        name = [
            'WavelengthControl',
            'TransmitterCooling',
            'OpticalDetector',
            'OpticalTunability',
        ]
        desc = [
            'Coded 1 if wavelength control is provided',
            'Coded 1 if transmitter cooling is provided',
            'Coded 1 if optical detector is present',
            'Coded 1 if optical tunability is supported',
        ]
        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (147 << 2),
                bitSize     = 1,
                bitOffset   = (3-i),
                mode        = 'RO',
                description = desc[i],
            ))

        self.add(pr.RemoteVariable(
            name        = 'MaxPowerUtilization',
            offset      = (148 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'Maximum power utilization in units of 0.1W (from upper page byte 148)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DataRatesSupported',
            offset      = (149 << 2),
            bitSize     = 7,
            bitOffset   = 1,
            mode        = 'RO',
            description = 'Supported data rates bitmask (binary value x 100 Mb/s)',
        ))


        self.add(pr.RemoteVariable(
            name        = 'CableLengthMsb',
            offset      = (150 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Cable length MSB (length in 0.5m units, 16-bit unsigned)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CableLengthLsb',
            offset      = (151 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Cable length LSB (length in 0.5m units, 16-bit unsigned)',
        ))

        self.add(pr.LinkVariable(
            name         = 'CableLength',
            mode         = 'RO',
            disp         = '0x{:x}',
            units        = '0.5m',
            typeStr      = 'UInt16',
            description  = 'Cable or fiber length in units of 0.5m',
            linkedGet    = self._getLsbMsb,
            dependencies = [self.CableLengthLsb, self.CableLengthMsb],
        ))

        self.addRemoteVariables(
            name         = 'VendorNameRaw',
            description  = 'Vendor name ASCII character bytes',
            offset       = (152 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorName',
            mode         = 'RO',
            description  = 'Vendor name string (16 ASCII characters)',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorNameRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name         = 'VendorOuiRaw',
            description  = 'Vendor OUI (Organizationally Unique Identifier) bytes',
            offset       = (168 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 3,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorOUI',
            mode         = 'RO',
            disp         = '0x{:x}',
            typeStr      = 'UInt12',
            description  = 'Vendor Organizationally Unique Identifier (3-byte IEEE company ID)',
            linkedGet    = lambda read: self.VendorOuiRaw[2].get(read=read)+(2**8)*self.VendorOuiRaw[1].get(read=read)+(2**16)*self.VendorOuiRaw[0].get(read=read),
            dependencies = [self.VendorOuiRaw[x] for x in range(3)],
        ))

        self.addRemoteVariables(
            name         = 'VendorPartNumberRaw',
            description  = 'Vendor part number ASCII character bytes',
            offset       = (171 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorPartNumber',
            mode         = 'RO',
            description  = 'Vendor part number string (16 ASCII characters)',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorPartNumberRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name         = 'VendorRevNumberRaw',
            description  = 'Vendor revision number ASCII character bytes',
            offset       = (187 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 2,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorRevNumber',
            mode         = 'RO',
            description  = 'Vendor revision number string (2 ASCII characters)',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorRevNumberRaw[x] for x in range(2)],
        ))

        self.addRemoteVariables(
            name         = 'VendorSerialNumberRaw',
            description  = 'Vendor serial number ASCII character bytes',
            offset       = (189 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorSerialNumber',
            mode         = 'RO',
            description  = 'Vendor serial number string (16 ASCII characters)',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorSerialNumberRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name         = 'VendorDateCodeRaw',
            description  = 'Vendor date code ASCII character bytes',
            offset       = (207 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 6,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorDateCode',
            mode         = 'RO',
            description  = 'Vendor date code string (manufacturing date)',
            linkedGet    = transceivers.getDate,
            dependencies = [self.VendorDateCodeRaw[x] for x in range(6)],
        ))

        self.addRemoteVariables(
            name         = 'LotCodeRaw',
            description  = 'Lot code ASCII character bytes',
            offset       = (213 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 10,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'LotCode',
            mode         = 'RO',
            description  = 'Lot code string (10 ASCII characters)',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.LotCodeRaw[x] for x in range(10)],
        ))


    def _getLsbMsb(self, var, read):
        with self.root.updateGroup():
            lsb = var.dependencies[0].get(read=read)
            msb = var.dependencies[1].get(read=read)
            return lsb + 256 * msb

    def _setLsbMsb(self, var, value, write):
        with self.root.updateGroup():
            var.dependencies[0].set(value=((value >> 0) & 0xff), write=write)
            var.dependencies[1].set(value=((value >> 8) & 0xff), write=write)
