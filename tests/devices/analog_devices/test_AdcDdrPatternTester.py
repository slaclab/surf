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
# - Sweep: Exercise two logical channels and one FCO lane in constant,
#   alternating, and arbitrary-phase PN23 modes, followed by every terminal
#   error class.
# - Stimulus: Configure and start finite windows through the module's AXI-Lite
#   interface, provide valid sample groups with shared A/B phase and PN23
#   recurrence, inject recurrence, channel-coherence, and FCO errors, suppress
#   FCO validity, then withhold valid samples or abort.
# - Checks: Verify configuration readback, completion sequencing, common sample
#   counts, phase acquisition, channel/FCO pass masks, error counters,
#   accumulated bit-error masks, configuration errors, timeout, and abort.
# - Timing: AXI-Lite and the primitive-free checker share the capture clock;
#   gaps in sampleValid exercise the programmable no-valid timeout.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test


FRAME_PATTERN = 0b11111110000000

START_ADDR = 0x00
ABORT_ADDR = 0x04
CONFIG_ADDR = 0x08
CHANNEL_MASK_ADDR = 0x0C
FCO_MASK_ADDR = 0x10
DATA_MASK_ADDR = 0x14
PATTERN_A_ADDR = 0x18
PATTERN_B_ADDR = 0x1C
SAMPLES_ADDR = 0x20
TIMEOUT_ADDR = 0x24
STATUS_ADDR = 0x28
SEQUENCE_ADDR = 0x2C
CHECKED_ADDR = 0x30
CHANNEL_PASS_ADDR = 0x34
FCO_PASS_ADDR = 0x38
WORD_ERROR_ADDR = 0x40
BIT_ERROR_ADDR = 0x80
FCO_ERROR_ADDR = 0xC0


async def axil_poll(axil, address, predicate, limit=128):
    for _ in range(limit):
        value = await axil_read_u32(axil, address)
        if predicate(value):
            return value
    assert False, f'AXI register 0x{address:03X} did not reach expected state'


async def send_sample(dut, channel0, channel1):
    """Propagation sampling: hold each sample through the registered TPD update."""
    await FallingEdge(dut.clk)
    dut.sampleIn.value = (channel1 << 16) | channel0
    dut.sampleValid.value = 1
    await RisingEdge(dut.clk)
    await Timer(2, unit='ns')
    dut.sampleValid.value = 0


def pn23_words(state=0x654321, count=8, width=14):
    mask = (1 << 23)-1
    words = []
    for _ in range(count):
        word = 0
        for _ in range(width):
            word = (word << 1) | ((state >> 22) & 1)
            state = (
                ((state << 1) & mask) |
                (((state >> 22) ^ (state >> 17)) & 1))
        words.append(word)
    return words


async def configure(
        axil,
        *,
        alternating,
        samples,
        timeout,
        pn23=False,
        dataMask=0x3FFF,
        patternA=0x1555,
        patternB=0x2AAA):
    await axil_write_u32(axil, CONFIG_ADDR, int(alternating) | (int(pn23) << 1))
    await axil_write_u32(axil, CHANNEL_MASK_ADDR, 3)
    await axil_write_u32(axil, FCO_MASK_ADDR, 1)
    await axil_write_u32(axil, DATA_MASK_ADDR, dataMask)
    await axil_write_u32(axil, PATTERN_A_ADDR, patternA)
    await axil_write_u32(axil, PATTERN_B_ADDR, patternB)
    await axil_write_u32(axil, SAMPLES_ADDR, samples)
    await axil_write_u32(axil, TIMEOUT_ADDR, timeout)


async def start_window(axil):
    sequence = await axil_read_u32(axil, SEQUENCE_ADDR)
    await axil_write_u32(axil, START_ADDR, 1)
    await axil_poll(axil, STATUS_ADDR, lambda value: value & 1)
    return sequence


async def wait_done(axil, sequence):
    await axil_poll(axil, SEQUENCE_ADDR, lambda value: value != sequence)
    return await axil_read_u32(axil, STATUS_ADDR)


@cocotb.test()
async def pattern_tester_test(dut):
    dut.rst.value = 1
    dut.sampleValid.value = 0
    dut.sampleIn.value = 0
    dut.fcoValid.value = 1
    dut.fcoWord.value = FRAME_PATTERN
    cocotb.start_soon(Clock(dut.clk, 8, unit='ns').start())

    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, 'S_AXI'), dut.clk, dut.rst)

    # Constant mode ignores unmasked transport bits and checks both channels.
    await configure(axil, alternating=False, samples=3, timeout=100)
    await axil_write_u32(axil, DATA_MASK_ADDR, 0x3F)
    await axil_write_u32(axil, PATTERN_A_ADDR, 0x15)
    assert await axil_read_u32(axil, DATA_MASK_ADDR) == 0x3F
    sequence = await start_window(axil)
    for _ in range(3):
        await send_sample(dut, 0x3015, 0x2015)
    status = await wait_done(axil, sequence)
    assert status == 0x70
    assert await axil_read_u32(axil, CHECKED_ADDR) == 3
    assert await axil_read_u32(axil, CHANNEL_PASS_ADDR) == 3
    assert await axil_read_u32(axil, FCO_PASS_ADDR) == 1
    assert await axil_read_u32(axil, WORD_ERROR_ADDR) == 0
    assert await axil_read_u32(axil, BIT_ERROR_ADDR) == 0

    # A reference word matching neither A nor B fails every enabled channel
    # without acquiring phase. A later match acquires one group-wide phase but
    # does not erase the first sample's errors.
    await configure(axil, alternating=True, samples=2, timeout=100)
    sequence = await start_window(axil)
    await send_sample(dut, 0, 0)
    assert await axil_read_u32(axil, STATUS_ADDR) & 0x10 == 0
    await send_sample(dut, 0x2AAA, 0x2AAA)
    status = await wait_done(axil, sequence)
    assert status & 0x10
    assert await axil_read_u32(axil, WORD_ERROR_ADDR) == 1
    assert await axil_read_u32(axil, WORD_ERROR_ADDR+4) == 1
    assert await axil_read_u32(axil, BIT_ERROR_ADDR) == 0x3FFF
    assert await axil_read_u32(axil, BIT_ERROR_ADDR+4) == 0x3FFF

    # Channel 1 accumulates one exact failing bit and the FCO lane records one
    # mismatch without disturbing the shared alternating phase.
    await configure(axil, alternating=True, samples=3, timeout=100)
    sequence = await start_window(axil)
    await send_sample(dut, 0x2AAA, 0x2AAA)
    dut.fcoWord.value = FRAME_PATTERN ^ 1
    await send_sample(dut, 0x1555, 0x1551)
    dut.fcoWord.value = FRAME_PATTERN
    await send_sample(dut, 0x2AAA, 0x2AAA)
    status = await wait_done(axil, sequence)
    assert status == 0x10
    assert await axil_read_u32(axil, CHANNEL_PASS_ADDR) == 1
    assert await axil_read_u32(axil, FCO_PASS_ADDR) == 0
    assert await axil_read_u32(axil, WORD_ERROR_ADDR) == 0
    assert await axil_read_u32(axil, WORD_ERROR_ADDR+4) == 1
    assert await axil_read_u32(axil, BIT_ERROR_ADDR+4) == 4
    assert await axil_read_u32(axil, FCO_ERROR_ADDR) == 1

    # PN23 mode acquires an arbitrary nonzero 23-bit prefix, applies PatternA
    # as an input XOR mask, and then checks recurrence plus channel coherence.
    words = pn23_words()
    xorMask = 0x2000
    await configure(
        axil,
        alternating=False,
        pn23=True,
        samples=len(words),
        timeout=100,
        patternA=xorMask,
        patternB=0)
    assert await axil_read_u32(axil, CONFIG_ADDR) & 0x3 == 0x2
    sequence = await start_window(axil)
    for word in words:
        await send_sample(dut, word ^ xorMask, word ^ xorMask)
    status = await wait_done(axil, sequence)
    assert status == 0x70
    assert await axil_read_u32(axil, CHANNEL_PASS_ADDR) == 3
    assert await axil_read_u32(axil, WORD_ERROR_ADDR) == 0
    assert await axil_read_u32(axil, WORD_ERROR_ADDR+4) == 0

    # A common corruption preserves channel coherence but violates the PN23
    # recurrence on the reference channel and reports its physical bit lane.
    await configure(
        axil,
        alternating=False,
        pn23=True,
        samples=len(words),
        timeout=100,
        patternA=xorMask,
        patternB=0)
    sequence = await start_window(axil)
    for index, word in enumerate(words):
        sample = (word ^ xorMask) ^ (4 if index == 4 else 0)
        await send_sample(dut, sample, sample)
    status = await wait_done(axil, sequence)
    assert status == 0x50
    assert await axil_read_u32(axil, CHANNEL_PASS_ADDR) == 2
    assert await axil_read_u32(axil, WORD_ERROR_ADDR) >= 1
    assert await axil_read_u32(axil, BIT_ERROR_ADDR) & 4
    assert await axil_read_u32(axil, WORD_ERROR_ADDR+4) == 0

    # A relative error leaves the reference recurrence valid while identifying
    # the non-reference channel and failing bit.
    await configure(
        axil,
        alternating=False,
        pn23=True,
        samples=len(words),
        timeout=100,
        patternA=xorMask,
        patternB=0)
    sequence = await start_window(axil)
    for index, word in enumerate(words):
        sample = word ^ xorMask
        await send_sample(dut, sample, sample ^ (8 if index == 5 else 0))
    status = await wait_done(axil, sequence)
    assert status == 0x50
    assert await axil_read_u32(axil, CHANNEL_PASS_ADDR) == 1
    assert await axil_read_u32(axil, WORD_ERROR_ADDR) == 0
    assert await axil_read_u32(axil, WORD_ERROR_ADDR+4) == 1
    assert await axil_read_u32(axil, BIT_ERROR_ADDR+4) == 8

    # A selected FCO lane must be observed during the window to pass. Missing
    # fcoValid is distinct from a mismatch and therefore leaves its error count
    # at zero while clearing the FCO pass result.
    await configure(axil, alternating=False, samples=2, timeout=100)
    dut.fcoValid.value = 0
    sequence = await start_window(axil)
    for _ in range(2):
        await send_sample(dut, 0x1555, 0x1555)
    status = await wait_done(axil, sequence)
    assert status == 0x30
    assert await axil_read_u32(axil, CHANNEL_PASS_ADDR) == 3
    assert await axil_read_u32(axil, FCO_PASS_ADDR) == 0
    assert await axil_read_u32(axil, FCO_ERROR_ADDR) == 0
    dut.fcoValid.value = 1

    # A zero sample request is rejected without entering busy.
    await configure(axil, alternating=False, samples=0, timeout=100)
    sequence = await axil_read_u32(axil, SEQUENCE_ADDR)
    await axil_write_u32(axil, START_ADDR, 1)
    status = await wait_done(axil, sequence)
    assert status == 0x04

    # PN23 requires exclusive mode selection, every sample bit, and enough
    # samples to acquire its 23-bit history.
    for alternating, dataMask, samples in (
            (True, 0x3FFF, 3),
            (False, 0x3FFE, 3),
            (False, 0x3FFF, 1)):
        await configure(
            axil,
            alternating=alternating,
            pn23=True,
            samples=samples,
            timeout=100,
            dataMask=dataMask)
        sequence = await axil_read_u32(axil, SEQUENCE_ADDR)
        await axil_write_u32(axil, START_ADDR, 1)
        status = await wait_done(axil, sequence)
        assert status == 0x04

    # Three consecutive capture clocks without sampleValid terminate a window.
    await configure(axil, alternating=False, samples=2, timeout=3)
    sequence = await axil_read_u32(axil, SEQUENCE_ADDR)
    await axil_write_u32(axil, START_ADDR, 1)
    status = await wait_done(axil, sequence)
    assert status == 0x12
    assert await axil_read_u32(axil, CHECKED_ADDR) == 0

    # Abort is a distinct terminal result and leaves partial counts readable.
    await configure(axil, alternating=False, samples=2, timeout=0)
    sequence = await start_window(axil)
    await send_sample(dut, 0x1555, 0x1555)
    await axil_write_u32(axil, ABORT_ADDR, 1)
    status = await wait_done(axil, sequence)
    assert status == 0x18
    assert await axil_read_u32(axil, CHECKED_ADDR) == 1


def test_AdcDdrPatternTester():
    sources = [
        'devices/AnalogDevices/adcDdr/rtl/AdcDdrPkg.vhd',
        'devices/AnalogDevices/adcDdr/rtl/AdcDdrPatternTester.vhd',
        'devices/AnalogDevices/adcDdr/wrappers/AdcDdrPatternTesterWrapper.vhd',
    ]
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel='surf.adcddrpatterntesterwrapper',
        extra_vhdl_sources={'surf': sources},
    )
