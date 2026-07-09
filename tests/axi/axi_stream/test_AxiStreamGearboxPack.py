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
# - Sweep: Keep a single 16-bit path using the default `13:2` extraction range
#   so the bench proves the documented packer behavior without broad
#   range/width exploration.
# - Stimulus: Send one frame whose first word is a header beat and whose next
#   four raw words contain payload bits to be packed into three output words.
# - Checks: The first output word must remain unchanged, the remaining output
#   words must match a separate Python bit-packing model, and frame metadata
#   must propagate unchanged.
# - Timing: The frame size is chosen so the packed portion is an exact multiple
#   of the output width, avoiding partial-word ambiguity in the initial bench.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.axi.axi_stream.gearbox_reference import pack_words, words_to_bytes
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
async def pack_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()

    raw_words = [0x5501, 0x0123, 0x0456, 0x0789, 0x0ABC]
    frame = AxiStreamFrame(words_to_bytes(raw_words, word_bytes=2))
    frame.tuser = [0x2, 0x2] + [0x0] * (len(frame.tdata) - 2)
    await tb.source.send(frame)

    rx_frame = await with_timeout(tb.sink.recv(), 1, "us")
    expected_words = pack_words(raw_words, word_bits=16, range_low=2, range_high=13)
    assert rx_frame.tdata == words_to_bytes(expected_words, word_bytes=2)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="default_range")])
def test_AxiStreamGearboxPack(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamgearboxpackipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamGearboxPackIpIntegrator.vhd"],
        },
    )
