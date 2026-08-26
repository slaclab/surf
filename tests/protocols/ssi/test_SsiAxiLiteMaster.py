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
# - Sweep: Keep one same-clock 32-bit SSI register path, but replace the
#   passive RAM backend with a small controllable AXI-Lite slave model so the
#   bench can force staggered handshakes and explicit response errors.
# - Stimulus: Send one single-word write, one multi-word write, one multi-word
#   read, one malformed short write, one write with `SLVERR`, and one read
#   with `SLVERR` through the flattened SSI interface.
# - Checks: Valid requests must echo the first word, return write/read payload
#   beats in order, auto-increment the AXI-Lite address between beats, and end
#   with a clear status word; malformed or errored requests must set the fail
#   bit in the final status word without corrupting memory.
# - Timing: The AXI-Lite slave model delays `AWREADY`, `WREADY`, `BVALID`,
#   `ARREADY`, and `RVALID` independently so the bridge has to step through
#   the full write/read state machine instead of only seeing zero-cycle acks.

import cocotb
import pytest
from cocotbext.axi import AxiResp

from tests.common.regression_utils import run_surf_vhdl_test
from tests.common.regression_utils import sample_after_tpd
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    recv_frame_and_check,
    reset_dut,
    send_contiguous_frame,
    SsiBeat,
    start_clock,
)


STATUS_OK = 0x00000000
STATUS_FAIL = 0x00010000


class SimpleAxiLiteSlave:
    def __init__(self, dut):
        self.dut = dut
        self.mem = {}
        self.read_resp = AxiResp.OKAY
        self.write_resp = AxiResp.OKAY
        self.last_writes = []
        self.last_reads = []

        dut.M_AXIL_AWREADY.setimmediatevalue(0)
        dut.M_AXIL_WREADY.setimmediatevalue(0)
        dut.M_AXIL_BVALID.setimmediatevalue(0)
        dut.M_AXIL_BRESP.setimmediatevalue(0)
        dut.M_AXIL_ARREADY.setimmediatevalue(0)
        dut.M_AXIL_RVALID.setimmediatevalue(0)
        dut.M_AXIL_RRESP.setimmediatevalue(0)
        dut.M_AXIL_RDATA.setimmediatevalue(0)

        # Run independent write and read responders so the DUT sees a realistic
        # AXI-Lite target rather than zero-delay combinational acks.
        self._responder_tasks = (
            cocotb.start_soon(self._run_write()),
            cocotb.start_soon(self._run_read()),
        )

    def in_reset(self) -> bool:
        try:
            return int(self.dut.axisRst.value) == 1
        except ValueError:
            return True

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axisClk)

    async def _wait_while_reset(self):
        # While reset is active, keep every ready/valid output deasserted.
        while self.in_reset():
            self.dut.M_AXIL_AWREADY.value = 0
            self.dut.M_AXIL_WREADY.value = 0
            self.dut.M_AXIL_BVALID.value = 0
            self.dut.M_AXIL_ARREADY.value = 0
            self.dut.M_AXIL_RVALID.value = 0
            await self.cycle()

    async def _run_write(self):
        """Lifetime agent: respond to AXI-Lite writes until the test ends."""
        while True:
            await self._wait_while_reset()

            # Wait for the DUT to present a write address.
            while not int(self.dut.M_AXIL_AWVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle()

            # Delay the address handshake on purpose so the bridge has to hold
            # its request stable across cycles.
            await self.cycle(1)
            awaddr = int(self.dut.M_AXIL_AWADDR.value)
            awprot = int(self.dut.M_AXIL_AWPROT.value)
            self.dut.M_AXIL_AWREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXIL_AWREADY.value = 0

            # Then wait independently for the write data channel.
            while not int(self.dut.M_AXIL_WVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle()

            # Apply byte strobes exactly like a small memory-mapped target.
            await self.cycle(2)
            wdata = int(self.dut.M_AXIL_WDATA.value)
            wstrb = int(self.dut.M_AXIL_WSTRB.value)
            self.last_writes.append((awaddr, wdata, wstrb, awprot))

            if self.write_resp == AxiResp.OKAY:
                prior = self.mem.get(awaddr, 0).to_bytes(4, "little")
                next_bytes = bytearray(prior)
                write_bytes = wdata.to_bytes(4, "little")
                for index in range(4):
                    if wstrb & (1 << index):
                        next_bytes[index] = write_bytes[index]
                self.mem[awaddr] = int.from_bytes(next_bytes, "little")

            self.dut.M_AXIL_WREADY.value = 1
            # Return the configured write response only after both address and
            # data have completed.
            await self.cycle(1)
            self.dut.M_AXIL_WREADY.value = 0

            await self.cycle(1)
            self.dut.M_AXIL_BRESP.value = int(self.write_resp)
            self.dut.M_AXIL_BVALID.value = 1
            while not int(self.dut.M_AXIL_BREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle()
            await self.cycle(1)
            self.dut.M_AXIL_BVALID.value = 0

    async def _run_read(self):
        """Lifetime agent: respond to AXI-Lite reads until the test ends."""
        while True:
            await self._wait_while_reset()

            # Wait for one read address request.
            while not int(self.dut.M_AXIL_ARVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle()

            # Delay address acceptance and data return separately so the DUT
            # exercises both halves of its read state machine.
            await self.cycle(2)
            araddr = int(self.dut.M_AXIL_ARADDR.value)
            arprot = int(self.dut.M_AXIL_ARPROT.value)
            self.last_reads.append((araddr, arprot))
            self.dut.M_AXIL_ARREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXIL_ARREADY.value = 0

            await self.cycle(1)
            self.dut.M_AXIL_RDATA.value = self.mem.get(araddr, 0)
            self.dut.M_AXIL_RRESP.value = int(self.read_resp)
            self.dut.M_AXIL_RVALID.value = 1
            while not int(self.dut.M_AXIL_RREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle()
            await self.cycle(1)
            self.dut.M_AXIL_RVALID.value = 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatSsiEndpoint(dut, prefix="sAxis")
        self.sink = FlatSsiEndpoint(dut, prefix="mAxis")
        self.axil = SimpleAxiLiteSlave(dut)

        # This testbench wrapper groups the SSI source/sink and the controllable
        # AXI-Lite backend so each scenario reads like protocol intent.
        start_clock(dut.axisClk)
        dut.axisRst.setimmediatevalue(1)
        self.source.set_idle()
        dut.mAxisTReady.setimmediatevalue(1)

    async def reset(self):
        await reset_dut(self.dut)


def request_keep() -> int:
    return 0xF


async def expect_response(tb: TB, *, expected: list[tuple[int, int, int, int]]):
    # Compare the returned SSI frame against only the user-visible fields that
    # matter for the bridge contract.
    await recv_frame_and_check(
        tb.sink,
        clk=tb.dut.axisClk,
        ready_signal=tb.dut.mAxisTReady,
        fields=("data", "last", "sof", "eofe"),
        expected=expected,
    )


async def send_write_request(tb: TB, *, echo: int, address: int, words: list[int]):
    # SSI write requests carry an echo word, an encoded address word, the data
    # payload, and a terminal status-placeholder beat.
    payload = [
        SsiBeat(data=echo, keep=request_keep(), last=0, sof=1),
        SsiBeat(data=0x40000000 | (address >> 2), keep=request_keep(), last=0),
    ]
    for word in words:
        payload.append(SsiBeat(data=word, keep=request_keep(), last=0))
    payload.append(SsiBeat(data=0x00000000, keep=request_keep(), last=1))
    await send_contiguous_frame(tb.source, payload, clk=tb.dut.axisClk)


async def send_read_request(tb: TB, *, echo: int, address: int, count: int):
    # SSI read requests carry the echo word, base address, word count, and a
    # terminal placeholder beat.
    await send_contiguous_frame(
        tb.source,
        [
            SsiBeat(data=echo, keep=request_keep(), last=0, sof=1),
            SsiBeat(data=(address >> 2), keep=request_keep(), last=0),
            SsiBeat(data=count, keep=request_keep(), last=0),
            SsiBeat(data=0x00000000, keep=request_keep(), last=1),
        ],
        clk=tb.dut.axisClk,
    )


@cocotb.test()
async def ssi_axi_lite_master_test(dut):
    tb = TB(dut)
    await tb.reset()

    # First prove a single-word write round-trip, including the echoed request
    # metadata and the final success status word.
    recv_task = cocotb.start_soon(
        expect_response(
            tb,
            expected=[
                (0xA5A50001, 0, 1, 0),
                (0x40000004, 0, 0, 0),
                (0xDEADBEEF, 0, 0, 0),
                (STATUS_OK, 1, 0, 0),
            ],
        )
    )
    await send_write_request(tb, echo=0xA5A50001, address=0x10, words=[0xDEADBEEF])
    await recv_task
    assert tb.axil.mem[0x10] == 0xDEADBEEF
    assert tb.axil.last_writes[-1] == (0x10, 0xDEADBEEF, 0xF, 0)

    # Then prove the bridge auto-increments the AXI-Lite address for a
    # multi-word write burst carried over SSI.
    recv_task = cocotb.start_soon(
        expect_response(
            tb,
            expected=[
                (0xA5A50002, 0, 1, 0),
                (0x40000008, 0, 0, 0),
                (0x11112222, 0, 0, 0),
                (0x33334444, 0, 0, 0),
                (STATUS_OK, 1, 0, 0),
            ],
        )
    )
    await send_write_request(tb, echo=0xA5A50002, address=0x20, words=[0x11112222, 0x33334444])
    await recv_task
    assert tb.axil.mem[0x20] == 0x11112222
    assert tb.axil.mem[0x24] == 0x33334444
    assert tb.axil.last_writes[-2:] == [
        (0x20, 0x11112222, 0xF, 0),
        (0x24, 0x33334444, 0xF, 0),
    ]

    # A read request should echo the request header and then stream back the
    # AXI-Lite read data in order.
    tb.axil.mem[0x30] = 0x12345678
    tb.axil.mem[0x34] = 0xCAFEBABE
    recv_task = cocotb.start_soon(
        expect_response(
            tb,
            expected=[
                (0x5A5A0003, 0, 1, 0),
                (0x0000000C, 0, 0, 0),
                (0x12345678, 0, 0, 0),
                (0xCAFEBABE, 0, 0, 0),
                (STATUS_OK, 1, 0, 0),
            ],
        )
    )
    await send_read_request(tb, echo=0x5A5A0003, address=0x30, count=1)
    await recv_task
    assert tb.axil.last_reads[-2:] == [(0x30, 0), (0x34, 0)]

    # A malformed short write request should fail without needing the AXI-Lite
    # backend to accept anything.
    recv_task = cocotb.start_soon(
        expect_response(
            tb,
            expected=[
                (0xBAD00004, 0, 1, 0),
                (0x4000000C, 0, 0, 0),
                (STATUS_FAIL, 1, 0, 0),
            ],
        )
    )
    await send_contiguous_frame(
        tb.source,
        [
            SsiBeat(data=0xBAD00004, keep=request_keep(), last=0, sof=1),
            SsiBeat(data=0x4000000C, keep=request_keep(), last=1),
        ],
        clk=tb.dut.axisClk,
    )
    await recv_task

    # Next force a write-side SLVERR and confirm that the bridge reports the
    # failure instead of updating memory.
    tb.axil.write_resp = AxiResp.SLVERR
    recv_task = cocotb.start_soon(
        expect_response(
            tb,
            expected=[
                (0xA5A50005, 0, 1, 0),
                (0x40000010, 0, 0, 0),
                (0x55667788, 0, 0, 0),
                (STATUS_FAIL, 1, 0, 0),
            ],
        )
    )
    await send_write_request(tb, echo=0xA5A50005, address=0x40, words=[0x55667788])
    await recv_task
    assert 0x40 not in tb.axil.mem

    # Finally, force a read-side SLVERR. The bridge still returns the observed
    # read data word, but the trailing status word must report failure.
    tb.axil.write_resp = AxiResp.OKAY
    tb.axil.read_resp = AxiResp.SLVERR
    tb.axil.mem[0x50] = 0x0F1E2D3C
    recv_task = cocotb.start_soon(
        expect_response(
            tb,
            expected=[
                (0x5A5A0006, 0, 1, 0),
                (0x00000014, 0, 0, 0),
                (0x0F1E2D3C, 0, 0, 0),
                (STATUS_FAIL, 1, 0, 0),
            ],
        )
    )
    await send_read_request(tb, echo=0x5A5A0006, address=0x50, count=0)
    await recv_task


@pytest.mark.parametrize("parameters", [pytest.param({}, id="same_clk_error_and_multiword")])
def test_SsiAxiLiteMaster(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiaxilitemasterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiAxiLiteMasterWrapper.vhd"]},
    )
