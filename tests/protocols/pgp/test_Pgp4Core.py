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
# - Sweep: Sweep four flow-control cases across the historical 1B-9B payload set.
# - Stimulus: Send incrementing frames after link-up with optional pause sources.
# - Checks: All received frames must match the transmitted payload.
# - Timing: Traffic begins only after `LINK_READY`.

import itertools

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    return list(range(1, 10))


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())
        self.source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, "S_AXIS"),
            clock=dut.AXIS_ACLK,
            reset=dut.AXIS_ARESETN,
            reset_active_level=False,
        )
        self.sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, "M_AXIS"),
            clock=dut.AXIS_ACLK,
            reset=dut.AXIS_ARESETN,
            reset_active_level=False,
        )

    def configure(self):
        if env_flag("ENABLE_IDLE_PAUSE", default=False):
            self.source.set_pause_generator(cycle_pause())
        if env_flag("ENABLE_BACKPRESSURE", default=False):
            self.sink.set_pause_generator(cycle_pause())

    async def reset(self):
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        for _ in range(2):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 0
        for _ in range(2):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(2):
            await RisingEdge(self.dut.AXIS_ACLK)
        while int(self.dut.LINK_READY.value) != 1:
            await RisingEdge(self.dut.AXIS_ACLK)


@cocotb.test()
async def pgp4_core_loopback_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.configure()
    frames = []
    for payload in [incrementing_payload(length) for length in size_list()]:
        frame = AxiStreamFrame(payload)
        await tb.source.send(frame)
        frames.append(frame)
    for frame in frames:
        rx_frame = await tb.sink.recv()
        assert rx_frame.tdata == frame.tdata
        assert len(rx_frame.tdata) == len(frame.tdata)
    assert tb.sink.empty()


PARAMETER_SWEEP = [
    parameter_case("steady_state", ENABLE_IDLE_PAUSE="0", ENABLE_BACKPRESSURE="0"),
    parameter_case("idle_pause_only", ENABLE_IDLE_PAUSE="1", ENABLE_BACKPRESSURE="0"),
    parameter_case("backpressure_only", ENABLE_IDLE_PAUSE="0", ENABLE_BACKPRESSURE="1"),
    parameter_case("idle_pause_and_backpressure", ENABLE_IDLE_PAUSE="1", ENABLE_BACKPRESSURE="1"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4Core(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.pgp4corewrapper",
        parameters={},
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/pgp/pgp4/core/wrappers/Pgp4CoreWrapper.vhd"]},
    )
