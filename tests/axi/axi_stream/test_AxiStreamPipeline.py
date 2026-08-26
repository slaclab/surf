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
# - Sweep: Sweep a zero-stage pass-through case, a two-stage synchronous case,
#   and a one-stage asynchronous active-low reset case so the bench covers the
#   combinational path, buffered pipeline path, sideband forwarding, and both
#   reset styles without building a large Cartesian matrix.
# - Stimulus: Send one-beat AXI Stream frames with distinct payload, keep,
#   `tid`, `tdest`, and sideband values; then hold the sink not-ready while a
#   beat is in flight and finally assert reset while the pipeline has state.
# - Checks: The output frame fields and sideband must match the source values,
#   the sink-handshake latency must match the wrapper-visible registered path,
#   held output data must remain stable under backpressure, and reset must
#   clear buffered state in the registered cases.
# - Timing: The zero-stage case checks same-cycle combinational visibility,
#   staged cases check the observed sink latency of `PIPE_STAGES_G + 2`
#   clocks, and reset is checked as a bounded flush for both synchronous and
#   asynchronous modes.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.pipe_stages = int(os.environ["PIPE_STAGES_G"])
        self.side_band_width = int(os.environ["SIDE_BAND_WIDTH_G"])
        self.data_bytes = int(os.environ["DATA_BYTES_G"])
        self.reset_async = os.environ["RST_ASYNC_G"].strip().lower() == "true"
        self.reset_active = int(os.environ["RST_POLARITY_G"].strip("'"))
        self.source = None
        self.sink = None
        self.tx_cycles = []
        self.rx_cycles = []
        self.rx_sidebands = []

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

        # Initialize the wrapper-facing scalar ports before cocotbext claims
        # them so the zero-stage combinational path never exposes `U` values.
        dut.axisRst.setimmediatevalue(self.reset_active_value())
        dut.S_AXIS_TVALID.setimmediatevalue(0)
        dut.S_AXIS_TDATA.setimmediatevalue(0)
        dut.S_AXIS_TKEEP.setimmediatevalue(0)
        dut.S_AXIS_TLAST.setimmediatevalue(0)
        dut.S_AXIS_TDEST.setimmediatevalue(0)
        dut.S_AXIS_TID.setimmediatevalue(0)
        dut.S_SIDE_BAND.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)

        # Record the cycle where source and sink handshakes complete so the
        # tests can talk about pipeline latency in exact clock cycles.
        cocotb.start_soon(self._monitor_handshakes())

    async def _monitor_handshakes(self):
        cycle = 0
        while True:
            await RisingEdge(self.dut.axisClk)
            await self.settle()
            cycle += 1

            if int(self.dut.S_AXIS_TVALID.value) and int(self.dut.S_AXIS_TREADY.value):
                self.tx_cycles.append(cycle)

            if int(self.dut.M_AXIS_TVALID.value) and int(self.dut.M_AXIS_TREADY.value):
                self.rx_cycles.append(cycle)
                self.rx_sidebands.append(int(self.dut.M_SIDE_BAND.value))

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def settle(self):
        # Sample one nanosecond after the clock edge so the DUT's default
        # `TPD_G` has elapsed before we inspect registered outputs.
        await Timer(1, unit="ns")

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await self.settle()

    async def reset(self):
        # Hold reset for a few edges so the source, sink, and DUT all start
        # from a clean handshake state before each cocotb test begins.
        self.dut.axisRst.setimmediatevalue(self.reset_active_value())
        self.dut.S_SIDE_BAND.value = 0
        self.dut.M_AXIS_TREADY.value = 0
        await self.cycle(2)
        self.dut.axisRst.value = self.reset_active_value()
        await self.cycle(2)
        self.dut.axisRst.value = self.reset_inactive_value()
        await self.cycle(2)

    def start_stream_agents(self):
        # Create the stream helpers only after reset has been exercised so the
        # zero-stage path does not expose an uninitialized ready signal to the
        # cocotbext source task at time zero.
        self.source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(self.dut, "S_AXIS"),
            clock=self.dut.axisClk,
            reset=self.dut.axisRst,
            reset_active_level=bool(self.reset_active),
        )
        self.sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(self.dut, "M_AXIS"),
            clock=self.dut.axisClk,
            reset=self.dut.axisRst,
            reset_active_level=bool(self.reset_active),
        )

    def clear_samples(self):
        self.tx_cycles.clear()
        self.rx_cycles.clear()
        self.rx_sidebands.clear()

    def drive_source(self, *, valid, data, keep, last, tid, tdest, sideband):
        # The manual path is used only for same-cycle and hold tests where we
        # need exact control of the source handshake edge.
        self.dut.S_AXIS_TVALID.value = valid
        self.dut.S_AXIS_TDATA.value = data
        self.dut.S_AXIS_TKEEP.value = keep
        self.dut.S_AXIS_TLAST.value = last
        self.dut.S_AXIS_TID.value = tid
        self.dut.S_AXIS_TDEST.value = tdest
        self.dut.S_SIDE_BAND.value = sideband

    def drive_source_idle(self):
        self.drive_source(
            valid=0,
            data=0,
            keep=0,
            last=0,
            tid=0,
            tdest=0,
            sideband=0,
        )

    def output_snapshot(self):
        return (
            int(self.dut.M_AXIS_TVALID.value),
            int(self.dut.M_AXIS_TDATA.value),
            int(self.dut.M_AXIS_TKEEP.value),
            int(self.dut.M_AXIS_TLAST.value),
            int(self.dut.M_AXIS_TID.value),
            int(self.dut.M_AXIS_TDEST.value),
            int(self.dut.M_SIDE_BAND.value),
        )

    async def wait_for_output_valid(self, timeout_cycles=16):
        # Staged cases need a bounded wait because the valid beat appears only
        # after the pipeline has absorbed the input handshake.
        for _ in range(timeout_cycles):
            if int(self.dut.M_AXIS_TVALID.value):
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for pipeline output valid")

    async def wait_for_output_clear(self, timeout_cycles=16):
        # Reset is treated as a bounded flush check because the registered path
        # may need one or more updates before the cleared state is visible.
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.M_AXIS_TVALID.value) == 0:
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for pipeline output clear")


@cocotb.test()
async def stream_order_and_sideband_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_stream_agents()

    frames = [
        (AxiStreamFrame(b"\x11"), 0x1),
        (AxiStreamFrame(bytes(range(1, min(tb.data_bytes, 4) + 1))), 0x2),
        (AxiStreamFrame(bytes((0xA0 + i) & 0xFF for i in range(tb.data_bytes))), (1 << tb.side_band_width) - 1),
    ]

    # Drive one frame at a time so the separate sideband signal remains aligned
    # with the exact beat the sink is about to accept.
    for index, (frame, sideband) in enumerate(frames, start=1):
        frame.tid = index
        frame.tdest = 0x40 + index
        dut.S_SIDE_BAND.value = sideband
        await tb.source.send(frame)
        rx_frame = await tb.sink.recv()
        assert rx_frame.tdata == frame.tdata
        assert rx_frame.tid == frame.tid
        assert rx_frame.tdest == frame.tdest

    # Give the handshake monitor one extra edge to record the final accepted
    # sideband before the test checks the collected list.
    await tb.cycle(1)
    assert tb.rx_sidebands == [sideband for _, sideband in frames]
    assert tb.sink.empty()


@cocotb.test()
async def latency_and_backpressure_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_stream_agents()

    tb.clear_samples()
    frame = AxiStreamFrame(bytes((0x30 + i) & 0xFF for i in range(tb.data_bytes)))
    frame.tid = 0x12
    frame.tdest = 0x34
    dut.S_SIDE_BAND.value = (1 << tb.side_band_width) - 1

    # First, prove the pass-through case stays zero-latency while the staged
    # cases add the expected wrapper-visible sink latency when no stall exists.
    await tb.source.send(frame)
    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == frame.tdata
    await tb.cycle(1)
    expected_latency = 0 if tb.pipe_stages == 0 else tb.pipe_stages + 2
    assert tb.rx_cycles[0] - tb.tx_cycles[0] == expected_latency

    tb.drive_source_idle()
    dut.M_AXIS_TREADY.value = 0
    await tb.settle()

    # Then drive one beat manually so we can freeze the sink and inspect that
    # the output payload and sideband stay stable until backpressure clears.
    hold_sideband = max(1, (1 << tb.side_band_width) - 1)
    tb.drive_source(
        valid=1,
        data=int.from_bytes(b"\xDE\xAD\xBE\xEF"[: tb.data_bytes].ljust(tb.data_bytes, b"\x5A"), "little"),
        keep=(1 << tb.data_bytes) - 1,
        last=1,
        tid=0x55,
        tdest=0x66,
        sideband=hold_sideband,
    )

    if tb.pipe_stages == 0:
        await tb.settle()
    else:
        await tb.wait_for_output_valid(timeout_cycles=tb.pipe_stages + 4)

    snapshot = tb.output_snapshot()
    assert snapshot[0] == 1

    # Hold the sink not-ready for several edges and require the output beat to
    # remain bit-for-bit stable while the pipeline is blocked.
    for _ in range(3):
        await tb.cycle(1)
        assert tb.output_snapshot() == snapshot

    dut.M_AXIS_TREADY.value = 1
    await tb.cycle(1)
    tb.drive_source_idle()


@cocotb.test(skip=int(os.environ.get("PIPE_STAGES_G", "0")) == 0)
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    dut.M_AXIS_TREADY.value = 0
    tb.drive_source(
        valid=1,
        data=0x1122334455667788 & ((1 << (tb.data_bytes * 8)) - 1),
        keep=(1 << tb.data_bytes) - 1,
        last=1,
        tid=0x21,
        tdest=0x43,
        sideband=max(1, (1 << tb.side_band_width) - 1),
    )

    # Let the staged pipeline capture one beat so reset has real buffered state
    # to clear instead of only resetting an idle design.
    for _ in range(tb.pipe_stages + 2):
        await tb.cycle(1)
        if tb.tx_cycles:
            break

    # Stop driving new source traffic before reset so the check below measures
    # pipeline flush behavior rather than immediate post-reset refilling.
    tb.drive_source_idle()

    dut.axisRst.value = tb.reset_active_value()
    # Poll for the cleared output instead of sampling immediately so both
    # reset styles are checked against the real registered flush behavior.
    await tb.wait_for_output_clear(timeout_cycles=tb.pipe_stages + 4)
    assert int(dut.M_AXIS_TVALID.value) == 0
    assert int(dut.M_SIDE_BAND.value) == 0

    dut.axisRst.value = tb.reset_inactive_value()
    tb.drive_source_idle()
    await tb.cycle(2)


PARAMETER_SWEEP = [
    parameter_case(
        "zero_stage_sync",
        DATA_BYTES_G="4",
        SIDE_BAND_WIDTH_G="3",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "stage2_sync",
        DATA_BYTES_G="4",
        SIDE_BAND_WIDTH_G="4",
        PIPE_STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "stage1_async_active_low",
        DATA_BYTES_G="8",
        SIDE_BAND_WIDTH_G="2",
        PIPE_STAGES_G="1",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiStreamPipeline(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreampipelineipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
