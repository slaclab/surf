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
# - Sweep: Signed multiply/divide with divisor widths 128 (default), 46 (PHC),
#   and 1 (minimum); rounding, overflow, synchronous reset and cancellation.
# - Stimulus: Boundary operands and seeded independent Python integer vectors;
#   distinguish signed overflow, addition carry, selected shifted-out bits,
#   high divisor bits and both outcomes of the restoring trial subtraction.
# - Checks: Full 128-bit result, truncation remainder, error, immutable operands,
#   stable stalled output and early rejection of zero/out-of-bound divisors.
# - Registered-valid check: cancel may not change resultValid before the edge;
#   producer and consumer must exclude cancellation edges from transfers.
# - Timing: Each normal operation completes in 128 work cycles; cancel wins over
#   input and result transfers, including cancellation during a stalled result.

import random
from fractions import Fraction

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import env_int, run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import nearest

MASK = (1 << 128)-1

@cocotb.test()
async def checked_arithmetic(d):
    async def edge(check_registered=False, **inputs):
        """Propagation sampling: manual 6.4 ns clock allows the 1 ns RTL TPD."""
        before = int(d.resultValid.value) if check_registered else None
        d.clk.value = 0
        for name, value in inputs.items():
            getattr(d, name).value = value
        await Timer(3.2, unit="ns")
        if check_registered:
            assert int(d.resultValid.value) == before, "result valid changed between edges"
        d.clk.value = 1
        await Timer(3.2, unit="ns")

    for name in ("clk", "cancel", "inputValid", "divide", "operandA", "operandB", "resultReady", "roundNearest"):
        getattr(d, name).value = 0
    await edge(rst=1)
    await edge(rst=0)
    divisor_width = env_int('DIVISOR_WIDTH_G', default=128)
    rng = random.Random(1588)
    pairs = [(0, 0), (1, 0), (-(1 << 127), -1), (-(1 << 127), 1),
             ((1 << 127)-1, 2), (3, 2), (-3, 2), (3, -2), (-3, -2),
             (1 << 100, 1 << 50), (-(1 << 80), 1 << 30)]
    # Multiplicand shifts continue for all 128 iterations. Unused high bits
    # must not flag overflow; selected ones and carries must, even when the
    # wrapped low product looks small. Check both operand orders and signs.
    boundaries = [(0, -(1 << 127)), (1, -(1 << 127)),
                  (2, 1 << 126), (-2, 1 << 126),
                  (3, (1 << 127)-1), (-(1 << 127), -(1 << 127)),
                  ((1 << 100)+1, (1 << 50)+3)]
    pairs += boundaries + [(b, a) for a, b in boundaries]
    pairs += [(rng.randrange(-(1 << 126), 1 << 126), rng.randrange(-(1 << 100), 1 << 100)) for _ in range(60)]

    # Exercise the admitted divisor range even when most of the full-width
    # vectors above intentionally reject. Exact divisions, almost-full
    # remainders and half-way ties stress both trial-subtraction outcomes.
    largest_divisor = min((1 << divisor_width)-1, (1 << 127)-1)
    divisors = {1, largest_divisor, min(1 << (divisor_width-1), 1 << 126)}
    if divisor_width == 128:
        divisors.add(1 << 127)
    if divisor_width >= 46:
        divisors.add(1000000000 << 16)
    for magnitude in sorted(divisors):
        signed_divisors = (-magnitude,) if magnitude == 1 << 127 else (-magnitude, magnitude)
        for b in signed_divisors:
            for a in (-(1 << 127), (1 << 127)-1, -magnitude+1, magnitude-1,
                      -(magnitude//2), magnitude//2):
                if -(1 << 127) <= a < (1 << 127):
                    pairs.append((a, b))
    if divisor_width < 128:
        pairs += [(7, 1 << divisor_width), (-7, -(1 << divisor_width)),
                  (7, (1 << divisor_width)+1), (-7, -((1 << divisor_width)+1))]
    pairs += [(rng.randrange(-(1 << 127), 1 << 127),
               rng.randrange(-largest_divisor, largest_divisor+1)) for _ in range(40)]

    for divide in (0, 1):
        for index, (a, b) in enumerate(pairs):
            rounding = index % 2
            await edge(inputValid=1, operandA=a & MASK, operandB=b & MASK,
                       divide=divide, roundNearest=rounding, resultReady=0)
            rejected = bool(divide and (b == 0 or abs(b) >= 1 << divisor_width))
            assert bool(d.resultValid.value) == rejected, 'admission completion changed'
            await edge(inputValid=0, operandA=(~a) & MASK, operandB=(~b) & MASK,
                       divide=1-divide, roundNearest=1-rounding)
            work_cycles = 1
            for _ in range(129):
                if int(d.resultValid.value):
                    break
                await edge()
                work_cycles += 1
            else:
                assert False, "bounded arithmetic completion"
            if rejected:
                error = True
                assert int(d.resultValue.value) == 0
                assert int(d.resultRemainder.value) == 0
            else:
                assert work_cycles == 128, "arithmetic schedule changed"
                trunc = (abs(a)//abs(b)) * (-1 if (a < 0) != (b < 0) else 1) if divide else 0
                expected = (nearest(Fraction(a, b)) if rounding else trunc) if divide else a*b
                error = not -(1 << 127) <= expected < (1 << 127)
                assert int(d.resultValue.value) == expected & MASK, (a, b, divide)
                assert int(d.resultRemainder.value) == ((a-trunc*b) & MASK if divide else 0)
            assert bool(d.resultError.value) == error
            old = (int(d.resultValue.value), int(d.resultRemainder.value), int(d.resultError.value))
            for _ in range(3):
                await edge()
                assert int(d.resultValid.value)
                assert not int(d.inputReady.value)
                assert old == (int(d.resultValue.value), int(d.resultRemainder.value), int(d.resultError.value))
            await edge(resultReady=1)
            assert int(d.inputReady.value)
    # Cancel running arithmetic and held results without publishing a transfer.
    for divide in (0, 1):
        for delay in (0, 1, 65, 127, 128, 131):
            await edge(inputValid=1, divide=divide, operandA=7, operandB=1, resultReady=0)
            for _ in range(delay):
                await edge(inputValid=0)
            await edge(check_registered=True, inputValid=0, cancel=1, resultReady=1)
            assert not int(d.resultValid.value)
            await edge(cancel=0)
            assert int(d.inputReady.value)


def test_ptp_math():
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpmathwrapper",
                      extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpMathWrapper.vhd"]})


@pytest.mark.parametrize('divisor_width', [1, 46], ids=['minimum', 'phc'])
def test_ptp_math_bounded_divisor(divisor_width):
    parameters = {'DIVISOR_WIDTH_G': divisor_width}
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpmathwrapper",
                      extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpMathWrapper.vhd"]},
                      parameters=parameters, extra_env=parameters)
