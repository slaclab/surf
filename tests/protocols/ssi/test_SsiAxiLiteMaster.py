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
# - Sweep: Keep one same-clock 32-bit SSI register path backed by a cocotb
#   AXI-Lite RAM model so the first pass proves both write and read response
#   framing without opening the wider FIFO/address matrix.
# - Stimulus: Send one single-word write request followed by one single-word
#   read request through the flattened SSI interface.
# - Checks: The downstream AXI-Lite RAM must see the write, and the SSI
#   response frames must echo the header words, return the payload data, and
#   finish with a clear status beat.
# - Timing: The bench waits on complete SSI response frames and polls the RAM
#   contents directly instead of assuming immediate bridge completion.

import cocotb
import pytest
from cocotbext.axi import AxiLiteBus, AxiLiteRam

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import FlatSsiEndpoint, SsiBeat, recv_frame, reset_dut, send_contiguous_frame, start_clock


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatSsiEndpoint(dut, prefix="sAxis")
        self.sink = FlatSsiEndpoint(dut, prefix="mAxis")
        self.ram = None

        start_clock(dut.axisClk)
        dut.axisRst.setimmediatevalue(1)
        self.source.set_idle()
        dut.mAxisTReady.setimmediatevalue(1)

    async def reset(self):
        await reset_dut(self.dut)

    def start_agents(self):
        if self.ram is None:
            self.ram = AxiLiteRam(AxiLiteBus.from_prefix(self.dut, "M_AXIL"), self.dut.axisClk, self.dut.axisRst, size=2**12)


def request_keep() -> int:
    return 0xF


async def send_write_request(tb: TB, *, echo: int, address: int, data: int):
    await send_contiguous_frame(
        tb.source,
        [
            SsiBeat(data=echo, keep=request_keep(), last=0, sof=1),
            SsiBeat(data=0x40000000 | (address >> 2), keep=request_keep(), last=0),
            SsiBeat(data=data, keep=request_keep(), last=0),
            SsiBeat(data=0x00000000, keep=request_keep(), last=1),
        ],
        clk=tb.dut.axisClk,
    )


async def send_read_request(tb: TB, *, echo: int, address: int):
    await send_contiguous_frame(
        tb.source,
        [
            SsiBeat(data=echo, keep=request_keep(), last=0, sof=1),
            SsiBeat(data=(address >> 2), keep=request_keep(), last=0),
            SsiBeat(data=0x00000000, keep=request_keep(), last=0),
            SsiBeat(data=0x00000000, keep=request_keep(), last=1),
        ],
        clk=tb.dut.axisClk,
    )


@cocotb.test()
async def single_word_write_and_read_round_trip(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await send_write_request(tb, echo=0xA5A50001, address=0x10, data=0xDEADBEEF)
    response = await recv_frame(tb.sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    assert [(beat.data, beat.last, beat.sof, beat.eofe) for beat in response] == [
        (0xA5A50001, 0, 1, 0),
        (0xDEADBEEF, 0, 0, 0),
        (0x00000000, 1, 0, 0),
    ]
    assert tb.ram.read(0x10, 4) == b"\xEF\xBE\xAD\xDE"

    tb.ram.write(0x20, b"\x78\x56\x34\x12")
    await send_read_request(tb, echo=0x5A5A0002, address=0x20)
    response = await recv_frame(tb.sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    assert [(beat.data, beat.last, beat.sof, beat.eofe) for beat in response] == [
        (0x5A5A0002, 0, 1, 0),
        (0x12345678, 0, 0, 0),
        (0x00000000, 1, 0, 0),
    ]


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_word_round_trip")])
def test_SsiAxiLiteMaster(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiaxilitemasterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiAxiLiteMasterWrapper.vhd"]},
    )
