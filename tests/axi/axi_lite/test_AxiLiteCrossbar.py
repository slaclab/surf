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
# - Termination: A second wrapper gives the crossbar two slave ports and leaves
#   master ports undriven at their AXI_LITE_*_SLAVE_EMPTY_{OK,SLVERR,DECERR}_C
#   signal defaults, plus one behind a cascaded crossbar, next to RAM windows.
#   Seeded random traffic with and without response backpressure, the raw
#   READY-drop driver, and two concurrent initiators must get the constant
#   response and zero RDATA from each EMPTY port, DECERR on a decode miss, and
#   correct RAM data, with no hang, duplicate, or stale response.

import itertools
import logging
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import (
    cancel_and_join_tasks,
    cocotb_filtered_env,
    cocotb_test_filter,
    cocotb_test_filter_excluding,
    run_surf_vhdl_test,
)


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




def raw_idle_inputs(dut, prefix):
    # Park a raw AXI-Lite source with no request pending and response READY high.
    inputs = {
        "AWADDR": 0, "AWPROT": 0, "AWVALID": 0,
        "WDATA": 0, "WSTRB": 0xF, "WVALID": 0,
        "BREADY": 1,
        "ARADDR": 0, "ARPROT": 0, "ARVALID": 0,
        "RREADY": 1,
    }
    for name, value in inputs.items():
        getattr(dut, f"{prefix}_{name}").value = value


async def raw_cycle(dut, prefix):
    # Sample the accepting edge before the registered outputs change at
    # TPD_G=1 ns, then drive the next cycle on the falling edge.
    await RisingEdge(dut.S_AXI_ACLK)
    await ReadOnly()
    values = {
        name: int(getattr(dut, f"{prefix}_{name}").value)
        for name in ("AWREADY", "WREADY", "ARREADY", "BVALID", "BRESP",
                     "RVALID", "RRESP", "RDATA")
    }
    await FallingEdge(dut.S_AXI_ACLK)
    return values


async def raw_transfer(dut, prefix, write, address, data, initial_ready, stall,
                       resp=AxiResp.OKAY, rdata=None):
    # Drive one transaction directly so response READY falls only after request
    # acceptance; the cocotbext pause generators do not enforce that ordering.
    rdata = data if rdata is None else rdata
    response = "B" if write else "R"
    ready = getattr(dut, f"{prefix}_{response}READY")
    ready.value = initial_ready
    if write:
        getattr(dut, f"{prefix}_AWADDR").value = address
        getattr(dut, f"{prefix}_WDATA").value = data
    else:
        getattr(dut, f"{prefix}_ARADDR").value = address
    requests = ["AW", "W"] if write else ["AR"]
    for request in requests:
        getattr(dut, f"{prefix}_{request}VALID").value = 1
    pending = set(requests)
    for _ in range(64):
        values = await raw_cycle(dut, prefix)
        for request in tuple(pending):
            if values[request + "READY"]:
                getattr(dut, f"{prefix}_{request}VALID").value = 0
                pending.remove(request)
        if not pending:
            break
    else:
        raise AssertionError(f"Request timed out at {address:#x}")

    held = None
    if stall:
        ready.value = 0
        for _ in range(20):
            values = await raw_cycle(dut, prefix)
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
        values = await raw_cycle(dut, prefix)
        if values[response + "VALID"]:
            assert values[response + "RESP"] == resp, f"{response} response mismatch at {address:#x}"
            if not write:
                assert values["RDATA"] == rdata, f"Read data mismatch at {address:#x}"
            break
    else:
        raise AssertionError(f"{response} response timed out at {address:#x}")
    for _ in range(8):
        values = await raw_cycle(dut, prefix)
        assert not values[response + "VALID"], f"Duplicate {response} response at {address:#x}"


@cocotb.test()
@cocotb.parametrize(channel=["write", "read"])
async def response_backpressure_test(dut, channel):
    dut.S_AXI_ARESETN.value = 0
    raw_idle_inputs(dut, "S_AXI")
    # Lifetime agent: clock this test's raw AXI-Lite source.
    clock_task = cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8, unit="ns").start())

    try:
        for _ in range(20):
            await raw_cycle(dut, "S_AXI")
        dut.S_AXI_ARESETN.value = 1
        for _ in range(10):
            await raw_cycle(dut, "S_AXI")

        for region in (0x0000_0000, 0x0010_2000, 0x0016_0000):
            # Also start READY low to prove downstream completion does not
            # depend on the READY value captured with the request. Reusing
            # each address with distinct data exposes stale responses.
            for initial_ready in (1, 0):
                for data in (0x76543210, 0x89ABCDEF):
                    address = region + 0x20
                    await raw_transfer(dut, "S_AXI", True, address, data,
                                       initial_ready if channel == "write" else 1, channel == "write")
                    await raw_transfer(dut, "S_AXI", False, address, data,
                                       initial_ready if channel == "read" else 1, channel == "read")
    finally:
        await cancel_and_join_tasks([clock_task])


# AxiLiteCrossbarTerminationIpIntegrator address map: (name, base, BRESP/RRESP,
# RDATA). RDATA None means RAM-backed; other targets always return that RDATA.
TERMINATION_TARGETS = (
    ("ram", 0x0000, AxiResp.OKAY, None),
    ("empty_ok", 0x1000, AxiResp.OKAY, 0),
    ("empty_slverr", 0x2000, AxiResp.SLVERR, 0),
    ("empty_decerr", 0x3000, AxiResp.DECERR, 0),
    ("cascade_ram", 0x4000, AxiResp.OKAY, None),
    ("cascade_empty_slverr", 0x4800, AxiResp.SLVERR, 0),
    ("decode_miss", 0x8000, AxiResp.DECERR, 0),
)

TERMINATION_TESTS = (
    "termination_mixed_traffic_test",
    "termination_ready_drop_test",
    "termination_two_initiator_test",
)


class TerminationTB:
    def __init__(self, dut):
        self.dut = dut
        dut.S_AXI_ARESETN.value = 0
        for prefix in ("S0_AXI", "S1_AXI"):
            raw_idle_inputs(dut, prefix)
        # Lifetime agent: clock shared by both slave ports for this test.
        self.clock_task = cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8, unit="ns").start())

    def add_master(self, prefix):
        return AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(self.dut, prefix),
            clock=self.dut.S_AXI_ACLK,
            reset=self.dut.S_AXI_ARESETN,
            reset_active_level=False,
        )

    @staticmethod
    def set_random_pauses(axil, seed):
        # Seeded random READY on B/R (60% paused) and VALID gaps on AW/W/AR.
        rng = random.Random(seed)
        for channel, pause in ((axil.write_if.b_channel, 0.6), (axil.read_if.r_channel, 0.6),
                               (axil.write_if.aw_channel, 0.3), (axil.write_if.w_channel, 0.3),
                               (axil.read_if.ar_channel, 0.3)):
            channel.set_pause_generator(iter(lambda p=pause: int(rng.random() < p), None))

    async def reset(self):
        self.dut.S_AXI_ARESETN.value = 0
        for _ in range(10):
            await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 1
        for _ in range(10):
            await RisingEdge(self.dut.S_AXI_ACLK)

    async def close(self):
        await cancel_and_join_tasks([self.clock_task])


async def termination_traffic(axil, seed, offset, count):
    # Random reads and writes across every target. RAM words are disjoint per
    # initiator (offset) so concurrent initiators can keep a private shadow.
    rng = random.Random(seed)
    shadow = {}
    for index in range(count):
        name, base, resp, rdata = rng.choice(TERMINATION_TARGETS)
        address = base + offset + 4 * rng.randint(0, 63)
        context = f"seed={seed} txn={index} {name} {address:#x}"
        if rng.random() < 0.5:
            data = rng.getrandbits(32).to_bytes(4, "little")
            txn = await with_timeout(axil.write(address, data), 20, "us")
            assert txn.resp == resp, f"{context}: BRESP {txn.resp}"
            if rdata is None:
                shadow[address] = data
        else:
            txn = await with_timeout(axil.read(address, 4), 20, "us")
            assert txn.resp == resp, f"{context}: RRESP {txn.resp}"
            if rdata is not None:
                assert txn.data == rdata.to_bytes(4, "little"), f"{context}: RDATA {txn.data.hex()}"
            elif address in shadow:
                assert txn.data == shadow[address], f"{context}: RDATA {txn.data.hex()}"


@cocotb.test()
async def termination_mixed_traffic_test(dut):
    # One initiator, with and without random response backpressure.
    tb = TerminationTB(dut)
    try:
        await tb.reset()
        axil = tb.add_master("S0_AXI")
        await termination_traffic(axil, 0x100, 0, 300)
        tb.set_random_pauses(axil, 0x51)
        await termination_traffic(axil, 0x151, 0, 300)
    finally:
        await tb.close()


@cocotb.test()
async def termination_ready_drop_test(dut):
    # Lower response READY after request acceptance (or start it low) for every
    # target, including the undriven EMPTY_* ports, on both channels.
    tb = TerminationTB(dut)
    try:
        await tb.reset()
        sequence = 0
        for write_stall in (True, False):
            for initial_ready in (1, 0):
                for name, base, resp, rdata in TERMINATION_TARGETS:
                    sequence += 1
                    address = base + 0x20
                    data = 0x5A00_0000 | sequence
                    context = f"{name} initial_ready={initial_ready} write_stall={write_stall}"
                    try:
                        await raw_transfer(dut, "S0_AXI", True, address, data,
                                           initial_ready if write_stall else 1, write_stall, resp)
                        await raw_transfer(dut, "S0_AXI", False, address, data,
                                           1 if write_stall else initial_ready, not write_stall,
                                           resp, rdata)
                    except AssertionError as error:
                        raise AssertionError(f"{context}: {error}") from None
    finally:
        await tb.close()


@cocotb.test()
async def termination_two_initiator_test(dut):
    # Two initiators share the RAM, EMPTY_* and cascade ports under random
    # response backpressure, forcing arbitration on every destination.
    tb = TerminationTB(dut)
    try:
        await tb.reset()
        masters = [tb.add_master("S0_AXI"), tb.add_master("S1_AXI")]
        for axil, seed in zip(masters, (0x61, 0x62)):
            tb.set_random_pauses(axil, seed)
        workers = [
            cocotb.start_soon(termination_traffic(masters[0], 0x200, 0x000, 300)),
            cocotb.start_soon(termination_traffic(masters[1], 0x201, 0x100, 300)),
        ]
        for worker in workers:
            await worker
    finally:
        await tb.close()


def test_AxiLiteCrossbar():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitecrossbaripintegrator",
        extra_env=cocotb_filtered_env({}, cocotb_test_filter_excluding(*TERMINATION_TESTS)),
    )


def test_AxiLiteCrossbarTermination():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitecrossbarterminationipintegrator",
        extra_env=cocotb_filtered_env({}, cocotb_test_filter(*TERMINATION_TESTS)),
    )
