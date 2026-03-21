##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import itertools
import logging

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.S_AXIS_ACLK, 5.0, unit="ns").start())
        cocotb.start_soon(Clock(dut.M_AXIS_ACLK, 5.0, unit="ns").start())

        self.source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, "S_AXIS"),
            clock=dut.S_AXIS_ACLK,
            reset=dut.S_AXIS_ARESETN,
            reset_active_level=False,
        )

        self.sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, "M_AXIS"),
            clock=dut.M_AXIS_ACLK,
            reset=dut.M_AXIS_ARESETN,
            reset_active_level=False,
        )

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    async def s_cycle_reset(self):
        self.dut.S_AXIS_ARESETN.setimmediatevalue(0)
        await RisingEdge(self.dut.S_AXIS_ACLK)
        await RisingEdge(self.dut.S_AXIS_ACLK)
        self.dut.S_AXIS_ARESETN.value = 0
        await RisingEdge(self.dut.S_AXIS_ACLK)
        await RisingEdge(self.dut.S_AXIS_ACLK)
        self.dut.S_AXIS_ARESETN.value = 1
        await RisingEdge(self.dut.S_AXIS_ACLK)
        await RisingEdge(self.dut.S_AXIS_ACLK)

    async def m_cycle_reset(self):
        self.dut.M_AXIS_ARESETN.setimmediatevalue(0)
        await RisingEdge(self.dut.M_AXIS_ACLK)
        await RisingEdge(self.dut.M_AXIS_ACLK)
        self.dut.M_AXIS_ARESETN.value = 0
        await RisingEdge(self.dut.M_AXIS_ACLK)
        await RisingEdge(self.dut.M_AXIS_ACLK)
        self.dut.M_AXIS_ARESETN.value = 1
        await RisingEdge(self.dut.M_AXIS_ACLK)
        await RisingEdge(self.dut.M_AXIS_ACLK)


async def run_test(
    dut,
    payload_lengths=None,
    payload_data=None,
    idle_inserter=None,
    backpressure_inserter=None,
):
    dut._log.info(f"Found M_TDATA_NUM_BYTES={dut.M_TDATA_NUM_BYTES.value.integer}")
    dut._log.info(f"Found S_TDATA_NUM_BYTES={dut.S_TDATA_NUM_BYTES.value.integer}")

    tb = TB(dut)

    id_count = 2 ** len(tb.source.bus.tid)
    cur_id = 1

    await tb.s_cycle_reset()
    await tb.m_cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames = []
    # Drive a range of frame sizes through the configured width-conversion path
    # and then compare the received metadata and payload byte-for-byte.
    for test_data in (payload_data(length) for length in payload_lengths()):
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id
        await tb.source.send(test_frame)
        test_frames.append(test_frame)
        cur_id = (cur_id + 1) % id_count

    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()
        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser

    assert tb.sink.empty()


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    return list(range(1, 32 + 1))


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


# Prevent pytest from trying to collect cocotb's generated test factory as a
# normal Python test object during import.
TestFactory.__test__ = False

SIM_NAME = getattr(cocotb, "SIM_NAME", None)
if SIM_NAME:
    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()


PARAMETER_SWEEP = []

# Cover equal-width, expansion, and contraction cases with a small explicit
# matrix rather than a large Cartesian sweep.
for s_tdata_num_bytes in ["2", "5", "6"]:
    for m_tdata_num_bytes in ["2", "5", "6"]:
        PARAMETER_SWEEP.append(
            {
                "M_TDATA_NUM_BYTES": m_tdata_num_bytes,
                "S_TDATA_NUM_BYTES": s_tdata_num_bytes,
            }
        )

PARAMETER_SWEEP.append(
    {
        # VALID_THOLD=0 changes the buffering behavior to frame-ready mode, so
        # keep one small-FIFO case that exercises that internal path.
        "VALID_THOLD": "0",
        "FIFO_ADDR_WIDTH": "4",
    }
)


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiStreamFifoV2IpIntegrator(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamfifov2ipintegrator",
        parameters=parameters,
    )
