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
# - Sweep: Reuse the legacy `AxiStreamGearboxTb` shell but narrow it to one
#   stable non-word-multiple case.
# - Stimulus: Send incrementing payload frames through the cocotb AXI-Stream
#   agents already used by the historical bench.
# - Checks: Output bytes, `tid`, and `tdest` must match end-to-end.
# - Timing: One idle/backpressure-free case keeps this as a deterministic leaf
#   regression rather than a large compatibility sweep.

import itertools

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None
        self.sink = None

        cocotb.start_soon(Clock(dut.AXIS_ACLK, 5.0, unit="ns").start())
        dut.AXIS_ARESETN.setimmediatevalue(0)

    async def reset(self):
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        for _ in range(4):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(2):
            await RisingEdge(self.dut.AXIS_ACLK)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.AXIS_ACLK, self.dut.AXIS_ARESETN, reset_active_level=False)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.AXIS_ACLK, self.dut.AXIS_ARESETN, reset_active_level=False)


@cocotb.test()
async def narrow_gearbox_payload_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    payload = bytes(itertools.islice(itertools.cycle(range(256)), 11))
    frame = AxiStreamFrame(payload)
    frame.tid = 1
    frame.tdest = 1
    await tb.source.send(frame)

    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == payload
    assert rx_frame.tid == frame.tid
    assert rx_frame.tdest == frame.tdest


@pytest.mark.parametrize(
    "parameters",
    [pytest.param({"BYTE_PACKER_MODE": "1", "M_TDATA_NUM_BYTES": "4", "S_TDATA_NUM_BYTES": "3"}, id="pack_3_to_4")],
)
def test_AxiStreamGearbox(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamgearboxtb",
        parameters=parameters,
        extra_env=parameters,
    )
