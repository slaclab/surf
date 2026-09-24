#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
"""
Flex BMR474 (BMR4743001/001) digital PoL regulator, PMBus over
surf.AxiLitePMbusMasterCore.

FIRMWARE REQUIREMENT: instantiate the core with
ACCESS_ROM_INIT_G => BMR474_ACCESS_ROM_C (surf.FlexPMbusPkg). The default
ROM has POWER_MODE (0x34) as a word and READ_MFR_VOUT (0xD4),
STATUS_PHASES (0xDC), MFR_SPECIFIC_WRITE_PROTECT (0xFB) as bytes; all four
are wrong for this part.

Paging: the part exposes PAGE 0 and PAGE 1, but "Page 1 is not used in
2-phase mode" (the standard 001 configuration). Leave PAGE = 0. All
per-page registers (READ_VOUT, READ_IOUT, STATUS_*, limits) refer to the
currently selected page.

Data formats: VIN/IIN/IOUT/temperature/POUT/PIN are LINEAR11.
VOUT is LINEAR16 with VOUT_MODE = 0x16 (exponent -10, LSB ~977 uV).

VOUT_COMMAND writes are ignored while the VSET pin-strap is in control;
set PIN_DETECT_OVERRIDE (0xEE) bit 0 first. VOUT_MAX defaults to 1.15 x
the pin-strap voltage.

PMBus address 0x72 with RSA = 5.11 kOhm (SA to VREF); see the PMBus
Addressing table for other values.

Reference: Flex technical specification 1/28701-BMR474 Rev A (May 2021).
"""

import pyrogue as pr

import surf.protocols.i2c

# Standard PMBus commands (base class surf.protocols.i2c.PMBus) that are NOT
# supported by the Flex BMR474 (see "PMBus Command Summary" in doc
# 1/28701-BMR474 Rev A). These are removed from the device.
NOT_IMPLEMENTED = [
    'CAPABILITY',
    'STORE_DEFAULT_CODE',
    'RESTORE_DEFAULT_CODE',
    'STORE_USER_CODE',
    'RESTORE_USER_CODE',
    'VOUT_CAL_OFFSET',
    'VOUT_SCALE_MONITOR',
    'POUT_MAX',
    'MAX_DUTY',
    'INTERLEAVE',
    'FAN_CONFIG_1_2',
    'FAN_COMMAND_1',
    'FAN_COMMAND_2',
    'FAN_CONFIG_3_4',
    'FAN_COMMAND_3',
    'FAN_COMMAND_4',
    'IOUT_OC_LV_FAULT_LIMIT',
    'IOUT_OC_LV_FAULT_RESPONSE',
    'UT_WARN_LIMIT',
    'UT_FAULT_LIMIT',
    'UT_FAULT_RESPONSE',
    'IIN_OC_FAULT_LIMIT',
    'IIN_OC_FAULT_RESPONSE',
    'IIN_OC_WARN_LIMIT',
    'POWER_GOOD_ON',
    'POWER_GOOD_OFF',
    'TOFF_MAX_WARN_LIMIT',
    'POUT_OP_FAULT_LIMIT',
    'POUT_OP_FAULT_RESPONSE',
    'POUT_OP_WARN_LIMIT',
    'PIN_OP_WARN_LIMIT',
    'STATUS_FANS_1_2',
    'STATUS_FANS_3_4',
    'READ_VCAP',
    'READ_TEMPERATURE_2',
    'READ_TEMPERATURE_3',
    'READ_FAN_SPEED_1',
    'READ_FAN_SPEED_2',
    'READ_FAN_SPEED_3',
    'READ_FAN_SPEED_4',
    'READ_DUTY_CYCLE',
    'READ_FREQUENCY',
    'MFR_LOCATION',
    'MFR_SERIAL',
]

class Bmr474(surf.protocols.i2c.PMBus):
    def __init__(self, simpleDisplay=True, **kwargs):
        super().__init__(simpleDisplay=simpleDisplay, notImplemented=NOT_IMPLEMENTED, **kwargs)

        literalDataFormat = surf.protocols.i2c.getPMbusLiteralDataFormat
        linearDataFormat  = surf.protocols.i2c.getPMbusLinearDataFormat

        # ---------------------------------------------------------------------
        # Standard-range commands implemented by the BMR474 but not in the
        # generic PMBus base class
        # ---------------------------------------------------------------------
        self.add(pr.RemoteVariable(
            name        = 'VOUT_MIN',
            description = 'Minimum allowed output voltage (Vout Mode / LINEAR16)',
            offset      = (4*0x2B),
            bitSize     = 16,
            mode        = 'RW',
            hidden      = simpleDisplay,
        ))

        self.add(pr.RemoteVariable(
            name        = 'POWER_MODE',
            description = 'Operating power state of the device',
            offset      = (4*0x34),
            bitSize     = 8,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )) # NOTE: requires BMR474_ACCESS_ROM_C (byte inside the 0x21-0x39 word range)

        # ---------------------------------------------------------------------
        # Manufacturer specific commands (0xAD - 0xFB)
        #
        # NOTE: Block-format commands are not supported by the I2C/PMBus core
        # (fixed-width word/byte transfers only) and are commented out below:
        #   0xAD IC_DEVICE_ID (Block6)      0xAE IC_DEVICE_REV (Block2)
        #   0xB1/B2/B4/BA/BB/BD USER_DATA_xx (Block)
        #   0xCD MULTIFUNCTION_PIN_CONFIG_1 (Block32)
        #   0xCE MULTIFUNCTION_PIN_CONFIG_2 (Block31)
        #   0xCF SMBALERT_MASK_EXTENDED (Block7)
        #   0xD1-0xD3, 0xD5-0xD8 READ_*_MIN_MAX (Block4)
        #   0xDD STATUS_EXTENDED (Block7)   0xE4 SYNC_CONFIG (Block6)
        #   0x1B SMBALERT_MASK (write-word / block process call)
        # ---------------------------------------------------------------------

        self.add(pr.RemoteVariable(
            name         = 'READ_MFR_VOUT',
            description  = 'Actual measured output voltage (Vout Mode / LINEAR16)',
            offset       = (4*0xD4),
            bitSize      = 16,
            mode         = 'RO',
            pollInterval = 1,
            hidden       = simpleDisplay,
        ))

        self.add(pr.RemoteVariable(
            name        = 'STATUS_PHASES',
            description = 'Per-phase fault status (PHASE=0xFF: bit per phase; else faults of selected phase)',
            offset      = (4*0xDC),
            bitSize     = 16,
            mode        = 'RO',
            hidden      = simpleDisplay,
        ))

        self.add(pr.RemoteVariable(
            name        = 'PIN_DETECT_OVERRIDE',
            description = 'Bit0 PD_BOOT: 0=VOUT_COMMAND from NVM, 1=from VSET pin-strap. Bit1 PD_ADDR: 0=SLAVE_ADDRESS from NVM, 1=from SA pin-strap',
            offset      = (4*0xEE),
            bitSize     = 8,
            mode        = 'RW',
            hidden      = simpleDisplay,
        ))

        self.add(pr.RemoteVariable(
            name        = 'SLAVE_ADDRESS',
            description = '7-bit PMBus slave address (bits 6:0). Writing takes effect after the next power cycle; see datasheet',
            offset      = (4*0xEF),
            bitSize     = 8,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )) # NOTE: R/W on the part; exposed RO here to prevent accidental address changes

        self.add(pr.RemoteVariable(
            name        = 'MFR_SPECIFIC_WRITE_PROTECT',
            description = 'Fine-grained write protect (bit15 WP_ALL, ...)',
            offset      = (4*0xFB),
            bitSize     = 16,
            mode        = 'RW',
            hidden      = simpleDisplay,
        ))

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
            name         = 'IIN',
            description  = 'Input current measurement',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_IIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'VOUT',
            description  = 'Output voltage measurement (selected PAGE)',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = linearDataFormat,
            dependencies = [self.VOUT_MODE, self.READ_VOUT],
        ))

        self.add(pr.LinkVariable(
            name         = 'IOUT',
            description  = 'Output current measurement (selected PAGE)',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_IOUT],
        ))

        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE',
            description  = 'Maximum power-stage temperature (selected PAGE)',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_TEMPERATURE_1],
        ))

        self.add(pr.LinkVariable(
            name         = 'POUT',
            description  = 'Calculated output power (selected PAGE)',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_POUT],
        ))

        self.add(pr.LinkVariable(
            name         = 'PIN',
            description  = 'Calculated input power',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_PIN],
        ))
