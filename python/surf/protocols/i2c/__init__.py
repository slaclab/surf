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
def getPMbusLiteralDataFormat(var, read):
    # Get the 16-bt RAW value
    raw = var.dependencies[0].get(read=read)

    # 11 bit, two's complement mantissa
    Y  = pr.twosComplement( int( (raw >> 0)  & 0x7FF), 11)

    # 5 bit, two's complement exponent (scaling factor)
    N  = pr.twosComplement( int( (raw >> 11) & 0x1F), 5)

    # X is the 'real world' value
    X = Y*(2**N)
    return X

##############################################################################
# PMBus Power System Mgt Protocol Specification - Part II - Revision 1.0:
##############################################################################
# 8.2. "Linear" Output Voltage Format (LINEAR16):
# The data bytes for VOUT_COMMAND, READ_VOUT and the other VOUT_* commands
# when VOUT_MODE selects the Linear voltage data format.
def getPMbusLinearDataFormat(var, read):
    """
    PMBus Part II section 8.2 "Linear" output-voltage format (LINEAR16).
    dependencies[0] = VOUT_MODE, dependencies[1] = the VOUT_* / READ_VOUT register.
    Mantissa is a 16-bit UNSIGNED integer; exponent is 5-bit two's complement
    from VOUT_MODE[4:0]. VOUT_MODE[7:5] must be 000 (Linear); VID (001) and
    Direct (010) modes are not supported here.
    """
    voutMode = var.dependencies[0].get(read=read)
    raw      = var.dependencies[1].get(read=read)

    # Only the Linear mode (VOUT_MODE[7:5] = 000) is decoded here
    if ((voutMode >> 5) & 0x7) != 0:
        return float('nan')

    # 5 bit, two's complement exponent (scaling factor)
    N = pr.twosComplement(int(voutMode & 0x1F), 5)

    # 16 bit, unsigned mantissa: X is the 'real world' value
    return (int(raw) & 0xFFFF) * (2.0 ** N)
