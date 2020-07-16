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

class EM22xx(surf.protocols.i2c.PMBus):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        literalDataFormat = surf.protocols.i2c.getPMbusLiteralDataFormat
        linearDataFormat  = surf.protocols.i2c.getPMbusLinearDataFormat

        self.add(pr.LinkVariable(
            name         = 'VIN',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_VIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'VOUT',
            mode         = 'RO',
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = linearDataFormat,
            dependencies = [self.VOUT_MODE,self.READ_VOUT],
        ))
        self.VOUT_MODE._default = 0x13

        self.add(pr.LinkVariable(
            name         = 'IOUT',
            mode         = 'RO',
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_IOUT],
        ))

        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[1]',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_TEMPERATURE_1],
        ))

        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[2]',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_TEMPERATURE_2],
        ))

        self.add(pr.LinkVariable(
            name         = 'DUTY_CYCLE',
            mode         = 'RO',
            units        = '%',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_DUTY_CYCLE],
        ))

        self.add(pr.LinkVariable(
            name         = 'FREQUENCY',
            mode         = 'RO',
            units        = 'kHz',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_FREQUENCY],
        ))

        self.add(pr.LinkVariable(
            name         = 'POUT',
            mode         = 'RO',
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = literalDataFormat,
            dependencies = [self.READ_POUT],
        ))
