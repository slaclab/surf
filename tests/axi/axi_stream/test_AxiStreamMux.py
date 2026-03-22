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
# - Sweep: Keep a three-case wrapper-focused sweep covering indexed arbitration
#   with explicit priority and `disableSel` control, routed `TDEST`/`TID`
#   remap under output backpressure, and a staged asynchronous active-low
#   passthrough reset case so the bench proves the mux-specific behaviors
#   without exploring every interleave or re-arbitration mode.
# - Stimulus: Launch overlapping traffic from both slave ports, stall the
#   output while a selected beat is buffered, and assert reset after the
#   passthrough case has visible state in the wrapper-facing output path.
# - Checks: The selected source order must follow the configured priority and
#   `disableSel` mask, routed mode must rewrite `tdest` and `tid` while
#   preserving payload fields, and reset must flush staged output state before
#   the mux accepts clean post-reset traffic again.
# - Timing: Indexed arbitration is checked across overlapping sends, routed
#   mode requires the output beat to stay stable for several blocked cycles,
#   and the reset case checks bounded flush and recovery on the staged path.

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
        self.sources = []

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

        dut.axisRst.setimmediatevalue(self.reset_active_value())
        dut.disableSel.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.drive_source_idle(0)
        self.drive_source_idle(1)

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def settle(self):
        # The SURF AXI wrappers use the default `TPD_G`, so wait briefly after
        # each edge before sampling registered outputs or ready signals.
        await Timer(1, unit="ns")

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await self.settle()

    async def reset(self):
        # Hold reset for a few edges so both slave wrappers and the mux state
        # machines start from the same known handshake state.
        self.dut.axisRst.setimmediatevalue(self.reset_active_value())
        self.dut.disableSel.value = 0
        self.dut.M_AXIS_TREADY.value = 0
        self.drive_source_idle(0)
        self.drive_source_idle(1)
        await self.cycle(2)
        self.dut.axisRst.value = self.reset_active_value()
        await self.cycle(2)
        self.dut.axisRst.value = self.reset_inactive_value()
        await self.cycle(2)

    def start_agents(self):
        if not self.sources:
            for index in range(2):
                self.sources.append(
                    AxiStreamSource(
                        bus=AxiStreamBus.from_prefix(self.dut, f"S{index}_AXIS"),
                        clock=self.dut.axisClk,
                        reset=self.dut.axisRst,
                        reset_active_level=bool(self.reset_active),
                    )
                )

    def drive_source(self, index, *, valid, data, keep, last, tdest, tid, tuser=0):
        getattr(self.dut, f"S{index}_AXIS_TVALID").value = valid
        getattr(self.dut, f"S{index}_AXIS_TDATA").value = data
        getattr(self.dut, f"S{index}_AXIS_TKEEP").value = keep
        getattr(self.dut, f"S{index}_AXIS_TLAST").value = last
        getattr(self.dut, f"S{index}_AXIS_TDEST").value = tdest
        getattr(self.dut, f"S{index}_AXIS_TID").value = tid
        getattr(self.dut, f"S{index}_AXIS_TUSER").value = tuser

    def drive_source_idle(self, index):
        self.drive_source(
            index,
            valid=0,
            data=0,
            keep=0,
            last=0,
            tdest=0,
            tid=0,
            tuser=0,
        )

    def output_snapshot(self):
        return (
            int(self.dut.M_AXIS_TVALID.value),
            int(self.dut.M_AXIS_TDATA.value),
            int(self.dut.M_AXIS_TKEEP.value),
            int(self.dut.M_AXIS_TLAST.value),
            int(self.dut.M_AXIS_TDEST.value),
            int(self.dut.M_AXIS_TID.value),
            int(self.dut.M_AXIS_TUSER.value),
        )

    async def wait_for_output_valid(self, timeout_cycles=16):
        # Staged configurations need a bounded poll because the selected beat
        # only becomes visible after the mux and output pipeline both update.
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.M_AXIS_TVALID.value):
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for mux output valid")

    async def wait_for_output_clear(self, timeout_cycles=16):
        # Reset and handshake completion both clear the wrapper-facing valid
        # bit asynchronously with respect to the Python coroutine schedule.
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.M_AXIS_TVALID.value) == 0:
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for mux output clear")

    async def wait_for_output_data(self, expected_data, timeout_cycles=16):
        # Some transitions go directly from one valid beat to the next without
        # an idle cycle, so poll for the specific payload instead of waiting
        # for a full clear between accepted transactions.
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.M_AXIS_TVALID.value) and int(self.dut.M_AXIS_TDATA.value) == expected_data:
                return
            await self.cycle(1)
        raise AssertionError(f"Timed out waiting for mux output data 0x{expected_data:X}")

    async def accept_output(self):
        # Pulse ready for one cycle so the current beat is accepted, then drop
        # back to blocked mode before the next assertion samples the output.
        self.dut.M_AXIS_TREADY.value = 1
        await self.cycle(1)
        self.dut.M_AXIS_TREADY.value = 0


async def run_indexed_priority_scenario(tb: TB):
    await tb.reset()
    tb.start_agents()

    frame0 = AxiStreamFrame(b"\x10\x11\x12\x13")
    frame0.tdest = 0xA0
    frame0.tid = 0x55
    frame1 = AxiStreamFrame(b"\x20\x21\x22\x23")
    frame1.tdest = 0xB0
    frame1.tid = 0x77

    # Launch both sources together so the mux has to arbitrate rather than
    # simply pass the only active requester through.
    send0 = cocotb.start_soon(tb.sources[0].send(frame0))
    send1 = cocotb.start_soon(tb.sources[1].send(frame1))

    await tb.wait_for_output_data(int.from_bytes(frame1.tdata, "little"), timeout_cycles=tb.pipe_stages + 8)
    first = tb.output_snapshot()
    assert first == (
        1,
        int.from_bytes(frame1.tdata, "little"),
        (1 << len(frame1.tdata)) - 1,
        1,
        1,
        1,
        0,
    )

    await tb.accept_output()

    await tb.wait_for_output_data(int.from_bytes(frame0.tdata, "little"), timeout_cycles=tb.pipe_stages + 8)
    second = tb.output_snapshot()
    await send0
    await send1
    assert second == (
        1,
        int.from_bytes(frame0.tdata, "little"),
        (1 << len(frame0.tdata)) - 1,
        1,
        0,
        0,
        0,
    )

    await tb.accept_output()

    # Then mask off the lower-priority port so the bench proves `disableSel`
    # blocks that source cleanly without conflicting with the mux's separate
    # higher-priority request masking logic.
    tb.dut.disableSel.value = 0b01

    frame2 = AxiStreamFrame(b"\x31\x32\x33\x34")
    frame2.tdest = 0xC1
    frame2.tid = 0x12
    frame3 = AxiStreamFrame(b"\x41\x42\x43\x44")
    frame3.tdest = 0xD1
    frame3.tid = 0x34

    send2 = cocotb.start_soon(tb.sources[0].send(frame2))

    # With source 0 masked off and no other active input, the mux should stay
    # idle instead of leaking the blocked source through.
    await tb.cycle(tb.pipe_stages + 4)
    assert int(tb.dut.M_AXIS_TVALID.value) == 0

    send3 = cocotb.start_soon(tb.sources[1].send(frame3))

    await tb.wait_for_output_data(int.from_bytes(frame3.tdata, "little"), timeout_cycles=tb.pipe_stages + 8)
    third = tb.output_snapshot()
    assert third == (
        1,
        int.from_bytes(frame3.tdata, "little"),
        (1 << len(frame3.tdata)) - 1,
        1,
        1,
        1,
        0,
    )

    await tb.accept_output()
    await send3

    tb.dut.disableSel.value = 0

    await tb.wait_for_output_data(int.from_bytes(frame2.tdata, "little"), timeout_cycles=tb.pipe_stages + 8)
    fourth = tb.output_snapshot()
    await send2
    assert fourth == (
        1,
        int.from_bytes(frame2.tdata, "little"),
        (1 << len(frame2.tdata)) - 1,
        1,
        0,
        0,
        0,
    )

    await tb.accept_output()
    await tb.wait_for_output_clear(timeout_cycles=tb.pipe_stages + 4)


async def run_routed_backpressure_scenario(tb: TB):
    await tb.reset()
    tb.start_agents()

    routed_expectations = [
        (0, 0xA2, 0x11, b"\x50\x51\x52\x53"),
        (1, 0x5C, 0x22, b"\x60\x61\x62\x63"),
    ]

    for source_index, routed_dest, routed_tid, payload in routed_expectations:
        frame = AxiStreamFrame(payload)
        frame.tdest = 0xE0 + source_index
        frame.tid = 0x70 + source_index

        tb.dut.M_AXIS_TREADY.value = 0
        send_task = cocotb.start_soon(tb.sources[source_index].send(frame))

        await tb.wait_for_output_valid(timeout_cycles=tb.pipe_stages + 8)
        snapshot = tb.output_snapshot()
        assert snapshot == (
            1,
            int.from_bytes(payload, "little"),
            (1 << len(payload)) - 1,
            1,
            routed_dest,
            routed_tid,
            0,
        )

        # Hold the sink blocked for a few cycles and require the selected beat
        # to stay completely stable while the wrapper output is stalled.
        for _ in range(3):
            await tb.cycle(1)
            assert tb.output_snapshot() == snapshot

        tb.dut.M_AXIS_TREADY.value = 1
        await send_task
        await tb.wait_for_output_clear(timeout_cycles=tb.pipe_stages + 4)
        tb.dut.M_AXIS_TREADY.value = 0


async def run_passthrough_reset_scenario(tb: TB):
    await tb.reset()
    tb.start_agents()

    first_frame = AxiStreamFrame(b"\x90\x91\x92\x93")
    first_frame.tdest = 0x4A
    first_frame.tid = 0x2C

    tb.dut.M_AXIS_TREADY.value = 0
    send_first = cocotb.start_soon(tb.sources[1].send(first_frame))

    await tb.wait_for_output_valid(timeout_cycles=tb.pipe_stages + 8)
    snapshot = tb.output_snapshot()
    assert snapshot == (
        1,
        int.from_bytes(first_frame.tdata, "little"),
        (1 << len(first_frame.tdata)) - 1,
        1,
        first_frame.tdest,
        first_frame.tid,
        0,
    )

    await send_first

    # Assert reset only after the staged output has real buffered state so the
    # check proves flush behavior instead of an idle reset.
    tb.dut.axisRst.value = tb.reset_active_value()
    await tb.wait_for_output_clear(timeout_cycles=tb.pipe_stages + 4)
    assert int(tb.dut.M_AXIS_TVALID.value) == 0

    tb.dut.axisRst.value = tb.reset_inactive_value()
    await tb.cycle(2)

    second_frame = AxiStreamFrame(b"\xA0\xA1\xA2\xA3")
    second_frame.tdest = 0x17
    second_frame.tid = 0x33

    send_second = cocotb.start_soon(tb.sources[0].send(second_frame))
    await tb.wait_for_output_valid(timeout_cycles=tb.pipe_stages + 8)
    recovery_snapshot = tb.output_snapshot()
    assert recovery_snapshot == (
        1,
        int.from_bytes(second_frame.tdata, "little"),
        (1 << len(second_frame.tdata)) - 1,
        1,
        second_frame.tdest,
        second_frame.tid,
        0,
    )

    tb.dut.M_AXIS_TREADY.value = 1
    await send_second
    await tb.wait_for_output_clear(timeout_cycles=tb.pipe_stages + 4)


@cocotb.test()
async def mux_behavior_test(dut):
    tb = TB(dut)
    scenario = os.environ["SCENARIO"]

    if scenario == "indexed_priority":
        await run_indexed_priority_scenario(tb)
    elif scenario == "routed_backpressure":
        await run_routed_backpressure_scenario(tb)
    elif scenario == "passthrough_reset":
        await run_passthrough_reset_scenario(tb)
    else:
        raise AssertionError(f"Unsupported AxiStreamMux scenario: {scenario}")


CASES = [
    pytest.param(
        {
            "parameters": {
                "DATA_BYTES_G": "4",
                "TUSER_WIDTH_G": "1",
                "PIPE_STAGES_G": "1",
                "MODE_G": "INDEXED",
                "TID_MODE_G": "INDEXED",
                "PRIORITY_0_G": "0",
                "PRIORITY_1_G": "3",
                "TDEST_LOW_G": "0",
                "RST_ASYNC_G": "false",
                "RST_POLARITY_G": "'1'",
            },
            "extra_env": {
                "SCENARIO": "indexed_priority",
            },
        },
        id="indexed_priority_sync",
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
                "TID_MODE_G": "ROUTED",
                "TID_ROUTE_0_G": "17",
                "TID_ROUTE_1_G": "34",
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
                "MODE_G": "PASSTHROUGH",
                "TID_MODE_G": "PASSTHROUGH",
                "RST_ASYNC_G": "true",
                "RST_POLARITY_G": "'0'",
            },
            "extra_env": {
                "SCENARIO": "passthrough_reset",
            },
        },
        id="passthrough_async_active_low_reset",
    ),
]


@pytest.mark.parametrize("case", CASES)
def test_AxiStreamMux(case):
    extra_env = dict(case["parameters"])
    extra_env.update(case["extra_env"])

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreammuxipintegrator",
        parameters=case["parameters"],
        extra_env=extra_env,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamMuxIpIntegrator.vhd"],
        },
    )
