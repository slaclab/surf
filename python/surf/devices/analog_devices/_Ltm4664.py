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

import surf.protocols.i2c

NOT_IMPLEMENTED = [
    'PHASE',
    'STORE_DEFAULT_ALL',
    'RESTORE_DEFAULT_ALL',
    'STORE_DEFAULT_CODE',
    'RESTORE_DEFAULT_CODE',
    'STORE_USER_CODE',
    'RESTORE_USER_CODE',
    'VOUT_TRIM',
    'VOUT_CAL_OFFSET',
    'VOUT_DROOP',
    'VOUT_SCALE_LOOP',
    'VOUT_SCALE_MONITOR',
    'POUT_MAX',
    'MAX_DUTY',
    'INTERLEAVE',
    'IOUT_CAL_GAIN',
    'IOUT_CAL_OFFSET',
    'FAN_CONFIG_1_2',
    'FAN_COMMAND_1',
    'FAN_COMMAND_2',
    'FAN_CONFIG_3_4',
    'FAN_COMMAND_3',
    'FAN_COMMAND_4',
    'IOUT_OC_LV_FAULT_LIMIT',
    'IOUT_OC_LV_FAULT_RESPONSE',
    'IOUT_UC_FAULT_LIMIT',
    'IOUT_UC_FAULT_RESPONSE',
    'UT_WARN_LIMIT',
    'VIN_OV_WARN_LIMIT',
    'VIN_UV_FAULT_LIMIT',
    'VIN_UV_FAULT_RESPONSE',
    'IIN_OC_FAULT_LIMIT',
    'IIN_OC_FAULT_RESPONSE',
    'POWER_GOOD_ON',
    'POWER_GOOD_OFF',
    'POUT_OP_FAULT_LIMIT',
    'POUT_OP_FAULT_RESPONSE',
    'POUT_OP_WARN_LIMIT',
    'PIN_OP_WARN_LIMIT',
    'STATUS_OTHER',
    'STATUS_FANS_1_2',
    'STATUS_FANS_3_4',
    'READ_VCAP',
    'READ_TEMPERATURE_3',
    'READ_FAN_SPEED_1',
    'READ_FAN_SPEED_2',
    'READ_FAN_SPEED_3',
    'READ_FAN_SPEED_4',
    'READ_DUTY_CYCLE',
    'MFR_REVISION',
    'MFR_LOCATION',
    'MFR_DATE',
    'MFR_SERIAL',
]

class Ltm4664(surf.protocols.i2c.PMBus):
    def __init__(self, **kwargs):
        super().__init__(notImplemented=NOT_IMPLEMENTED, **kwargs)

        # ---------------------------
        # Helper functions
        # ---------------------------
        def getLinear16uDataFormat(var, read):
            # Get the VOUT_MODE and VOUT_COMMAND
            voutMode = var.dependencies[0].get(read=read)
            voutCmd  = var.dependencies[1].get(read=read)

            # 16 bit, two's complement mantissa
            Y = pr.twosComplement(int(voutCmd & 0xFFFF), 16)

            # 5 bit, two's complement exponent (scaling factor)
            N = pr.twosComplement(int(voutMode & 0x001F), 5)

            # X is the 'real world' value
            X = Y*(2**N)
            return X

        def getLinear5s11sDataFormat(var, read):
            # Get the 16-bit RAW value
            raw = var.dependencies[0].get(read=read)

            # 11 bit, two's complement mantissa
            Y = pr.twosComplement(int((raw >> 0) & 0x7FF), 11)

            # 5 bit, two's complement exponent (scaling factor)
            N = pr.twosComplement(int((raw >> 11) & 0x1F), 5)

            # X is the 'real world' value
            X = Y*(2**N)
            return X

        # ---------------------------
        # Hide and delete PMBus registers that are not supported by LTM4664, see datasheet
        # ---------------------------
        self.tenbit.hidden = True
        self.ignoreResp.hidden = True


        # NOTE: string commands MFR_ID and MFR_MODEL do not work correctly

        # ---------------------------
        # Remote variables
        # ---------------------------
        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'PAGE_PLUS_WRITE',
        #     description  = 'Writes data to page register and selected PMBus page simultaneously',
        #     offset       = (4*0x05),
        #     bitSize      = 8,
        #     mode         = 'WO',
        # ))

        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'PAGE_PLUS_READ',
        #     description  = 'Reads data from selected PMBus page with simultaneous page selection',
        #     offset       = (4*0x06),
        #     bitSize      = 8,
        #     mode         = 'RW',
        # ))

        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'SMBALERT_MASK',
        #     description  = 'Configures which status bits assert the SMBALERT signal',
        #     offset       = (4*0x1B),
        #     bitSize      = 8,
        #     mode         = 'RW',
        # ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_VOUT_MAX',
            description = 'Maximum allowable output voltage (manufacturer programmed)',
            offset      = (4*0xA5),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_PIN_ACCURACY',
            description = 'Input power measurement accuracy specification in 0.1% steps',
            offset      = (4*0xAC),
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'USER_DATA_00',
            description = 'User-defined data register 0 (read-only storage)',
            offset      = (4*0xB0),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'USER_DATA_01',
            description = 'User-defined data register 1 (read-only storage)',
            offset      = (4*0xB1),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'USER_DATA_02',
            description = 'User-defined data register 2 (read-only storage)',
            offset      = (4*0xB2),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'USER_DATA_03',
            description = 'User-defined data register 3 (read-write storage)',
            offset      = (4*0xB3),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'USER_DATA_04',
            description = 'User-defined data register 4 (read-write storage)',
            offset      = (4*0xB4),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_CHAN_CONFIG',
            description = 'Per-channel configuration register for output enable and sequencing',
            offset      = (4*0xD0),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_CONFIG_ALL',
            description = 'Global device configuration register',
            offset      = (4*0xD1),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_FAULT_PROPAGATE',
            description = 'Configures which faults propagate to the FAULT pin',
            offset      = (4*0xD2),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_PWM_COMP',
            description = 'PWM comparator configuration register',
            offset      = (4*0xD3),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_PWM_MODE',
            description = 'PWM operating mode selection (e.g., forced continuous, discontinuous)',
            offset      = (4*0xD4),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_FAULT_RESPONSE',
            description = 'Configures device response to fault conditions',
            offset      = (4*0xD5),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_OT_FAULT_RESPONSE',
            description = 'Over-temperature fault response configuration',
            offset      = (4*0xD6),
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_IOUT_PEAK',
            description = 'Peak output current reading since last cleared',
            offset      = (4*0xD7),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_ADC_CONTROL',
            description = 'Internal ADC control and averaging configuration',
            offset      = (4*0xD8),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_IOUT_CAL_GAIN',
            description = 'Output current calibration gain (DCR sense resistance)',
            offset      = (4*0xDA),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_RETRY_DELAY',
            description = 'Delay before retrying after a fault shutdown',
            offset      = (4*0xDB),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_RESTART_DELAY',
            description = 'Delay before output restart after a commanded off state',
            offset      = (4*0xDC),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_VOUT_PEAK',
            description = 'Peak output voltage reading since last cleared',
            offset      = (4*0xDD),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_VIN_PEAK',
            description = 'Peak input voltage reading since last cleared',
            offset      = (4*0xDE),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_TEMPERATURE_1_PEAK',
            description = 'Peak external temperature 1 reading since last cleared',
            offset      = (4*0xDF),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_READ_IIN_PEAK',
            description = 'Peak input current reading since last cleared',
            offset      = (4*0xE1),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'MFR_CLEAR_PEAKS',
            description = 'Clears all stored peak measurement registers',
            offset      = (4*0xE3),
            bitSize     = 1,
            function    = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_READ_ICHIP',
            description = 'Internal chip current consumption reading',
            offset      = (4*0xE4),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_PADS',
            description = 'Manufacturer pad configuration and status register',
            offset      = (4*0xE5),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_ADDRESS',
            description = 'PMBus device address configuration register',
            offset      = (4*0xE6),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_SPECIAL_ID',
            description = 'Manufacturer special device identification code',
            offset      = (4*0xE7),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_IIN_CAL_GAIN',
            description = 'Input current calibration gain (sense resistance)',
            offset      = (4*0xE8),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteCommand(
            name        = 'MFR_FAULT_LOG_STORE',
            description = 'Stores the current fault log to non-volatile memory',
            offset      = (4*0xEA),
            bitSize     = 1,
            function    = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteCommand(
            name        = 'MFR_FAULT_LOG_CLEAR',
            description = 'Clears the fault log stored in non-volatile memory',
            offset      = (4*0xEC),
            bitSize     = 1,
            function    = lambda cmd: cmd.post(1),
        ))

        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'MFR_FAULT_LOG',
        #     description  = 'Fault log data read from non-volatile memory',
        #     offset       = (4*0xEE),
        #     bitSize      = 32,
        #     mode         = 'RO',
        # ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_COMMON',
            description = 'Common manufacturer status and configuration bits',
            offset      = (4*0xEF),
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'MFR_COMPARE_USER_ALL',
            description = 'Compares all user configuration registers to NVM defaults',
            offset      = (4*0xF0),
            bitSize     = 1,
            function    = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_TEMPERATURE_2_PEAK',
            description = 'Peak external temperature 2 reading since last cleared',
            offset      = (4*0xF4),
            bitSize     = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_PWM_CONFIG',
            description = 'PWM switching configuration (frequency, phase, etc.)',
            offset      = (4*0xF5),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_IOUT_CAL_GAIN_TC',
            description = 'Temperature coefficient for output current calibration gain',
            offset      = (4*0xF6),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_RVIN',
            description = 'Input voltage divider resistance configuration',
            offset      = (4*0xF7),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_TEMP_1_GAIN',
            description = 'Temperature sensor 1 gain calibration factor',
            offset      = (4*0xF8),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_TEMP_1_OFFSET',
            description = 'Temperature sensor 1 offset calibration adjustment',
            offset      = (4*0xF9),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_RAIL_ADDRESS',
            description = 'PMBus rail address for multi-rail addressing',
            offset      = (4*0xFA),
            bitSize     = 8,
            mode        = 'RW',
        ))

        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'MFR_REAL_TIME',
        #     description  = 'Real-time clock value from device internal counter',
        #     offset       = (4*0xFB),
        #     bitSize      = 32,
        #     mode         = 'RO',
        # ))

        self.add(pr.RemoteCommand(
            name        = 'MFR_RESET',
            description = 'Issues a full device reset',
            offset      = (4*0xFD),
            bitSize     = 1,
            function    = lambda cmd: cmd.post(1),
        ))

        # ---------------------------
        # Linked variables
        # ---------------------------
        self.add(pr.LinkVariable(
            name         = 'Vin',
            description  = 'Converted input voltage reading',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_VIN],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'VinPeak',
            description  = 'Peak input voltage reading since last cleared',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_VIN_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Iin',
            description  = 'Converted input current reading',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_IIN],
            pollInterval = 1,
        ))
        self.add(pr.LinkVariable(
            name         = 'IinPeak',
            description  = 'Peak input current reading since last cleared',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_READ_IIN_PEAK],
        ))

        self.add(pr.LinkVariable(
            name         = 'Pin',
            description  = 'Converted input power reading',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_PIN],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Vout',
            description  = 'Converted output voltage reading',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear16uDataFormat,
            dependencies = [self.VOUT_MODE, self.READ_VOUT],
            pollInterval = 1,
        ))
        self.VOUT_MODE._default = 0x14

        self.add(pr.LinkVariable(
            name         = 'VoutPeak',
            description  = 'Peak output voltage reading since last cleared',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear16uDataFormat,
            dependencies = [self.VOUT_MODE, self.MFR_VOUT_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'VoutMax',
            description  = 'Maximum output voltage (manufacturer limit) converted value',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear16uDataFormat,
            dependencies = [self.VOUT_MODE, self.MFR_VOUT_MAX],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Iout',
            description  = 'Converted output current reading',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_IOUT],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'IoutPeak',
            description  = 'Peak output current reading since last cleared',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_IOUT_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Pout',
            description  = 'Converted output power reading',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_POUT],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Ichip',
            description  = 'Converted internal chip current consumption',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_READ_ICHIP],
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature1',
            description  = 'Converted external temperature sensor 1 reading',
            mode         = 'RO',
            units        = '°C',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_TEMPERATURE_1],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature1Peak',
            description  = 'Peak external temperature 1 reading since last cleared',
            mode         = 'RO',
            units        = '°C',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_TEMPERATURE_1_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature2',
            description  = 'Converted external temperature sensor 2 reading',
            mode         = 'RO',
            units        = '°C',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_TEMPERATURE_2],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature2Peak',
            description  = 'Peak external temperature 2 reading since last cleared',
            mode         = 'RO',
            units        = '°C',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_TEMPERATURE_2_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Frequency',
            description  = 'Converted switching frequency reading',
            mode         = 'RO',
            units        = 'kHz',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_FREQUENCY],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'IoutCalGainConverted',
            description  = 'Output current calibration gain converted to milliohms',
            mode         = 'RO',
            units        = 'mΩ',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_IOUT_CAL_GAIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'IinCalGainConverted',
            description  = 'Input current calibration gain converted to milliohms',
            mode         = 'RO',
            units        = 'mΩ',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_IIN_CAL_GAIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'PinAccuracy',
            description  = 'Input power measurement accuracy in percent',
            mode         = 'RO',
            units        = '%',
            disp         = '{:1.3f}',
            linkedGet    = lambda read: self.MFR_PIN_ACCURACY.get(read=read)*0.1, # Conversion factor: 0.1%/Bit
            dependencies = [self.MFR_PIN_ACCURACY],
        ))

        # Status bits
        def addStatusBit(registerVar, name, bitOffset):
            self.add(pr.LinkVariable(
                name         = name,
                description  = f'Status bit: {name} from {registerVar.name}',
                linkedGet    = lambda read: bool((registerVar.get(read=read) >> bitOffset) & 0x1),
                dependencies = [registerVar],
                pollInterval = 1,
            ))
        addStatusBit(self.STATUS_WORD, 'statusCML', 1)
        addStatusBit(self.STATUS_WORD, 'statusTEMPERATURE', 2)
        addStatusBit(self.STATUS_WORD, 'statusVIN_UV', 3)
        addStatusBit(self.STATUS_WORD, 'statusIOUT_OC', 4)
        addStatusBit(self.STATUS_WORD, 'statusVOUT_OV', 5)
        addStatusBit(self.STATUS_WORD, 'statusOFF', 6)
        addStatusBit(self.STATUS_WORD, 'statusBUSY', 7)
        addStatusBit(self.STATUS_WORD, 'statusPOWER_GOOD', 11)
        addStatusBit(self.STATUS_WORD, 'statusMFR_SPECIFIC', 12)
        addStatusBit(self.STATUS_WORD, 'statusINPUT', 13)
        addStatusBit(self.STATUS_WORD, 'statusIout', 14)
        addStatusBit(self.STATUS_WORD, 'statusVout', 15)
        addStatusBit(self.STATUS_MFR_SPECIFIC, 'statusFaultPin', 0)
        addStatusBit(self.STATUS_MFR_SPECIFIC, 'statusShortCycle', 1)
        addStatusBit(self.STATUS_MFR_SPECIFIC, 'statusVDD33_UV_OV', 2)
        addStatusBit(self.STATUS_MFR_SPECIFIC, 'statusFaultLogPresent', 3)
        addStatusBit(self.STATUS_MFR_SPECIFIC, 'statusPllUnlocked', 4)
        addStatusBit(self.STATUS_MFR_SPECIFIC, 'statusNvmCrcFault', 5)
        addStatusBit(self.STATUS_MFR_SPECIFIC, 'statusInternalTempWarning', 6)
        addStatusBit(self.STATUS_MFR_SPECIFIC, 'statusInternalTempFault', 7)
