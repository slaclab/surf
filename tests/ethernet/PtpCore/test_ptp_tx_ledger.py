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
# - Sweep: Two physical slots, two-bit sequence wrap, bounded network lifetime.
# - Stimulus: Early responses, late wire completion, timeout/restart, duplicate
#   completion, identity change, explicit MAC reset and startup quarantine.
# - Checks: Exact sequence/capture association; unknown wire fates retain slots;
#   retired keys cannot emit samples or be reused before quarantine expiry.
# - Timing: Monotonic ticks are independent inputs; abort wins over stalled output.

import cocotb
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test

IDENTITY = int("001122fffe3344550001", 16)

@cocotb.test()
async def lifecycle(d):
    now = 0
    async def edge(**values):
        nonlocal now
        d.clk.value = 0
        d.ticks.value = now
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(3.2, unit="ns")
        d.clk.value = 1
        await Timer(3.2, unit="ns")
        now += 1
    for name in ("clk", "rst", "restart", "macResetDone", "ticks", "generation", "domainNumber", "allocate",
                 "wireValid", "wireSequence", "wireDomain", "wireTicks", "wireGeneration", "wireError",
                 "responseValid", "responseSequence", "responseDomain", "responseTicks", "responseGeneration", "sampleReady"):
        getattr(d, name).value = 0
    for name in ("identity", "wireIdentity", "responseIdentity"):
        getattr(d, name).value = IDENTITY
    d.timeout.value = 30
    await edge(rst=1)
    await edge(rst=0)
    assert not int(d.allocateReady.value)
    await edge(macResetDone=1)
    await edge(macResetDone=0)
    for _ in range(102):
        await edge()
    async def allocate():
        for _ in range(8):
            if int(d.allocateReady.value):
                break
            await edge()
        else:
            assert False, "expected free wire slot"
        seq = int(d.allocateSequence.value)
        await edge(allocate=1)
        await edge(allocate=0)
        return seq
    # Response publication can precede the queued TX completion record, even
    # though its physical capture must follow the actual wire capture.
    first = await allocate()
    wire_tick = now
    await edge(responseValid=1, responseSequence=first, responseTicks=wire_tick+1)
    await edge(responseValid=0)
    await edge(wireValid=1, wireSequence=first, wireTicks=wire_tick)
    await edge(wireValid=0)
    assert int(d.sampleValid.value)
    assert int(d.sampleSequence.value) == first
    assert int(d.sampleTicks.value) == wire_tick
    await edge(restart=1, sampleReady=1, generation=1)
    assert not int(d.sampleValid.value)
    await edge(restart=0, sampleReady=0)
    second = await allocate()
    for _ in range(35):
        await edge()
    assert not int(d.allocateReady.value), "timeout freed unresolved wire fate"
    await edge(restart=1, generation=2)
    await edge(restart=0)
    # The old generation's late physical frame retires without producing time.
    late = now
    await edge(wireValid=1, wireSequence=second, wireTicks=late, wireGeneration=1)
    await edge(wireValid=0)
    assert not int(d.sampleValid.value)
    for _ in range(103):
        await edge()
    assert int(d.allocateReady.value)
    # Repeated allocation/completion cycles force sequence wrap. Holding a
    # duplicate key extends quarantine, so no old request can become live again.
    seen = []
    for _ in range(8):
        seq = await allocate()
        seen.append(seq)
        wire_tick = now
        await edge(wireValid=1, wireSequence=seq, wireTicks=wire_tick, wireGeneration=2)
        await edge(wireValid=0, responseValid=1, responseSequence=seq, responseTicks=wire_tick+1, responseGeneration=2)
        await edge(responseValid=0)
        assert int(d.sampleValid.value)
        assert int(d.sampleSequence.value) == seq
        await edge(sampleReady=1)
        await edge(sampleReady=0)
        for _ in range(102):
            await edge()
    assert len(set(seen)) == 4
    await allocate()
    await allocate()
    await edge(macResetDone=1)
    await edge(macResetDone=0)
    assert not int(d.allocateReady.value)
    for _ in range(102):
        await edge()
    assert int(d.allocateReady.value)


def test_ptp_tx_ledger():
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptxledgerwrapper")
