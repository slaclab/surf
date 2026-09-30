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

Only the VIN, VOUT, IOUT and TEMPERATURE[1] measurements are exposed, and
nothing is polled: every PMBus access is slow once the core's inter-command
gaps are applied. The raw registers behind them are hidden. VOUT_MODE is a
byte and the READ_* commands are words in both PMBUS_ACCESS_ROM_INIT_C and
BMR474_ACCESS_ROM_C (surf.FlexPMbusPkg).

Paging: PAGE is not exposed. The part powers up with PAGE = 0, and "Page 1
is not used in 2-phase mode" (the standard 001 configuration). READ_VOUT,
READ_IOUT and READ_TEMPERATURE_1 refer to the currently selected page.

Data formats: VIN/IOUT/temperature are LINEAR11.
VOUT is LINEAR16 with VOUT_MODE = 0x16 (exponent -10, LSB ~977 uV).

PMBus address 0x72 with RSA = 5.11 kOhm (SA to VREF); see the PMBus
Addressing table for other values.

Reference: Flex technical specification 1/28701-BMR474 Rev A (May 2021).
"""

import pyrogue as pr

import surf.protocols.i2c

class Bmr474(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        literalDataFormat = surf.protocols.i2c.getPMbusLiteralDataFormat
        linearDataFormat  = surf.protocols.i2c.getPMbusLinearDataFormat

        # ---------------------------------------------------------------------
        # Raw PMBus registers (hidden)
        # ---------------------------------------------------------------------
        self.add(pr.RemoteVariable(
            name        = 'VOUT_MODE',
            description = 'Output voltage data format and exponent (LINEAR16)',
            offset      = (4*0x20),
            bitSize     = 8,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'READ_VIN',
            description = 'Raw input voltage measurement (LINEAR11)',
            offset      = (4*0x88),
            bitSize     = 16,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'READ_VOUT',
            description = 'Raw output voltage measurement (LINEAR16 mantissa)',
            offset      = (4*0x8B),
            bitSize     = 16,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'READ_IOUT',
            description = 'Raw output current measurement (LINEAR11)',
            offset      = (4*0x8C),
            bitSize     = 16,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'READ_TEMPERATURE_1',
            description = 'Raw maximum power-stage temperature measurement (LINEAR11)',
            offset      = (4*0x8D),
            bitSize     = 16,
            mode        = 'RO',
            hidden      = True,
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
            name         = 'VOUT',
            description  = 'Output voltage measurement (selected PAGE)',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = linearDataFormat,
            dependencies = [self.VOUT_MODE,self.READ_VOUT],
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
            name         = 'TEMPERATURE[1]',
            description  = 'Maximum power-stage temperature (selected PAGE)',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_TEMPERATURE_1],
        ))
