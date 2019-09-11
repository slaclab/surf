#!/usr/bin/env python
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
from surf.protocols.i2c._PMBus import *

def getPMbusLinearDataFormat(var):
    # Get the 16-bt RAW value
    raw = var.dependencies[0].value()
    
    # 11 bit, two's complement mantissa
    Y  = int((raw >> 0)  & 0x3FF)
    if (raw & 0x400):
        Y = -1.0*Y            
    else:
        Y = 1.0*Y
    
    # 5 bit, two's complement exponent (scaling factor)
    N  = int((raw >> 11) & 0xF)
    if (raw & 0x8000):
        N = -1.0*N
    else:
        N = 1.0*N
        
    # X is the 'real world' value
    X = Y*(2**N)
    return X
