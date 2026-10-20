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
# - Sweep: Four width cases (equal-width bypass, 32-bit-to-64-bit upsize,
#   32-bit-to-128-bit upsize, and 64-bit-to-32-bit downsize), each run with
#   the slave read data channel free running and with it randomly stalled.
# - Stimulus: One aligned write/read burst pair as the round-trip baseline.
#   Then single reads of 1 to 9 slave beats from a master-aligned address and,
#   when upsizing, from every slave-aligned offset inside a master beat, with
#   the same ARID reused so a leftover beat would corrupt the next read. Then a
#   batch of concurrent reads with mixed lengths and IDs issued back to back so
#   more requests are outstanding than the read request queue can hold.
# - Checks: Every read returns exactly the requested bytes from the downstream
#   RAM image. A slave-side R monitor confirms each burst delivers ARLEN+1
#   handshakes with RLAST only on the final one. The accepted downstream
#   AWLEN/ARLEN/ARSIZE match the resized beat count for the active widths.
# - Timing: Handshake monitors sample at the clock edge so the resize logic is
#   measured on actual handshakes, not on source intent. Stalled runs pause
#   slave RREADY with a repeating pattern so the hold register and the queue
#   head are reused under backpressure.

import itertools
import os
import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from cocotbext.axi import AxiBus, AxiMaster, AxiRam

from tests.common.regression_utils import hdl_parameters_from, parameter_case, run_surf_vhdl_test, sample_after_tpd

RAM_SIZE = 2**16
RAM_IMAGE_LEN = 0x1000


def logic_int(value) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.slave_bytes = int(os.environ["SLAVE_DATA_BYTES_G"])
        self.master_bytes = int(os.environ["MASTER_DATA_BYTES_G"])
        self.stall = os.environ.get("R_STALL", "0") == "1"
        self.aw_meta = []
        self.ar_meta = []
        self.r_beats = []

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())

        dut.axiRst.setimmediatevalue(1)
        self.master = None
        self.ram = None

        # Lifetime monitors retained by the bench until cocotb ends the test.
        # They sample at the clock edge so valid and ready are read from the
        # same cycle: registered DUT outputs change after TPD and the model
        # drives its ready for the next cycle right after the edge.
        self._monitor_tasks = (
            cocotb.start_soon(self._monitor_aw()),
            cocotb.start_soon(self._monitor_ar()),
            cocotb.start_soon(self._monitor_r()),
        )

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axiClk)

    async def reset(self):
        # Reset the wrapper shims and the resize state so each parameter case
        # starts from an empty partial-beat accumulator and request queue.
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    async def start_agents(self):
        if self.master is None:
            self.master = AxiMaster(AxiBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)
            if self.stall:
                # Deassert slave-side RREADY on a repeating pattern so slices
                # drain from the hold register under backpressure.
                self.master.read_if.r_channel.set_pause_generator(itertools.cycle([False, True, True, False, True]))
        if self.ram is None:
            self.ram = AxiRam(AxiBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=RAM_SIZE)
            # Unique data at every byte address so a stale or shifted beat is
            # visible as a payload mismatch.
            rng = random.Random(0x5EED)
            self.ram.write(0, bytes(rng.getrandbits(8) for _ in range(RAM_IMAGE_LEN)))
        # Give the models a few cycles to arm their ready signals before any
        # transaction is issued.
        await self.cycle(3)

    async def _monitor_aw(self):
        """Lifetime agent: record resized write metadata for this test."""
        while True:
            await RisingEdge(self.dut.axiClk)
            if logic_int(self.dut.M_AXI_AWVALID.value) and logic_int(self.dut.M_AXI_AWREADY.value):
                self.aw_meta.append(
                    (
                        int(self.dut.M_AXI_AWADDR.value),
                        int(self.dut.M_AXI_AWLEN.value),
                        int(self.dut.M_AXI_AWSIZE.value),
                    )
                )

    async def _monitor_ar(self):
        """Lifetime agent: record resized read metadata for this test."""
        while True:
            await RisingEdge(self.dut.axiClk)
            if logic_int(self.dut.M_AXI_ARVALID.value) and logic_int(self.dut.M_AXI_ARREADY.value):
                self.ar_meta.append(
                    (
                        int(self.dut.M_AXI_ARADDR.value),
                        int(self.dut.M_AXI_ARLEN.value),
                        int(self.dut.M_AXI_ARSIZE.value),
                    )
                )

    async def _monitor_r(self):
        """Lifetime agent: record every slave-side read data handshake."""
        while True:
            await RisingEdge(self.dut.axiClk)
            if logic_int(self.dut.S_AXI_RVALID.value) and logic_int(self.dut.S_AXI_RREADY.value):
                self.r_beats.append(
                    (
                        int(self.dut.S_AXI_RID.value),
                        logic_int(self.dut.S_AXI_RLAST.value),
                    )
                )

    def read_bursts(self):
        """Split the recorded R handshakes into bursts at each RLAST."""
        bursts = []
        current = []
        for rid, rlast in self.r_beats:
            current.append(rid)
            if rlast:
                bursts.append(tuple(current))
                current = []
        assert current == [], f"read data left without RLAST: {current}"
        return bursts

    def expected_master_beats(self, address, length):
        """Master beats needed to cover the slave-side byte range."""
        offset = address % self.master_bytes
        return (offset + length + self.master_bytes - 1) // self.master_bytes


@cocotb.test()
async def write_read_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.start_agents()

    payload_len = 2 * max(tb.slave_bytes, tb.master_bytes)
    payload = bytes((0x40 + i) & 0xFF for i in range(payload_len))
    address = 0x0020

    write_resp = await with_timeout(tb.master.write(address, payload, awid=3), 2, "us")
    read_resp = await with_timeout(tb.master.read(address, payload_len, arid=2), 2, "us")

    expected_beats = (payload_len + tb.master_bytes - 1) // tb.master_bytes
    expected_size = tb.master_bytes.bit_length() - 1

    assert write_resp.resp == 0
    assert bytes(read_resp) == payload
    assert read_resp.resp == 0
    assert tb.ram.read(address, payload_len) == payload
    assert tb.aw_meta[-1] == (address, expected_beats - 1, expected_size)
    assert tb.ar_meta[-1] == (address, expected_beats - 1, expected_size)


@cocotb.test()
async def read_length_sweep_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.start_agents()

    expected_size = tb.master_bytes.bit_length() - 1

    # Every slave-aligned start offset inside one master beat when upsizing,
    # otherwise only the aligned start.
    if tb.master_bytes > tb.slave_bytes:
        offsets = range(0, tb.master_bytes, tb.slave_bytes)
    else:
        offsets = [0]

    base = 0x0100
    for offset in offsets:
        for beats in range(1, 10):
            address = base + offset
            length = beats * tb.slave_bytes
            expected = tb.ram.read(address, length)

            # Reuse one ARID so any beat left behind by the previous read
            # would be returned as the start of this one.
            tb.r_beats.clear()
            read_resp = await with_timeout(tb.master.read(address, length, arid=2), 5, "us")
            await tb.cycle(8)

            assert read_resp.resp == 0
            assert bytes(read_resp) == expected, f"payload mismatch offset={offset} beats={beats}"

            bursts = tb.read_bursts()
            assert bursts == [tuple([2] * beats)], f"R beats offset={offset} beats={beats}: {tb.r_beats}"

            expected_beats = tb.expected_master_beats(address, length)
            assert tb.ar_meta[-1] == (address, expected_beats - 1, expected_size)

            # Step through memory so consecutive reads never see the same data.
            base += 0x40


@cocotb.test()
async def outstanding_reads_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.start_agents()

    # More requests than the default 16-entry read request queue, mixing
    # lengths and IDs, all issued without waiting for data.
    lengths = itertools.cycle([1, 3, 2, 5, 1, 4, 7, 2, 9])
    ids = itertools.cycle([1, 2, 3])
    requests = []
    address = 0x0200
    for _ in range(24):
        beats = next(lengths)
        requests.append((address, beats * tb.slave_bytes, next(ids)))
        address += 0x80

    tb.r_beats.clear()
    tasks = [cocotb.start_soon(tb.master.read(addr, length, arid=arid)) for addr, length, arid in requests]
    results = [await with_timeout(task, 50, "us") for task in tasks]
    await tb.cycle(8)

    for (addr, length, arid), read_resp in zip(requests, results):
        assert read_resp.resp == 0
        assert bytes(read_resp) == tb.ram.read(addr, length), f"payload mismatch addr={addr:#x} len={length}"

    # The downstream RAM returns bursts whole and in request order, so the
    # slave-side bursts must line up one to one with the requests.
    expected_bursts = [tuple([arid] * (length // tb.slave_bytes)) for _, length, arid in requests]
    assert tb.read_bursts() == expected_bursts


PARAMETER_SWEEP = [
    parameter_case("equal_width", SLAVE_DATA_BYTES_G="4", MASTER_DATA_BYTES_G="4", R_STALL="0"),
    parameter_case("equal_width_stall", SLAVE_DATA_BYTES_G="4", MASTER_DATA_BYTES_G="4", R_STALL="1"),
    parameter_case("upsize", SLAVE_DATA_BYTES_G="4", MASTER_DATA_BYTES_G="8", R_STALL="0"),
    parameter_case("upsize_stall", SLAVE_DATA_BYTES_G="4", MASTER_DATA_BYTES_G="8", R_STALL="1"),
    parameter_case("upsize_4x", SLAVE_DATA_BYTES_G="4", MASTER_DATA_BYTES_G="16", R_STALL="0"),
    parameter_case("upsize_4x_stall", SLAVE_DATA_BYTES_G="4", MASTER_DATA_BYTES_G="16", R_STALL="1"),
    parameter_case("downsize", SLAVE_DATA_BYTES_G="8", MASTER_DATA_BYTES_G="4", R_STALL="0"),
    parameter_case("downsize_stall", SLAVE_DATA_BYTES_G="8", MASTER_DATA_BYTES_G="4", R_STALL="1"),
]

@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiResize(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiresizeipintegrator",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiResizeIpIntegrator.vhd",
            ],
        },
    )
