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

class UCD92xx(surf.protocols.i2c.PMBus):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.LinkVariable(
            name         = 'VIN',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_VIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'IIN',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_IIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'VOUT',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = surf.protocols.i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_VIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'IOUT',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_IOUT],
        ))

        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[1]',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_TEMPERATURE_1],
        ))

        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[2]',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_TEMPERATURE_2],
        ))

        self.add(pr.LinkVariable(
            name         = 'FAN_SPEED[1]',
            mode         = 'RO',
            units        = 'RPM',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_FAN_SPEED_1],
        ))

        self.add(pr.LinkVariable(
            name         = 'DUTY_CYCLE',
            mode         = 'RO',
            units        = '%',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_DUTY_CYCLE],
        ))

        self.add(pr.LinkVariable(
            name         = 'POUT',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_POUT],
        ))

        self.add(pr.LinkVariable(
            name         = 'PIN',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = self.getPMbusLinearDataFormat11Bit,
            dependencies = [self.READ_PIN],
        ))

    @staticmethod
    def getPMbusLinearDataFormat11Bit(var):
        # Get the 16-bt RAW value
        raw = var.dependencies[0].value()

        # V is a 16-bit unsigned binary integer mantissa,
        V  = 1.0*raw

        # The exponent is reported in the bottom 5 bits of the VOUT_MODE parameter.
        # In the UCD92xx, this exponent is a read-only parameter
        # whose value is fixed at –12. This allows setting voltage-related variables
        # over a range from 0 to 15.9997V, with a resolution of 0.244mV.
        X  = -12.0

        return V*(2**X)
