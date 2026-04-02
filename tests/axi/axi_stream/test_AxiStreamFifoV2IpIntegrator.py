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
# - Sweep: Use a curated ten-case sweep that covers equal-width sync-FIFO
#   traffic, async upsize and custom-internal-width resize paths, downsize with
#   a narrow internal FIFO width, metadata-width truncation, multi-stage
#   cascade buffering, frame-ready and threshold-prefill release modes,
#   thresholded burst mode, and dynamic pause-threshold handling with and
#   without slave-side `tready`.
# - Stimulus: Use cocotbext AXI Stream agents for end-to-end traffic with idle
#   insertion and backpressure in the general cases, then use manual single-
#   byte driving in the thresholded cases so the bench can inspect output-valid
#   and pause behavior cycle-by-cycle.
# - Checks: Payload bytes must survive every configuration, `tid`/`tdest` and
#   one-beat `tuser` metadata must truncate to the wrapper-visible widths when
#   the source is wider than the sink, frame-ready and thresholded modes must
#   hold output until their release condition is met, burst mode must break
#   long frames into bounded output runs, and programmable pause must assert
#   and clear as the FIFO fills and drains.
# - Timing: Common-clock cases are driven from one coroutine so shared-edge
#   behavior is exact, async cases use skewed source and sink clocks to make
#   the CDC path do real work, and every timing-sensitive check uses bounded
#   waits around valid assertion, burst gaps, and pause release.

import itertools
import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import env_flag, run_surf_vhdl_test, start_lockstep_clocks


def mask(width: int) -> int:
    return (1 << width) - 1


def scalar_tuser(value) -> int:
    if value is None:
        return 0
    if isinstance(value, list):
        return int(value[0]) if value else 0
    return int(value)


def cycle_pause():
    return itertools.cycle([1, 1, 0, 1, 0, 0])


def curated_lengths(tb) -> list[int]:
    return sorted(
        {
            1,
            tb.s_bytes,
            tb.m_bytes,
            tb.s_bytes + 1,
            tb.m_bytes + 1,
            tb.s_bytes + tb.m_bytes + 1,
            (2 * max(tb.s_bytes, tb.m_bytes)) + 1,
        }
    )


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.s_bytes = int(os.environ["S_TDATA_NUM_BYTES"])
        self.m_bytes = int(os.environ["M_TDATA_NUM_BYTES"])
        self.s_tid_width = int(os.environ["S_TID_WIDTH"])
        self.m_tid_width = int(os.environ["M_TID_WIDTH"])
        self.s_dest_width = int(os.environ["S_TDEST_WIDTH"])
        self.m_dest_width = int(os.environ["M_TDEST_WIDTH"])
        self.s_user_width = int(os.environ["S_TUSER_WIDTH"])
        self.m_user_width = int(os.environ["M_TUSER_WIDTH"])
        self.source_has_tready = env_flag("S_HAS_TREADY", default=True)
        self.pipe_stages = int(os.environ["PIPE_STAGES"])
        self.int_pipe_stages = int(os.environ["INT_PIPE_STAGES"])
        self.fifo_addr_width = int(os.environ["FIFO_ADDR_WIDTH"])
        self.valid_thold = int(os.environ["VALID_THOLD"])
        self.valid_burst_mode = env_flag("VALID_BURST_MODE", default=False)
        self.clock_mode = os.environ["TEST_CLOCK_MODE"]
        self.test_metadata_truncation = env_flag("TEST_METADATA_TRUNCATION", default=False)
        self.test_frame_ready = env_flag("TEST_FRAME_READY", default=False)
        self.test_threshold_prefill = env_flag("TEST_THRESHOLD_PREFILL", default=False)
        self.test_burst_behavior = env_flag("TEST_BURST_BEHAVIOR", default=False)
        self.test_dynamic_pause = env_flag("TEST_DYNAMIC_PAUSE", default=False)
        self.source = None
        self.sink = None
        self.tx_cycles = []
        self.rx_cycles = []
        self.rx_last_users = []
        self.rx_beat_users = []

        if self.clock_mode == "lockstep":
            start_lockstep_clocks(dut.S_AXIS_ACLK, dut.M_AXIS_ACLK, period_ns=5.0)
        else:
            cocotb.start_soon(Clock(dut.S_AXIS_ACLK, 5.0, unit="ns").start())
            cocotb.start_soon(Clock(dut.M_AXIS_ACLK, 7.0, unit="ns").start())

        dut.S_AXIS_ARESETN.setimmediatevalue(0)
        dut.M_AXIS_ARESETN.setimmediatevalue(0)
        dut.S_AXIS_TVALID.setimmediatevalue(0)
        dut.S_AXIS_TDATA.setimmediatevalue(0)
        dut.S_AXIS_TKEEP.setimmediatevalue(0)
        dut.S_AXIS_TLAST.setimmediatevalue(0)
        dut.S_AXIS_TDEST.setimmediatevalue(0)
        dut.S_AXIS_TID.setimmediatevalue(0)
        dut.S_AXIS_TUSER.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        dut.fifoPauseThresh.setimmediatevalue((1 << self.fifo_addr_width) - 1)

        cocotb.start_soon(self._monitor_source_handshakes())
        cocotb.start_soon(self._monitor_sink_handshakes())

    async def settle(self):
        await Timer(1, unit="ns")

    async def cycle_source(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.S_AXIS_ACLK)
            await self.settle()

    async def cycle_sink(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.M_AXIS_ACLK)
            await self.settle()

    async def _monitor_source_handshakes(self):
        cycle = 0
        while True:
            await RisingEdge(self.dut.S_AXIS_ACLK)
            await self.settle()
            cycle += 1
            if int(self.dut.S_AXIS_TVALID.value) and int(self.dut.S_AXIS_TREADY.value):
                self.tx_cycles.append(cycle)

    async def _monitor_sink_handshakes(self):
        cycle = 0
        while True:
            await RisingEdge(self.dut.M_AXIS_ACLK)
            await self.settle()
            cycle += 1
            if int(self.dut.M_AXIS_TVALID.value) and int(self.dut.M_AXIS_TREADY.value):
                self.rx_cycles.append(cycle)
                self.rx_last_users.append(int(self.dut.mTLastTUser.value))
                self.rx_beat_users.append(int(self.dut.M_AXIS_TUSER.value))

    async def reset(self):
        self.clear_source()
        self.dut.M_AXIS_TREADY.value = 0
        self.dut.fifoPauseThresh.value = (1 << self.fifo_addr_width) - 1
        self.dut.S_AXIS_ARESETN.setimmediatevalue(0)
        self.dut.M_AXIS_ARESETN.setimmediatevalue(0)
        await self.cycle_source(2)
        await self.cycle_sink(2)
        self.dut.S_AXIS_ARESETN.value = 1
        self.dut.M_AXIS_ARESETN.value = 1
        await self.cycle_source(2)
        await self.cycle_sink(2)
        self.clear_samples()

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(
                bus=AxiStreamBus.from_prefix(self.dut, "S_AXIS"),
                clock=self.dut.S_AXIS_ACLK,
                reset=self.dut.S_AXIS_ARESETN,
                reset_active_level=False,
            )
        if self.sink is None:
            self.sink = AxiStreamSink(
                bus=AxiStreamBus.from_prefix(self.dut, "M_AXIS"),
                clock=self.dut.M_AXIS_ACLK,
                reset=self.dut.M_AXIS_ARESETN,
                reset_active_level=False,
            )

    def set_idle_generator(self, generator=None):
        if generator is not None:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator is not None:
            self.sink.set_pause_generator(generator())

    def clear_samples(self):
        self.tx_cycles.clear()
        self.rx_cycles.clear()
        self.rx_last_users.clear()
        self.rx_beat_users.clear()

    def clear_source(self):
        self.dut.S_AXIS_TVALID.value = 0
        self.dut.S_AXIS_TDATA.value = 0
        self.dut.S_AXIS_TKEEP.value = 0
        self.dut.S_AXIS_TLAST.value = 0
        self.dut.S_AXIS_TDEST.value = 0
        self.dut.S_AXIS_TID.value = 0
        self.dut.S_AXIS_TUSER.value = 0

    def drive_source_beat(self, data: int, *, last: bool, tid: int, tdest: int, tuser: int):
        self.dut.S_AXIS_TVALID.value = 1
        self.dut.S_AXIS_TDATA.value = data
        self.dut.S_AXIS_TKEEP.value = 1
        self.dut.S_AXIS_TLAST.value = int(last)
        self.dut.S_AXIS_TDEST.value = tdest
        self.dut.S_AXIS_TID.value = tid
        self.dut.S_AXIS_TUSER.value = tuser

    async def send_manual_frame(self, payload: bytes, *, tid: int, tdest: int, tuser_values: list[int] | None = None):
        assert self.s_bytes == 1
        tuser_values = tuser_values or [0] * len(payload)

        for index, data_byte in enumerate(payload):
            self.drive_source_beat(
                data_byte,
                last=index == (len(payload) - 1),
                tid=tid,
                tdest=tdest,
                tuser=tuser_values[index],
            )
            while True:
                await RisingEdge(self.dut.S_AXIS_ACLK)
                await self.settle()
                if int(self.dut.S_AXIS_TVALID.value) and int(self.dut.S_AXIS_TREADY.value):
                    break

        self.clear_source()
        await self.cycle_source(1)

    async def wait_for_output_valid(self, timeout_cycles: int):
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.M_AXIS_TVALID.value):
                return
            await self.cycle_sink(1)
        raise AssertionError("Timed out waiting for FIFO output valid")

    async def wait_for_pause(self, timeout_cycles: int):
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.sAxisPause.value):
                return
            await self.cycle_source(1)
        raise AssertionError("Timed out waiting for FIFO pause assertion")

    async def wait_for_pause_clear(self, timeout_cycles: int):
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.sAxisPause.value) == 0:
                return
            await self.cycle_source(1)
        raise AssertionError("Timed out waiting for FIFO pause deassertion")

    async def wait_for_fifo_empty(self, timeout_cycles: int):
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.fifoWrCnt.value) == 0 and int(self.dut.M_AXIS_TVALID.value) == 0:
                return
            await self.cycle_sink(1)
        raise AssertionError("Timed out waiting for FIFO drain")

    async def capture_manual_frame(self, timeout_cycles: int = 128):
        assert self.m_bytes == 1

        payload = bytearray()
        users = []
        sidebands = []
        tids = []
        dests = []

        for _ in range(timeout_cycles):
            await self.cycle_sink(1)
            if int(self.dut.M_AXIS_TVALID.value) and int(self.dut.M_AXIS_TREADY.value):
                payload.append(int(self.dut.M_AXIS_TDATA.value) & 0xFF)
                users.append(int(self.dut.M_AXIS_TUSER.value))
                sidebands.append(int(self.dut.mTLastTUser.value))
                tids.append(int(self.dut.M_AXIS_TID.value))
                dests.append(int(self.dut.M_AXIS_TDEST.value))
                if int(self.dut.M_AXIS_TLAST.value):
                    return {
                        "payload": bytes(payload),
                        "tuser": users,
                        "last_sideband": sidebands,
                        "tid": tids[0],
                        "tdest": dests[0],
                    }

        raise AssertionError("Timed out waiting for manual frame capture")


@cocotb.test()
async def stream_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()
    tb.set_idle_generator(cycle_pause)
    if tb.source_has_tready:
        tb.set_backpressure_generator(cycle_pause)

    frames = []
    source_tid_mask = mask(tb.s_tid_width)
    source_dest_mask = mask(tb.s_dest_width)
    sink_tid_mask = mask(tb.m_tid_width)
    sink_dest_mask = mask(tb.m_dest_width)

    for index, length in enumerate(curated_lengths(tb), start=1):
        payload = bytes((0x20 * index + offset) & 0xFF for offset in range(length))
        frame = AxiStreamFrame(payload)
        frame.tid = (0x30 + index) & source_tid_mask
        frame.tdest = (0x50 + index) & source_dest_mask
        await tb.source.send(frame)
        frames.append(frame)

    for frame in frames:
        rx_frame = await with_timeout(tb.sink.recv(), 5, "us")
        assert rx_frame.tdata == frame.tdata
        assert rx_frame.tid == (frame.tid & sink_tid_mask)
        assert rx_frame.tdest == (frame.tdest & sink_dest_mask)

    assert tb.sink.empty()
    assert int(tb.dut.sAxisOverflow.value) == 0


@cocotb.test()
async def metadata_truncation_test(dut):
    tb = TB(dut)
    if not tb.test_metadata_truncation:
        return

    await tb.reset()
    tb.start_agents()

    frame = AxiStreamFrame(b"\xAB")
    frame.tid = mask(tb.s_tid_width)
    frame.tdest = mask(tb.s_dest_width) - 1
    frame.tuser = mask(tb.s_user_width)

    await tb.source.send(frame)
    rx_frame = await with_timeout(tb.sink.recv(), 2, "us")

    assert rx_frame.tdata == frame.tdata
    assert rx_frame.tid == (frame.tid & mask(tb.m_tid_width))
    assert rx_frame.tdest == (frame.tdest & mask(tb.m_dest_width))
    assert scalar_tuser(rx_frame.tuser) == (scalar_tuser(frame.tuser) & mask(tb.m_user_width))


@cocotb.test()
async def frame_ready_release_and_last_user_test(dut):
    tb = TB(dut)
    if not tb.test_frame_ready:
        return

    await tb.reset()
    tb.clear_samples()
    tb.dut.M_AXIS_TREADY.value = 1

    payload = b"\x10\x11\x12\x13"
    beat_users = [0x0, 0x1, 0x2, 0x5]
    capture_task = cocotb.start_soon(tb.capture_manual_frame())

    for index, data_byte in enumerate(payload[:-1]):
        tb.drive_source_beat(data_byte, last=False, tid=0x1, tdest=0x2, tuser=beat_users[index])
        while True:
            await RisingEdge(tb.dut.S_AXIS_ACLK)
            await tb.settle()
            if int(tb.dut.S_AXIS_TVALID.value) and int(tb.dut.S_AXIS_TREADY.value):
                break
        assert tb.rx_cycles == []
        assert int(tb.dut.M_AXIS_TVALID.value) == 0

    tb.drive_source_beat(payload[-1], last=True, tid=0x1, tdest=0x2, tuser=beat_users[-1])
    while True:
        await RisingEdge(tb.dut.S_AXIS_ACLK)
        await tb.settle()
        if int(tb.dut.S_AXIS_TVALID.value) and int(tb.dut.S_AXIS_TREADY.value):
            break

    tb.clear_source()
    received = await with_timeout(capture_task, 2, "us")

    assert received["payload"] == payload
    assert received["tuser"] == beat_users
    assert received["tid"] == 0x1
    assert received["tdest"] == 0x2
    assert received["last_sideband"] == [beat_users[-1]] * len(payload)


@cocotb.test()
async def threshold_prefill_release_test(dut):
    tb = TB(dut)
    if not tb.test_threshold_prefill:
        return

    await tb.reset()
    tb.dut.M_AXIS_TREADY.value = 0

    payload = b"\x21\x22\x23"
    for data_byte in payload[: tb.valid_thold - 1]:
        tb.drive_source_beat(data_byte, last=False, tid=0x1, tdest=0x1, tuser=0)
        while True:
            await RisingEdge(tb.dut.S_AXIS_ACLK)
            await tb.settle()
            if int(tb.dut.S_AXIS_TVALID.value) and int(tb.dut.S_AXIS_TREADY.value):
                break
        assert int(tb.dut.M_AXIS_TVALID.value) == 0

    tb.drive_source_beat(payload[tb.valid_thold - 1], last=False, tid=0x1, tdest=0x1, tuser=0)
    while True:
        await RisingEdge(tb.dut.S_AXIS_ACLK)
        await tb.settle()
        if int(tb.dut.S_AXIS_TVALID.value) and int(tb.dut.S_AXIS_TREADY.value):
            break

    await tb.wait_for_output_valid(timeout_cycles=4)
    assert int(tb.dut.M_AXIS_TVALID.value) == 1
    tb.clear_source()
    await tb.cycle_sink(1)

    # Flush the partially-filled frame so the threshold-specific timing check
    # does not depend on a more contrived drain sequence than the broad
    # round-trip test already covers for this parameter set.
    tb.dut.S_AXIS_ARESETN.value = 0
    tb.dut.M_AXIS_ARESETN.value = 0
    await tb.cycle_source(2)
    await tb.cycle_sink(2)


@cocotb.test()
async def burst_mode_release_test(dut):
    tb = TB(dut)
    if not tb.test_burst_behavior:
        return

    await tb.reset()
    tb.clear_samples()
    tb.dut.M_AXIS_TREADY.value = 1

    payload = b"\x30\x31\x32\x33\x34\x35\x36"
    capture_task = cocotb.start_soon(tb.capture_manual_frame())
    await tb.send_manual_frame(payload, tid=0x1, tdest=0x3, tuser_values=[0] * len(payload))
    received = await with_timeout(capture_task, 2, "us")

    assert received["payload"] == payload

    run_lengths = []
    current_run = 1
    for earlier, later in zip(tb.rx_cycles, tb.rx_cycles[1:]):
        if later == earlier + 1:
            current_run += 1
        else:
            run_lengths.append(current_run)
            current_run = 1
    run_lengths.append(current_run)

    assert max(run_lengths) <= tb.valid_thold
    assert any(later > earlier + 1 for earlier, later in zip(tb.rx_cycles, tb.rx_cycles[1:]))


@cocotb.test()
async def dynamic_pause_threshold_test(dut):
    tb = TB(dut)
    if not tb.test_dynamic_pause:
        return

    await tb.reset()
    tb.dut.fifoPauseThresh.value = 1
    tb.dut.M_AXIS_TREADY.value = 0

    for data_byte in [0x40, 0x41, 0x42]:
        tb.drive_source_beat(data_byte, last=True, tid=0x1, tdest=0x1, tuser=0)
        while True:
            await RisingEdge(tb.dut.S_AXIS_ACLK)
            await tb.settle()
            if int(tb.dut.S_AXIS_TVALID.value) and int(tb.dut.S_AXIS_TREADY.value):
                break
        if int(tb.dut.sAxisPause.value):
            break

    tb.clear_source()
    await tb.wait_for_pause(timeout_cycles=4)
    assert int(tb.dut.fifoWrCnt.value) > 0
    assert int(tb.dut.sAxisOverflow.value) == 0

    tb.dut.M_AXIS_TREADY.value = 1
    await tb.wait_for_pause_clear(timeout_cycles=16)
    await tb.wait_for_fifo_empty(timeout_cycles=32)
    assert int(tb.dut.sAxisPause.value) == 0


def build_case(case_id: str, *, hdl: dict[str, str], env: dict[str, str] | None = None):
    default_hdl = {
        "S_TDATA_NUM_BYTES": "1",
        "M_TDATA_NUM_BYTES": "1",
        "S_TUSER_WIDTH": "2",
        "M_TUSER_WIDTH": "2",
        "S_HAS_TREADY": "1",
        "S_TID_WIDTH": "1",
        "M_TID_WIDTH": "1",
        "S_TDEST_WIDTH": "1",
        "M_TDEST_WIDTH": "1",
        "INT_PIPE_STAGES": "0",
        "PIPE_STAGES": "1",
        "VALID_BURST_MODE": "false",
        "VALID_THOLD": "1",
        "GEN_SYNC_FIFO": "false",
        "FIFO_ADDR_WIDTH": "9",
        "FIFO_FIXED_THRESH": "true",
        "FIFO_PAUSE_THRESH": "1",
        "INT_WIDTH_SELECT": "WIDE",
        "INT_DATA_WIDTH": "16",
        "LAST_FIFO_ADDR_WIDTH": "0",
        "CASCADE_PAUSE_SEL": "0",
        "CASCADE_SIZE": "1",
    }
    effective_hdl = {**default_hdl, **hdl}
    sim_hdl = {
        key: value
        for key, value in effective_hdl.items()
        if default_hdl.get(key) != value
    }
    env_vars = {
        **effective_hdl,
        "TEST_CLOCK_MODE": "skewed",
        "TEST_METADATA_TRUNCATION": "false",
        "TEST_FRAME_READY": "false",
        "TEST_THRESHOLD_PREFILL": "false",
        "TEST_BURST_BEHAVIOR": "false",
        "TEST_DYNAMIC_PAUSE": "false",
    }
    if env:
        env_vars.update(env)
    return pytest.param({"hdl": sim_hdl, "env": env_vars}, id=case_id)


PARAMETER_SWEEP = [
    build_case(
        "equal_width_sync_baseline",
        hdl={
            "S_TDATA_NUM_BYTES": "4",
            "M_TDATA_NUM_BYTES": "4",
            "S_TUSER_WIDTH": "2",
            "M_TUSER_WIDTH": "2",
            "S_TID_WIDTH": "3",
            "M_TID_WIDTH": "3",
            "S_TDEST_WIDTH": "3",
            "M_TDEST_WIDTH": "3",
            "INT_PIPE_STAGES": "0",
            "PIPE_STAGES": "0",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "1",
            "GEN_SYNC_FIFO": "true",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "true",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "WIDE",
            "INT_DATA_WIDTH": "4",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
        env={"TEST_CLOCK_MODE": "lockstep"},
    ),
    build_case(
        "upsize_async_truncation",
        hdl={
            "S_TDATA_NUM_BYTES": "2",
            "M_TDATA_NUM_BYTES": "6",
            "S_TUSER_WIDTH": "4",
            "M_TUSER_WIDTH": "2",
            "S_TID_WIDTH": "4",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "5",
            "M_TDEST_WIDTH": "3",
            "INT_PIPE_STAGES": "1",
            "PIPE_STAGES": "1",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "1",
            "GEN_SYNC_FIFO": "false",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "true",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "WIDE",
            "INT_DATA_WIDTH": "6",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
        env={"TEST_METADATA_TRUNCATION": "true"},
    ),
    build_case(
        "downsize_sync_narrow_internal",
        hdl={
            "S_TDATA_NUM_BYTES": "6",
            "M_TDATA_NUM_BYTES": "2",
            "S_TUSER_WIDTH": "2",
            "M_TUSER_WIDTH": "2",
            "S_TID_WIDTH": "2",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "2",
            "M_TDEST_WIDTH": "2",
            "INT_PIPE_STAGES": "0",
            "PIPE_STAGES": "1",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "1",
            "GEN_SYNC_FIFO": "true",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "true",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "NARROW",
            "INT_DATA_WIDTH": "2",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
        env={"TEST_CLOCK_MODE": "lockstep"},
    ),
    build_case(
        "async_custom_internal_width",
        hdl={
            "S_TDATA_NUM_BYTES": "3",
            "M_TDATA_NUM_BYTES": "5",
            "S_TUSER_WIDTH": "2",
            "M_TUSER_WIDTH": "2",
            "S_TID_WIDTH": "2",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "2",
            "M_TDEST_WIDTH": "2",
            "INT_PIPE_STAGES": "1",
            "PIPE_STAGES": "1",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "1",
            "GEN_SYNC_FIFO": "false",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "true",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "CUSTOM",
            "INT_DATA_WIDTH": "4",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
    ),
    build_case(
        "sync_cascade_two_stage",
        hdl={
            "S_TDATA_NUM_BYTES": "4",
            "M_TDATA_NUM_BYTES": "4",
            "S_TUSER_WIDTH": "2",
            "M_TUSER_WIDTH": "2",
            "S_TID_WIDTH": "2",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "2",
            "M_TDEST_WIDTH": "2",
            "INT_PIPE_STAGES": "0",
            "PIPE_STAGES": "1",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "1",
            "GEN_SYNC_FIFO": "true",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "true",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "WIDE",
            "INT_DATA_WIDTH": "4",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "2",
        },
        env={"TEST_CLOCK_MODE": "lockstep"},
    ),
    build_case(
        "sync_frame_ready_last_user",
        hdl={
            "S_TDATA_NUM_BYTES": "1",
            "M_TDATA_NUM_BYTES": "1",
            "S_TUSER_WIDTH": "3",
            "M_TUSER_WIDTH": "3",
            "S_TID_WIDTH": "2",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "2",
            "M_TDEST_WIDTH": "2",
            "INT_PIPE_STAGES": "0",
            "PIPE_STAGES": "1",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "0",
            "GEN_SYNC_FIFO": "true",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "true",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "WIDE",
            "INT_DATA_WIDTH": "1",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
        env={
            "TEST_CLOCK_MODE": "lockstep",
            "TEST_FRAME_READY": "true",
        },
    ),
    build_case(
        "sync_threshold_prefill",
        hdl={
            "S_TDATA_NUM_BYTES": "1",
            "M_TDATA_NUM_BYTES": "1",
            "S_TUSER_WIDTH": "1",
            "M_TUSER_WIDTH": "1",
            "S_TID_WIDTH": "2",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "2",
            "M_TDEST_WIDTH": "2",
            "INT_PIPE_STAGES": "0",
            "PIPE_STAGES": "0",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "3",
            "GEN_SYNC_FIFO": "true",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "true",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "WIDE",
            "INT_DATA_WIDTH": "1",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
        env={
            "TEST_CLOCK_MODE": "lockstep",
            "TEST_THRESHOLD_PREFILL": "true",
        },
    ),
    build_case(
        "sync_threshold_burst",
        hdl={
            "S_TDATA_NUM_BYTES": "1",
            "M_TDATA_NUM_BYTES": "1",
            "S_TUSER_WIDTH": "1",
            "M_TUSER_WIDTH": "1",
            "S_TID_WIDTH": "2",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "2",
            "M_TDEST_WIDTH": "2",
            "INT_PIPE_STAGES": "0",
            "PIPE_STAGES": "0",
            "VALID_BURST_MODE": "true",
            "VALID_THOLD": "3",
            "GEN_SYNC_FIFO": "true",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "true",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "WIDE",
            "INT_DATA_WIDTH": "1",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
        env={
            "TEST_CLOCK_MODE": "lockstep",
            "TEST_BURST_BEHAVIOR": "true",
        },
    ),
    build_case(
        "sync_dynamic_pause_threshold",
        hdl={
            "S_TDATA_NUM_BYTES": "1",
            "M_TDATA_NUM_BYTES": "1",
            "S_TUSER_WIDTH": "1",
            "M_TUSER_WIDTH": "1",
            "S_TID_WIDTH": "2",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "2",
            "M_TDEST_WIDTH": "2",
            "INT_PIPE_STAGES": "0",
            "PIPE_STAGES": "0",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "1",
            "GEN_SYNC_FIFO": "true",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "false",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "WIDE",
            "INT_DATA_WIDTH": "1",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
        env={
            "TEST_CLOCK_MODE": "lockstep",
            "TEST_DYNAMIC_PAUSE": "true",
        },
    ),
    build_case(
        "sync_no_tready_dynamic_pause",
        hdl={
            "S_TDATA_NUM_BYTES": "1",
            "M_TDATA_NUM_BYTES": "1",
            "S_TUSER_WIDTH": "1",
            "M_TUSER_WIDTH": "1",
            "S_HAS_TREADY": "0",
            "S_TID_WIDTH": "2",
            "M_TID_WIDTH": "2",
            "S_TDEST_WIDTH": "2",
            "M_TDEST_WIDTH": "2",
            "INT_PIPE_STAGES": "0",
            "PIPE_STAGES": "0",
            "VALID_BURST_MODE": "false",
            "VALID_THOLD": "1",
            "GEN_SYNC_FIFO": "true",
            "FIFO_ADDR_WIDTH": "4",
            "FIFO_FIXED_THRESH": "false",
            "FIFO_PAUSE_THRESH": "15",
            "INT_WIDTH_SELECT": "WIDE",
            "INT_DATA_WIDTH": "1",
            "LAST_FIFO_ADDR_WIDTH": "0",
            "CASCADE_PAUSE_SEL": "0",
            "CASCADE_SIZE": "1",
        },
        env={
            "TEST_CLOCK_MODE": "lockstep",
            "TEST_DYNAMIC_PAUSE": "true",
        },
    ),
]


@pytest.mark.parametrize("case", PARAMETER_SWEEP)
def test_AxiStreamFifoV2IpIntegrator(case):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamfifov2ipintegrator",
        parameters=case["hdl"],
        extra_env=case["env"],
    )
