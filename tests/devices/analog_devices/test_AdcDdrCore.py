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
# - Sweep: Integrate two data lanes/channels and one 14-bit FCO lane with the
#   optional pattern engine both enabled and disabled.
# - Stimulus: Access the relocatable block at a nonzero absolute AXI address,
#   verify hardware-owned startup waits for delay readiness and loads every
#   configured delay, exercise the manual reset/reload path and required DDR
#   bitslip quiet interval, acquire lock, stream samples, load every delay
#   class, and snapshot sample history.
# - Checks: AXI status follows alignment, streams preserve both channels and
#   sidebands, delay requests are width-limited and read back, snapshot writes
#   reject reset state and block until publication, and AXI transactions
#   execute coherently in the capture domain; the pattern window is
#   capability-gated and reports its shared-phase result through AXI-Lite.
# - Timing: AXI-Lite is crossed as a complete bus into the capture clock domain;
#   one wide FIFO crosses coherent channel samples to the stream clock.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.axi.utils import axil_read_u32 as _axil_read_u32
from tests.axi.utils import axil_write_u32 as _axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test


AXIL_BASE_ADDR = 0xC100_0000


def negate14(value):
    return (-value) & 0x3FFF


async def axil_read_u32(axil, address):
    return await _axil_read_u32(axil, AXIL_BASE_ADDR + address)


async def axil_write_u32(axil, address, value):
    await _axil_write_u32(axil, AXIL_BASE_ADDR + address, value)


async def axil_poll(axil, address, predicate, limit=128):
    for _ in range(limit):
        value = await axil_read_u32(axil, address)
        if predicate(value):
            return value
    assert False, f"AXI register 0x{address:03X} did not reach expected state"


async def wait_load(clock, signal, mask, limit=80):
    for _ in range(limit):
        await RisingEdge(clock)
        await Timer(2, unit="ns")
        if int(signal.value) & mask:
            return
    assert False, "delay-load pulse was not observed"


@cocotb.test()
async def core_integration_test(dut):
    dut.axilRst.value = 1
    dut.captureRst.value = 1
    dut.streamRst.value = 1
    dut.delayReady.value = 0
    dut.fcoWord.value = 0b11111110000000
    dut.fcoValid.value = 0
    dut.sampleValid.value = 0
    dut.sampleIn.value = 0
    cocotb.start_soon(Clock(dut.axilClk, 5, unit="ns").start())
    cocotb.start_soon(Clock(dut.captureClk, 8, unit="ns").start())
    cocotb.start_soon(Clock(dut.streamClk, 11, unit="ns").start())

    for _ in range(5):
        await RisingEdge(dut.axilClk)
    dut.axilRst.value = 0
    dut.captureRst.value = 0
    dut.streamRst.value = 0
    await Timer(500, unit="ns")
    axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axilClk, dut.axilRst)
    await RisingEdge(dut.axilClk)
    assert int(dut.S_AXI_BVALID.value) == 0
    await Timer(200, unit="ns")
    status = await axil_read_u32(axil, 0x01C)
    assert status & 0x07 == 0
    assert await axil_read_u32(axil, 0x00C) & 0x01 == 0
    assert int(dut.phyReset.value) == 1
    response = await axil.write(AXIL_BASE_ADDR + 0x014, (0x01).to_bytes(4, 'little'))
    assert response.resp == AxiResp.SLVERR
    assert await axil_read_u32(axil, 0x024) == 0

    data_load = cocotb.start_soon(wait_load(dut.captureClk, dut.dataDelayLoad, 0x3))
    fco_load = cocotb.start_soon(wait_load(dut.captureClk, dut.fcoDelayLoad, 0x1))
    await FallingEdge(dut.captureClk)
    dut.delayReady.value = 1
    await data_load
    await fco_load
    await RisingEdge(dut.captureClk)
    await Timer(2, unit="ns")
    assert int(dut.phyReset.value) == 0

    status = await axil_read_u32(axil, 0x01C)
    assert status & 0x07 == 0x02

    # A 7-series DDR ISERDES needs three quiet CLKDIV cycles after each
    # one-cycle BITSLIP request before another request can be issued.
    await FallingEdge(dut.captureClk)
    dut.fcoWord.value = 0
    dut.fcoValid.value = 1
    slip_cycles = []
    for cycle in range(20):
        await RisingEdge(dut.captureClk)
        await Timer(2, unit="ns")
        if int(dut.bitSlip.value):
            slip_cycles.append(cycle)
            if len(slip_cycles) == 1:
                # A transient pre-settle match must not end the quiet interval.
                dut.fcoWord.value = 0b11111110000000
            if len(slip_cycles) == 3:
                break
        if len(slip_cycles) == 1 and cycle == slip_cycles[0]+1:
            dut.fcoWord.value = 0
    assert len(slip_cycles) == 3
    assert all(b-a >= 4 for a, b in zip(slip_cycles, slip_cycles[1:]))

    await FallingEdge(dut.captureClk)
    dut.fcoWord.value = 0b11111110000000
    status = await axil_poll(axil, 0x01C, lambda value: (value & 0x07) == 0x06)
    assert status & 0x07 == 0x06
    assert await axil_read_u32(axil, 0x300) == 0b11111110000000

    # Manual reset remains available, but release is also hardware sequenced
    # and reapplies every retained delay without any additional software step.
    await axil_write_u32(axil, 0x00C, 0x01)
    await axil_poll(axil, 0x01C, lambda value: (value & 0x04) == 0)
    assert int(dut.phyReset.value) == 1
    dut.delayReady.value = 0
    data_load = cocotb.start_soon(wait_load(dut.captureClk, dut.dataDelayLoad, 0x3))
    fco_load = cocotb.start_soon(wait_load(dut.captureClk, dut.fcoDelayLoad, 0x1))
    await axil_write_u32(axil, 0x00C, 0)
    for _ in range(5):
        await RisingEdge(dut.captureClk)
        await Timer(2, unit="ns")
        assert int(dut.phyReset.value) == 1
        assert int(dut.dataDelayLoad.value) == 0
        assert int(dut.fcoDelayLoad.value) == 0
    await FallingEdge(dut.captureClk)
    dut.delayReady.value = 1
    await data_load
    await fco_load
    await RisingEdge(dut.captureClk)
    await Timer(2, unit="ns")
    assert int(dut.phyReset.value) == 0
    await axil_poll(axil, 0x01C, lambda value: (value & 0x04) == 0x04)

    await FallingEdge(dut.captureClk)
    dut.sampleIn.value = 0x2345_1234
    dut.sampleValid.value = 1
    await RisingEdge(dut.captureClk)
    await Timer(2, unit="ns")
    dut.sampleValid.value = 0
    for _ in range(40):
        await FallingEdge(dut.streamClk)
        await Timer(1, unit="ns")
        if int(dut.streamValid.value) == 3:
            assert int(dut.streamData.value) == (negate14(0x2345) << 16) | negate14(0x1234)
            assert int(dut.streamKeep.value) == 0xF
            assert int(dut.streamDest.value) == 0x0100
            assert int(dut.streamLast.value) == 0
            assert int(dut.streamUser.value) == 0
            break
    else:
        assert False, "sample did not cross to stream clock"

    # Preserve sample cadence during loss of alignment and mark each affected
    # channel with ordinary AXI Stream tUser(0), without SSI framing.
    dut.fcoWord.value = 0
    await axil_poll(axil, 0x01C, lambda value: (value & 0x04) == 0)
    await FallingEdge(dut.captureClk)
    dut.sampleIn.value = 0x2567_3456
    dut.sampleValid.value = 1
    await RisingEdge(dut.captureClk)
    await Timer(2, unit="ns")
    dut.sampleValid.value = 0
    for _ in range(40):
        await FallingEdge(dut.streamClk)
        await Timer(1, unit="ns")
        if int(dut.streamValid.value) == 3:
            assert int(dut.streamData.value) == (negate14(0x2567) << 16) | negate14(0x3456)
            assert int(dut.streamLast.value) == 0
            assert int(dut.streamUser.value) == 0x0101
            break
    else:
        assert False, "unaligned sample did not cross to stream clock"

    dut.fcoWord.value = 0b11111110000000
    await axil_poll(axil, 0x01C, lambda value: (value & 0x04) == 0x04)

    # Observe each acknowledged load and feed the applied value back as the
    # logical PHY's current-delay status.
    load = cocotb.start_soon(wait_load(dut.captureClk, dut.dataDelayLoad, 1))
    await axil_write_u32(axil, 0x100, 0x12)
    await load
    assert int(dut.dataDelayValue.value) & 0xFFFF == 0x12

    # The default five-bit core must never forward discarded AXI write bits to
    # the shared nine-bit PHY command.
    load = cocotb.start_soon(wait_load(dut.captureClk, dut.dataDelayLoad, 1))
    await axil_write_u32(axil, 0x100, 0x1FF)
    await load
    assert int(dut.dataDelayValue.value) & 0xFFFF == 0x1F
    assert await axil_read_u32(axil, 0x100) == 0x1F

    load = cocotb.start_soon(wait_load(dut.captureClk, dut.dataDelayLoad, 2))
    await axil_write_u32(axil, 0x104, 0x13)
    await load

    load = cocotb.start_soon(wait_load(dut.captureClk, dut.fcoDelayLoad, 1))
    await axil_write_u32(axil, 0x200, 0x14)
    await load
    await axil_poll(axil, 0x104, lambda value: value == 0x13)
    await axil_poll(axil, 0x200, lambda value: value == 0x14)

    dut.sampleIn.value = 0x2000_1000
    snapshot = cocotb.start_soon(axil_write_u32(axil, 0x014, 0x01))
    await Timer(500, unit="ns")
    assert not snapshot.done()
    for index in range(4):
        await FallingEdge(dut.captureClk)
        dut.sampleIn.value = ((0x2000 + index) << 16) | (0x1000 + index)
        dut.sampleValid.value = 1
        await RisingEdge(dut.captureClk)
        await Timer(2, unit="ns")
        dut.sampleValid.value = 0
        if index != 3:
            assert not snapshot.done()
    await snapshot
    assert await axil_read_u32(axil, 0x024) == 1
    assert await axil_read_u32(axil, 0x600) == 0x1000
    assert await axil_read_u32(axil, 0x610) == 0x2000
    assert await axil_read_u32(axil, 0x000) == 0x00010000
    assert await axil_read_u32(axil, 0x004) == 0x0E020102
    assert await axil_read_u32(axil, 0x500) == 0
    response = await axil.read(AXIL_BASE_ADDR + 0x028, 4)
    assert response.resp == AxiResp.DECERR
    pattern_check = os.getenv('PATTERN_CHECK_G', 'true').lower() == 'true'
    assert await axil_read_u32(axil, 0x008) == (0x00010E05 if pattern_check else 0x00000E05)

    if not pattern_check:
        response = await axil.read(AXIL_BASE_ADDR + 0x800, 4)
        assert response.resp == AxiResp.DECERR
        return

    # Run one shared-phase alternating-pattern window through the integrated
    # AXI-Lite register map. Both channels acquire B first and then A.
    await axil_write_u32(axil, 0x808, 0x00000001)
    await axil_write_u32(axil, 0x80C, 0x00000003)
    await axil_write_u32(axil, 0x810, 0x00000001)
    await axil_write_u32(axil, 0x814, 0x00003FFF)
    await axil_write_u32(axil, 0x818, 0x00001555)
    await axil_write_u32(axil, 0x81C, 0x00002AAA)
    await axil_write_u32(axil, 0x820, 0x00000002)
    await axil_write_u32(axil, 0x824, 0x00000020)
    await axil_write_u32(axil, 0x800, 0x00000001)
    await axil_poll(axil, 0x828, lambda value: value & 0x01)
    for sample in (0x2AAA, 0x1555):
        await FallingEdge(dut.captureClk)
        dut.sampleIn.value = (sample << 16) | sample
        dut.sampleValid.value = 1
        await RisingEdge(dut.captureClk)
        await Timer(2, unit="ns")
        dut.sampleValid.value = 0
    await axil_poll(axil, 0x82C, lambda value: value == 1)
    assert await axil_read_u32(axil, 0x828) == 0x70
    assert await axil_read_u32(axil, 0x830) == 2
    assert await axil_read_u32(axil, 0x834) == 3
    assert await axil_read_u32(axil, 0x838) == 1
    assert await axil_read_u32(axil, 0x840) == 0
    assert await axil_read_u32(axil, 0x844) == 0
    assert await axil_read_u32(axil, 0x8C0) == 0


@pytest.mark.parametrize('pattern_check', (True, False))
def test_AdcDdrCore(pattern_check):
    sources = [
        "devices/AnalogDevices/adcDdr/rtl/AdcDdrPkg.vhd",
        "devices/AnalogDevices/adcDdr/rtl/AdcDdrPhy.vhd",
        "devices/AnalogDevices/adcDdr/rtl/AdcDdrPatternTester.vhd",
        "devices/AnalogDevices/adcDdr/rtl/AdcDdrCore.vhd",
        "devices/AnalogDevices/adcDdr/wrappers/AdcDdrCoreWrapper.vhd",
    ]
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.adcddrcorewrapper",
        parameters={
            'AXIL_BASE_ADDR_G': f'{AXIL_BASE_ADDR:032b}',
            'NEGATE_G': True,
            'PATTERN_CHECK_G': pattern_check,
        },
        extra_vhdl_sources={"surf": sources},
    )
