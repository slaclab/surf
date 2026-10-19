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
# - Sweep: Keep one fixed cocotb-facing wrapper topology in which a single
#   slave port fans into a local RAM window plus a cascaded secondary crossbar
#   feeding two more RAM windows; the coverage focus is address decode and
#   transaction routing rather than a broad generic sweep.
# - Stimulus: Drive byte, word, dword, and qword AXI-Lite transactions into
#   all three decoded regions, then issue decode-miss accesses and finally run
#   concurrent randomized traffic across the mapped windows.
# - Checks: Each region must return the data written into that region only,
#   decode misses must return `DECERR`, and concurrent traffic through the top
#   and cascaded crossbars must not cross-couple data or responses.
# - Timing: The test checks that read and write responses complete cleanly
#   through optional channel pauses and that decode-error responses are
#   returned as proper AXI-Lite responses rather than hanging the transaction.
#   Lower response READY after request acceptance and hold it low for 20 clocks;
#   check stable response fields, completion on release, and no stale responses
#   on subsequent accesses with different data, including READY starting low.

import itertools
import logging
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import cancel_and_join_tasks, run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8.0, unit="ns").start())

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.S_AXI_ACLK,
            reset=dut.S_AXI_ARESETN,
            reset_active_level=False,
        )

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil.write_if.aw_channel.set_pause_generator(generator())
            self.axil.write_if.w_channel.set_pause_generator(generator())
            self.axil.read_if.ar_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil.write_if.b_channel.set_pause_generator(generator())
            self.axil.read_if.r_channel.set_pause_generator(generator())

    async def cycle_reset(self):
        # Hold the active-low reset across several edges so the shim layer,
        # crossbar state machines, and backing RAMs all restart together.
        self.dut.S_AXI_ARESETN.setimmediatevalue(0)
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 0
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 1
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


@cocotb.test()
async def region_round_trip_test(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    tb.set_idle_generator(cycle_pause)
    tb.set_backpressure_generator(cycle_pause)

    regions = [0x0000_0000, 0x0010_2000, 0x0016_0000]

    # Sweep short byte payloads across all decoded windows and byte offsets so
    # the test proves both direct and cascaded routing paths.
    for region in regions:
        for offset in range(4):
            for length in range(1, 8):
                addr = region + offset
                payload = bytearray((region // 0x1000 + offset + i) & 0xFF for i in range(length))
                wr_txn = await tb.axil.write(addr, payload)
                assert wr_txn.resp == AxiResp.OKAY
                rd_txn = await tb.axil.read(addr, length)
                assert rd_txn.resp == AxiResp.OKAY
                assert rd_txn.data == payload


@cocotb.test()
async def typed_access_and_decode_error_test(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    base_addrs = [0x0000_0000, 0x0010_2000, 0x0016_0000]

    # Exercise the convenience accessors at representative aligned addresses so
    # the crossbar proves it preserves transfer size and byte ordering.
    for index, base in enumerate(base_addrs, start=1):
        addr = base + 0x20

        await tb.axil.write_byte(addr + 0, 0x10 + index)
        assert await tb.axil.read_byte(addr + 0) == 0x10 + index

        await tb.axil.write_word(addr + 2, 0x1200 + index)
        assert await tb.axil.read_word(addr + 2) == 0x1200 + index

        await tb.axil.write_dword(addr + 4, 0x12340000 + index)
        assert await tb.axil.read_dword(addr + 4) == 0x12340000 + index

        await tb.axil.write_qword(addr + 8, 0x1234567800000000 + index)
        assert await tb.axil.read_qword(addr + 8) == 0x1234567800000000 + index

    # Hit an unmapped region so the test proves decode misses terminate with a
    # `DECERR` response instead of disappearing inside the crossbar.
    bad_addr = 0x0020_0000
    wr_txn = await tb.axil.write(bad_addr, b"\xAA\xBB\xCC\xDD")
    assert wr_txn.resp == AxiResp.DECERR
    rd_txn = await tb.axil.read(bad_addr, 4)
    assert rd_txn.resp == AxiResp.DECERR
    assert rd_txn.data == b"\x00\x00\x00\x00"


@cocotb.test()
async def concurrent_region_stress_test(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    tb.set_idle_generator(cycle_pause)
    tb.set_backpressure_generator(cycle_pause)

    async def worker(region_base, seed):
        rng = random.Random(seed)
        for _ in range(10):
            length = rng.randint(1, 16)
            addr = region_base + rng.randint(0, 0x100 - length)
            payload = bytearray(rng.randint(0, 255) for _ in range(length))

            # Add small randomized gaps so requests from different regions
            # overlap in time and force the crossbar to arbitrate actively.
            await Timer(rng.randint(1, 40), unit="ns")
            wr_txn = await tb.axil.write(addr, payload)
            assert wr_txn.resp == AxiResp.OKAY
            await Timer(rng.randint(1, 40), unit="ns")
            rd_txn = await tb.axil.read(addr, length)
            assert rd_txn.resp == AxiResp.OKAY
            assert rd_txn.data == payload

    workers = [
        cocotb.start_soon(worker(0x0000_0000, 0x11)),
        cocotb.start_soon(worker(0x0010_2000, 0x22)),
        cocotb.start_soon(worker(0x0016_0000, 0x33)),
    ]

    while workers:
        await workers.pop(0)


@cocotb.test()
@cocotb.parametrize(channel=["write", "read"])
async def response_backpressure_test(dut, channel):
    # Drive the source directly so READY falls only after request acceptance.
    # The existing pause generator does not enforce that ordering.
    inputs = {
        "S_AXI_ARESETN": 0,
        "S_AXI_AWADDR": 0, "S_AXI_AWPROT": 0, "S_AXI_AWVALID": 0,
        "S_AXI_WDATA": 0, "S_AXI_WSTRB": 0xF, "S_AXI_WVALID": 0,
        "S_AXI_BREADY": 1,
        "S_AXI_ARADDR": 0, "S_AXI_ARPROT": 0, "S_AXI_ARVALID": 0,
        "S_AXI_RREADY": 1,
    }
    for name, value in inputs.items():
        getattr(dut, name).value = value
    # Lifetime agent: clock this test's raw AXI-Lite source.
    clock_task = cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8, unit="ns").start())

    async def cycle():
        # Sample the accepting edge before the registered outputs change at
        # TPD_G=1 ns, then drive the next cycle on the falling edge.
        await RisingEdge(dut.S_AXI_ACLK)
        await ReadOnly()
        values = {
            name: int(getattr(dut, "S_AXI_" + name).value)
            for name in ("AWREADY", "WREADY", "ARREADY", "BVALID", "BRESP",
                         "RVALID", "RRESP", "RDATA")
        }
        await FallingEdge(dut.S_AXI_ACLK)
        return values

    async def transfer(write, address, data, initial_ready, stall):
        response = "B" if write else "R"
        ready = getattr(dut, "S_AXI_" + response + "READY")
        ready.value = initial_ready
        if write:
            dut.S_AXI_AWADDR.value = address
            dut.S_AXI_WDATA.value = data
        else:
            dut.S_AXI_ARADDR.value = address
        requests = ["AW", "W"] if write else ["AR"]
        for request in requests:
            getattr(dut, "S_AXI_" + request + "VALID").value = 1
        pending = set(requests)
        for _ in range(64):
            values = await cycle()
            for request in tuple(pending):
                if values[request + "READY"]:
                    getattr(dut, "S_AXI_" + request + "VALID").value = 0
                    pending.remove(request)
            if not pending:
                break
        else:
            raise AssertionError(f"Request timed out at {address:#x}")

        held = None
        if stall:
            ready.value = 0
            for _ in range(20):
                values = await cycle()
                fields = (values[response + "VALID"], values[response + "RESP"])
                if not write:
                    fields += (values["RDATA"],)
                if held is not None:
                    assert fields == held, f"Stalled {response} response changed at {address:#x}"
                elif values[response + "VALID"]:
                    held = fields
            assert held is not None, f"No {response} response during stall at {address:#x}"
            ready.value = 1

        for _ in range(64):
            values = await cycle()
            if values[response + "VALID"]:
                assert values[response + "RESP"] == AxiResp.OKAY
                if not write:
                    assert values["RDATA"] == data, f"Read data mismatch at {address:#x}"
                break
        else:
            raise AssertionError(f"{response} response timed out at {address:#x}")
        for _ in range(8):
            values = await cycle()
            assert not values[response + "VALID"], f"Duplicate {response} response at {address:#x}"

    try:
        for _ in range(20):
            await cycle()
        dut.S_AXI_ARESETN.value = 1
        for _ in range(10):
            await cycle()

        for region in (0x0000_0000, 0x0010_2000, 0x0016_0000):
            # Also start READY low to prove downstream completion does not
            # depend on the READY value captured with the request. Reusing
            # each address with distinct data exposes stale responses.
            for initial_ready in (1, 0):
                for data in (0x76543210, 0x89ABCDEF):
                    address = region + 0x20
                    await transfer(True, address, data, initial_ready if channel == "write" else 1,
                                   channel == "write")
                    await transfer(False, address, data, initial_ready if channel == "read" else 1,
                                   channel == "read")
    finally:
        await cancel_and_join_tasks([clock_task])


def test_AxiLiteCrossbar():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitecrossbaripintegrator",
    )
