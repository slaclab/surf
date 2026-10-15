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
# - Sweep: Production BILLION/NOMINAL/SECOND widths and divisors, including
#   power-of-two bypass, odd-divisor rounding and the maximum 64-bit divisor.
# - Stimulus: Signed minima/maxima, ties and adjacent values, residual bands and
#   deterministic random inputs in both rounding modes.
# - Checks: Independent Python quotient and truncation-remainder oracle, operand
#   capture, held output, bounded latency, cancellation at every execution edge.
# - Timing: Manual 8 ns clock samples after the RTL propagation delay; no physical
#   timing or endpoint service-floor claim follows from a leaf simulation.

import os
import random

import cocotb
import pytest
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test

def vectors(width, divisor, count=256):
    low, high = -(1 << (width-1)), (1 << (width-1))-1
    points = {low, low+1, high, high-1, 0, 1, -1}
    for base in (divisor//2, divisor-1, divisor, 3*divisor//2,
                 1 << ((divisor-1).bit_length()-1), abs(low)//divisor*divisor):
        for delta in (-1, 0, 1, divisor//8):
            for sign in (-1, 1):
                a = sign*(base+delta)
                if low <= a <= high:
                    points.add(a)
    rng = random.Random(20261014)
    return sorted(points) + [rng.randrange(low, high+1) for _ in range(count)]


def oracle(a, d, rounded):
    sign = -1 if a < 0 else 1
    q, r = divmod(abs(a), d)
    return sign*(q+int(rounded and 2*r >= d)), sign*r


@cocotb.test()
async def check_converter(dut):
    width = int(os.environ["CONVERTER_WIDTH"])
    divisor = int(os.environ["CONVERTER_DIVISOR"])
    shift = (divisor & -divisor).bit_length()-1
    latency = 1 if divisor == 1 << shift else width-shift+1
    mask = (1 << width)-1

    async def edge():
        dut.clk.value = 0
        await Timer(4, unit="ns")
        dut.clk.value = 1
        await Timer(4, unit="ns")

    dut.rst.value = 1
    dut.cancel.value = 0
    dut.inputValid.value = 0
    dut.resultReady.value = 0
    dut.roundNearest.value = 0
    dut.operand.value = 0
    await edge()
    dut.rst.value = 0
    await edge()

    for index, a in enumerate(vectors(width, divisor)):
        for rounded in (False, True):
            assert int(dut.inputReady.value)
            dut.operand.value = a & mask
            dut.roundNearest.value = int(rounded)
            dut.inputValid.value = 1
            await edge()
            dut.inputValid.value = 0
            dut.operand.value = (~a) & mask
            dut.roundNearest.value = int(not rounded)
            for cycle in range(latency):
                assert not int(dut.resultValid.value), (divisor, cycle)
                await edge()
            assert int(dut.resultValid.value), (divisor, latency)
            q, r = oracle(a, divisor, rounded)
            trunc, _ = oracle(a, divisor, False)
            assert a == trunc*divisor+r and abs(r) < divisor
            assert int(dut.resultValue.value) == q & mask, (a, rounded)
            assert int(dut.resultRemainder.value) == r & mask, (a, rounded)
            if index % 23 == 0:
                for _ in range(3):
                    await edge()
                    assert int(dut.resultValid.value)
                    assert int(dut.resultValue.value) == q & mask
                    assert int(dut.resultRemainder.value) == r & mask
            dut.resultReady.value = 1
            await edge()
            dut.resultReady.value = 0

    # Cancel in every stage, including publication and a held response.
    for cancel_edge in range(latency+2):
        dut.operand.value = mask
        dut.inputValid.value = 1
        await edge()
        dut.inputValid.value = 0
        for _ in range(cancel_edge):
            await edge()
        dut.cancel.value = 1
        await edge()
        assert not int(dut.resultValid.value)
        dut.cancel.value = 0
        await edge()
        assert int(dut.inputReady.value)
    dut.rst.value = 1
    await edge()
    assert not int(dut.resultValid.value)


@pytest.mark.parametrize("width,divisor", [
    pytest.param(98, 1_000_000_000, id="billion"),
    pytest.param(95, 1 << 35, id="nominal-125MHz"),
    pytest.param(95, 27_487_790_694, id="nominal-156MHz"),
    pytest.param(128, 1_000_000_000 << 16, id="second"),
    pytest.param(95, 3, id="odd"),
    pytest.param(128, (1 << 64)-1, id="max-divisor"),
])
def test_ptp_const_divide(width, divisor):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.PtpConstDivide",
        parameters={"WIDTH_G": width, "DIVISOR_G": format(divisor, "064b")},
        extra_env={"CONVERTER_WIDTH": width, "CONVERTER_DIVISOR": divisor})
