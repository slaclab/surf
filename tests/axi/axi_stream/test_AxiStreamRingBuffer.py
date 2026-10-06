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
# - Sweep: Keep one small common-clock 16-bit wrapper configuration with a
#   16-deep ring so the bench proves the trigger-to-stream export behavior.
# - Stimulus: Push a short sequence into the data port, confirm the visible
#   buffered-length register, then stop capture with `extTrig` and drain the
#   exported AXI-Stream frame.
# - Checks: The stream must emit the current wrapper's captured window, which
#   includes the design's initial BRAM word followed by the populated samples
#   visible through the registered read path at trigger time.
# - Timing: The bench waits for the DUT to emit the stream frame after the
#   trigger instead of assuming the readout begins immediately on the same cycle.
# - Recovery: A second test runs the data clock on its own and lets
#   ContinuousMode capture until the data side has written 16 read requests
#   into its readReq CDC FIFO, so the FIFO write pointer has wrapped to its
#   reset value. With the data side's logging stopped for that capture, the
#   bench stops dataClk and pulses dataRst: the AXI-Lite side and the FIFO
#   read side reset, the unclocked data side keeps logging stopped and its
#   buffer armed, and no stale FIFO entry re-triggers the readout. The next
#   local trigger is never answered with a read request, which is the wedge
#   (TrigState WAIT_S with DataState IDLE_S) seen in hardware. The checks
#   require fresh frames after the clock restarts and no wedge left behind.
#   TRIG_TIMEOUT_G is set short so the trigger timeout fits the bench. The
#   bench only observes the FIFO's wr_en; it drives no internal signal.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, with_timeout

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp, AxiStreamBus, AxiStreamSink

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks

TRIG_TIMEOUT_C = 64

# SynchronizerFifo's default ADDR_WIDTH_G (4) inside the DUT's readReq CDC path
READREQ_FIFO_DEPTH_C = 16

TRIG_STATE_WAIT_C = 2
DATA_STATE_IDLE_C = 0


def fsm_states(status: int) -> tuple[int, int]:
    """Return (trigStateIdx, dataStateIdx) from the register at offset 0x0."""
    return (status >> 28) & 0x3, (status >> 30) & 0x3


class TB:
    def __init__(self, dut, independent_data_clk=False):
        self.dut = dut
        self.axil = None
        self.sink = None
        self.data_clock = None

        if independent_data_clk:
            # The AXI-Lite and stream-export clocks stay aligned for the
            # wrapper's synchronous TX FIFO, while the data clock is a
            # bench-owned lifetime agent that the recovery test stops and
            # restarts.
            start_lockstep_clocks(dut.axilClk, dut.axisClk, period_ns=5.0)
            self.data_clock = Clock(dut.dataClk, 4.0, unit="ns")
            self.data_clock.start()
        else:
            # Keep the data, AXI-Lite, and stream-export clocks truly aligned for
            # the common-clock wrapper subset this bench is validating.
            start_lockstep_clocks(dut.dataClk, dut.axilClk, dut.axisClk, period_ns=5.0)
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

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def write_reg(self, address: int, value: int):
        txn = await self.axil.write(address, value.to_bytes(4, "little"))
        assert txn.resp == AxiResp.OKAY

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
    tb.data_clock.start()

    # Let any frame already in the TX FIFO drain, then require fresh frames.
    await tb.cycle(400)
    tb.sink.clear()
    for _ in range(4):
        await with_timeout(tb.sink.recv(), 20, "us")

    trig_state, data_state = fsm_states(await tb.read_reg(0x0))
    assert not (trig_state == TRIG_STATE_WAIT_C and data_state == DATA_STATE_IDLE_C)


@pytest.mark.parametrize("parameters", [pytest.param({"TRIG_TIMEOUT_G": TRIG_TIMEOUT_C}, id="small_common_clk_capture")])
def test_AxiStreamRingBuffer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamringbufferipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
