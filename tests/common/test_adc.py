##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Known 1-, 8-, 14-, and 16-bit coding vectors and every 8-bit word.
# - Stimulus: Convert rails, zero, and signed extrema in both directions;
#   supply invalid widths and out-of-range bit patterns.
# - Checks: Fixed expected words, inverse round trips, and range rejection.
# - Timing: Pure Python; no simulator or clock.

import pytest

from tests.common.adc import (
    offset_binary_to_twos_complement,
    twos_complement_to_offset_binary,
)


@pytest.mark.parametrize("bits,offset,twos", [
    (1, 0, 1), (1, 1, 0),
    (8, 0x00, 0x80), (8, 0x7F, 0xFF), (8, 0x80, 0x00), (8, 0xFF, 0x7F),
    (14, 0x0000, 0x2000), (14, 0x1FFF, 0x3FFF),
    (14, 0x2000, 0x0000), (14, 0x3FFF, 0x1FFF),
    (16, 0x0000, 0x8000), (16, 0x7FFF, 0xFFFF),
    (16, 0x8000, 0x0000), (16, 0xFFFF, 0x7FFF),
])
def test_adc_coding_vectors(bits, offset, twos):
    assert offset_binary_to_twos_complement(offset, bits) == twos
    assert twos_complement_to_offset_binary(twos, bits) == offset


def test_adc_coding_round_trip():
    for code in range(256):
        twos = offset_binary_to_twos_complement(code, 8)
        assert twos_complement_to_offset_binary(twos, 8) == code
        offset = twos_complement_to_offset_binary(code, 8)
        assert offset_binary_to_twos_complement(offset, 8) == code


@pytest.mark.parametrize("convert", [
    offset_binary_to_twos_complement, twos_complement_to_offset_binary,
])
@pytest.mark.parametrize("code,bits", [(0, 0), (0, -1), (-1, 14), (0x4000, 14)])
def test_adc_coding_rejects_invalid_words(convert, code, bits):
    with pytest.raises(ValueError):
        convert(code, bits)
