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
# - Sweep: Signed multiply/divide, rounding, overflow, and synchronous reset.
# - Stimulus: Boundary operands and seeded independent Python integer vectors.
# - Checks: Full 128-bit result, truncation remainder, error, stable stalled output.
# - Timing: Each normal operation completes in 128 work cycles; cancel wins over
#   input and result transfers, including cancellation during a stalled result.

import random
import cocotb
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import nearest
from fractions import Fraction

MASK = (1 << 128)-1

@cocotb.test()
async def checked_arithmetic(d):
    async def edge(**inputs):
        d.clk.value = 0
        for name, value in inputs.items():
            getattr(d, name).value = value
        await Timer(3.2, unit="ns")
        d.clk.value = 1
        await Timer(3.2, unit="ns")

    for name in ("clk", "cancel", "inputValid", "divide", "operandA", "operandB", "resultReady", "roundNearest"):
        getattr(d, name).value = 0
    await edge(rst=1)
    await edge(rst=0)
    rng = random.Random(1588)
    pairs = [(0, 0), (1, 0), (-(1 << 127), -1), (-(1 << 127), 1),
             ((1 << 127)-1, 2), (3, 2), (-3, 2), (3, -2), (-3, -2),
             (1 << 100, 1 << 50), (-(1 << 80), 1 << 30)]
    pairs += [(rng.randrange(-(1 << 126), 1 << 126), rng.randrange(-(1 << 100), 1 << 100)) for _ in range(60)]
    for divide in (0, 1):
        for index, (a, b) in enumerate(pairs):
            rounding = index % 2
            await edge(inputValid=1, operandA=a & MASK, operandB=b & MASK,
                       divide=divide, roundNearest=rounding, resultReady=0)
            await edge(inputValid=0)
            for _ in range(129):
                if int(d.resultValid.value):
                    break
                await edge()
            else:
                assert False, "bounded arithmetic completion"
            if divide and b == 0:
                error = True
            else:
                trunc = (abs(a)//abs(b)) * (-1 if (a < 0) != (b < 0) else 1) if divide else 0
                expected = (nearest(Fraction(a, b)) if rounding else trunc) if divide else a*b
                error = not -(1 << 127) <= expected < (1 << 127)
                assert int(d.resultValue.value) == expected & MASK, (a, b, divide)
                assert int(d.resultRemainder.value) == ((a-trunc*b) & MASK if divide else 0)
            assert bool(d.resultError.value) == error
            old = (int(d.resultValue.value), int(d.resultError.value))
            for _ in range(3):
                await edge()
                assert int(d.resultValid.value)
                assert old == (int(d.resultValue.value), int(d.resultError.value))
            await edge(resultReady=1)
            assert int(d.inputReady.value)
    # Cancel running arithmetic and held results without publishing a transfer.
    for delay in (1, 65, 129):
        await edge(inputValid=1, divide=0, operandA=7, operandB=9, resultReady=0)
        for _ in range(delay):
            await edge(inputValid=0)
        await edge(cancel=1, resultReady=1)
        assert not int(d.resultValid.value)
        await edge(cancel=0)
        assert int(d.inputReady.value)


def test_ptp_math():
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpmath")
