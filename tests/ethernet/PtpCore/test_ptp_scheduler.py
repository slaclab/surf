#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: Seeded request intervals and accepted-response/local interval limits.
# - Stimulus: Production PtpDelayReqTx with a ready ledger, controlled raw ticks
#   and real eight-beat AXI serialization; no alternate scheduler RTL.
# - Checks: Progress, response/local interval scaling and restart determinism;
#   independent histogram/range/mean acceptance for 1588-2019 9.5.11.2(c)(1).
# - Timing: Raw ticks freeze during frame drain. Offers are measured at 1/32
#   interval resolution. MAC queueing and wire-transmission spacing are separate.
#   Only DistributionDeparture is an expected failure; build/protocol failures
#   must fail normally. Revisit the strict xfail if the chosen distribution changes.

import json
import os
from pathlib import Path

import cocotb
from cocotb.triggers import Timer
import pytest

from tests.common.regression_utils import run_surf_vhdl_test


class DistributionDeparture(AssertionError):
    pass


@cocotb.test()
async def scheduler_samples(d):
    async def edge(**values):
        d.clk.value = 0
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(4, unit='ns')
        transfer = bool(int(d.txValid.value) and int(d.txReady.value))
        last = bool(int(d.txLast.value))
        d.clk.value = 1
        await Timer(4, unit='ns')
        return transfer, last

    for name in ('clk', 'rst', 'enable', 'cancel', 'ticks', 'localInterval',
                 'seed', 'intervalValid', 'intervalTicks', 'grant', 'txReady'):
        getattr(d, name).value = 0

    async def collect(local, advertised, seed, count):
        await edge(rst=1, enable=0, txReady=0, ticks=0)
        await edge(rst=0, cancel=1, localInterval=local, seed=seed, grant=1)
        await edge(cancel=0, intervalValid=1, intervalTicks=advertised)
        await edge(intervalValid=0, enable=1)
        mean = max(local, advertised)
        quantum = mean//32
        now = previous = 0
        samples = []
        for index in range(count+1):
            for _ in range(66):
                # Registered allocation and stream publication may each take
                # a clock; raw time is fixed while those handshakes settle.
                for _ in range(4):
                    await edge(ticks=now)
                if int(d.txValid.value):
                    break
                now += quantum
            else:
                assert False, 'scheduler failed to offer within two intervals'
            if index:
                samples.append(now-previous)
            previous = now
            beats = 0
            for _ in range(16):
                transfer, last = await edge(txReady=1)
                if transfer:
                    beats += 1
                    if last:
                        break
            assert beats == 8, beats
            await edge(txReady=0)
        return samples

    if os.environ['SCENARIO'] == 'distribution':
        samples = [await collect(320000, 320000, seed, 512) for seed in (1, 0xACE1)]
        Path(os.environ['SAMPLES_PATH']).write_text(json.dumps(samples))
    else:
        baseline = await collect(320000, 0, 1, 32)
        assert set(baseline) == {160000, 320000, 480000}
        # Repeating a seed after cancellation/reset reproduces the public
        # sequence. A matched response can slow it; a smaller response cannot
        # override the configured local floor. The first request is excluded.
        assert await collect(320000, 10000, 1, 32) == baseline
        slower = await collect(320000, 1280000, 1, 32)
        assert slower == [4*x for x in baseline]
        assert await collect(320000, 0, 0, 32) == baseline


def run_scheduler(scenario, samples_path):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpdelayreqschedulewrapper',
                      extra_env={'SCENARIO': scenario, 'SAMPLES_PATH': str(samples_path)},
                      extra_vhdl_sources={'surf': ['ethernet/PtpCore/wrappers/PtpDelayReqScheduleWrapper.vhd']})


def test_scheduler_interval_policy(tmp_path):
    run_scheduler('intervals', tmp_path/'samples.json')


@pytest.mark.xfail(strict=True, raises=DistributionDeparture,
                   reason='Known 1588-2019 9.5.11.2 departure: three-point multicast schedule')
def test_default_multicast_distribution(tmp_path):
    output = tmp_path/'samples.json'
    run_scheduler('distribution', output)
    runs = json.loads(output.read_text())
    # The mean-rate requirement is supported today. Its regression is a real
    # failure, not part of the expected distribution departure below.
    for samples in runs:
        assert len(samples) == 512
        assert sum(samples)/len(samples) >= 0.9*320000
    for samples in runs:
        # Broad deterministic acceptance, not a certification statistics test.
        # The 1/32-interval observation grid is finer than the required 1/16
        # granularity when logSyncInterval equals logMinDelayReqInterval.
        mean = sum(samples)/len(samples)
        bins = {value//10000 for value in samples}
        if not (len(bins) >= 28 and min(samples) <= 40000 and max(samples) >= 600000
                and 0.9*320000 <= mean <= 1.1*320000):
            raise DistributionDeparture(
                f'bins={len(bins)}, range={min(samples)}..{max(samples)}, mean={mean}')
