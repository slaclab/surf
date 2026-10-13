#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: 64/66/67-bit adders, carry input, every chunk boundary and 4096 seeded
#   random triples per width, including wrapped/future raw tick differences.
# - Stimulus: Combinational inputs to the actual PtpPkg functions.
# - Checks: Python unbounded integer sums masked to width; unsigned modulo-64
#   age compared strictly against the timeout, including equality and +/-1.
# - Timing: Sample after a settling interval; this fixture has no registers.

import os
import random

import cocotb
from cocotb.triggers import Timer
import pytest

from tests.common.regression_utils import run_surf_vhdl_test


async def settle():
    """Propagation sampling: settle the combinational function outputs."""
    await Timer(1, unit="ns")


@cocotb.test()
async def integer_oracles(d):
    width = int(os.environ["WIDTH"])
    mask = (1 << width)-1
    ticks_mask = (1 << 64)-1
    edges = {0, 1, mask, mask-1}
    for bit in (15, 16, 31, 32, 47, 48, 63, 64, 65, 66):
        if bit < width:
            edges.update(((1 << bit)-1, 1 << bit, (1 << bit)+1))
    rng = random.Random(1588)
    vectors = [(a, b, limit, carry) for a in sorted(edges) for b in sorted(edges)
               for limit in (((a-b) & ticks_mask), ((a-b-1) & ticks_mask), ((a-b+1) & ticks_mask))
               for carry in (0, 1)]
    vectors.extend((rng.getrandbits(width), rng.getrandbits(width), rng.getrandbits(64), rng.randrange(2))
                   for _ in range(4096))
    for a, b, limit, carry in vectors:
        d.operandA.value = a
        d.operandB.value = b
        d.timeout.value = limit
        d.carry.value = carry
        await settle()
        assert int(d.sumValue.value) == (a+b+carry) & mask, (a, b, carry)
        assert bool(int(d.expired.value)) == (((a-b) & ticks_mask) > limit), (a, b, limit)


@pytest.mark.parametrize("width", [64, 66, 67])
def test_ptp_timing_math(width):
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptimingmathwrapper",
                       parameters={"WIDTH_G": width}, extra_env={"WIDTH": width})
