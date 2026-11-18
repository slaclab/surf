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
# - Sweep: One 16-bit wrapper (`DspFixedPkgTestWrapper`) exposes every
#   DspFixedPkg function on ports. Widths are fixed; the sweep is over operand
#   values, shift counts and the seven rounding modes instead.
# - Stimulus: Drive the corner values of a 16-bit word (zero, plus and minus
#   one, full scale, the most negative value, the saturate/clamp boundaries) and
#   seeded random words through `a` and `b`, shift counts from 0 to 17 so
#   `n = width` and `n > width` are covered, and every rounding mode.
# - Checks: Every output must match an independent Python model: exact and
#   saturating |x|, saturating negate, saturation at the rails and the matching
#   in-range flag, all rounding tie rules, saturating left shift, round then
#   saturate rescale, saturating add/subtract (including mixed widths), clamp,
#   |I|+|Q|, max(|I|,|Q|), the range constants and the toFixed/toReal constants
#   evaluated at elaboration.
# - Timing: The wrapper is combinational, so each vector is sampled after a
#   1 ns settle.

import itertools
import random

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.dsp.generic.dsp_test_utils import to_unsigned, truncate_signed

WIDTH = 16

# RoundModeType'pos order
TRUNC, HALF_UP, HALF_DOWN, HALF_AWAY, HALF_ZERO, HALF_EVEN, HALF_ODD = range(7)
MODES = list(range(7))

A_CORNERS = [
    0, 1, -1, 2, -2, 3, -3, 5, -5, 0x7FFF, -0x8000, -0x7FFF, 0x7FFE,
    0x7F, 0x80, -0x80, -0x81, 0xFF, 0x100,
    1000, -1000, 1001, -1001, 999, -999,
    100, 99, 101, 60000 - 65536, 60001 - 65536, 59999 - 65536,
    0x4000, -0x4000, 0x5555, -0x5556, 0x0180, -0x0180, 0x0280, -0x0280,
]
B_CORNERS = [0, 1, -1, 0x7FFF, -0x8000, 0x7F, -0x80, 1000, -1000]
SHIFTS = [0, 1, 2, 3, 7, 8, 15, 16, 17]


def sat_s(value: int, width: int) -> int:
    return max(-(1 << (width - 1)), min((1 << (width - 1)) - 1, value))


def sat_u(value: int, width: int) -> int:
    return max(0, min((1 << width) - 1, value))


def in_range_s(value: int, width: int) -> bool:
    return sat_s(value, width) == value


def in_range_u(value: int, width: int) -> bool:
    return sat_u(value, width) == value


def shr_round(value: int, n: int, mode: int) -> int:
    if n == 0:
        return value
    # Python floor division keeps the remainder non-negative, so the discarded
    # bits compare directly with one half for negative values as well
    quotient, remainder = divmod(value, 1 << n)
    half = 1 << (n - 1)
    above = remainder > half
    tie = remainder == half
    negative = value < 0
    increment = {
        TRUNC: False,
        HALF_UP: above or tie,
        HALF_DOWN: above,
        HALF_AWAY: above or (tie and not negative),
        HALF_ZERO: above or (tie and negative),
        HALF_EVEN: above or (tie and quotient % 2 == 1),
        HALF_ODD: above or (tie and quotient % 2 == 0),
    }[mode]
    return quotient + 1 if increment else quotient


def to_fixed(value: float, width: int, frac_bits: int) -> int:
    scaled = value * (1 << frac_bits)
    # Round half away from zero, as ieee.math_real.round does
    code = int(abs(scaled) + 0.5) * (1 if scaled >= 0 else -1)
    return to_unsigned(sat_s(code, width), width)


class TB:
    def __init__(self, dut):
        self.dut = dut
        dut.a.setimmediatevalue(0)
        dut.b.setimmediatevalue(0)
        dut.n.setimmediatevalue(0)
        dut.rndMode.setimmediatevalue(0)

    async def apply(self, a: int, b: int, n: int, mode: int):
        self.dut.a.value = to_unsigned(a, WIDTH)
        self.dut.b.value = to_unsigned(b, WIDTH)
        self.dut.n.value = n
        self.dut.rndMode.value = mode
        await Timer(1, unit="ns")

    def out(self, name: str) -> int:
        return int(getattr(self.dut, name).value)


def check(tb: TB, name: str, expected: int, vector: tuple):
    observed = tb.out(name)
    assert observed == expected, (
        f"{name}(a, b, n, mode)={vector} = 0x{observed:X}, expected 0x{expected:X}"
    )


@cocotb.test()
async def constants_test(dut):
    tb = TB(dut)
    await tb.apply(0, 0, 0, 0)

    assert tb.out("maxS8") == 0x7F
    assert tb.out("minS8") == 0x80
    assert tb.out("maxU8") == 0xFF

    assert tb.out("fixedHalf") == 0x4000
    assert tb.out("fixedMinusOne") == 0x8000
    assert tb.out("fixedSatHi") == 0x7FFF
    assert tb.out("fixedSatLo") == 0x8000
    assert tb.out("fixedTenth") == 410
    assert tb.out("fixedNeg") == to_unsigned(-5, 8)
    assert tb.out("fixedTie") == 3
    assert tb.out("fixedTieNeg") == to_unsigned(-3, 8)
    assert tb.out("fixedInt") == to_unsigned(-3, 32)
    assert tb.out("fixedHalf") == to_fixed(0.5, 16, 15)
    assert tb.out("fixedTenth") == to_fixed(0.1, 16, 12)
    assert tb.out("fixedNeg") == to_fixed(-0.3, 8, 4)
    assert tb.out("toRealOk") == 1


@cocotb.test()
async def operand_sweep_test(dut):
    # Functions of a and b only: one pass over the operand pairs
    tb = TB(dut)
    rng = random.Random(0x5F1D)

    a_values = A_CORNERS + [truncate_signed(rng.getrandbits(WIDTH), WIDTH) for _ in range(40)]
    b_values = B_CORNERS + [truncate_signed(rng.getrandbits(WIDTH), WIDTH) for _ in range(8)]

    for a, b in itertools.product(a_values, b_values):
        await tb.apply(a, b, 0, 0)
        vector = (a, b, 0, 0)
        au = to_unsigned(a, WIDTH)
        bu = to_unsigned(b, WIDTH)
        b8 = truncate_signed(b, 8)

        check(tb, "absMagOut", abs(a), vector)
        check(tb, "absSatOut", to_unsigned(sat_s(abs(a), WIDTH), WIDTH), vector)
        check(tb, "negSatOut", to_unsigned(sat_s(-a, WIDTH), WIDTH), vector)

        check(tb, "satS", to_unsigned(sat_s(a, 8), 8), vector)
        check(tb, "satU", sat_u(au, 8), vector)
        check(tb, "inRangeS", int(in_range_s(a, 8)), vector)
        check(tb, "inRangeU", int(in_range_u(au, 8)), vector)

        check(tb, "addSatS", to_unsigned(sat_s(a + b, WIDTH), WIDTH), vector)
        check(tb, "subSatS", to_unsigned(sat_s(a - b, WIDTH), WIDTH), vector)
        check(tb, "addSatU", sat_u(au + bu, WIDTH), vector)
        check(tb, "subSatU", sat_u(au - bu, WIDTH), vector)
        check(tb, "addSatMix", to_unsigned(sat_s(a + b8, WIDTH), WIDTH), vector)

        check(tb, "clampS", to_unsigned(max(-1000, min(1000, a)), WIDTH), vector)
        check(tb, "clampU", max(100, min(60000, au)), vector)

        check(tb, "magL1Out", abs(a) + abs(b), vector)
        check(tb, "magLinfOut", max(abs(a), abs(b)), vector)


@cocotb.test()
async def shift_sweep_test(dut):
    # Functions of a, n and the rounding mode
    tb = TB(dut)
    rng = random.Random(0x5A1F)

    a_values = A_CORNERS + [truncate_signed(rng.getrandbits(WIDTH), WIDTH) for _ in range(40)]

    for a, n, mode in itertools.product(a_values, SHIFTS, MODES):
        await tb.apply(a, 0, n, mode)
        vector = (a, 0, n, mode)
        au = to_unsigned(a, WIDTH)

        check(tb, "shrS", to_unsigned(shr_round(a, n, mode), WIDTH), vector)
        check(tb, "shrU", shr_round(au, n, mode), vector)
        check(tb, "shlSatS", to_unsigned(sat_s(a << n, WIDTH), WIDTH), vector)
        check(tb, "shlSatU", sat_u(au << n, WIDTH), vector)
        check(tb, "rescaleS", to_unsigned(sat_s(shr_round(a, n, mode), 8), 8), vector)
        check(tb, "rescaleU", sat_u(shr_round(au, n, mode), 8), vector)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="fixed_point")])
def test_DspFixedPkg(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.dspfixedpkgtestwrapper",
        parameters=None,
        extra_vhdl_sources={
            "surf": [
                "dsp/generic/wrappers/DspFixedPkgTestWrapper.vhd",
            ]
        },
    )
