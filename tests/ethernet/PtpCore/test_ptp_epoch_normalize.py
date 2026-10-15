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
# - Sweep: Local Q16 and wire ns32 representations, full seconds48 range,
#   noncanonical subseconds, fractional carries and deterministic random values.
# - Checks: Independent integer conversion, two-cycle latency, four-cycle
#   initiation, immutable inputs, held results and reset/cancel at every stage.
# - Timing: Manual 8 ns clock; synchronous reset excludes transfers even when
#   combinational ready advertises capacity. No endpoint/timing qualification.

import os
import random

import cocotb
import pytest
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test

MASK48 = (1 << 48) - 1
SECOND = 1_000_000_000 << 16


@cocotb.test()
async def check_epoch_normalize(d):
    wire = os.environ["EPOCH_FORMAT"] == "wire"
    rng = random.Random(1588)

    async def edge():
        d.clk.value = 0
        await Timer(4, unit="ns")
        d.clk.value = 1
        await Timer(4, unit="ns")

    async def settle():
        await Timer(1, unit="ns")

    for name in ("rst", "cancel", "inputValid", "resultReady", "seconds", "subsecondQ16"):
        getattr(d, name).value = 0
    d.rst.value = 1
    await edge()
    assert not int(d.resultValid.value)
    # Ready advertises capacity before synchronous reset; no transfer occurs.
    d.rst.value = 0
    await settle()

    async def accept(seconds, subsecond):
        d.seconds.value = seconds
        d.subsecondQ16.value = subsecond
        d.inputValid.value = 1
        await settle()
        assert int(d.inputReady.value)
        await edge()
        d.inputValid.value = 0
        # Change both operands immediately; later arithmetic must use the capture.
        d.seconds.value = seconds ^ MASK48
        d.subsecondQ16.value = subsecond ^ MASK48
        assert not int(d.inputReady.value)
        assert not int(d.resultValid.value)

    async def transaction(seconds, subsecond, stalls=0):
        expected = seconds * 1_000_000_000 * 65536 + subsecond
        assert 0 <= expected < 1 << 94
        await accept(seconds, subsecond)
        await edge()
        assert not int(d.resultValid.value)
        assert not int(d.inputReady.value)
        await edge()
        assert int(d.resultValid.value)
        assert int(d.resultValue.value) == expected
        assert not int(d.inputReady.value)
        # An asserted new request while the output is held must not replace it.
        d.inputValid.value = 1
        for _ in range(stalls):
            d.seconds.value = rng.getrandbits(48)
            d.subsecondQ16.value = rng.getrandbits(48)
            await edge()
            assert not int(d.inputReady.value)
            assert int(d.resultValid.value)
            assert int(d.resultValue.value) == expected
        d.resultReady.value = 1
        await edge()
        d.inputValid.value = 0
        d.resultReady.value = 0
        await settle()
        assert not int(d.resultValid.value)
        assert int(d.inputReady.value)

    seconds_points = (0, 1, (1 << 24) - 1, 1 << 24, (1 << 47), MASK48)
    ns_points = (0, 1, 511, 512, 513, 999_999_999, 1_000_000_000, (1 << 32) - 1)
    if wire:
        # The callers zero-fill the fraction for wire timestamps, even when the
        # ns32 field is noncanonical. No rejection belongs in this arithmetic.
        subsecond_points = sorted({ns << 16 for ns in ns_points})
    else:
        subsecond_points = sorted({0, 1, 65535, 65536, SECOND - 1, SECOND,
                                   SECOND + 1, MASK48, (1 << 25) - 1, 1 << 25,
                                   (1 << 25) + 1} |
                                  {(ns << 16) | frac for ns in ns_points
                                   for frac in (0, 1, 65535)})
    for seconds in seconds_points:
        for subsecond in subsecond_points:
            await transaction(seconds, subsecond, stalls=3)
    for _ in range(512):
        subsecond = rng.getrandbits(32) << 16 if wire else rng.getrandbits(48)
        await transaction(rng.getrandbits(48), subsecond, stalls=rng.randrange(5))

    # Continuous valid/ready exercises the exact minimum initiation interval.
    d.inputValid.value = 1
    d.resultReady.value = 1
    accepted = []
    pending = None
    for cycle in range(40):
        seconds, subsecond = cycle * 17, cycle << 16
        d.seconds.value = seconds
        d.subsecondQ16.value = subsecond
        await settle()
        if int(d.resultValid.value):
            assert pending is not None
            assert int(d.resultValue.value) == pending
            pending = None
        if int(d.inputReady.value):
            assert pending is None
            pending = seconds * SECOND + subsecond
            accepted.append(cycle)
        await edge()
    assert accepted == list(range(0, 40, 4))
    assert pending is None
    d.inputValid.value = 0
    d.resultReady.value = 0

    for control in ("cancel", "rst"):
        for stop in range(5):
            await accept(MASK48, MASK48)
            for _ in range(stop):
                await edge()
            # Flush dominates an asserted replacement request and response ready.
            getattr(d, control).value = 1
            d.inputValid.value = 1
            d.resultReady.value = 1
            await settle()
            assert not int(d.inputReady.value)
            await edge()
            assert not int(d.resultValid.value)
            getattr(d, control).value = 0
            d.inputValid.value = 0
            d.resultReady.value = 0
            await settle()
            assert int(d.inputReady.value)
            await transaction(7, 123 << 16, stalls=2)
            for _ in range(4):
                await edge()
                assert not int(d.resultValid.value)

    # Flush in idle wins over a coincident input; no hidden request may emerge.
    for control in ("cancel", "rst"):
        d.inputValid.value = 1
        getattr(d, control).value = 1
        await edge()
        d.inputValid.value = 0
        getattr(d, control).value = 0
        for _ in range(4):
            await edge()
            assert not int(d.resultValid.value)
        await transaction(11, 17, stalls=1)


@pytest.mark.parametrize("timestamp_format", ("local", "wire"))
def test_ptp_epoch_normalize(timestamp_format):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.PtpEpochNormalize",
        extra_env={"EPOCH_FORMAT": timestamp_format})
