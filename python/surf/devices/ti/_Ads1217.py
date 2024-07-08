#-----------------------------------------------------------------------------
# Title      : PyRogue _Ads1217 Module
#-----------------------------------------------------------------------------
# File       : _Ads1217.py
#-----------------------------------------------------------------------------
# Description:
# PyRogue module for interfacing with a ADS1217 ADC.
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

class Ads1217(pr.Device):
    def __init__(self,
                 name           = 'ADS1217',
                 description    = 'ADS1217 ADC',
                 raw_hidden     = False,
                 pga_hidden     = False,
                 num_channels   = 8,
                 **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        first_adc_data_raw_offset = 32
        first_adc_pga_value_offset = first_adc_data_raw_offset + 4 * (num_channels + 1)

        # ----------------------------------------------------------------
        # Manual ADC start control
        self.add(pr.RemoteVariable(name='adcStartEnManual', description='Manual control of the ADC start', offset=0x10, bitSize=1, bitOffset=0, base=pr.Bool, mode='RW'))

        # ----------------------------------------------------------------
        # Add all raw ADC data variables
        for i in range(num_channels):
            self.add(pr.RemoteVariable(
                name            = f'AdcDataRaw[{i}]',
                description     = f'Raw ADC data channel {i}',
                offset          = first_adc_data_raw_offset + 4 * i,
                bitSize         = 24,
                bitOffset       = 0,
                base            = pr.UInt,
                disp            = '{}',
                mode            = 'RO',
                hidden          = raw_hidden,
            ))

        # ----------------------------------------------------------------
        # Add all ADC PGA value variables
        for i in range(num_channels):
            self.add(pr.RemoteVariable(
                name            = f'AdcPgaValue[{i}]',
                description     = f'ADC PGA value channel {i}',
                offset          = first_adc_pga_value_offset + 4 * i,
                bitSize         = 3,
                bitOffset       = 0,
                base            = pr.UInt,
                disp            = '{}',
                mode            = 'RW',
                hidden          = pga_hidden,
            ))

