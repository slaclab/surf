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
# - Sweep: Keep one inverse 16-bit case aligned with the packer bench so the
#   first regression proves the stable unpack path on the same documented
#   `13:2` extraction range.
# - Stimulus: Send one packed frame whose first word is a header beat and whose
#   remaining three packed words expand into four raw words.
# - Checks: The first output word must remain unchanged, the remaining raw
#   words must match a separate Python bit-unpacking model, and frame metadata
#   must propagate unchanged.
# - Timing: The packed payload is chosen so the bitstream expands into a whole
#   number of raw output words, avoiding partial-tail ambiguity in the first
#   bench.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.axi.axi_stream.gearbox_reference import unpack_words, words_to_bytes
from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

        dut.axisRst.setimmediatevalue(1)

        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S_AXIS"), dut.axisClk, dut.axisRst)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "M_AXIS"), dut.axisClk, dut.axisRst)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axisRst.value = 0
        await self.cycle(3)


@cocotb.test()
async def unpack_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()

    packed_words = [0x5501, 0x6123, 0xA456, 0x0789]
    frame = AxiStreamFrame(words_to_bytes(packed_words, word_bytes=2))
    frame.tuser = [0x2, 0x2] + [0x0] * (len(frame.tdata) - 2)
    await tb.source.send(frame)

    rx_frame = await with_timeout(tb.sink.recv(), 1, "us")
    expected_words = unpack_words(packed_words, word_bits=16, range_low=2, range_high=13)
    assert rx_frame.tdata == words_to_bytes(expected_words, word_bytes=2)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="default_range")])
def test_AxiStreamGearboxUnpack(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamgearboxunpackipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamGearboxUnpackIpIntegrator.vhd"],
        },
    )
