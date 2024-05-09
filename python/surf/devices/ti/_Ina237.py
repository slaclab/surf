#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class Ina237(pr.Device):
    def __init__(self,
                 pollInterval = 1,
                 senseRes     = 20.E-3, # Units of Ohms
                 **kwargs):

        super().__init__(**kwargs)

        self.add(pr.LocalVariable(
            name   = 'senseRes',
            mode   = 'RW',
            value  = senseRes,
            hidden = True,
        ))

        ##############
        # 0h CONFIG
        ##############

        self.add(pr.RemoteVariable(
            name         = 'RST',
            description  = 'Reset Bit. Setting this bit to 1 generates a system reset that is the same as power-on reset.',
            offset       = (0x0 << 2),
            bitSize      = 1,
            bitOffset    = 15,
            mode         = 'WO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CONVDLY',
            description  = 'Sets the Delay for initial ADC conversion in steps of 2 ms.',
            offset       = (0x0 << 2),
            bitSize      = 8,
            bitOffset    = 6,
            mode         = 'RW',
            units        = '2ms',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ADCRANGE',
            description  = 'Reset Bit. Setting this bit to 1 generates a system reset that is the same as power-on reset.',
            offset       = (0x0 << 2),
            bitSize      = 1,
            bitOffset    = 4,
            mode         = 'RW',
            enum      = {
                0 : '+/-163.84mV',
                1 : '+/-40.96mV',
            },
            hidden       = True,
        ))

        ##############
        # 1h ADC_CONFIG
        ##############

        self.add(pr.RemoteVariable(
            name         = 'MODE',
            description  = 'The user can set the MODE bits for continuous or triggered mode on bus voltage, shunt voltage or temperature measurement.',
            offset       = (0x1 << 2),
            bitSize      = 4,
            bitOffset    = 12,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'VBUSCT',
            description  = 'Sets the conversion time of the bus voltage measurement',
            offset       = (0x1 << 2),
            bitSize      = 3,
            bitOffset    = 9,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'VSHCT',
            description  = 'Sets the conversion time of the shunt voltage measurement',
            offset       = (0x1 << 2),
            bitSize      = 3,
            bitOffset    = 6,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'VTCT',
            description  = 'Sets the conversion time of the temperature measurement',
            offset       = (0x1 << 2),
            bitSize      = 3,
            bitOffset    = 3,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AVG',
            description  = 'Selects ADC sample averaging count. The averaging setting applies to all active inputs',
            offset       = (0x1 << 2),
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW',
            hidden       = True,
        ))

        ##############
        # 2h SHUNT_CAL
        ##############

        self.add(pr.RemoteVariable(
            name         = 'SHUNT_CAL',
            description  = 'The register provides the device with a conversion constant value that represents shunt resistance used to calculate current value in Amperes',
            offset       = (0x2 << 2),
            bitSize      = 15,
            bitOffset    = 0,
            mode         = 'RW',
            hidden       = True,
        ))


        ##############
        # 4h VSHUNT
        ##############

        self.add(pr.RemoteVariable(
            name         = 'VSHUNT',
            description  = 'Differential voltage measured across the shunt output. Twos complement value',
            offset       = (0x4 << 2),
            bitSize      = 16,
            bitOffset    = 0,
            base         = pr.Int,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True,
        ))

        ##############
        # 5h VBUS
        ##############

        self.add(pr.RemoteVariable(
            name         = 'VBUS',
            description  = 'Bus voltage output. Twos complement value, however always positive',
            offset       = (0x5 << 2),
            bitSize      = 16,
            bitOffset    = 0,
            base         = pr.Int,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True,
        ))

        ##############
        # 6h DIETEMP
        ##############

        self.add(pr.RemoteVariable(
            name         = 'DIETEMP',
            description  = 'Internal die temperature measurement. Twos complement value',
            offset       = (0x6 << 2),
            bitSize      = 12,
            bitOffset    = 4,
            base         = pr.Int,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True,
        ))

        ###############################################################################

        self.add(pr.RemoteVariable(
            name         = 'MANFID',
            description  = 'Reads back TI in ASCII (should be 0x5449)',
            offset       = (0x3E << 2),
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        ###############################################################################

        self.add(pr.LinkVariable(
            name         = 'Vin',
            description  = 'Voltage Measurement',
            mode         = 'RO',
            linkedGet    = lambda read: self.VBUS.get(read=read)*3.125E-3, # Conversion factor: 3.125 mV/LSB
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            units        = 'V',
            dependencies = [self.VBUS],
        ))

        self.add(pr.LinkVariable(
            name         = 'Iin',
            description  = 'Current Measurement',
            mode         = 'RO',
            linkedGet    = self.convCurrent,
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            units        = 'A',
            dependencies = [self.ADCRANGE,self.VSHUNT,self.senseRes],
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
            name         = "DieTempature",
            mode         = 'RO',
            linkedGet    = lambda read: self.DIETEMP.get(read=read)*0.125, # Conversion factor: 0.125 degC/LSB
            typeStr      = "Float32",
            disp         = '{:1.3f}',
            units        = 'degC',
            dependencies = [self.DIETEMP],
        ))

    @staticmethod
    def convCurrent(dev, var):
        adcRange = var.dependencies[0].get(read=False)
        if adcRange == 0:
            lsbScale = 5.0E-6 # 5 uV/LSB
        else:
            lsbScale = 1.23E-6 # 1.25 uV/LSB
        value   = var.dependencies[1].get(read=False)
        fpValue = value*lsbScale
        return (fpValue/var.dependencies[2].get(read=False))
