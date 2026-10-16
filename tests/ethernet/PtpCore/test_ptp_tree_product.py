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
# - Sweep: Production E2E signed68-by-unsigned64 registered product tree.
# - Stimulus: Signed extremes and seeded random streaming operands, stalls and
#   cancellation with in-flight tokens followed by restart/drain.
# - Checks: Independent full integer product and pre-shift signed128 overflow,
#   ordered response scoreboard, exact latency and simultaneous consume/refill.
# - Timing: Manual 8 ns clock; no physical timing claim follows from simulation.

from collections import deque
import random

import cocotb
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test

@cocotb.test()
async def check_pipeline(d):
    aw, bw, stages = 68, 64, 4
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
    d.operandA.value, d.operandB.value = (1 << aw)-3, 7
    d.inputValid.value = 1
    await edge()
    d.inputValid.value = 0
    for _ in range(stages):
        assert not int(d.resultValid.value)
        await edge()
    assert int(d.resultValid.value) and int(d.resultValue.value) == (-21) & mask
    d.resultReady.value = 1
    await edge()

    rng = random.Random(1588)
    queue = deque()
    pending = None
    completed = 0
    for cycle in range(1200):
        drain = cycle >= 1100
        cancel = not drain and cycle % 79 == 30
        ready = drain or rng.randrange(4) != 0
        if cancel:
            pending = None
        elif pending is None and not drain and rng.randrange(5) != 0:
            if cycle % 7 == 0:
                pending = (-(1 << (aw-1)), (1 << bw)-1)
            else:
                pending = (rng.randrange(-(1 << (aw-1)), 1 << (aw-1)), rng.getrandbits(bw))
        d.clk.value = 0
        d.cancel.value = int(cancel)
        d.resultReady.value = int(ready)
        d.inputValid.value = int(pending is not None)
        a, b = pending or (0, 0)
        d.operandA.value, d.operandB.value = a & ((1 << aw)-1), b
        await Timer(4, unit="ns")
        if cancel:
            queue.clear()
            assert not int(d.inputReady.value)
        else:
            if int(d.resultValid.value):
                assert queue
                expected = queue[0]
                assert int(d.resultValue.value) == expected & mask
                assert int(d.overflow.value) == int(not -(1 << 127) <= expected < 1 << 127)
                if ready:
                    queue.popleft()
                    completed += 1
            if pending is not None and int(d.inputReady.value):
                queue.append(a*b)
                pending = None
        d.clk.value = 1
        await Timer(4, unit="ns")
    assert not queue and pending is None and completed > 100


def test_ptp_tree_product():
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.PtpTreeProductWrapper",
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpTreeProductWrapper.vhd"]})
