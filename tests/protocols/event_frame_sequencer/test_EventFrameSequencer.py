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
# - Sweep: Exercise the default two-input/two-output mux/demux topology across
#   the historical eight-byte transition phases.
# - Stimulus: Send a transition marker on channel 0, then send one payload
#   frame on each channel.
# - Checks: Output frames must preserve payload and sideband fields.
# - Timing: The test waits for each receive in order after reset.

import logging

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


CUSTOM_LEVEL = 60
logging.addLevelName(CUSTOM_LEVEL, "CUSTOM")


def custom(self, message, *args, **kwargs):
    if self.isEnabledFor(CUSTOM_LEVEL):
        self._log(CUSTOM_LEVEL, message, args, **kwargs)


logging.Logger.custom = custom


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())
        self.sources = [
            AxiStreamSource(
                bus=AxiStreamBus.from_prefix(dut, f"S_AXIS{i}"),
                clock=dut.AXIS_ACLK,
                reset=dut.AXIS_ARESETN,
                reset_active_level=False,
            )
            for i in range(2)
        ]
        self.sinks = [
            AxiStreamSink(
                bus=AxiStreamBus.from_prefix(dut, f"M_AXIS{i}"),
                clock=dut.AXIS_ACLK,
                reset=dut.AXIS_ARESETN,
                reset_active_level=False,
            )
            for i in range(2)
        ]

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


@cocotb.test()
async def event_frame_mux_demux_test(dut):
    tb = TB(dut)
    await tb.reset()

    for phase in range(8):
        transition = AxiStreamFrame(bytearray(range(phase, 16)))
        transition.tdest = 0
        transition.tuser = phase

        payload_frames = []
        for index in range(2):
            frame = AxiStreamFrame(bytearray(range(1 + index + phase, 17)))
            frame.tdest = index + 1
            frame.tuser = phase
            payload_frames.append(frame)

        await tb.sources[0].send(transition)
        rx_transition = await tb.sinks[0].recv()
        assert rx_transition.tdata == transition.tdata
        assert rx_transition.tdest == transition.tdest
        assert rx_transition.tuser == transition.tuser
        assert tb.sinks[0].empty()

        for index, frame in enumerate(payload_frames):
            tb.log.custom(f"payload[{index}]={frame.tdata}")
            await tb.sources[index].send(frame)

        for index, frame in enumerate(payload_frames):
            rx_frame = await tb.sinks[index].recv()
            assert rx_frame.tdata == frame.tdata
            assert rx_frame.tdest == frame.tdest
            assert rx_frame.tuser == frame.tuser
            assert tb.sinks[index].empty()


PARAMETER_SWEEP = [pytest.param({}, id="default_configuration")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EventFrameSequencer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.eventframesequencerwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/event-frame-sequencer/wrappers/EventFrameSequencerWrapper.vhd"]},
    )
