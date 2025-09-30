#-----------------------------------------------------------------------------
# Description:
#
# Based on SFF-8636 Rev Rev 2.11 (03JAN2023)
# https://members.snia.org/document/dl/26418
#
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
import rogue.interfaces.memory as rim

import threading
import queue

from surf.devices import transceivers

class Qsfp(pr.Device):
    def __init__(self, advDebug=False, **kwargs):
        super().__init__(**kwargs)

        ################
        # Lower Page 00h
        ################

        self.add(pr.RemoteVariable(
            name         = 'Identifier',
            description  = 'Type of serial transceiver',
            offset       = (0 << 2),
            bitSize      = 5,
            mode         = 'RO',
            enum         = transceivers.IdentifierDict,
        ))

        if advDebug:

            self.add(pr.RemoteVariable(
                name         = 'RevisionCompliance',
                description  = 'SFF-8636 revision compliance',
                offset       = (1 << 2),
                bitSize      = 8,
                mode         = 'RO',
                enum         = {
                    0x00: 'Revision not specified. Do not use for SFF-8636 rev 2.5 or higher.',
                    0x01: 'SFF-8436 Rev 4.8 or earlier',
                    0x02: 'Includes functionality described in revision 4.8 or earlier of SFF-8436, except that this byte and Bytes 186-189 are as defined in this document',
                    0x03: 'SFF-8636 Rev 1.3 or earlier',
                    0x04: 'SFF-8636 Rev 1.4',
                    0x05: 'SFF-8636 Rev 1.5',
                    0x06: 'SFF-8636 Rev 2.0',
                    0x07: 'SFF-8636 Rev 2.5, 2.6 and 2.7',
                    0x08: 'SFF-8636 Rev 2.8, 2.9 and 2.10',
                    0xFF: 'Reserved',
                },
            ))

            self.add(pr.RemoteVariable(
                name         = 'Flat_mem',
                description  = 'Upper memory flat or paged',
                offset       = (2 << 2),
                bitSize      = 1,
                bitOffset    = 2,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IntL',
                description  = 'Digital state of the IntL Interrupt output pin',
                offset       = (2 << 2),
                bitSize      = 1,
                bitOffset    = 1,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'Data_Not_Ready',
                description  = 'Indicates free-side does not yet have valid monitor data. The bit remains high until valid data can be read at which time the bit goes low.',
                offset       = (2 << 2),
                bitSize      = 1,
                bitOffset    = 0,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedTxLos',
                description  = 'Interrupt flags for TX LOS',
                offset       = (3 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedRxLos',
                description  = 'Interrupt flags for RX LOS',
                offset       = (3 << 2),
                bitSize      = 4,
                bitOffset    = 0,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedTxAdaptEqFault',
                description  = 'Interrupt flags for TX Adapt EQ Fault',
                offset       = (4 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedRxFault',
                description  = 'Interrupt flags for TX Transmitter/Laser fault indicator',
                offset       = (4 << 2),
                bitSize      = 4,
                bitOffset    = 0,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedTxCdrLol',
                description  = 'Interrupt flags for TX CDR LOL indicator',
                offset       = (5 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedRxCdrLol',
                description  = 'Interrupt flags for RX CDR LOL indicator',
                offset       = (5 << 2),
                bitSize      = 4,
                bitOffset    = 0,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedTempHighAlarm',
                description  = 'Interrupt flags for high-temperature alarm',
                offset       = (6 << 2),
                bitSize      = 1,
                bitOffset    = 7,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedTempLowAlarm',
                description  = 'Interrupt flags for low-temperature alarm',
                offset       = (6 << 2),
                bitSize      = 1,
                bitOffset    = 6,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedTempHighWarning',
                description  = 'Interrupt flags for high-temperature warning',
                offset       = (6 << 2),
                bitSize      = 1,
                bitOffset    = 5,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedTempLowWarning',
                description  = 'Interrupt flags for low-temperature warning',
                offset       = (6 << 2),
                bitSize      = 1,
                bitOffset    = 4,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'TcReadinessFlag',
                description  = 'Asserted (one) after TC has stabilized. Returns to zero when read',
                offset       = (6 << 2),
                bitSize      = 1,
                bitOffset    = 1,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'InitComplete',
                description  = 'Asserted (one) after initialization and/or reset has completed. Returns to zero when read.',
                offset       = (6 << 2),
                bitSize      = 1,
                bitOffset    = 0,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedVccHighAlarm',
                description  = 'Interrupt flags for high supply voltage alarm',
                offset       = (7 << 2),
                bitSize      = 1,
                bitOffset    = 7,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedVccLowAlarm',
                description  = 'Interrupt flags for low supply voltage alarm',
                offset       = (7 << 2),
                bitSize      = 1,
                bitOffset    = 6,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedVccHighWarning',
                description  = 'Interrupt flags for high supply voltage alarm',
                offset       = (7 << 2),
                bitSize      = 1,
                bitOffset    = 5,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'LatchedVccLowWarning',
                description  = 'Interrupt flags for low supply voltage alarm',
                offset       = (7 << 2),
                bitSize      = 1,
                bitOffset    = 4,
                mode         = 'RO',
            ))

        # 8 All Vendor Specific

        ###############################################################
        # TODO: Add registers 9 ~ 14
        ###############################################################

        # 15-16 All Reserved Reserved channel monitor flags, set 4
        # 17-18 All Reserved Reserved channel monitor flags, set 5
        # 19-21 All Vendor Specific

        self.addRemoteVariables(
            name         = 'TemperatureRaw',
            description  = 'Internally measured temperature',
            offset       = (22 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 2, # BYTE22:BYTE23
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'Temperature',
            description  = 'Internally measured module temperature',
            mode         = 'RO',
            units        = 'degC',
            linkedGet    = transceivers.getTemp,
            disp         = '{:1.3f}',
            dependencies = [self.TemperatureRaw[0],self.TemperatureRaw[1]],
        ))

        # 24-25 All Reserved

        self.addRemoteVariables(
            name         = 'VccRaw',
            description  = 'Internally measured temperature',
            offset       = (26 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 2, # BYTE26:BYTE27
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'Vcc',
            description  = 'Internally measured supply voltage in transceiver',
            mode         = 'RO',
            units        = 'V',
            linkedGet    = transceivers.getVolt,
            disp         = '{:1.3f}',
            dependencies = [self.VccRaw[0],self.VccRaw[1]],
        ))

        # 28-29 All Reserved
        # 30-33 All Vendor Specific

        self.addRemoteVariables(
            name         = 'RxPwrRaw',
            description  = 'Rx input power',
            offset       = (34 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 8, # BYTE34:BYTE41
            stride       = 4,
            hidden       = True,
        )

        for i in range(4):
            self.add(pr.LinkVariable(
                name         = f'RxPower[{i}]',
                description  = 'Measured RX input power',
                mode         = 'RO',
                units        = 'dBm',
                linkedGet    = transceivers.getOpticalPwr,
                disp         = '{:1.3f}',
                dependencies = [self.RxPwrRaw[2*i+0],self.RxPwrRaw[2*i+1]],
            ))

        self.addRemoteVariables(
            name         = 'TxBiasRaw',
            description  = 'Tx bias current',
            offset       = (42 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 8, # BYTE42:BYTE49
            stride       = 4,
            hidden       = True,
        )

        for i in range(4):
            self.add(pr.LinkVariable(
                name         = f'TxBias[{i}]',
                description  = 'Internally measured TX Bias Current',
                mode         = 'RO',
                units        = 'mA',
                linkedGet    = transceivers.getTxBias,
                disp         = '{:1.3f}',
                dependencies = [self.TxBiasRaw[2*i+0],self.TxBiasRaw[2*i+1]],
            ))

        self.addRemoteVariables(
            name         = 'TxPwrRaw',
            description  = 'Tx output power',
            offset       = (50 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 8, # BYTE50:BYTE57
            stride       = 4,
            hidden       = True,
        )

        for i in range(4):
            self.add(pr.LinkVariable(
                name         = f'TxPower[{i}]',
                description  = 'Measured TX output power',
                mode         = 'RO',
                units        = 'dBm',
                linkedGet    = transceivers.getOpticalPwr,
                disp         = '{:1.3f}',
                dependencies = [self.TxPwrRaw[2*i+0],self.TxPwrRaw[2*i+1]],
            ))

        # 58-65 Reserved channel monitor set 4
        # 66-73 Reserved channel monitor set 5
        # 74-81 Vendor Specific
        # 82-85 All Reserved

        self.add(pr.RemoteVariable(
            name         = 'TxDisable',
            description  = 'Tx_Disable bit that allows software disable of transmitters, Writing 1 disables the laser of the channel',
            offset       = (86 << 2),
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        if advDebug:

            for i in range(4):
                self.add(pr.RemoteVariable(
                    name         = f'RxRateSelect[{i}]',
                    description  = f'Software rate select. Rx Channel {i} (refer Table 6-12 xN_Rate_Select with Extended Rate Selection)',
                    offset       = (87 << 2),
                    bitSize      = 2,
                    bitOffset    = 2*i,
                    mode         = 'RW',
                    hidden       = True,
                ))

            for i in range(4):
                self.add(pr.RemoteVariable(
                    name         = f'TxRateSelect[{i}]',
                    description  = f'Software rate select. Tx Channel {i} (refer Table 6-12 xN_Rate_Select with Extended Rate Selection)',
                    offset       = (88 << 2),
                    bitSize      = 2,
                    bitOffset    = 2*i,
                    mode         = 'RW',
                    hidden       = True,
                ))

        # 89-92 All Reserved (Prior to Rev 2.10 used for SFF-8079 – now deprecated.)

        if advDebug:

            self.add(pr.RemoteCommand(
                name         = 'SoftReset',
                description  = 'Software reset is a self-clearing bit that causes the module to be reset',
                offset       = (93 << 2),
                bitSize      = 1,
                bitOffset    = 7,
                function     = lambda cmd: cmd.post(1),
            ))

            self.add(pr.RemoteVariable(
                name         = 'HighPowerClassEnable',
                description  = 'Table 6-11 Truth table for enabling power classes (Page 00h Byte 93)',
                offset       = (93 << 2),
                bitSize      = 2,
                bitOffset    = 2,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'PowerMode',
                description  = 'Power set to low power mode: 1 sets to LP mode if PowerOverride is 1',
                offset       = (93 << 2),
                bitSize      = 1,
                bitOffset    = 1,
                mode         = 'RW',
                base         = pr.Bool,
            ))

            self.add(pr.RemoteVariable(
                name         = 'PowerOverride',
                description  = '0: allows setting power mode with hardware, 1: allows setting power mode with software',
                offset       = (93 << 2),
                bitSize      = 1,
                bitOffset    = 0,
                mode         = 'RW',
                base         = pr.Bool,
            ))

        # 94-97 All Reserved

        self.add(pr.RemoteVariable(
            name         = 'TxCdrEnable',
            description  = 'Enable CDR for Tx lane[3:0]',
            offset       = (98 << 2),
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxCdrEnable',
            description  = 'Enable CDR for Rx lane[3:0]',
            offset       = (98 << 2),
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        if advDebug:

            self.add(pr.RemoteVariable(
                name         = 'LPMode_TxDis_Pin',
                description  = 'IntL/LOSL output signal control',
                offset       = (99 << 2),
                bitSize      = 1,
                bitOffset    = 1,
                mode         = 'RW',
                enum         = {
                    0x0: 'LPMode',
                    0x1: 'TxDis',
                },
            ))

            self.add(pr.RemoteVariable(
                name         = 'IntL_LOSL_Pin',
                description  = 'IntL/LOSL output signal control',
                offset       = (99 << 2),
                bitSize      = 1,
                bitOffset    = 0,
                mode         = 'RW',
                enum         = {
                    0x0: 'IntL',
                    0x1: 'LOSL',
                },
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqTxLosMask',
                description  = 'Masking bits for TX LOS',
                offset       = (100 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqRxLosMask',
                description  = 'Masking bits for RX LOS',
                offset       = (100 << 2),
                bitSize      = 4,
                bitOffset    = 0,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqTxAdaptEqFaultMask',
                description  = 'Masking bits for TX Adapt EQ Fault',
                offset       = (101 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqRxFaultMask',
                description  = 'Masking bits for TX Transmitter/Laser fault indicator',
                offset       = (101 << 2),
                bitSize      = 4,
                bitOffset    = 0,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqTxCdrLolMask',
                description  = 'Masking bits for TX CDR LOL indicator',
                offset       = (102 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqRxCdrLolMask',
                description  = 'Masking bits for RX CDR LOL indicator',
                offset       = (102 << 2),
                bitSize      = 4,
                bitOffset    = 0,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqTempHighAlarmMask',
                description  = 'Masking bits for high-temperature alarm',
                offset       = (103 << 2),
                bitSize      = 1,
                bitOffset    = 7,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqTempLowAlarmMask',
                description  = 'Masking bits for low-temperature alarm',
                offset       = (103 << 2),
                bitSize      = 1,
                bitOffset    = 6,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqTempHighWarningMask',
                description  = 'Masking bits for high-temperature warning',
                offset       = (103 << 2),
                bitSize      = 1,
                bitOffset    = 5,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqTempLowWarningMask',
                description  = 'Masking bits for low-temperature warning',
                offset       = (103 << 2),
                bitSize      = 1,
                bitOffset    = 4,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'TcReadinessFlagMask',
                description  = 'Masking bit for TC readiness flag',
                offset       = (103 << 2),
                bitSize      = 1,
                bitOffset    = 1,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqVccHighAlarmMask',
                description  = 'Masking bits for high supply voltage alarm',
                offset       = (104 << 2),
                bitSize      = 1,
                bitOffset    = 7,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqVccLowAlarmMask',
                description  = 'Masking bits for low supply voltage alarm',
                offset       = (104 << 2),
                bitSize      = 1,
                bitOffset    = 6,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqVccHighWarningMask',
                description  = 'Masking bits for high supply voltage alarm',
                offset       = (104 << 2),
                bitSize      = 1,
                bitOffset    = 5,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'IrqVccLowWarningMask',
                description  = 'Masking bits for low supply voltage alarm',
                offset       = (104 << 2),
                bitSize      = 1,
                bitOffset    = 4,
                mode         = 'RW',
            ))

        # 105-106 Vendor Specific

        if advDebug:

            self.add(pr.RemoteVariable(
                name         = 'MaxPowerConsumption',
                description  = 'Maximum power consumption of module',
                offset       = (107 << 2),
                bitSize      = 8,
                mode         = 'RO',
                units        = '0.1W',
            ))

            self.addRemoteVariables(
                name         = 'PropagationDelayRaw',
                description  = 'propagation delay',
                offset       = (108 << 2),
                bitSize      = 8,
                mode         = 'RO',
                number       = 2, # BYTE108:BYTE109
                stride       = 4,
                hidden       = True,
            )

            self.add(pr.RemoteVariable(
                name         = 'AdvLowPwrMode',
                description  = 'The code indicates maximum power consumption less than 1.5 W',
                offset       = (110 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RO',
                enum         = {
                    0x0: '1.5W or higher',
                    0x1: 'no more than 1 W',
                    0x2: 'no more than 0.75 W',
                    0x3: 'no more than 0.5 W',
                    0xF: 'UNDEFINED',
                },
            ))

            self.add(pr.RemoteVariable(
                name         = 'FarSideManaged',
                description  = 'A value of 1 indicates that the far end is managed and complies with SFF-8636',
                offset       = (110 << 2),
                bitSize      = 1,
                bitOffset    = 3,
                mode         = 'RO',
                base         = pr.Bool,
            ))

            self.add(pr.RemoteVariable(
                name         = 'MinOperatingVoltage',
                description  = 'The code indicates nominal supply voltages lower than 3.3 V.',
                offset       = (110 << 2),
                bitSize      = 3,
                bitOffset    = 0,
                mode         = 'RO',
                enum         = {
                    0x0: '3.3 V',
                    0x1: '2.5 V',
                    0x2: '1.8 V',
                    0x7: 'UNDEFINED',
                },
            ))

        # 111-112 Assigned for use by PCI Express

        if advDebug:

            self.add(pr.RemoteVariable(
                name         = 'FarEndImpl',
                description  = 'Far End Implementation',
                offset       = (113 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RO',
                enum         = {
                    0x0: 'Far end is unspecified',
                    0x1: 'Cable with single far-end with 4 channels implemented, or separable module with a 4-channel connector',
                    0x2: 'Cable with single far-end with 2 channels implemented, or separable module with a 2-channel connector',
                    0x3: 'Cable with single far-end with 1 channel implemented, or separable module with a 1-channel connector',
                    0x4: '4 far-ends with 1 channel implemented in each (i.e. 4x1 break out)',
                    0x5: '2 far-ends with 2 channels implemented in each (i.e. 2x2 break out)',
                    0x6: '2 far-ends with 1 channel implemented in each (i.e. 2x1 break out)',
                    0xF: 'UNDEFINED',
                },
            ))

            self.add(pr.RemoteVariable(
                name         = 'NearEndImpl',
                description  = 'Near End Implementation Bit Mask (1: implemented, 0: Not implemented)',
                offset       = (113 << 2),
                bitSize      = 4,
                bitOffset    = 0,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'Tx_TurnOn_MaxDuration',
                description  = 'Tx_TurnOn_MaxDuration for microQSFP MSA (0000b=Not implemented)',
                offset       = (114 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'DataPathInit_MaxDuration',
                description  = 'DataPathInit_MaxDuration for microQSFP MSA (0000b=Not implemented)',
                offset       = (114 << 2),
                bitSize      = 4,
                bitOffset    = 0,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'ModSelL_wait_time_exponent',
                description  = 'The ModSelL wait time is the mantissa x 2^exponent expressed in microseconds. (0=Not implemented)',
                offset       = (115 << 2),
                bitSize      = 3,
                bitOffset    = 5,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'ModSelL_wait_time_mantissa',
                description  = 'The ModSelL wait time is the mantissa x 2^exponent expressed in microseconds. (0=Not implemented)',
                offset       = (115 << 2),
                bitSize      = 5,
                bitOffset    = 0,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'SecondExtSpecCompliance',
                description  = 'Secondary Extended Specification Compliance Codes (See SFF-8024 Transceiver Management)',
                offset       = (116 << 2),
                bitSize      = 8,
                bitOffset    = 0,
                mode         = 'RO',
            ))


            self.add(pr.RemoteVariable(
                name         = 'TransceiverSubtype',
                description  = 'Transceiver Sub-type code (See SFF-8024 Transceiver Management)',
                offset       = (117 << 2),
                bitSize      = 4,
                bitOffset    = 4,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'FiberFaceType',
                description  = 'Fiber Face Type code (See SFF-8024 Transceiver Management)',
                offset       = (117 << 2),
                bitSize      = 2,
                bitOffset    = 0,
                mode         = 'RO',
            ))

        # 118 118 Reserved
        # 119 122 Optional Password Change
        # 123 126 Optional Password Entry


        # 127 127 Page Select Byte
        self.add(_UpperPageProxy(
            name     = 'UpperPageProxy',
            memBase  = self,
            offset   = 0x0000,
            hidden   = True,
        ))
        self.proxy = _ProxySlave(self.UpperPageProxy)

        self.add(transceivers.QsfpUpperPage00h(
            name     = 'UpperPage00h',
            memBase  = self.proxy,
            advDebug = advDebug,
            offset   = (0+1)<<10, # Page00 plus 1 mem addres region offset
        ))

        self.add(transceivers.QsfpUpperPage03h(
            name     = 'UpperPage03h',
            memBase  = self.proxy,
            advDebug = advDebug,
            offset   = (3+1)<<10, # Page03 plus 1 mem addres region offset
        ))

    def add(self, node):
        pr.Node.add(self, node)

        if isinstance(node, pr.Device):
            if node._memBase is None:
                node._setSlave(self.proxy)

#################################################
#               Upper Page Proxy
#################################################
class _UpperPageProxy(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self._queue = queue.Queue()
        self._pollThread = threading.Thread(target=self._pollWorker)
        self._pollThread.start()

        self._armed = False

        self.add(pr.RemoteVariable(
            name         = 'PageSelectByte',
            description  = 'Byte 127 is used to select the upper page',
            offset       = (127 << 2),
            bitSize      = 8,
            mode         = 'WO',
            hidden       = True,
            groups        = ['NoStream','NoState','NoConfig'],
        ))

        self.add(pr.RemoteVariable(
            name        = 'UpperPage',
            offset      = (128 << 2),
            mode        = 'RW',
            numValues   = 128, # Upper Page has 128 register offset
            valueBits   = 8,   # Only 8b data values
            valueStride = 32,  # 32b AXI-Lite word stride
            updateNotify= False,
            bulkOpEn    = False,
            hidden      = True,
            verify      = False, # Do not verify because some upper page are RO
            groups      = ['NoStream','NoState','NoConfig'],
        ))

    def proxyTransaction(self, transaction):
        self._queue.put(transaction)

    def _pollWorker(self):
        while True:
            #print('Main thread loop start')
            transaction = self._queue.get()
            if transaction is None:
                return
            with self._memLock, transaction.lock():

                # Determine the page select and register index
                pageSelect = ((transaction.address()>>10)&0xFF)-1
                regIndex   = ((transaction.address()>>2)&0xFF)-128

                # Check if the page select has changed
                if (self.PageSelectByte.value() != pageSelect) or not self._armed:

                    # Set the flag
                    self._armed = True

                    # Perform the hardware write
                    self.PageSelectByte.set(value=pageSelect, write=True)

                # Check for a write or post TXN
                if (transaction.type() == rim.Write) or (transaction.type() == rim.Post):

                    # Convert from TXN.data to the write byte array
                    dataBa = bytearray(4)
                    transaction.getData(dataBa, 0)
                    data = int.from_bytes(dataBa, 'little', signed=False)

                    # Perform the hardware write
                    self.UpperPage.set(index=regIndex, value=data, write=True)

                    # Close out the transaction
                    transaction.done()

                # Else this is a read or verify TXN
                else:

                    # Perform the hardware read
                    data = self.UpperPage.get(index=regIndex, read=True)

                    # Convert from write byte array to TXN.data to the
                    dataBa = bytearray(data.to_bytes(4, 'little', signed=False))
                    transaction.setData(dataBa, 0)

                    # Close out the transaction
                    transaction.done()

    def _stop(self):
        self._queue.put(None)
        self._pollThread.join()

class _ProxySlave(rim.Slave):

    def __init__(self, UpperPageProxy):
        super().__init__(4,4)
        self._UpperPageProxy = UpperPageProxy

    def _doTransaction(self, transaction):
        self._UpperPageProxy.proxyTransaction(transaction)
