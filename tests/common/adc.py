##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""ADC coding helpers for Python stimulus and independent scoreboards.

Arguments and results are unsigned bit patterns of exactly ``bits`` bits.
Neither helper sign-extends, justifies, clips, nor changes the word width.
"""


def offset_binary_to_twos_complement(code: int, bits: int) -> int:
    """Recode an offset-binary word into a two's-complement bit pattern."""
    if bits < 1:
        raise ValueError("bits must be positive")
    if not 0 <= code < (1 << bits):
        raise ValueError("code must fit the specified unsigned bit width")
    return (code - (1 << (bits - 1))) % (1 << bits)


def twos_complement_to_offset_binary(code: int, bits: int) -> int:
    """Recode a two's-complement bit pattern into an offset-binary word."""
    if bits < 1:
        raise ValueError("bits must be positive")
    if not 0 <= code < (1 << bits):
        raise ValueError("code must fit the specified unsigned bit width")
    return (code + (1 << (bits - 1))) % (1 << bits)
