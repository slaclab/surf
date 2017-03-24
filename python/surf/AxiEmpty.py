#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiEmpty
#-----------------------------------------------------------------------------
# File       : AxiEmpty.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiEmpty
# Auto created from ../surf/axi/yaml/AxiEmpty.yaml
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'SLAC Firmware Standard Library', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue

def create(name='axiEmpty', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x0,
                         description='AxiEmpty Module as a placeholder for future module')

    return dev
