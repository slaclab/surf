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
# - Sweep: Generic 68x64 and production PI 96x95 signed-by-unsigned products.
# - Stimulus: Signed extrema, partial-limb boundaries, seeded random operands.
# - Checks: Independent full integer product and pre-shift signed128 overflow;
#   operand isolation, exact latency, held results, cancel at every stage.
# - Timing: Manually driven 8 ns clock with propagation settling after each edge.

import os
import random

import cocotb
import pytest
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test

@cocotb.test()
async def check_limb(d):
    aw, bw = int(os.environ["LIMB_A"]), int(os.environ["LIMB_B"])
    latency = 2*((bw+16)//17)+1
    mask = (1 << (aw+bw))-1

    async def edge():
        d.clk.value = 0
        await Timer(4, unit="ns")
        d.clk.value = 1
        await Timer(4, unit="ns")

    for name in ("rst", "cancel", "inputValid", "resultReady", "operandA", "operandB"):
        getattr(d, name).value = 0
    d.rst.value = 1
    await edge()
    d.rst.value = 0
    await edge()
    points_a = (0, 1, -1, -(1 << (aw-1)), (1 << (aw-1))-1)
    points_b = {0, 1, (1 << bw)-1}
    for bit in range(17, bw, 17):
        points_b.update((1 << bit)+delta for delta in (-1, 0, 1))
    pairs = [(a, b) for a in points_a for b in sorted(points_b)]
    rng = random.Random(1588)
    pairs += [(rng.randrange(-(1 << (aw-1)), 1 << (aw-1)), rng.getrandbits(bw)) for _ in range(256)]
    for a, b in pairs:
        d.operandA.value, d.operandB.value = a & ((1 << aw)-1), b
        d.inputValid.value = 1
        assert int(d.inputReady.value)
        await edge()
        d.inputValid.value = 0
        d.operandA.value = (~a) & ((1 << aw)-1)
        d.operandB.value = (~b) & ((1 << bw)-1)
        for _ in range(latency):
            assert not int(d.resultValid.value)
            await edge()
        assert int(d.resultValid.value)
        assert int(d.resultValue.value) == (a*b) & mask
        assert int(d.overflow.value) == int(not -(1 << 127) <= a*b < 1 << 127)
        await edge()
        assert int(d.resultValue.value) == (a*b) & mask and int(d.resultValid.value)
        d.resultReady.value = 1
        await edge()
        d.resultReady.value = 0
    for stop in range(latency+2):
        d.inputValid.value = 1
        await edge()
        d.inputValid.value = 0
        for _ in range(stop):
            await edge()
        d.cancel.value = 1
        await edge()
        assert not int(d.resultValid.value)
        d.cancel.value = 0
        await edge()
        assert int(d.inputReady.value)


@pytest.mark.parametrize("aw,bw", [(68, 64), (96, 95)], ids=["e2e", "pi"])
def test_ptp_limb_product(aw, bw):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.PtpLimbProductWrapper",
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpLimbProductWrapper.vhd"]},
        parameters={"A_G": aw, "B_G": bw}, extra_env={"LIMB_A": aw, "LIMB_B": bw})
