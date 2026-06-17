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

# Standard PMBus commands (base class surf.protocols.i2c.PMBus) that are NOT
# supported by the Flex BMR467 (see "PMBus Command Summary" in the technical
# specification, doc 28701-BMR 467 Rev E). These are removed from the device.
NOT_IMPLEMENTED = [
    'PAGE',
    'PHASE',
    'WRITE_PROTECT',
    'STORE_DEFAULT_CODE',
    'RESTORE_DEFAULT_CODE',
    'STORE_USER_CODE',
    'RESTORE_USER_CODE',
    'CAPABILITY',
    'VOUT_SCALE_LOOP',
    'VOUT_SCALE_MONITOR',
    'POUT_MAX',
    'MAX_DUTY',
    'VIN_ON',
    'VIN_OFF',
    'IOUT_CAL_GAIN',
    'IOUT_CAL_OFFSET',
    'FAN_CONFIG_1_2',
    'FAN_COMMAND_1',
    'FAN_COMMAND_2',
    'FAN_CONFIG_3_4',
    'FAN_COMMAND_3',
    'FAN_COMMAND_4',
    'VOUT_OV_WARN_LIMIT',
    'VOUT_UV_WARN_LIMIT',
    'IOUT_OC_FAULT_RESPONSE',    # Replaced by MFR_IOUT_OC_FAULT_RESPONSE (0xE5)
    'IOUT_OC_LV_FAULT_LIMIT',
    'IOUT_OC_LV_FAULT_RESPONSE',
    'IOUT_OC_WARN_LIMIT',
    'IOUT_UC_FAULT_RESPONSE',    # Replaced by MFR_IOUT_UC_FAULT_RESPONSE (0xE6)
    'IIN_OC_FAULT_LIMIT',
    'IIN_OC_FAULT_RESPONSE',
    'IIN_OC_WARN_LIMIT',
    'POWER_GOOD_OFF',
    'TON_MAX_FAULT_LIMIT',
    'TON_MAX_FAULT_RESPONSE',
    'TOFF_MAX_WARN_LIMIT',
    'POUT_OP_FAULT_LIMIT',
    'POUT_OP_FAULT_RESPONSE',
    'POUT_OP_WARN_LIMIT',
    'PIN_OP_WARN_LIMIT',
    'STATUS_OTHER',
    'STATUS_FANS_1_2',
    'STATUS_FANS_3_4',
    'READ_IIN',
    'READ_VCAP',
    'READ_FAN_SPEED_1',
    'READ_FAN_SPEED_2',
    'READ_FAN_SPEED_3',
    'READ_FAN_SPEED_4',
    'READ_POUT',
    'READ_PIN',
]

class Bmr467(surf.protocols.i2c.PMBus):
    def __init__(self, **kwargs):
        super().__init__(notImplemented=NOT_IMPLEMENTED, **kwargs)

        literalDataFormat = surf.protocols.i2c.getPMbusLiteralDataFormat
        linearDataFormat  = surf.protocols.i2c.getPMbusLinearDataFormat

        # ---------------------------------------------------------------------
        # Manufacturer specific commands (0xAD - 0xFD)
        # See "PMBus Command Summary and Factory Default Values" and
        # "PMBus Command Details" in the BMR467 technical specification.
        #
        # NOTE: Block-format commands are not supported by the I2C/PMBus core
        # (fixed-width word/byte transfers only) and are commented out below.
        # ---------------------------------------------------------------------

        # self.add(pr.RemoteVariable(
        #     name        = 'IC_DEVICE_ID',
        #     description = 'IC manufacturer and device identification',
        #     offset      = (4*0xAD),
        #     bitSize     = 32,
        #     mode        = 'RO',
        # )) # NOTE: Read Block(4) not supported

        # self.add(pr.RemoteVariable(
        #     name        = 'IC_DEVICE_REV',
        #     description = 'IC device revision',
        #     offset      = (4*0xAE),
        #     bitSize     = 32,
        #     mode        = 'RO',
        # )) # NOTE: Read Block(4) not supported

        # self.add(pr.RemoteVariable(
        #     name        = 'USER_DATA_00',
        #     description = 'User scratchpad data register 0',
        #     offset      = (4*0xB0),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(23) not supported

        # self.add(pr.RemoteVariable(
        #     name        = 'USER_DATA_01',
        #     description = 'User scratchpad data register 1',
        #     offset      = (4*0xB1),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(8) not supported

        self.add(pr.RemoteVariable(
            name        = 'DEADTIME_MAX',
            description = 'Maximum allowed gate-drive dead time',
            offset      = (4*0xBF),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IOUT0_CAL_GAIN',
            description = 'Phase 0 output current calibration gain (sense resistance)',
            offset      = (4*0xCA),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IOUT1_CAL_GAIN',
            description = 'Phase 1 output current calibration gain (sense resistance)',
            offset      = (4*0xCB),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IOUT0_CAL_OFFSET',
            description = 'Phase 0 output current calibration offset',
            offset      = (4*0xCC),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IOUT1_CAL_OFFSET',
            description = 'Phase 1 output current calibration offset',
            offset      = (4*0xCD),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MIN_VOUT_REG',
            description = 'Minimum regulated output voltage',
            offset      = (4*0xCE),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ISENSE_CONFIG',
            description = 'Current sense configuration register',
            offset      = (4*0xD0),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'USER_CONFIG',
            description = 'User configuration register (e.g. PG push-pull / open-drain)',
            offset      = (4*0xD1),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'GCB_CONFIG',
            description = 'Group Communication Bus configuration register',
            offset      = (4*0xD3),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'POWER_GOOD_DELAY',
            description = 'Delay from Vout reaching target to Power Good (PG) assertion',
            offset      = (4*0xD4),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MULTI_PHASE_RAMP_GAIN',
            description = 'Multi-phase soft-start ramp gain',
            offset      = (4*0xD5),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'INDUCTOR',
            description = 'Output inductor value',
            offset      = (4*0xD6),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SNAPSHOT_FAULT_MASK',
            description = 'Selects which faults trigger a snapshot store to NVM',
            offset      = (4*0xD7),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'OVUV_CONFIG',
            description = 'Output over/under-voltage protection configuration',
            offset      = (4*0xD8),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'XTEMP_SCALE',
            description = 'External temperature sensor scaling factor',
            offset      = (4*0xD9),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'XTEMP_OFFSET',
            description = 'External temperature sensor offset',
            offset      = (4*0xDA),
            bitSize     = 16,
            mode        = 'RW',
        ))

        # self.add(pr.RemoteVariable(
        #     name        = 'MFR_SMBALERT_MASK',
        #     description = 'Masks which fault conditions assert the SALERT pin',
        #     offset      = (4*0xDB),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(7) not supported

        self.add(pr.RemoteVariable(
            name        = 'TEMPCO_CONFIG',
            description = 'Current sense temperature coefficient configuration',
            offset      = (4*0xDC),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DEADTIME',
            description = 'Gate-drive dead time setting',
            offset      = (4*0xDD),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DEADTIME_CONFIG',
            description = 'Gate-drive dead time configuration',
            offset      = (4*0xDE),
            bitSize     = 16,
            mode        = 'RW',
        ))

        # self.add(pr.RemoteVariable(
        #     name        = 'ASCR_CONFIG',
        #     description = 'Active State Control Response (load transient) configuration',
        #     offset      = (4*0xDF),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(4) not supported

        self.add(pr.RemoteVariable(
            name        = 'SEQUENCE',
            description = 'Output voltage sequencing configuration',
            offset      = (4*0xE0),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TRACK_CONFIG',
            description = 'Voltage tracking (VTRK) configuration',
            offset      = (4*0xE1),
            bitSize     = 8,
            mode        = 'RW',
        ))

        # self.add(pr.RemoteVariable(
        #     name        = 'GCB_GROUP',
        #     description = 'Group Communication Bus group assignment',
        #     offset      = (4*0xE2),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(4) not supported

        self.add(pr.RemoteVariable(
            name         = 'READ_IOUT1',
            description  = 'Phase 1 output current measurement',
            offset       = (4*0xE3),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        ))

        # self.add(pr.RemoteVariable(
        #     name        = 'DEVICE_ID',
        #     description = 'Device identification string',
        #     offset      = (4*0xE4),
        #     bitSize     = 32,
        #     mode        = 'RO',
        # )) # NOTE: Read Block(16) not supported

        self.add(pr.RemoteVariable(
            name        = 'MFR_IOUT_OC_FAULT_RESPONSE',
            description = 'Output over-current (peak, per phase) fault response',
            offset      = (4*0xE5),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_IOUT_UC_FAULT_RESPONSE',
            description = 'Output under-current (peak, per phase) fault response',
            offset      = (4*0xE6),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IOUT_AVG_OC_FAULT_LIMIT',
            description = 'Average output over-current fault threshold',
            offset      = (4*0xE7),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IOUT_AVG_UC_FAULT_LIMIT',
            description = 'Average output under-current fault threshold',
            offset      = (4*0xE8),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_USER_CONFIG',
            description = 'Manufacturer user configuration register',
            offset      = (4*0xE9),
            bitSize     = 16,
            mode        = 'RW',
        ))

        # self.add(pr.RemoteVariable(
        #     name        = 'SNAPSHOT',
        #     description = 'Parametric snapshot data captured at fault',
        #     offset      = (4*0xEA),
        #     bitSize     = 32,
        #     mode        = 'RO',
        # )) # NOTE: Read Block(32) not supported

        # self.add(pr.RemoteVariable(
        #     name        = 'BLANK_PARAMS',
        #     description = 'Blank/unprogrammed parameter data',
        #     offset      = (4*0xEB),
        #     bitSize     = 32,
        #     mode        = 'RO',
        # )) # NOTE: Read Block(16) not supported

        # self.add(pr.RemoteVariable(
        #     name        = 'LEGACY_FAULT_GROUP',
        #     description = 'Legacy fault group configuration',
        #     offset      = (4*0xF0),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(4) not supported

        self.add(pr.RemoteVariable(
            name         = 'READ_IOUT0',
            description  = 'Phase 0 output current measurement',
            offset       = (4*0xF2),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'SNAPSHOT_CONTROL',
            description = 'Snapshot capture control register',
            offset      = (4*0xF3),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_VMON_OV_FAULT_LIMIT',
            description = 'Voltage monitor (VMON) over-voltage fault threshold',
            offset      = (4*0xF5),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MFR_VMON_UV_FAULT_LIMIT',
            description = 'Voltage monitor (VMON) under-voltage fault threshold',
            offset      = (4*0xF6),
            bitSize     = 16,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'VMON_OV_FAULT_RESPONSE',
            description = 'Voltage monitor (VMON) over-voltage fault response',
            offset      = (4*0xF8),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'VMON_UV_FAULT_RESPONSE',
            description = 'Voltage monitor (VMON) under-voltage fault response',
            offset      = (4*0xF9),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SECURITY_LEVEL',
            description = 'Current NVM security/protection level',
            offset      = (4*0xFA),
            bitSize     = 8,
            mode        = 'RO',
        ))

        # self.add(pr.RemoteVariable(
        #     name        = 'PRIVATE_PASSWORD',
        #     description = 'Private password for NVM unprotect',
        #     offset      = (4*0xFB),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(9) not supported

        # self.add(pr.RemoteVariable(
        #     name        = 'PUBLIC_PASSWORD',
        #     description = 'Public password for NVM unprotect',
        #     offset      = (4*0xFC),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(4) not supported

        # self.add(pr.RemoteVariable(
        #     name        = 'UNPROTECT',
        #     description = 'Unprotect NVM using the supplied password',
        #     offset      = (4*0xFD),
        #     bitSize     = 32,
        #     mode        = 'RW',
        # )) # NOTE: R/W Block(32) not supported

        # ---------------------------------------------------------------------
        # Linked variables (real-world converted measurements)
        # ---------------------------------------------------------------------
        self.add(pr.LinkVariable(
            name         = 'VIN',
            description  = 'Input voltage measurement',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_VIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'VOUT',
            description  = 'Output voltage measurement',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = linearDataFormat,
            dependencies = [self.VOUT_MODE,self.READ_VOUT],
        ))
        self.VOUT_MODE._default = 0x13

        self.add(pr.LinkVariable(
            name         = 'IOUT',
            description  = 'Total output current measurement',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_IOUT],
        ))

        self.add(pr.LinkVariable(
            name         = 'IOUT_PHASE[0]',
            description  = 'Phase 0 output current measurement',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_IOUT0],
        ))

        self.add(pr.LinkVariable(
            name         = 'IOUT_PHASE[1]',
            description  = 'Phase 1 output current measurement',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_IOUT1],
        ))

        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[1]',
            description  = 'Controller temperature sensor measurement',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_TEMPERATURE_1],
        ))

        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[2]',
            description  = 'External temperature sensor 2 measurement',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_TEMPERATURE_2],
        ))

        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[3]',
            description  = 'External temperature sensor 3 measurement',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_TEMPERATURE_3],
        ))

        self.add(pr.LinkVariable(
            name         = 'DUTY_CYCLE',
            description  = 'PWM duty cycle measurement',
            mode         = 'RO',
            units        = '%',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_DUTY_CYCLE],
        ))

        self.add(pr.LinkVariable(
            name         = 'FREQUENCY',
            description  = 'Switching frequency measurement',
            mode         = 'RO',
            units        = 'kHz',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_FREQUENCY],
        ))
