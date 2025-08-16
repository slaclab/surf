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

class PMBus(pr.Device):
    def __init__(self, simpleDisplay = True, dynamicAddr=False, notImplemented=[], **kwargs):
        super().__init__(**kwargs)

        self.notImplemented = notImplemented.copy()

        def addPMBusVariable(**kwargs):
            if kwargs['name'] not in self.notImplemented:
                self.add(pr.RemoteVariable(hidden=simpleDisplay, **kwargs))

        def addPMBusCommand(**kwargs):
            if kwargs['name'] not in self.notImplemented:
                self.add(pr.RemoteVariable(hidden=simpleDisplay, **kwargs))


        self.add(pr.RemoteVariable(
            name         = 'i2cAddr',
            offset       =  0x400,
            bitSize      =  10,
            bitOffset    =  0,
            mode         = 'RW' if dynamicAddr else 'RO',
            hidden       = simpleDisplay,
        ))

        self.add(pr.RemoteVariable(
            name         = 'tenbit',
            offset       =  0x400,
            bitSize      =  1,
            bitOffset    =  10,
            mode         = 'RW' if dynamicAddr else 'RO',
            hidden       = simpleDisplay,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ignoreResp',
            offset       =  0x400,
            bitSize      =  1,
            bitOffset    =  11,
            mode         = 'RW',
            hidden       = simpleDisplay,
        ))

        addPMBusVariable(
            name         = 'PAGE',
            offset       = (4*0x00),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'OPERATION',
            offset       = (4*0x01),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'ON_OFF_CONFIG',
            offset       = (4*0x02),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusCommand(
            name         = 'CLEAR_FAULTS',
            offset       = (4*0x03),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        )

        addPMBusVariable(
            name         = 'PHASE',
            offset       = (4*0x04),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'WRITE_PROTECT',
            offset       = (4*0x10),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusCommand(
            name         = 'STORE_DEFAULT_ALL',
            offset       = (4*0x11),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        )

        addPMBusCommand(
            name         = 'RESTORE_DEFAULT_ALL',
            offset       = (4*0x12),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        )

        addPMBusVariable(
            name         = 'STORE_DEFAULT_CODE',
            offset       = (4*0x13),
            bitSize      = 8,
            mode         = 'WO',
        )

        addPMBusVariable(
            name         = 'RESTORE_DEFAULT_CODE',
            offset       = (4*0x14),
            bitSize      = 8,
            mode         = 'WO',
        )

        addPMBusCommand(
            name         = 'STORE_USER_ALL',
            offset       = (4*0x15),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        )

        addPMBusCommand(
            name         = 'RESTORE_USER_ALL',
            offset       = (4*0x16),
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
        )

        addPMBusVariable(
            name         = 'STORE_USER_CODE',
            offset       = (4*0x17),
            bitSize      = 8,
            mode         = 'WO',
        )

        addPMBusVariable(
            name         = 'RESTORE_USER_CODE',
            offset       = (4*0x18),
            bitSize      = 8,
            mode         = 'WO',
        )

        addPMBusVariable(
            name         = 'CAPABILITY',
            offset       = (4*0x19),
            bitSize      = 8,
            mode         = 'RO',
        )

        addPMBusVariable(
            name         = 'VOUT_MODE',
            offset       = (4*0x20),
            bitSize      = 8,
            mode         = 'RO',
        )

        addPMBusVariable(
            name         = 'VOUT_COMMAND',
            offset       = (4*0x21),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_TRIM',
            offset       = (4*0x22),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_CAL_OFFSET',
            offset       = (4*0x23),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_MAX',
            offset       = (4*0x24),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_MARGIN_HIGH',
            offset       = (4*0x25),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_MARGIN_LOW',
            offset       = (4*0x26),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_TRANSITION_RATE',
            offset       = (4*0x27),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_DROOP',
            offset       = (4*0x28),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_SCALE_LOOP',
            offset       = (4*0x29),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_SCALE_MONITOR',
            offset       = (4*0x2A),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'POUT_MAX',
            offset       = (4*0x31),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'MAX_DUTY',
            offset       = (4*0x32),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'FREQUENCY_SWITCH',
            offset       = (4*0x33),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VIN_ON',
            offset       = (4*0x35),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VIN_OFF',
            offset       = (4*0x36),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'INTERLEAVE',
            offset       = (4*0x37),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_CAL_GAIN',
            offset       = (4*0x38),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_CAL_OFFSET',
            offset       = (4*0x39),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'FAN_CONFIG_1_2',
            offset       = (4*0x3A),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'FAN_COMMAND_1',
            offset       = (4*0x3B),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'FAN_COMMAND_2',
            offset       = (4*0x3C),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'FAN_CONFIG_3_4',
            offset       = (4*0x3D),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'FAN_COMMAND_3',
            offset       = (4*0x3E),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'FAN_COMMAND_4',
            offset       = (4*0x3F),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_OV_FAULT_LIMIT',
            offset       = (4*0x40),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_OV_FAULT_RESPONSE',
            offset       = (4*0x41),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_OV_WARN_LIMIT',
            offset       = (4*0x42),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_UV_WARN_LIMIT',
            offset       = (4*0x43),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_UV_FAULT_LIMIT',
            offset       = (4*0x44),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VOUT_UV_FAULT_RESPONSE',
            offset       = (4*0x45),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_OC_FAULT_LIMIT',
            offset       = (4*0x46),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_OC_FAULT_RESPONSE',
            offset       = (4*0x47),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_OC_LV_FAULT_LIMIT',
            offset       = (4*0x48),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_OC_LV_FAULT_RESPONSE',
            offset       = (4*0x49),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_OC_WARN_LIMIT',
            offset       = (4*0x4A),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_UC_FAULT_LIMIT',
            offset       = (4*0x4B),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IOUT_UC_FAULT_RESPONSE',
            offset       = (4*0x4C),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'OT_FAULT_LIMIT',
            offset       = (4*0x4F),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'OT_FAULT_RESPONSE',
            offset       = (4*0x50),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'OT_WARN_LIMIT',
            offset       = (4*0x51),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'UT_WARN_LIMIT',
            offset       = (4*0x52),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'UT_FAULT_LIMIT',
            offset       = (4*0x53),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'UT_FAULT_RESPONSE',
            offset       = (4*0x54),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VIN_OV_FAULT_LIMIT',
            offset       = (4*0x55),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VIN_OV_FAULT_RESPONSE',
            offset       = (4*0x56),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VIN_OV_WARN_LIMIT',
            offset       = (4*0x57),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VIN_UV_WARN_LIMIT',
            offset       = (4*0x58),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VIN_UV_FAULT_LIMIT',
            offset       = (4*0x59),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'VIN_UV_FAULT_RESPONSE',
            offset       = (4*0x5A),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IIN_OC_FAULT_LIMIT',
            offset       = (4*0x5B),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IIN_OC_FAULT_RESPONSE',
            offset       = (4*0x5C),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'IIN_OC_WARN_LIMIT',
            offset       = (4*0x5D),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'POWER_GOOD_ON',
            offset       = (4*0x5E),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'POWER_GOOD_OFF',
            offset       = (4*0x5F),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'TON_DELAY',
            offset       = (4*0x60),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'TON_RISE',
            offset       = (4*0x61),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'TON_MAX_FAULT_LIMIT',
            offset       = (4*0x62),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'TON_MAX_FAULT_RESPONSE',
            offset       = (4*0x63),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'TOFF_DELAY',
            offset       = (4*0x64),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'TOFF_FALL',
            offset       = (4*0x65),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'TOFF_MAX_WARN_LIMIT',
            offset       = (4*0x66),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'POUT_OP_FAULT_LIMIT',
            offset       = (4*0x68),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'POUT_OP_FAULT_RESPONSE',
            offset       = (4*0x69),
            bitSize      = 8,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'POUT_OP_WARN_LIMIT',
            offset       = (4*0x6A),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'PIN_OP_WARN_LIMIT',
            offset       = (4*0x6B),
            bitSize      = 16,
            mode         = 'RW',
        )

        addPMBusVariable(
            name         = 'STATUS_BYTE',
            offset       = (4*0x78),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_WORD',
            offset       = (4*0x79),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_VOUT',
            offset       = (4*0x7A),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_IOUT',
            offset       = (4*0x7B),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_INPUT',
            offset       = (4*0x7C),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_TEMPERATURE',
            offset       = (4*0x7D),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_CML',
            offset       = (4*0x7E),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_OTHER',
            offset       = (4*0x7F),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_MFR_SPECIFIC',
            offset       = (4*0x80),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_FANS_1_2',
            offset       = (4*0x81),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'STATUS_FANS_3_4',
            offset       = (4*0x82),
            bitSize      = 8,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_VIN',
            offset       = (4*0x88),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_IIN',
            offset       = (4*0x89),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_VCAP',
            offset       = (4*0x8A),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_VOUT',
            offset       = (4*0x8B),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_IOUT',
            offset       = (4*0x8C),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_TEMPERATURE_1',
            offset       = (4*0x8D),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_TEMPERATURE_2',
            offset       = (4*0x8E),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_TEMPERATURE_3',
            offset       = (4*0x8F),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_FAN_SPEED_1',
            offset       = (4*0x90),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_FAN_SPEED_2',
            offset       = (4*0x91),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_FAN_SPEED_3',
            offset       = (4*0x92),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_FAN_SPEED_4',
            offset       = (4*0x93),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_DUTY_CYCLE',
            offset       = (4*0x94),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_FREQUENCY',
            offset       = (4*0x95),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_POUT',
            offset       = (4*0x96),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'READ_PIN',
            offset       = (4*0x97),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        )

        addPMBusVariable(
            name         = 'PMBUS_REVISION',
            offset       = (4*0x98),
            bitSize      = 8,
            mode         = 'RO',
        )

        addPMBusVariable(
            name         = 'MFR_ID',
            offset       = (4*0x99),
            bitSize      = 32,
            mode         = 'RO',
        )

        addPMBusVariable(
            name         = 'MFR_MODEL',
            offset       = (4*0x9A),
            bitSize      = 32,
            mode         = 'RO',
        )

        addPMBusVariable(
            name         = 'MFR_REVISION',
            offset       = (4*0x9B),
            bitSize      = 32,
            mode         = 'RO',
        )

        addPMBusVariable(
            name         = 'MFR_LOCATION',
            offset       = (4*0x9C),
            bitSize      = 32,
            mode         = 'RO',
        )

        addPMBusVariable(
            name         = 'MFR_DATE',
            offset       = (4*0x9D),
            bitSize      = 32,
            mode         = 'RO',
        )

        addPMBusVariable(
            name         = 'MFR_SERIAL',
            offset       = (4*0x9E),
            bitSize      = 32,
            mode         = 'RO',
        )
