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
# - Sweep: Run same-width and widening cases through the flat IP-integrator
#   wrapper, including 4-byte and 8-byte output widths.
# - Stimulus: Drive contiguous-from-bit-0 tKeep beats into the flat slave port
#   with both always-ready and held-ready-low sink behavior.
# - Checks (four scenarios, reset between each):
#   1. Single-beat final flush preserves payload, keep, sidebands, and `tLast`.
#   2. Multi-beat repack: four contiguous single-byte beats compact into one
#      full 4-byte output word.
#   3. Overflow + partial-final flush: more than one master word of payload
#      fills one word and spills the remainder onto a second beat carrying
#      `tLast` with a partial keep.
#   4. Output backpressure holds the output beat stable until `M_AXIS_TREADY`.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.rx_beats = []
        self.slave_bytes = len(dut.S_AXIS_TKEEP)
        self.master_bytes = len(dut.M_AXIS_TKEEP)
        self.user_mask = (1 << len(dut.S_AXIS_TUSER)) - 1

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())
        dut.axisRst.setimmediatevalue(1)
        dut.S_AXIS_TVALID.setimmediatevalue(0)
        dut.S_AXIS_TDATA.setimmediatevalue(0)
        dut.S_AXIS_TKEEP.setimmediatevalue(0)
        dut.S_AXIS_TLAST.setimmediatevalue(0)
        dut.S_AXIS_TDEST.setimmediatevalue(0)
        dut.S_AXIS_TID.setimmediatevalue(0)
        dut.S_AXIS_TUSER.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(1)
        # Lifetime monitor retained by the bench until cocotb ends the test.
        self._monitor_task = cocotb.start_soon(self._monitor())

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axisRst.value = 0
        await self.cycle(3)

    async def _monitor(self):
        """Lifetime agent: collect compacted output beats until the test ends."""
        while True:
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")
            if int(self.dut.M_AXIS_TVALID.value) and int(self.dut.M_AXIS_TREADY.value):
                self.rx_beats.append(
                    (
                        int(self.dut.M_AXIS_TDATA.value),
                        int(self.dut.M_AXIS_TKEEP.value),
                        int(self.dut.M_AXIS_TLAST.value),
                        int(self.dut.M_AXIS_TDEST.value),
                        int(self.dut.M_AXIS_TID.value),
                        int(self.dut.M_AXIS_TUSER.value),
                    )
                )

    async def drive_beat(self, *, data: int, keep: int, last: int, dest: int, tid: int, user: int):
        self.dut.S_AXIS_TDATA.value = data
        self.dut.S_AXIS_TKEEP.value = keep
        self.dut.S_AXIS_TLAST.value = last
        self.dut.S_AXIS_TDEST.value = dest
        self.dut.S_AXIS_TID.value = tid
        self.dut.S_AXIS_TUSER.value = user & self.user_mask
        self.dut.S_AXIS_TVALID.value = 1
        await wait_sampled_ready(self.dut.S_AXIS_TREADY, clk=self.dut.axisClk)
        self.dut.S_AXIS_TVALID.value = 0

    async def drive_payload(self, payload: bytes, *, chunk_size: int, dest: int, tid: int, user: int):
        offset = 0
        while offset < len(payload):
            chunk = payload[offset:offset + chunk_size]
            offset += len(chunk)
            await self.drive_beat(
                data=int.from_bytes(chunk, "little"),
                keep=(1 << len(chunk)) - 1,
                last=1 if offset == len(payload) else 0,
                dest=dest,
                tid=tid,
                user=user,
            )

    def expected_beat(self, payload: bytes, *, last: int, dest: int, tid: int, user: int):
        return (
            int.from_bytes(payload.ljust(self.master_bytes, b"\x00"), "little"),
            (1 << len(payload)) - 1,
            last,
            dest,
            tid,
            user & self.user_mask,
        )


@cocotb.test()
async def repack_scenarios_test(dut):
    tb = TB(dut)

    dest = 0x5A
    tid = 0xC3
    user = 0x3

    # Scenario 1: a single final beat flushes unchanged.
    await tb.reset()
    tb.rx_beats.clear()
    single = bytes(range(0x11, 0x11 + tb.slave_bytes))
    await tb.drive_payload(single, chunk_size=tb.slave_bytes, dest=dest, tid=tid, user=user)
    await tb.cycle(4)
    assert tb.rx_beats == [tb.expected_beat(single, last=1, dest=dest, tid=tid, user=user)], tb.rx_beats

    # Scenario 2: four contiguous single-byte beats compact into one full word.
    await tb.reset()
    tb.rx_beats.clear()
    payload = bytes(range(0x21, 0x21 + tb.master_bytes))
    await tb.drive_payload(payload, chunk_size=1, dest=dest, tid=tid, user=user)
    await tb.cycle(4)
    assert tb.rx_beats == [tb.expected_beat(payload, last=1, dest=dest, tid=tid, user=user)], tb.rx_beats

    # Scenario 3: payload longer than the master width spills onto a final
    # partial beat.
    await tb.reset()
    tb.rx_beats.clear()
    payload = bytes(range(0x31, 0x31 + tb.master_bytes + 2))
    await tb.drive_payload(payload, chunk_size=min(tb.slave_bytes, tb.master_bytes - 1), dest=dest, tid=tid, user=user)
    await tb.cycle(4)
    assert tb.rx_beats == [
        tb.expected_beat(payload[:tb.master_bytes], last=0, dest=dest, tid=tid, user=user),
        tb.expected_beat(payload[tb.master_bytes:], last=1, dest=dest, tid=tid, user=user),
    ], tb.rx_beats

    # Scenario 4: backpressure holds a completed output beat until the sink is ready.
    await tb.reset()
    tb.rx_beats.clear()
    dut.M_AXIS_TREADY.value = 0
    payload = bytes(range(0x51, 0x51 + tb.slave_bytes))
    await tb.drive_payload(payload, chunk_size=tb.slave_bytes, dest=dest, tid=tid, user=user)
    await tb.cycle(3)
    assert tb.rx_beats == []
    assert int(dut.M_AXIS_TVALID.value) == 1
    assert int(dut.M_AXIS_TDATA.value) == int.from_bytes(payload.ljust(tb.master_bytes, b"\x00"), "little")
    assert int(dut.M_AXIS_TKEEP.value) == (1 << len(payload)) - 1
    assert int(dut.M_AXIS_TLAST.value) == 1
    dut.M_AXIS_TREADY.value = 1
    await tb.cycle(4)
    assert tb.rx_beats == [tb.expected_beat(payload, last=1, dest=dest, tid=tid, user=user)], tb.rx_beats


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({}, id="contiguous_same_width"),
        pytest.param({"SLAVE_DATA_BYTES_G": 2, "MASTER_DATA_BYTES_G": 4}, id="contiguous_2_to_4"),
        pytest.param({"SLAVE_DATA_BYTES_G": 4, "MASTER_DATA_BYTES_G": 8}, id="contiguous_4_to_8"),
        pytest.param({"SLAVE_DATA_BYTES_G": 8, "MASTER_DATA_BYTES_G": 8}, id="contiguous_8_to_8"),
    ],
)
def test_AxiStreamCompact(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamcompactipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
