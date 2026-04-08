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
# - Sweep: Exercise the default SRPv3 AXI bridge with the same posted-write
#   then non-posted-read flow as the legacy bench.
# - Stimulus: Drive SRPv3 request frames on the 32-bit SSI-side stream.
# - Checks: The read response header and payload must match the written RAM
#   contents and request metadata.
# - Timing: Transfer is handshake-driven with a bounded receive timeout.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test


REQ_BYTE_SIZE = 2**12
REQ_WORD_SIZE = REQ_BYTE_SIZE // 4


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())

    async def reset(self):
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.dut.S_AXIS_TVALID.setimmediatevalue(0)
        self.dut.S_AXIS_TDATA.setimmediatevalue(0)
        self.dut.S_AXIS_TKEEP.setimmediatevalue(0xF)
        self.dut.S_AXIS_TLAST.setimmediatevalue(0)
        self.dut.S_AXIS_TDEST.setimmediatevalue(0)
        self.dut.S_AXIS_TID.setimmediatevalue(0)
        self.dut.S_AXIS_TUSER.setimmediatevalue(0)
        self.dut.M_AXIS_TREADY.setimmediatevalue(1)
        for _ in range(110):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(4):
            await RisingEdge(self.dut.AXIS_ACLK)

    async def send_words(self, words):
        for index, word in enumerate(words):
            self.dut.S_AXIS_TVALID.value = 1
            self.dut.S_AXIS_TDATA.value = word
            self.dut.S_AXIS_TKEEP.value = 0xF
            self.dut.S_AXIS_TLAST.value = 1 if index == len(words) - 1 else 0
            self.dut.S_AXIS_TUSER.value = 0x2 if index == 0 else 0x0
            self.dut.S_AXIS_TID.value = 0
            while int(self.dut.S_AXIS_TREADY.value) != 1:
                await RisingEdge(self.dut.AXIS_ACLK)
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.S_AXIS_TVALID.value = 0
        self.dut.S_AXIS_TLAST.value = 0
        self.dut.S_AXIS_TUSER.value = 0

    async def recv_words(self):
        words = []
        while True:
            await with_timeout(RisingEdge(self.dut.AXIS_ACLK), 2, "ms")
            if int(self.dut.M_AXIS_TVALID.value) != 1:
                continue
            words.append(int(self.dut.M_AXIS_TDATA.value))
            if int(self.dut.M_AXIS_TLAST.value) == 1:
                return words


def request_header(opcode, tid, address):
    return [
        ((opcode & 0xFF) << 8) | 0x03,
        tid,
        address & 0xFFFF_FFFF,
        0,
        REQ_BYTE_SIZE - 1,
    ]


@cocotb.test()
async def srpv3_axi_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()

    write_tid = 0x1234_0000
    address = 0
    write_words = request_header(0x02, write_tid, address) + list(range(REQ_WORD_SIZE))
    await tb.send_words(write_words)

    read_tid = write_tid + 1
    read_words = request_header(0x00, read_tid, address)
    await tb.send_words(read_words)

    response = await tb.recv_words()
    assert response[0] == ((0x00 << 8) | 0x03)
    assert response[1] == read_tid
    assert response[2] == address
    assert response[4] == REQ_BYTE_SIZE - 1
    payload = response[5:]
    assert payload[:-1] == list(range(REQ_WORD_SIZE))
    assert payload[-1] == 0


PARAMETER_SWEEP = [pytest.param({}, id="default_request_window")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SrpV3Axi(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.srpv3axiwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/srp/wrappers/SrpV3AxiWrapper.vhd"]},
    )
