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

class Ltc3815(surf.protocols.i2c.PMBus):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.LinkVariable(
            name         = 'Vin',
            mode         = 'RO',
            units        = 'V',
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            linkedGet    = lambda read: self.READ_VIN.get(read=read)*4.0E-3, # Conversion factor: 4mV/Bit
            dependencies = [self.READ_VIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'Iin',
            mode         = 'RO',
            units        = 'A',
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            linkedGet    = lambda read: self.READ_IIN.get(read=read)*10.0E-3, # Conversion factor: 10mA/Bit
            dependencies = [self.READ_IIN],
        ))

        self.add(pr.LinkVariable(
            name         = 'Vout',
            mode         = 'RO',
            units        = 'V',
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            linkedGet    = lambda read: self.READ_VOUT.get(read=read)*0.5E-3, # Conversion factor: 0.5mV/Bit
            dependencies = [self.READ_VOUT],
        ))

        self.add(pr.LinkVariable(
            name         = 'Iout',
            mode         = 'RO',
            units        = 'A',
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            linkedGet    = lambda read: self.READ_IOUT.get(read=read)*10.0E-3, # Conversion factor: 10mA/Bit
            dependencies = [self.READ_IOUT],
        ))

        self.add(pr.LinkVariable(
            name         = "DieTempature",
            mode         = 'RO',
            linkedGet    = lambda read: self.READ_TEMPERATURE_1.get(read=read)*1.0, # Conversion factor: 1 degC/Bit
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            units        = 'degC',
            dependencies = [self.READ_TEMPERATURE_1],
        ))

        self.add(pr.LinkVariable(
            name         = 'Pin',
            description  = 'Power Measurement',
            mode         = 'RO',
            linkedGet    = lambda read: (self.Vin.get(read=read))*(self.Iin.get(read=read)),
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            units        = 'W',
            dependencies = [self.Vin,self.Iin],
        ))

        self.add(pr.LinkVariable(
            name         = 'Pout',
            description  = 'Power Measurement',
            mode         = 'RO',
            linkedGet    = lambda read: (self.Vout.get(read=read))*(self.Iout.get(read=read)),
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            units        = 'W',
            dependencies = [self.Vout,self.Iout],
        ))

        self.add(pr.LinkVariable(
            name         = 'Peff',
            description  = 'Power Conversion Efficiency',
            mode         = 'RO',
            linkedGet    = lambda read: 100.0*(self.Pout.get(read=read))/(self.Pin.get(read=read)) if self.Pin.get(read=read)>0.0 else 0.0,
            typeStr      = "Float32",
            disp         = '{:1.1f}',
            units        = '%',
            dependencies = [self.Pin,self.Pout],
        ))
