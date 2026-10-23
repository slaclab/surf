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
# - Sweep: One 16-bit wrapper configuration with a 16-deep ring, built twice.
#   The common-clock case (COMMON_CLK_G=true, lockstep clocks) runs the
#   capture-window test. The independent-clock case (COMMON_CLK_G=false,
#   4 ns dataClk against 5 ns AXI-Lite/stream clocks) runs the recovery,
#   backpressure, and timeout-boundary tests. TRIG_TIMEOUT_G is set short so
#   the trigger timeout fits the bench.
# - Stimulus: The capture test pushes a short sequence into the data port,
#   confirms the visible buffered-length register, then stops capture with
#   `extTrig` and drains the exported AXI-Stream frame. The independent-clock
#   tests hold dataValid high and drive dataValue with a ramp that advances
#   once per dataClk cycle, so every full-ring frame is 16 consecutive values.
# - Checks: The capture test expects the current wrapper's captured window,
#   which includes the design's initial BRAM word followed by the populated
#   samples visible through the registered read path at trigger time.
#   Full-ring frames must be 16 beats of contiguous ramp data with SOF on the
#   first beat, EOFE clear on the last beat, and TDEST/TID zero.
# - Timing: The bench waits for the DUT to emit the stream frame after the
#   trigger instead of assuming the readout begins immediately on the same cycle.
# - Recovery: ContinuousMode captures until the data side has written 16 read
#   requests into its readReq CDC FIFO, so the FIFO write pointer has wrapped
#   to its reset value. With the data side's logging stopped for that capture,
#   the bench stops dataClk and pulses dataRst: the AXI-Lite side and the FIFO
#   read side reset, the unclocked data side keeps logging stopped and its
#   buffer armed, and no stale FIFO entry re-triggers the readout. The next
#   local trigger is never answered with a read request, which is the wedge
#   (TrigState WAIT_S with DataState IDLE_S) seen in hardware. The ramp starts
#   with the restarted dataClk, so the bounded frame receives must return
#   fresh ramp data captured after the trigger timeout cleared the data side.
# - Backpressure: With the stream sink paused, ContinuousMode fills the TX FIFO
#   until a readout stalls in DataState MOVE_S. The status register must hold
#   MOVE_S/WAIT_S for 16 trigger timeouts, then every frame drained after the
#   sink resumes must be intact, showing the timeout never cleared the stalled
#   readout.
# - Boundary: For single-shot triggers the bench stops dataClk with the ring
#   armed, waits for the local trigger, then restarts dataClk after a chosen
#   delay. It counts axilClk cycles from the softTrig rising edge to the
#   readReq strobe, and sweeps the delay so the strobe lands one cycle before,
#   on, and one or two cycles after the last timer cycle. A strobe on or before
#   the last timer cycle must produce a clean frame with no bufferClear; a later
#   strobe must see bufferClear on the cycle after the last timer cycle, no
#   frame, and a return to idle.
# - Observation: The bench observes the readReq FIFO's wr_en, the readReq and
#   armed signals, and the softTrig/bufferClear inputs of U_SyncVec_dataClk.
#   It drives no internal signal.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, with_timeout
from cocotb.utils import get_sim_time

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp, AxiStreamBus, AxiStreamSink

from tests.common.regression_utils import (
    cocotb_filtered_env,
    cocotb_test_filter,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)

TRIG_TIMEOUT_C = 64

AXIL_PERIOD_NS_C = 5.0

# RAM_ADDR_WIDTH_G (4) in the wrapper
RING_DEPTH_C = 16

# SynchronizerFifo's default ADDR_WIDTH_G (4) inside the DUT's readReq CDC path
READREQ_FIFO_DEPTH_C = 16

# SsiPkg tUser bit positions
SSI_EOFE_BIT_C = 0
SSI_SOF_BIT_C = 1

TRIG_STATE_IDLE_C = 0
TRIG_STATE_WAIT_C = 2
DATA_STATE_IDLE_C = 0
DATA_STATE_MOVE_C = 1

RAMP_BASE_C = 0x1000


def fsm_states(status: int) -> tuple[int, int]:
    """Return (trigStateIdx, dataStateIdx) from the register at offset 0x0."""
    return (status >> 28) & 0x3, (status >> 30) & 0x3


def beat_values(values, beats: int) -> list[int]:
    """Return one sideband value per 2-byte beat from a compacted sink field."""
    if isinstance(values, list):
        return [int(values[2 * beat]) for beat in range(beats)]
    return [int(values)] * beats


def check_ramp_frame(frame) -> list[int]:
    """Check one full-ring frame of ramp data and return its words."""
    data = bytes(frame.tdata)
    assert len(data) == 2 * RING_DEPTH_C, f"frame length {len(data)} bytes"
    words = [int.from_bytes(data[i:i + 2], "little") for i in range(0, len(data), 2)]
    for prev, word in zip(words, words[1:]):
        assert (word - prev) & 0xFFFF == 1, f"non-contiguous ramp payload {words}"

    tuser = beat_values(frame.tuser, RING_DEPTH_C)
    assert (tuser[0] >> SSI_SOF_BIT_C) & 0x1 == 1, "SOF missing on first beat"
    assert (tuser[-1] >> SSI_EOFE_BIT_C) & 0x1 == 0, "EOFE set on last beat"
    assert beat_values(frame.tdest, RING_DEPTH_C) == [0] * RING_DEPTH_C
    assert beat_values(frame.tid, RING_DEPTH_C) == [0] * RING_DEPTH_C
    return words


class TB:
    def __init__(self, dut, independent_data_clk=False):
        self.dut = dut
        self.axil = None
        self.sink = None
        self.data_clock = None
        self.ramp_task = None

        if independent_data_clk:
            # The AXI-Lite and stream-export clocks stay aligned for the
            # wrapper's synchronous TX FIFO, while the data clock is a
            # bench-owned lifetime agent that the tests stop and restart.
            start_lockstep_clocks(dut.axilClk, dut.axisClk, period_ns=AXIL_PERIOD_NS_C)
            self.data_clock = Clock(dut.dataClk, 4.0, unit="ns")
            self.data_clock.start()
        else:
            # Keep the data, AXI-Lite, and stream-export clocks truly aligned for
            # the common-clock wrapper subset this bench is validating.
            start_lockstep_clocks(dut.dataClk, dut.axilClk, dut.axisClk, period_ns=AXIL_PERIOD_NS_C)
        dut.dataRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.axisRst.setimmediatevalue(1)
        dut.dataValid.setimmediatevalue(0)
        dut.dataValue.setimmediatevalue(0)
        dut.extTrig.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axilClk)

    async def reset(self):
        self.dut.dataRst.value = 1
        self.dut.axilRst.value = 1
        self.dut.axisRst.value = 1
        self.dut.dataValid.value = 0
        self.dut.extTrig.value = 0
        await self.cycle(4)
        self.dut.dataRst.value = 0
        self.dut.axilRst.value = 0
        self.dut.axisRst.value = 0
        await self.cycle(6)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)

    def start_ramp(self, start: int):
        async def drive(value):
            """Lifetime agent: advance dataValue by one on every dataClk cycle."""
            while True:
                self.dut.dataValue.value = value & 0xFFFF
                await sample_after_tpd(self.dut.dataClk)
                value += 1

        assert self.ramp_task is None
        self.ramp_task = cocotb.start_soon(drive(start))

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def write_reg(self, address: int, value: int):
        txn = await self.axil.write(address, value.to_bytes(4, "little"))
        assert txn.resp == AxiResp.OKAY

    async def wait_states(self, trig_state: int, data_state: int):
        while fsm_states(await self.read_reg(0x0)) != (trig_state, data_state):
            pass

    async def push_value(self, value: int):
        self.dut.dataValue.value = value
        self.dut.dataValid.value = 1
        await self.cycle(1)
        self.dut.dataValid.value = 0
        await self.cycle(1)


@cocotb.test()
async def trigger_exports_captured_window_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    samples = [0x0010, 0x0021, 0x0132, 0x0243, 0x0354, 0x0465]
    for sample in samples:
        await tb.push_value(sample)
    await tb.cycle(1)

    tb.dut.extTrig.value = 1
    await tb.cycle(1)
    tb.dut.extTrig.value = 0
    await tb.cycle(6)

    frame = await with_timeout(tb.sink.recv(), 3, "us")
    expected = b"\x00\x00" + b"".join(sample.to_bytes(2, "little") for sample in samples[:-1])

    assert bytes(frame.tdata) == expected


@cocotb.test()
async def continuous_mode_recovers_from_unclocked_data_reset_test(dut):
    tb = TB(dut, independent_data_clk=True)
    await tb.reset()
    tb.start_agents()

    # Start ContinuousMode capture with every data cycle valid.
    readReqWrite = tb.dut.u_dut.u_sync_readreq.wr_en
    tb.dut.dataValid.value = 1
    await tb.write_reg(0xC, 1)

    # Each falling edge of wr_en is one read request landed in the readReq
    # CDC FIFO. After the 16th the write pointer is back at its reset value,
    # and the data side has stopped logging for that capture.
    for _ in range(READREQ_FIFO_DEPTH_C):
        await with_timeout(FallingEdge(readReqWrite), 10, "us")

    # Pulse dataRst while dataClk is stopped: the AXI-Lite side and the FIFO
    # read side reset through their RstSync, the data side does not.
    tb.data_clock.stop()
    tb.dut.dataRst.value = 1
    await tb.cycle(8)
    tb.dut.dataRst.value = 0
    await tb.cycle(8)

    # Restart dataClk with a ramp in place of the constant zero captured so
    # far, so recovered frames are distinguishable from stale ones.
    tb.start_ramp(RAMP_BASE_C)
    tb.data_clock.start()

    # Let any frame already in the TX FIFO drain, then require fresh frames.
    await tb.cycle(400)
    tb.sink.clear()
    prev_first = None
    for _ in range(4):
        frame = await with_timeout(tb.sink.recv(), 20, "us")
        words = check_ramp_frame(frame)
        assert words[0] >= RAMP_BASE_C, f"stale payload {words}"
        if prev_first is not None:
            assert words[0] > prev_first, "frame did not capture new data"
        prev_first = words[0]


@cocotb.test()
async def output_backpressure_stalls_readout_without_timeout_test(dut):
    tb = TB(dut, independent_data_clk=True)
    await tb.reset()
    tb.start_agents()

    # Hold the stream output in backpressure and start ContinuousMode capture.
    tb.sink.pause = True
    tb.start_ramp(RAMP_BASE_C)
    tb.dut.dataValid.value = 1
    await tb.write_reg(0xC, 1)

    # Readouts continue until the TX FIFO fills. A normal 16-word readout
    # leaves MOVE_S in well under four timeouts, so a MOVE_S streak that long
    # means the readout is stalled on the full FIFO.
    stall_detect_ns = 4 * TRIG_TIMEOUT_C * AXIL_PERIOD_NS_C
    hold_ns = 16 * TRIG_TIMEOUT_C * AXIL_PERIOD_NS_C

    stall_deadline = get_sim_time(unit="ns") + 100_000
    streak_start = None
    while streak_start is None or get_sim_time(unit="ns") - streak_start < stall_detect_ns:
        assert get_sim_time(unit="ns") < stall_deadline, "no readout held MOVE_S for four timeouts under backpressure"
        _, data_state = fsm_states(await tb.read_reg(0x0))
        if data_state != DATA_STATE_MOVE_C:
            streak_start = None
        elif streak_start is None:
            streak_start = get_sim_time(unit="ns")

    # The stalled readout must hold through many trigger timeouts.
    hold_end = get_sim_time(unit="ns") + hold_ns
    while get_sim_time(unit="ns") < hold_end:
        states = fsm_states(await tb.read_reg(0x0))
        assert states == (TRIG_STATE_WAIT_C, DATA_STATE_MOVE_C), f"stalled readout left MOVE_S: {states}"
    assert tb.sink.empty()

    # Release backpressure. Drain every buffered frame plus fresh ones; a
    # readout cleared mid-frame would show up as a short, merged, or
    # non-contiguous frame.
    tb.sink.pause = False
    fifo_frames = 512 // RING_DEPTH_C
    prev_first = None
    for _ in range(fifo_frames + 4):
        frame = await with_timeout(tb.sink.recv(), 20, "us")
        words = check_ramp_frame(frame)
        if prev_first is not None:
            assert 0 < (words[0] - prev_first) & 0xFFFF < 0x8000, "frame did not capture new data"
        prev_first = words[0]


@cocotb.test()
async def read_request_at_timeout_boundary_wins_test(dut):
    tb = TB(dut, independent_data_clk=True)
    await tb.reset()
    tb.start_agents()

    syncIn = tb.dut.u_dut.u_syncvec_dataclk.datain  # (0) softTrig, (1) bufferClear
    readReq = tb.dut.u_dut.readreq
    armed = tb.dut.u_dut.armed

    tb.start_ramp(RAMP_BASE_C)
    tb.dut.dataValid.value = 1

    async def trial(delay: int) -> int:
        """Restart dataClk `delay` cycles into WAIT_S; return the readReq cycle."""
        # Let the data side fill the ring, then stop dataClk right after a
        # rising edge so every restart has the same phase against axilClk.
        while int(armed.value) == 0:
            await tb.cycle()
        await RisingEdge(tb.dut.dataClk)
        tb.data_clock.stop()

        # Issue one local trigger. Cycle 0 is the first WAIT_S cycle, where
        # softTrig rises and the trigger timer is zero.
        await tb.write_reg(0x8, 1)
        while (int(syncIn.value) >> 0) & 0x1 == 0:
            await tb.cycle()

        req_cycle = None
        clear_cycle = None
        n = 0
        while n <= TRIG_TIMEOUT_C + 4:
            if n == delay:
                tb.data_clock.start()
            if req_cycle is None and int(readReq.value) == 1:
                req_cycle = n
            if clear_cycle is None and (int(syncIn.value) >> 1) & 0x1 == 1:
                clear_cycle = n
            await tb.cycle()
            n += 1
        assert req_cycle is not None, "dataClk restart never produced a read request"

        if req_cycle <= TRIG_TIMEOUT_C - 1:
            # The read request arrived by the last timer cycle: it must win,
            # so the readout runs without bufferClear and returns a full frame.
            assert clear_cycle is None, f"bufferClear at cycle {clear_cycle} with readReq at cycle {req_cycle}"
            frame = await with_timeout(tb.sink.recv(), 20, "us")
            check_ramp_frame(frame)
        else:
            # The timeout fired on the last timer cycle: bufferClear rises on
            # the next cycle, the late read request is dropped, and no frame
            # is exported.
            assert clear_cycle == TRIG_TIMEOUT_C, f"bufferClear at cycle {clear_cycle}"
            await tb.cycle(200)
            assert tb.sink.empty(), "late read request exported a frame after timeout"

        await with_timeout(tb.wait_states(TRIG_STATE_IDLE_C, DATA_STATE_IDLE_C), 20, "us")
        return req_cycle

    # Measure the restart-to-readReq latency, then place the strobe around the
    # last timer cycle (TRIG_TIMEOUT_C - 1).
    latency = await with_timeout(trial(0), 50, "us")
    for target in range(TRIG_TIMEOUT_C - 2, TRIG_TIMEOUT_C + 2):
        req_cycle = await with_timeout(trial(target - latency), 50, "us")
        assert req_cycle == target, f"readReq at cycle {req_cycle}, expected {target}"


# Each wrapper build runs only the scenarios that match its clocking.
PARAMETER_SWEEP = [
    pytest.param(
        {"COMMON_CLK_G": "true", "TRIG_TIMEOUT_G": TRIG_TIMEOUT_C},
        cocotb_test_filter("trigger_exports_captured_window_test"),
        id="common_clk_capture",
    ),
    pytest.param(
        {"COMMON_CLK_G": "false", "TRIG_TIMEOUT_G": TRIG_TIMEOUT_C},
        cocotb_test_filter(
            "continuous_mode_recovers_from_unclocked_data_reset_test",
            "output_backpressure_stalls_readout_without_timeout_test",
            "read_request_at_timeout_boundary_wins_test",
        ),
        id="independent_clk_recovery",
    ),
]


@pytest.mark.parametrize("parameters, test_filter", PARAMETER_SWEEP)
def test_AxiStreamRingBuffer(parameters, test_filter):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamringbufferipintegrator",
        parameters=parameters,
        extra_env=cocotb_filtered_env(parameters, test_filter),
    )
