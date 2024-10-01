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

import math

class LeapXcvrUpperRxPage01(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        def getOpticalPwr(var, read):
            raw = var.dependencies[0].get(read=read) # Units of 0.1 uW
            if raw == 0:
                pwr = 0.0001 # Prevent log10(zero) case
            else:
                pwr = float(raw)*0.0001 # units of mW

            # Return value in units of dBm
            return 10.0*math.log10(pwr)

        for i in range(12):
            self.add(pr.RemoteVariable(
                name        = f'InputOpticalPowerMonitorRaw[{11-i}]',
                offset      = ((206+i) << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.LinkVariable(
                name         = f'InputOpticalPowerMonitor[{11-i}]',
                mode         = 'RO',
                disp         = '{:1.1f}',
                units        = 'dBm',
                linkedGet    = getOpticalPwr,
                dependencies = [self.InputOpticalPowerMonitorRaw[11-i]],
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
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxCdrPresence',
            offset      = (129 << 2),
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxCdrPresence',
            offset      = (129 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConnectorCable',
            offset      = (130 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxTemperature',
            offset      = (132 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            units       = 'degC',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MinPerChannelBitRate',
            offset      = (133 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxPerChannelBitRate',
            offset      = (134 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LaserWavelengthMsb',
            offset      = (135 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LaserWavelengthLsb',
            offset      = (136 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LaserWavelength',
            mode         = 'RO',
            disp         = '0x{:x}',
            typeStr      = 'UInt16',
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
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxWavelengthDeviationLsb',
            offset      = (138 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'MaxWavelengthDeviation',
            mode         = 'RO',
            disp         = '0x{:x}',
            typeStr      = 'UInt16',
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
        for i in range(8):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (139 << 2),
                bitSize     = 1,
                bitOffset   = (7-i),
                mode        = 'RO',
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
        for i in range(8):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (140 << 2),
                bitSize     = 1,
                bitOffset   = (7-i),
                mode        = 'RO',
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
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (141 << 2),
                bitSize     = 1,
                bitOffset   = (7-i),
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxChannelDisableCapabilities',
            offset      = (142 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxChannelOutputDisableCapabilities',
            offset      = (142 << 2),
            bitSize     = 2,
            bitOffset   = 4,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxSquelchDisableCapabilities',
            offset      = (142 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxPolarityFlipMode',
            offset      = (142 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxMarginMode',
            offset      = (142 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxInputEqualizationControl',
            offset      = (143 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxRateSelectControl',
            offset      = (143 << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxChannelDisableCapabilities',
            offset      = (144 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxChannelOutputDisableCapabilities',
            offset      = (144 << 2),
            bitSize     = 2,
            bitOffset   = 4,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxSquelchDisableCapabilities',
            offset      = (144 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxPolarityFlipMode',
            offset      = (144 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxMarginMode',
            offset      = (144 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputAmplitudeControl',
            offset      = (145 << 2),
            bitSize     = 2,
            bitOffset   = 4,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputDeEmphasisControl',
            offset      = (145 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxRateSelectControl',
            offset      = (145 << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'RO',
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
        for i in range(7):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (146 << 2),
                bitSize     = 1,
                bitOffset   = (6-i),
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'DeviceTechnology',
            offset      = (147 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RO',
        ))

        name = [
            'WavelengthControl',
            'TransmitterCooling',
            'OpticalDetector',
            'OpticalTunability',
        ]
        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = name[i],
                offset      = (147 << 2),
                bitSize     = 1,
                bitOffset   = (3-i),
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'MaxPowerUtilization',
            offset      = (148 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DataRatesSupported',
            offset      = (149 << 2),
            bitSize     = 7,
            bitOffset   = 1,
            mode        = 'RO',
        ))


        self.add(pr.RemoteVariable(
            name        = 'CableLengthMsb',
            offset      = (150 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CableLengthLsb',
            offset      = (151 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'CableLength',
            mode         = 'RO',
            disp         = '0x{:x}',
            units        = '0.5m',
            typeStr      = 'UInt16',
            linkedGet    = self._getLsbMsb,
            dependencies = [self.CableLengthLsb, self.CableLengthMsb],
        ))

        self.addRemoteVariables(
            name         = 'VendorNameRaw',
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
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorNameRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name         = 'VendorOuiRaw',
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
            linkedGet    = lambda read: self.VendorOuiRaw[2].get(read=read)+(2**8)*self.VendorOuiRaw[1].get(read=read)+(2**16)*self.VendorOuiRaw[0].get(read=read),
            dependencies = [self.VendorOuiRaw[x] for x in range(3)],
        ))

        self.addRemoteVariables(
            name         = 'VendorPartNumberRaw',
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
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorPartNumberRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name         = 'VendorRevNumberRaw',
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
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorRevNumberRaw[x] for x in range(2)],
        ))

        self.addRemoteVariables(
            name         = 'VendorSerialNumberRaw',
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
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorSerialNumberRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name         = 'VendorDateCodeRaw',
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
            linkedGet    = transceivers.getDate,
            dependencies = [self.VendorDateCodeRaw[x] for x in range(6)],
        ))

        self.addRemoteVariables(
            name         = 'LotCodeRaw',
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
