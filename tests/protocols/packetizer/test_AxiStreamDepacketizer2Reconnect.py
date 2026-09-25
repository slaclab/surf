##############################################################################
## This file is part of 'SLAC Firmware Standard Library'. It is subject to
## the license terms in the LICENSE.txt file found in the top-level directory
## of this distribution and at:
## https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of the 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - DUT: Production V2 depacketizer through its existing flat wrapper. Curated
#   cases cover every inferred RAM read latency, output pipeline bypass,
#   NONE/DATA/FULL CRC, CRC pipelining, and RSSI's 256-entry FULL-CRC profile.
# - Stimulus: Open enough destinations to fill the output buffers during link
#   cleanup, then present fresh headers immediately when linkGood returns.
#   Separate sparse/empty sweeps distinguish destination 0 from the inactive
#   highest entry. Repeat reconnects without a global reset, including a short
#   link-up/down pulse while termination output is blocked.
# - Oracle: Independent zlib CRC and explicit application beats; no packetizer
#   RTL generates stimulus. Check exact accepted input/output sequences, one
#   EOF+EOFE without SOF per open destination before any fresh payload, and no
#   output for inactive entries. Fresh frames exercise nonzero TID/TUSER and a
#   three-byte final beat. Synthetic termination payload/TID are unspecified.
# - Timing: Ready changes on falling edges. The finite monitor samples the
#   accepting rising edge before the DUT's 1 ns TPD, checks held-beat stability,
#   and is explicitly awaited. Progress waits and tests have finite bounds.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    AxisBeat,
    CRC_MODE_VALUES,
    FlatAxisEndpoint,
    PACKETIZER2_CRC_DATA,
    PACKETIZER2_CRC_FULL,
    cycle,
    packetizer2_sof_packet,
    payload_to_beats,
    reset_packetizer_dut,
    send_beats,
    wait_debug_init_done,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatAxisEndpoint(dut, prefix="S_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")
        self.table_size = 1 << int(os.environ["TDEST_BITS_G"])
        self.destinations = list(range(min(self.table_size, 8)))
        self.crc_mode = CRC_MODE_VALUES[os.environ["CRC_MODE_G"]]
        self.received = []
        self.sent = []
        self.accepted = []
        self.monitor_done = False
        dut.axisRst.setimmediatevalue(1)
        dut.linkGood.setimmediatevalue(1)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source.set_idle()
        # Lifetime clock agent; cocotb stops it at the end of the test.
        self.clock_task = cocotb.start_soon(Clock(dut.axisClk, 5, unit="ns").start())

    async def start(self):
        await reset_packetizer_dut(self.dut)
        await wait_debug_init_done(self.dut, timeout_cycles=4*self.table_size+16)
        self.monitor_task = cocotb.start_soon(self.monitor())
        await FallingEdge(self.dut.axisClk)
        self.dut.M_AXIS_TREADY.value = 1

    async def monitor(self):
        held = None
        for _ in range(12000):
            await RisingEdge(self.dut.axisClk)
            valid = int(self.dut.M_AXIS_TVALID.value)
            ready = int(self.dut.M_AXIS_TREADY.value)
            beat = self.sink.snapshot()
            if held is not None:
                assert valid and beat == held, f"Stalled output changed: {held} -> {beat}"
            held = beat if valid and not ready else None
            if valid and ready:
                self.received.append(beat)
            if int(self.dut.S_AXIS_TVALID.value) and int(self.dut.S_AXIS_TREADY.value):
                self.accepted.append(self.source.snapshot())
            if self.monitor_done:
                break
        else:
            raise AssertionError("Recovery monitor exceeded its cycle limit")

    async def finish(self):
        self.monitor_done = True
        await self.monitor_task
        assert self.accepted == self.sent, "Stimulus did not transfer exactly once per input beat"

    async def wait_count(self, count):
        for _ in range(4*self.table_size+512):
            if len(self.received) >= count:
                break
            await cycle(self.dut.axisClk)
        else:
            raise AssertionError(f"Expected {count} output beats, received {self.received}")

    async def send_packet(self, payload, *, dest, eof, last_user=0):
        beats = packetizer2_sof_packet(
            payload, dest=dest, tid=0x40+dest, eof=eof,
            last_user=last_user, crc_mode=self.crc_mode,
        )
        self.sent.extend(beats)
        await send_beats(self.source, beats, clk=self.dut.axisClk)

    async def reconnect(self, active, *, epoch, flap=False):
        start = len(self.received)
        expected_open = []
        # Leave only the requested destinations inside unfinished frames.
        for dest in active:
            value = 0x12340000 + (epoch << 8) + dest
            await self.send_packet(value.to_bytes(8, "little"), dest=dest, eof=False)
            expected_open.append(AxisBeat(data=value, dest=dest, tid=0x40+dest, user=0x22))
        await self.wait_count(start+len(active))
        await cycle(self.dut.axisClk, 20)
        assert self.received[start:] == expected_open

        await FallingEdge(self.dut.axisClk)
        self.dut.M_AXIS_TREADY.value = 0
        self.dut.linkGood.value = 0
        # Allow even the largest RAM table to reach the active entries. With
        # many open frames the sweep must then wait for output capacity.
        await cycle(self.dut.axisClk, 4*self.table_size+16)
        self.dut.linkGood.value = 1
        if flap:
            # Restart an interrupted cleanup while its prior markers remain
            # queued. Already-cleared entries must not emit a second marker.
            await cycle(self.dut.axisClk, 2)
            self.dut.linkGood.value = 0
            await cycle(self.dut.axisClk, 4)
            self.dut.linkGood.value = 1

        expected_fresh = []
        async def send_fresh():
            for dest in self.destinations:
                # Two payload beats, including a partial final word, exercise
                # normal forwarding and CRC after each cleanup.
                payload = (0x56780000 + (epoch << 8) + dest).to_bytes(8, "little") + b"\xa4\xb6\xc8"
                expected_fresh.extend(payload_to_beats(
                    payload, dest=dest, tid=0x40+dest, first_user=0x22, last_user=0x40,
                ))
                await self.send_packet(payload, dest=dest, eof=True, last_user=0x40)

        # Present the fresh header while the sink is still blocked, rather
        # than waiting for cleanup to drain before exercising reconnection.
        sender = cocotb.start_soon(send_fresh())
        await cycle(self.dut.axisClk, 8)
        for index in range(350):
            await FallingEdge(self.dut.axisClk)
            self.dut.M_AXIS_TREADY.value = int(index % 9 == 0)
        self.dut.M_AXIS_TREADY.value = 1
        await sender
        # All input has transferred and ready is now held high. Allow the
        # bounded CRC/output pipelines to empty, then check the complete trace
        # so a missing termination fails an assertion rather than a timeout.
        await cycle(self.dut.axisClk, 32)

        output = self.received[start+len(active):]
        assert len(output) == len(active)+len(expected_fresh), (
            f"epoch={epoch}, active={active}: missing or extra recovery output: {output}"
        )
        endings = output[:len(active)]
        assert sorted(beat.dest for beat in endings) == sorted(active), (
            f"epoch={epoch}, active={active}: wrong termination destinations: {endings}"
        )
        for beat in endings:
            assert beat.last and beat.keep == 0xFF
            assert (beat.user >> 56) & 1, f"Termination missing EOFE: {beat}"
            assert not beat.user & 2, f"Termination introduced a new SOF: {beat}"
        assert output[len(active):] == expected_fresh, (
            f"epoch={epoch}: fresh payload/sidebands changed or appeared before cleanup: {output}"
        )


@cocotb.test(timeout_time=80, timeout_unit="us")
async def reconnect_with_pending_terminations(dut):
    tb = TB(dut)
    await tb.start()
    # Both iterations reconnect without resetting the depacketizer.
    await tb.reconnect(tb.destinations, epoch=0)
    await tb.reconnect(tb.destinations, epoch=1, flap=True)
    await tb.finish()


@cocotb.test(timeout_time=80, timeout_unit="us")
async def sparse_and_empty_sweeps(dut):
    tb = TB(dut)
    await tb.start()
    # The highest RAM entry is inactive, unlike the original all-active and
    # mask-9 cases. An old read of active destination 0 must not terminate it.
    await tb.reconnect([0], epoch=0)
    # Fresh frames above all ended normally: another disconnect owes no EOFE.
    await tb.reconnect([], epoch=1)
    await tb.finish()


@pytest.mark.parametrize("crc_mode,expected_hex", [
    pytest.param(PACKETIZER2_CRC_DATA,
                 "12200040000000803132333435363738000108009ae0daaf", id="data_crc_vector"),
    pytest.param(PACKETIZER2_CRC_FULL,
                 "22200040000000803132333435363738000108004c7742b2", id="full_crc_vector"),
])
def test_packetizer2_sof_packet_crc_vector(crc_mode, expected_hex):
    # Literal wire vectors calculated with an independent bit-at-a-time
    # CRC-32/ISO-HDLC reference (check value for "123456789": 0xCBF43926).
    # These pin the zlib oracle's coverage and CRC byte order.
    packet = packetizer2_sof_packet(b"12345678", dest=0, tid=0x40, eof=True, crc_mode=crc_mode)
    assert b"".join(beat.data.to_bytes(8, "little") for beat in packet).hex() == expected_hex


PARAMETER_SWEEP = [
    pytest.param("block", False, 3, 1, "NONE", 0, id="block_unregistered"),
    pytest.param("block", True, 3, 1, "NONE", 0, id="block_registered"),
    pytest.param("distributed", False, 3, 1, "NONE", 0, id="lut_unregistered"),
    pytest.param("distributed", True, 3, 1, "DATA", 1, id="lut_registered_crc_pipeline"),
    pytest.param("block", True, 2, 0, "NONE", 0, id="block_output_bypass"),
    pytest.param("distributed", False, 2, 0, "NONE", 0, id="lut_output_bypass"),
    pytest.param("block", True, 8, 1, "FULL", 0, id="rssi_full_crc"),
    pytest.param("block", True, 3, 1, "FULL", 1, id="full_crc_pipeline"),
]


@pytest.mark.parametrize("memory,registered,bits,output,crc,crc_pipeline", PARAMETER_SWEEP)
def test_AxiStreamDepacketizer2Reconnect(memory, registered, bits, output, crc, crc_pipeline):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdepacketizer2wrapper",
        parameters={
            "MEMORY_TYPE_G": memory, "REG_EN_G": registered, "TDEST_BITS_G": bits,
            "OUTPUT_PIPE_STAGES_G": output, "CRC_MODE_G": crc, "CRC_PIPELINE_G": crc_pipeline,
        },
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamDepacketizer2Wrapper.vhd"],
        },
    )
