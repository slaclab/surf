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
# - Sweep: Isolate `SrpV0AxiLite` from the loopback wrapper, covering
#   multi-word write/read frames, malformed request frames, and 32-bit address
#   expansion.
# - Stimulus: Drive legacy four-word SRPv0 request frames directly on AXI
#   Stream and attach a cocotb AXI-Lite RAM to the generated master bus.
# - Checks: Response frames must echo the request header/data, return readback
#   payload words, set bit 16 on malformed frames, and issue AXI-Lite accesses
#   at the expected decoded addresses.
# - Timing: The flat stream helper holds every beat until sampled `TREADY`, and
#   response collection is bounded so lost terminal status words fail quickly.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteRam, AxiResp

from tests.common.regression_utils import hdl_parameters_from, run_surf_vhdl_test
from tests.protocols.srp.srp_test_utils import FlatSrpAxis


SRPV0_READ = 0
SRPV0_WRITE = 1
SRPV0_UNSUPPORTED = 2
SRPV0_STATUS_FAIL = 1 << 16


def srpv0_addr_word(opcode: int, address: int) -> int:
    high = (address >> 26) & 0x3F
    low = (address >> 2) & 0x00FF_FFFF
    return ((opcode & 0x3) << 30) | (high << 24) | low


class TB:
    def __init__(self, dut, *, use_ram: bool = True):
        self.dut = dut
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 8.0, unit="ns").start())
        self.axis = FlatSrpAxis(dut, clk=dut.AXIS_ACLK, data_bytes=4)
        self.ram = None
        if use_ram:
            self.ram = AxiLiteRam(
                AxiLiteBus.from_prefix(dut, "M_AXIL"),
                dut.AXIS_ACLK,
                dut.AXIS_ARESETN,
                reset_active_level=False,
                size=2**20,
            )

    async def reset(self):
        # Initialize stream ports while reset is asserted. The AXI-Lite RAM
        # model follows the same active-low reset as the wrapper.
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.axis.init_source()
        self.axis.init_sink()
        if self.ram is None:
            self.dut.M_AXIL_AWREADY.setimmediatevalue(0)
            self.dut.M_AXIL_WREADY.setimmediatevalue(0)
            self.dut.M_AXIL_BRESP.setimmediatevalue(0)
            self.dut.M_AXIL_BVALID.setimmediatevalue(0)
            self.dut.M_AXIL_ARREADY.setimmediatevalue(0)
            self.dut.M_AXIL_RDATA.setimmediatevalue(0)
            self.dut.M_AXIL_RRESP.setimmediatevalue(0)
            self.dut.M_AXIL_RVALID.setimmediatevalue(0)
        for _ in range(12):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(12):
            await RisingEdge(self.dut.AXIS_ACLK)

    async def accept_one_write(self, *, resp: AxiResp = AxiResp.OKAY) -> dict[str, int]:
        # This minimal responder is used only for the high-address decode case,
        # where a dense cocotb RAM would waste memory just to cover one address.
        record = {}
        self.dut.M_AXIL_AWREADY.value = 1
        self.dut.M_AXIL_WREADY.value = 1

        while "address" not in record or "data" not in record:
            await RisingEdge(self.dut.AXIS_ACLK)
            if int(self.dut.M_AXIL_AWVALID.value) and int(self.dut.M_AXIL_AWREADY.value):
                record["address"] = int(self.dut.M_AXIL_AWADDR.value)
            if int(self.dut.M_AXIL_WVALID.value) and int(self.dut.M_AXIL_WREADY.value):
                record["data"] = int(self.dut.M_AXIL_WDATA.value)
                record["strobe"] = int(self.dut.M_AXIL_WSTRB.value)

        self.dut.M_AXIL_AWREADY.value = 0
        self.dut.M_AXIL_WREADY.value = 0
        self.dut.M_AXIL_BRESP.value = int(resp)
        self.dut.M_AXIL_BVALID.value = 1
        while True:
            await RisingEdge(self.dut.AXIS_ACLK)
            if int(self.dut.M_AXIL_BREADY.value):
                break
        self.dut.M_AXIL_BVALID.value = 0
        self.dut.M_AXIL_BRESP.value = 0
        return record

    async def accept_one_read(self, *, data: int, resp: AxiResp = AxiResp.OKAY) -> dict[str, int]:
        record = {}
        self.dut.M_AXIL_ARREADY.value = 1
        while "address" not in record:
            await RisingEdge(self.dut.AXIS_ACLK)
            if int(self.dut.M_AXIL_ARVALID.value) and int(self.dut.M_AXIL_ARREADY.value):
                record["address"] = int(self.dut.M_AXIL_ARADDR.value)

        self.dut.M_AXIL_ARREADY.value = 0
        self.dut.M_AXIL_RDATA.value = data
        self.dut.M_AXIL_RRESP.value = int(resp)
        self.dut.M_AXIL_RVALID.value = 1
        while True:
            await RisingEdge(self.dut.AXIS_ACLK)
            if int(self.dut.M_AXIL_RREADY.value):
                break
        self.dut.M_AXIL_RVALID.value = 0
        self.dut.M_AXIL_RRESP.value = 0
        return record


async def send_request(tb: TB, words: list[int]) -> list[int]:
    await tb.axis.send_words(words)
    return (await tb.axis.recv_response()).words


@cocotb.test()
async def srpv0_axilite_write_read_frames_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A write frame carries an echo word, an address/opcode word, one or more
    # data words, and a terminal padding word. The response echoes the useful
    # words and appends a zero status.
    address = 0x100
    payload = [0x1122_3344, 0x5566_7788]
    write_words = [0x0102_0304, srpv0_addr_word(SRPV0_WRITE, address), *payload, 0]
    assert await send_request(tb, write_words) == [
        write_words[0],
        write_words[1],
        payload[0],
        payload[1],
        0,
    ]

    # The generated AXI-Lite writes must land in consecutive 32-bit locations.
    assert tb.ram is not None
    assert tb.ram.read(address, 8) == b"\x44\x33\x22\x11\x88\x77\x66\x55"

    # A read frame returns the requested number of zero-based data words before
    # the final status word.
    read_words = [0xA0B0_C0D0, srpv0_addr_word(SRPV0_READ, address), 1, 0]
    assert await send_request(tb, read_words) == [
        read_words[0],
        read_words[1],
        payload[0],
        payload[1],
        0,
    ]


@cocotb.test()
async def srpv0_axilite_error_frames_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Ending the frame on the address word is a malformed request and must set
    # the legacy fail bit in the returned status word.
    short_frame = [0x1111_2222, srpv0_addr_word(SRPV0_READ, 0x120)]
    short_response = await send_request(tb, short_frame)
    assert short_response == [short_frame[0], short_frame[1], SRPV0_STATUS_FAIL]

    # Unsupported opcodes dump the rest of the request and then report the same
    # status failure without issuing a read or write.
    unsupported_frame = [
        0x3333_4444,
        srpv0_addr_word(SRPV0_UNSUPPORTED, 0x124),
        0xAAAA_5555,
        0,
    ]
    unsupported_response = await send_request(tb, unsupported_frame)
    assert unsupported_response == [
        unsupported_frame[0],
        unsupported_frame[1],
        SRPV0_STATUS_FAIL,
    ]


@cocotb.test()
async def srpv0_axilite_downstream_error_status_test(dut):
    tb = TB(dut, use_ram=False)
    await tb.reset()

    # Downstream AXI-Lite write errors must preserve the echoed write payload
    # and set the legacy fail bit in the final status word.
    write_address = 0x180
    write_payload = 0x0BAD_F00D
    write_frame = [
        0x1111_AAAA,
        srpv0_addr_word(SRPV0_WRITE, write_address),
        write_payload,
        0,
    ]
    write_task = cocotb.start_soon(tb.accept_one_write(resp=AxiResp.SLVERR))
    assert await send_request(tb, write_frame) == [
        write_frame[0],
        write_frame[1],
        write_payload,
        SRPV0_STATUS_FAIL,
    ]
    assert await write_task == {
        "address": write_address,
        "data": write_payload,
        "strobe": 0xF,
    }

    # Read errors still return the sampled read-data word followed by the fail
    # status so software can distinguish bus failure from an absent response.
    read_address = 0x184
    read_data = 0xFFFF_0001
    read_frame = [0x2222_BBBB, srpv0_addr_word(SRPV0_READ, read_address), 0, 0]
    read_task = cocotb.start_soon(
        tb.accept_one_read(data=read_data, resp=AxiResp.SLVERR),
    )
    assert await send_request(tb, read_frame) == [
        read_frame[0],
        read_frame[1],
        read_data,
        SRPV0_STATUS_FAIL,
    ]
    assert await read_task == {"address": read_address}


@cocotb.test(skip=os.environ.get("EN_32BIT_ADDR_G", "false").lower() != "true")
async def srpv0_axilite_32bit_address_decode_test(dut):
    tb = TB(dut, use_ram=False)
    await tb.reset()

    # With EN_32BIT_ADDR_G enabled, bits 29:24 of the address/opcode word feed
    # address bits 31:26. A custom responder avoids allocating a sparse RAM for
    # this high address while still returning an OK AXI-Lite write response.
    address = 0x0800_0120
    payload = [0xFEED_FACE]
    write_words = [0x5555_AAAA, srpv0_addr_word(SRPV0_WRITE, address), payload[0], 0]
    write_task = cocotb.start_soon(tb.accept_one_write())
    assert await send_request(tb, write_words) == [
        write_words[0],
        write_words[1],
        payload[0],
        0,
    ]
    write_record = await write_task
    assert write_record == {
        "address": address,
        "data": payload[0],
        "strobe": 0xF,
    }


PARAMETER_SWEEP = [
    pytest.param({}, id="legacy_26bit_addr"),
    pytest.param({"EN_32BIT_ADDR_G": True}, id="extended_32bit_addr"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SrpV0AxiLite(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.srpv0axilitewrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/srp/wrappers/SrpV0AxiLiteWrapper.vhd"]},
    )
