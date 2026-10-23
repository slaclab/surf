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
# - Sweep: Keep a three-case wrapper-focused sweep covering indexed routing to
#   both outputs, routed exact-match decode with sink-side backpressure, and a
#   staged dynamic-route case that also proves unmatched destinations are
#   dropped and asynchronous active-low reset flushes buffered output.
# - Stimulus: Drive one-beat AXI Stream frames with distinct payload, `tdest`,
#   `tid`, and `tuser` values through the single slave port, hold one selected
#   output not-ready while a beat is buffered, update the dynamic route table
#   between transfers, and assert reset after the staged path has state.
# - Checks: Frames must appear on exactly the selected output, metadata must be
#   preserved end-to-end, unmatched destinations must be accepted and dropped
#   without creating output traffic, and reset must clear staged output before
#   post-reset traffic routes cleanly through the updated table.
# - Timing: The bench checks the bounded output visibility of routed and
#   dynamic cases under `PIPE_STAGES_G`, requires blocked output beats to stay
#   stable across several stalled cycles, and checks reset as a bounded flush
#   on the staged path.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource

from tests.common.regression_utils import env_flag, env_sl, run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.data_bytes = int(os.environ["DATA_BYTES_G"])
        self.pipe_stages = int(os.environ["PIPE_STAGES_G"])
        self.reset_async = env_flag("RST_ASYNC_G", default=False)
        self.reset_active = env_sl("RST_POLARITY_G", default=1)
        self.source = None

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

        dut.axisRst.setimmediatevalue(self.reset_active_value())
        dut.dynamicRouteMask0.setimmediatevalue(0)
        dut.dynamicRouteDest0.setimmediatevalue(0)
        dut.dynamicRouteMask1.setimmediatevalue(0)
        dut.dynamicRouteDest1.setimmediatevalue(0)
        dut.M0_AXIS_TREADY.setimmediatevalue(0)
        dut.M1_AXIS_TREADY.setimmediatevalue(0)
        self.drive_source_idle()

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def settle(self):
        await Timer(1, unit="ns")

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await self.settle()

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(self.reset_active_value())
        self.dut.M0_AXIS_TREADY.value = 0
        self.dut.M1_AXIS_TREADY.value = 0
        self.drive_source_idle()
        await self.cycle(2)
        self.dut.axisRst.value = self.reset_active_value()
        await self.cycle(2)
        self.dut.axisRst.value = self.reset_inactive_value()
        await self.cycle(2)

    def start_source(self):
        if self.source is None:
            self.source = AxiStreamSource(
                bus=AxiStreamBus.from_prefix(self.dut, "S_AXIS"),
                clock=self.dut.axisClk,
                reset=self.dut.axisRst,
                reset_active_level=bool(self.reset_active),
            )

    def drive_source_idle(self):
        self.dut.S_AXIS_TVALID.value = 0
        self.dut.S_AXIS_TDATA.value = 0
        self.dut.S_AXIS_TKEEP.value = 0
        self.dut.S_AXIS_TLAST.value = 0
        self.dut.S_AXIS_TDEST.value = 0
        self.dut.S_AXIS_TID.value = 0
        self.dut.S_AXIS_TUSER.value = 0

    def output_snapshot(self, index):
        prefix = f"M{index}_AXIS"
        return (
            int(getattr(self.dut, f"{prefix}_TVALID").value),
            int(getattr(self.dut, f"{prefix}_TDATA").value),
            int(getattr(self.dut, f"{prefix}_TKEEP").value),
            int(getattr(self.dut, f"{prefix}_TLAST").value),
            int(getattr(self.dut, f"{prefix}_TDEST").value),
            int(getattr(self.dut, f"{prefix}_TID").value),
            int(getattr(self.dut, f"{prefix}_TUSER").value),
        )

    def any_output_valid(self):
        return int(self.dut.M0_AXIS_TVALID.value) or int(self.dut.M1_AXIS_TVALID.value)

    async def wait_for_output_valid(self, index, timeout_cycles=16):
        for _ in range(timeout_cycles):
            await self.settle()
            if int(getattr(self.dut, f"M{index}_AXIS_TVALID").value):
                return
            await self.cycle(1)
        raise AssertionError(f"Timed out waiting for output {index} valid")

    async def wait_for_output_clear(self, index, timeout_cycles=16):
        for _ in range(timeout_cycles):
            await self.settle()
            if int(getattr(self.dut, f"M{index}_AXIS_TVALID").value) == 0:
                return
            await self.cycle(1)
        raise AssertionError(f"Timed out waiting for output {index} clear")

    async def wait_for_all_outputs_clear(self, timeout_cycles=16):
        for _ in range(timeout_cycles):
            await self.settle()
            if not self.any_output_valid():
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for all outputs to clear")

    async def accept_output(self, index):
        getattr(self.dut, f"M{index}_AXIS_TREADY").value = 1
        await self.cycle(1)
        getattr(self.dut, f"M{index}_AXIS_TREADY").value = 0


def make_frame(payload_bytes, *, tdest, tid, tuser):
    frame = AxiStreamFrame(payload_bytes)
    frame.tdest = tdest
    frame.tid = tid
    frame.tuser = tuser
    return frame


async def run_indexed_routing_scenario(tb: TB):
    await tb.reset()
    tb.start_source()

    frame0 = make_frame(b"\x10\x11\x12\x13", tdest=0x00, tid=0x21, tuser=1)
    frame1 = make_frame(b"\x20\x21\x22\x23", tdest=0x01, tid=0x32, tuser=0)

    send0 = cocotb.start_soon(tb.source.send(frame0))
    await tb.wait_for_output_valid(0, timeout_cycles=tb.pipe_stages + 8)
    assert tb.output_snapshot(0) == (
        1,
        int.from_bytes(frame0.tdata, "little"),
        (1 << len(frame0.tdata)) - 1,
        1,
        frame0.tdest,
        frame0.tid,
        frame0.tuser,
    )
    assert tb.output_snapshot(1)[0] == 0
    await tb.accept_output(0)
    await send0
    await tb.wait_for_output_clear(0, timeout_cycles=tb.pipe_stages + 4)

    send1 = cocotb.start_soon(tb.source.send(frame1))
    await tb.wait_for_output_valid(1, timeout_cycles=tb.pipe_stages + 8)
    assert tb.output_snapshot(1) == (
        1,
        int.from_bytes(frame1.tdata, "little"),
        (1 << len(frame1.tdata)) - 1,
        1,
        frame1.tdest,
        frame1.tid,
        frame1.tuser,
    )
    assert tb.output_snapshot(0)[0] == 0
    await tb.accept_output(1)
    await send1
    await tb.wait_for_output_clear(1, timeout_cycles=tb.pipe_stages + 4)


async def run_routed_backpressure_scenario(tb: TB):
    await tb.reset()
    tb.start_source()

    cases = [
        (0, 0xA2, make_frame(b"\x30\x31\x32\x33", tdest=0xA2, tid=0x11, tuser=0)),
        (1, 0x5C, make_frame(b"\x40\x41\x42\x43", tdest=0x5C, tid=0x22, tuser=1)),
    ]

    for output_index, _, frame in cases:
        send_task = cocotb.start_soon(tb.source.send(frame))
        await tb.wait_for_output_valid(output_index, timeout_cycles=tb.pipe_stages + 8)
        snapshot = tb.output_snapshot(output_index)
        assert snapshot == (
            1,
            int.from_bytes(frame.tdata, "little"),
            (1 << len(frame.tdata)) - 1,
            1,
            frame.tdest,
            frame.tid,
            frame.tuser,
        )
        assert tb.output_snapshot(1 - output_index)[0] == 0

        for _ in range(3):
            await tb.cycle(1)
            assert tb.output_snapshot(output_index) == snapshot

        await tb.accept_output(output_index)
        await send_task
        await tb.wait_for_output_clear(output_index, timeout_cycles=tb.pipe_stages + 4)


async def run_dynamic_drop_reset_scenario(tb: TB):
    await tb.reset()
    tb.start_source()

    tb.dut.dynamicRouteMask0.value = 0xF0
    tb.dut.dynamicRouteDest0.value = 0xA0
    tb.dut.dynamicRouteMask1.value = 0xF0
    tb.dut.dynamicRouteDest1.value = 0x50

    drop_frame = make_frame(b"\x50\x51\x52\x53", tdest=0xE3, tid=0x17, tuser=1)
    send_drop = cocotb.start_soon(tb.source.send(drop_frame))
    await send_drop
    await tb.cycle(tb.pipe_stages + 3)
    assert not tb.any_output_valid()

    routed_frame = make_frame(b"\x60\x61\x62\x63", tdest=0x57, tid=0x2A, tuser=0)
    send_route = cocotb.start_soon(tb.source.send(routed_frame))
    await tb.wait_for_output_valid(1, timeout_cycles=tb.pipe_stages + 8)
    snapshot = tb.output_snapshot(1)
    assert snapshot == (
        1,
        int.from_bytes(routed_frame.tdata, "little"),
        (1 << len(routed_frame.tdata)) - 1,
        1,
        routed_frame.tdest,
        routed_frame.tid,
        routed_frame.tuser,
    )
    await send_route

    tb.dut.axisRst.value = tb.reset_active_value()
    await tb.wait_for_all_outputs_clear(timeout_cycles=tb.pipe_stages + 4)
    tb.dut.axisRst.value = tb.reset_inactive_value()
    await tb.cycle(2)

    tb.dut.dynamicRouteMask0.value = 0xF0
    tb.dut.dynamicRouteDest0.value = 0xC0
    tb.dut.dynamicRouteMask1.value = 0xF0
    tb.dut.dynamicRouteDest1.value = 0x50

    recovery_frame = make_frame(b"\x70\x71\x72\x73", tdest=0xC9, tid=0x44, tuser=1)
    send_recovery = cocotb.start_soon(tb.source.send(recovery_frame))
    await tb.wait_for_output_valid(0, timeout_cycles=tb.pipe_stages + 8)
    assert tb.output_snapshot(0) == (
        1,
        int.from_bytes(recovery_frame.tdata, "little"),
        (1 << len(recovery_frame.tdata)) - 1,
        1,
        recovery_frame.tdest,
        recovery_frame.tid,
        recovery_frame.tuser,
    )
    await tb.accept_output(0)
    await send_recovery
    await tb.wait_for_output_clear(0, timeout_cycles=tb.pipe_stages + 4)


@cocotb.test()
async def demux_behavior_test(dut):
    tb = TB(dut)
    scenario = os.environ["SCENARIO"]

    if scenario == "indexed_routing":
        await run_indexed_routing_scenario(tb)
    elif scenario == "routed_backpressure":
        await run_routed_backpressure_scenario(tb)
    elif scenario == "dynamic_drop_reset":
        await run_dynamic_drop_reset_scenario(tb)
    else:
        raise AssertionError(f"Unsupported AxiStreamDeMux scenario: {scenario}")


CASES = [
    pytest.param(
        {
            "parameters": {
                "DATA_BYTES_G": "4",
                "TUSER_WIDTH_G": "1",
                "PIPE_STAGES_G": "0",
                "MODE_G": "INDEXED",
                "TDEST_HIGH_G": "0",
                "TDEST_LOW_G": "0",
                "RST_ASYNC_G": "false",
                "RST_POLARITY_G": "'1'",
            },
            "extra_env": {
                "SCENARIO": "indexed_routing",
            },
        },
        id="indexed_sync",
    ),
    pytest.param(
        {
            "parameters": {
                "DATA_BYTES_G": "4",
                "TUSER_WIDTH_G": "1",
                "PIPE_STAGES_G": "1",
                "MODE_G": "ROUTED",
                "TDEST_ROUTE_0_G": "162",
                "TDEST_ROUTE_1_G": "92",
                "RST_ASYNC_G": "false",
                "RST_POLARITY_G": "'1'",
            },
            "extra_env": {
                "SCENARIO": "routed_backpressure",
            },
        },
        id="routed_backpressure_sync",
    ),
    pytest.param(
        {
            "parameters": {
                "DATA_BYTES_G": "4",
                "TUSER_WIDTH_G": "1",
                "PIPE_STAGES_G": "2",
                "MODE_G": "DYNAMIC",
                "RST_ASYNC_G": "true",
                "RST_POLARITY_G": "'0'",
            },
            "extra_env": {
                "SCENARIO": "dynamic_drop_reset",
            },
        },
        id="dynamic_drop_async_active_low",
    ),
]


@pytest.mark.parametrize("case", CASES)
def test_AxiStreamDeMux(case):
    extra_env = dict(case["parameters"])
    extra_env.update(case["extra_env"])

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdemuxipintegrator",
        parameters=case["parameters"],
        extra_env=extra_env,
    )
