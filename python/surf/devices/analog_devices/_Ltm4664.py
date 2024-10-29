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

class Ltm4664(surf.protocols.i2c.PMBus):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

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

        del self._nodes['PHASE']
        del self._nodes['STORE_DEFAULT_ALL']
        del self._nodes['RESTORE_DEFAULT_ALL']
        del self._nodes['STORE_DEFAULT_CODE']
        del self._nodes['RESTORE_DEFAULT_CODE']
        del self._nodes['STORE_USER_CODE']
        del self._nodes['RESTORE_USER_CODE']
        del self._nodes['VOUT_TRIM']
        del self._nodes['VOUT_CAL_OFFSET']
        del self._nodes['VOUT_DROOP']
        del self._nodes['VOUT_SCALE_LOOP']
        del self._nodes['VOUT_SCALE_MONITOR']
        del self._nodes['POUT_MAX']
        del self._nodes['MAX_DUTY']
        del self._nodes['INTERLEAVE']
        del self._nodes['IOUT_CAL_GAIN']
        del self._nodes['IOUT_CAL_OFFSET']
        del self._nodes['FAN_CONFIG_1_2']
        del self._nodes['FAN_COMMAND_1']
        del self._nodes['FAN_COMMAND_2']
        del self._nodes['FAN_CONFIG_3_4']
        del self._nodes['FAN_COMMAND_3']
        del self._nodes['FAN_COMMAND_4']
        del self._nodes['IOUT_OC_LV_FAULT_LIMIT']
        del self._nodes['IOUT_OC_LV_FAULT_RESPONSE']
        del self._nodes['IOUT_UC_FAULT_LIMIT']
        del self._nodes['IOUT_UC_FAULT_RESPONSE']
        del self._nodes['UT_WARN_LIMIT']
        del self._nodes['VIN_OV_WARN_LIMIT']
        del self._nodes['VIN_UV_FAULT_LIMIT']
        del self._nodes['VIN_UV_FAULT_RESPONSE']
        del self._nodes['IIN_OC_FAULT_LIMIT']
        del self._nodes['IIN_OC_FAULT_RESPONSE']
        del self._nodes['POWER_GOOD_ON']
        del self._nodes['POWER_GOOD_OFF']
        del self._nodes['POUT_OP_FAULT_LIMIT']
        del self._nodes['POUT_OP_FAULT_RESPONSE']
        del self._nodes['POUT_OP_WARN_LIMIT']
        del self._nodes['PIN_OP_WARN_LIMIT']
        del self._nodes['STATUS_OTHER']
        del self._nodes['STATUS_FANS_1_2']
        del self._nodes['STATUS_FANS_3_4']
        del self._nodes['READ_VCAP']
        del self._nodes['READ_TEMPERATURE_3']
        del self._nodes['READ_FAN_SPEED_1']
        del self._nodes['READ_FAN_SPEED_2']
        del self._nodes['READ_FAN_SPEED_3']
        del self._nodes['READ_FAN_SPEED_4']
        del self._nodes['READ_DUTY_CYCLE']
        del self._nodes['MFR_REVISION']
        del self._nodes['MFR_LOCATION']
        del self._nodes['MFR_DATE']
        del self._nodes['MFR_SERIAL']

        # NOTE: string commands MFR_ID and MFR_MODEL do not work correctly

        # ---------------------------
        # Remote variables
        # ---------------------------
        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'PAGE_PLUS_WRITE',
        #     offset       = (4*0x05),
        #     bitSize      = 8,
        #     mode         = 'WO',
        # ))

        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'PAGE_PLUS_READ',
        #     offset       = (4*0x06),
        #     bitSize      = 8,
        #     mode         = 'RW',
        # ))

        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'SMBALERT_MASK',
        #     offset       = (4*0x1B),
        #     bitSize      = 8,
        #     mode         = 'RW',
        # ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_VOUT_MAX',
            offset       = (4*0xA5),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_PIN_ACCURACY',
            offset       = (4*0xAC),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'USER_DATA_00',
            offset       = (4*0xB0),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'USER_DATA_01',
            offset       = (4*0xB1),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'USER_DATA_02',
            offset       = (4*0xB2),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'USER_DATA_03',
            offset       = (4*0xB3),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'USER_DATA_04',
            offset       = (4*0xB4),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_CHAN_CONFIG',
            offset       = (4*0xD0),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_CONFIG_ALL',
            offset       = (4*0xD1),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_FAULT_PROPAGATE',
            offset       = (4*0xD2),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_PWM_COMP',
            offset       = (4*0xD3),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_PWM_MODE',
            offset       = (4*0xD4),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_FAULT_RESPONSE',
            offset       = (4*0xD5),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_OT_FAULT_RESPONSE',
            offset       = (4*0xD6),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_IOUT_PEAK',
            offset       = (4*0xD7),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_ADC_CONTROL',
            offset       = (4*0xD8),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_IOUT_CAL_GAIN',
            offset       = (4*0xDA),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_RETRY_DELAY',
            offset       = (4*0xDB),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_RESTART_DELAY',
            offset       = (4*0xDC),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_VOUT_PEAK',
            offset       = (4*0xDD),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_VIN_PEAK',
            offset       = (4*0xDE),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_TEMPERATURE_1_PEAK',
            offset       = (4*0xDF),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_READ_IIN_PEAK',
            offset       = (4*0xE1),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name         = 'MFR_CLEAR_PEAKS',
            offset       = (4*0xE3),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_READ_ICHIP',
            offset       = (4*0xE4),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_PADS',
            offset       = (4*0xE5),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_ADDRESS',
            offset       = (4*0xE6),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_SPECIAL_ID',
            offset       = (4*0xE7),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_IIN_CAL_GAIN',
            offset       = (4*0xE8),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteCommand(
            name         = 'MFR_FAULT_LOG_STORE',
            offset       = (4*0xEA),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteCommand(
            name         = 'MFR_FAULT_LOG_CLEAR',
            offset       = (4*0xEC),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        ))

        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'MFR_FAULT_LOG',
        #     offset       = (4*0xEE),
        #     bitSize      = 32,
        #     mode         = 'RO',
        # ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_COMMON',
            offset       = (4*0xEF),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name         = 'MFR_COMPARE_USER_ALL',
            offset       = (4*0xF0),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_TEMPERATURE_2_PEAK',
            offset       = (4*0xF4),
            bitSize      = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_PWM_CONFIG',
            offset       = (4*0xF5),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_IOUT_CAL_GAIN_TC',
            offset       = (4*0xF6),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_RVIN',
            offset       = (4*0xF7),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_TEMP_1_GAIN',
            offset       = (4*0xF8),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_TEMP_1_OFFSET',
            offset       = (4*0xF9),
            bitSize      = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MFR_RAIL_ADDRESS',
            offset       = (4*0xFA),
            bitSize      = 8,
            mode         = 'RW',
        ))

        # # NOTE: Block command not working
        # self.add(pr.RemoteVariable(
        #     name         = 'MFR_REAL_TIME',
        #     offset       = (4*0xFB),
        #     bitSize      = 32,
        #     mode         = 'RO',
        # ))

        self.add(pr.RemoteCommand(
            name         = 'MFR_RESET',
            offset       = (4*0xFD),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        ))

        # ---------------------------
        # Linked variables
        # ---------------------------
        self.add(pr.LinkVariable(
            name         = 'Vin',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_VIN],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'VinPeak',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_VIN_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Iin',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_IIN],
            pollInterval = 1,
        ))
        self.add(pr.LinkVariable(
            name         = 'IinPeak',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_READ_IIN_PEAK],
        ))

        self.add(pr.LinkVariable(
            name         = 'Pin',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_PIN],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Vout',
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
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear16uDataFormat,
            dependencies = [self.VOUT_MODE, self.MFR_VOUT_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'VoutMax',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = getLinear16uDataFormat,
            dependencies = [self.VOUT_MODE, self.MFR_VOUT_MAX],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Iout',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_IOUT],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'IoutPeak',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_IOUT_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Pout',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_POUT],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Ichip',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_READ_ICHIP],
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature1',
            mode         = 'RO',
            units        = '°C',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_TEMPERATURE_1],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature1Peak',
            mode         = 'RO',
            units        = '°C',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_TEMPERATURE_1_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature2',
            mode         = 'RO',
            units        = '°C',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_TEMPERATURE_2],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature2Peak',
            mode         = 'RO',
            units        = '°C',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_TEMPERATURE_2_PEAK],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'Frequency',
            mode         = 'RO',
            units        = 'kHz',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.READ_FREQUENCY],
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = 'IoutCalGainConverted',
            mode         = 'RO',
            units        = 'mΩ',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_IOUT_CAL_GAIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'IinCalGainConverted',
            mode         = 'RO',
            units        = 'mΩ',
            disp         = '{:1.3f}',
            linkedGet    = getLinear5s11sDataFormat,
            dependencies = [self.MFR_IIN_CAL_GAIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'PinAccuracy',
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

