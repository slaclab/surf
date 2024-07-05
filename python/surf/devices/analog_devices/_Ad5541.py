#-----------------------------------------------------------------------------
# Title      : PyRogue _ad5541 Module
#-----------------------------------------------------------------------------
# File       : _ad5541.py
#-----------------------------------------------------------------------------
# Description:
# PyRogue module for interfacing with a AD5541 DAC.
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

class Ad5541(pr.Device):
    def __init__(self,
                 name        = 'AD5541',
                 description = 'AD5541 DAC',
                 maximum     = 0, # Sets the limit for the maximum allowed voltage from software
                 **kwargs):

        super().__init__(name=name, description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name        = 'SetValue',
            description = '16-bit DAC output value',
            offset      = 0x000,
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            maximum     = maximum,
            mode        = 'WO',
        ))
