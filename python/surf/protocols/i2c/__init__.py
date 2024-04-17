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

import pyrogue as pr

##############################################################################
# PMBus Power System Mgt Protocol Specification – Part II – Revision 1.0:
##############################################################################
# 7.1. LITERAL Data Format:
#
# The Literal Data Format is typically used for commanding and reporting the
# parameters such as the following:
#       Output Current,
#       Input Voltage,
#       Input Current,
#       Operating Temperatures,
#       Time (durations)
#       Energy Storage Capacitor Voltage.
#
# The Literal Data Format is a two byte value with:
#       An 11 bit, two’s complement mantissa
#       A 5 bit, two’s complement exponent (scaling factor)
##############################################################################
def getPMbusLiteralDataFormat(var):
    # Get the 16-bt RAW value
    raw = var.dependencies[0].value()

    # 11 bit, two's complement mantissa
    Y  = pr.twosComplement( int( (raw >> 0)  & 0x7FF), 11)

    # 5 bit, two's complement exponent (scaling factor)
    N  = pr.twosComplement( int( (raw >> 11) & 0x1F), 5)

    # X is the 'real world' value
    X = Y*(2**N)
    return X

##############################################################################
# PMBus Power System Mgt Protocol Specification – Part II – Revision 1.0:
##############################################################################
# 8.3.1. Linear Mode:
# The data bytes for the VOUT_MODE and VOUT_COMMAND when using the Linear
# voltage data format.
def getPMbusLinearDataFormat(var):
    # Get the VOUT_MODE and VOUT_COMMAND
    voutMode = var.dependencies[0].value()
    voutCmd  = var.dependencies[1].value()

    # 11 bit, two's complement mantissa
    Y  = pr.twosComplement( int(voutCmd  & 0xFFFF), 11)

    # 5 bit, two's complement exponent (scaling factor)
    N  = pr.twosComplement( int(voutMode & 0x001F), 5)

    # X is the 'real world' value
    X = Y*(2**N)
    return X
