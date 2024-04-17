#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _hmc624 Module
#-----------------------------------------------------------------------------
# File       : _hmc624.py
# Created    : 2019-07-16
# Last update: 2019-07-16
#-----------------------------------------------------------------------------
# Description:
# PyRogue _hmc624 Module
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

class AttHmc624(pr.Device):
    def __init__(self,
            name        = "AttHmc624",
            description = "Attenuator Hmc624",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name        = 'SetValue',
            description = 'Attenuation Level Active low: D0-0.5bB D1-1dB D2-2dB D3-4dB D4-8dB D5-16dB',
            offset      = 0x00,
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))
