##############################################################################
## This file is part of 'SLAC Firmware Standard Library'. It is subject to
## the license terms in the LICENSE.txt file found in the top-level directory
## of this distribution and at:
## https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of the 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Purpose: Terminate every open destination exactly once on link loss, even
#   when output is stalled and the link returns before the sweep completes.
# - DUT: Production depacketizer, existing flat wrapper, four destinations;
#   inferred block/distributed RAM with and without its output register.
# - Stimulus: Independent V2/NONE packets open all or selected destinations. Hold the sink
#   across link loss, return linkGood, then drain under intermittent readiness.
# - Checks: Exact application payloads before/after disconnect; held AXI beat
#   stability; one EOF+EOFE without SOF per destination; no extra output.
# - Timing: Finite monitor records pre-edge handshakes and is explicitly awaited;
#   all scenarios have a timeout. The companion Reconnect regression covers
#   CRC-enabled cleanup and fresh input arriving before terminations drain.

import os

import cocotb
import pytest
from cocotb.triggers import FallingEdge, RisingEdge

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.test_AxiStreamDepacketizer2 import TB
from tests.protocols.packetizer.packetizer_test_utils import (
    cycle, packetizer2_header_beat, packetizer2_data_beat,
    packetizer2_tail_beat, send_beats, recv_beats, assert_app_beat,
)


@cocotb.test(timeout_time=20, timeout_unit='us')
async def active_destinations_survive_link_sweep(dut):
    tb = TB(dut)
    await tb.reset()
    received = []
    mask = int(os.getenv('ACTIVE_MASK', '15'))
    active = {dest for dest in range(4) if mask & (1 << dest)}

    async def monitor():
        held = None
        for _ in range(1000):
            await RisingEdge(dut.axisClk)
            valid = int(dut.M_AXIS_TVALID.value)
            ready = int(dut.M_AXIS_TREADY.value)
            beat = tb.sink.snapshot()
            if held is not None:
                assert valid and beat == held, 'Output changed while stalled'
            held = beat if valid and not ready else None
            if valid and ready:
                received.append(beat)

    async def wait_count(count):
        for _ in range(150):
            if len(received) >= count:
                return
            await cycle(dut.axisClk)
        raise AssertionError(f'Expected {count} beats, got {received}')

    monitor_task = cocotb.start_soon(monitor())
    dut.M_AXIS_TREADY.value = 1
    for dest in range(4):
        payload = (0x12340000+dest).to_bytes(8, 'little')
        await send_beats(tb.source, [
            packetizer2_header_beat(sof=1, tuser=2, dest=dest, tid=0, seq=0),
            packetizer2_data_beat(payload),
            packetizer2_tail_beat(eof=int(dest not in active), tuser=0, byte_count=8),
        ], clk=dut.axisClk)
    await wait_count(4)
    assert [(b.data, b.dest, b.last, b.keep, b.user) for b in received] == [
        (0x12340000+d, d, int(d not in active), 255, 2) for d in range(4)]

    await FallingEdge(dut.axisClk)
    dut.M_AXIS_TREADY.value = 0
    dut.linkGood.value = 0
    await cycle(dut.axisClk, 40)
    dut.linkGood.value = 1
    await cycle(dut.axisClk, 8)
    for i in range(60):
        await FallingEdge(dut.axisClk)
        dut.M_AXIS_TREADY.value = int(i % 3 == 0)
    dut.M_AXIS_TREADY.value = 1
    await cycle(dut.axisClk, 30)
    endings = received[4:]
    dut._log.info('Termination beats: %s', endings)
    assert len(endings) == len(active), f'Expected one termination per active destination, got {endings}'
    assert sorted(b.dest for b in endings) == sorted(active)
    assert all(b.last and (b.user >> 56) & 1 and not b.user & 2 for b in endings)

    # Every destination must accept a new frame without swallowing its SOF.
    for dest in range(4):
        await send_beats(tb.source, [
            packetizer2_header_beat(sof=1, tuser=2, dest=dest, tid=0, seq=0),
            packetizer2_data_beat((0x56780000+dest).to_bytes(8, 'little')),
            packetizer2_tail_beat(eof=1, tuser=0, byte_count=8),
        ], clk=dut.axisClk)
    await wait_count(8+len(active))
    await monitor_task
    assert [(b.data, b.dest, b.last, b.keep, b.user) for b in received[4+len(active):]] == [
        (0x56780000+d, d, 1, 255, 2) for d in range(4)]


@cocotb.test(timeout_time=20, timeout_unit='us')
async def reset_during_termination(dut):
    tb = TB(dut)
    await tb.reset()
    first = cocotb.start_soon(recv_beats(tb.sink, 1, clk=dut.axisClk))
    await send_beats(tb.source, [
        packetizer2_header_beat(sof=1, tuser=2, dest=3, tid=0, seq=0),
        packetizer2_data_beat(bytes(range(8))),
        packetizer2_tail_beat(eof=0, tuser=0, byte_count=8),
    ], clk=dut.axisClk)
    received = await first
    assert_app_beat(received[0], payload=bytes(range(8)), dest=3, tid=0, user=2)
    await FallingEdge(dut.axisClk)
    dut.M_AXIS_TREADY.value = 0
    dut.linkGood.value = 0
    await cycle(dut.axisClk, 4)
    # Global reset intentionally cancels old data and any pending termination.
    dut.linkGood.value = 1
    await tb.reset()
    assert not int(dut.M_AXIS_TVALID.value)
    result = cocotb.start_soon(recv_beats(tb.sink, 1, clk=dut.axisClk))
    payload = bytes(range(16, 24))
    await send_beats(tb.source, [
        packetizer2_header_beat(sof=1, tuser=2, dest=0, tid=0, seq=0),
        packetizer2_data_beat(payload),
        packetizer2_tail_beat(eof=1, tuser=0, byte_count=8),
    ], clk=dut.axisClk)
    received = await result
    assert_app_beat(received[0], payload=payload, dest=0, tid=0, user=2, last=1)
    await cycle(dut.axisClk, 16)
    assert not int(dut.M_AXIS_TVALID.value), 'Old termination leaked across global reset'


@pytest.mark.parametrize('memory,registered', [('block', True), ('block', False),
                                               ('distributed', True), ('distributed', False)])
def test_AxiStreamDepacketizer2Recovery(memory, registered):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.axistreamdepacketizer2wrapper',
                       parameters={'TDEST_BITS_G': 2, 'MEMORY_TYPE_G': memory, 'REG_EN_G': registered},
                       extra_vhdl_sources={'surf': ['protocols/packetizer/wrappers/AxiStreamDepacketizer2Wrapper.vhd']})


@pytest.mark.parametrize('memory', ['block', 'distributed'])
def test_AxiStreamDepacketizer2RecoveryMixed(memory):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.axistreamdepacketizer2wrapper',
                       parameters={'TDEST_BITS_G': 2, 'MEMORY_TYPE_G': memory, 'REG_EN_G': memory == 'block'},
                       extra_env={'ACTIVE_MASK': 9},
                       extra_vhdl_sources={'surf': ['protocols/packetizer/wrappers/AxiStreamDepacketizer2Wrapper.vhd']})
