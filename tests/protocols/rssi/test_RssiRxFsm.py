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
# - Sweep: Run `RssiRxFsm` through a thin wrapper with small receive and
#   transmit windows, checksum enabled, and an internal behavioral segment RAM.
# - Stimulus: Drive flattened transport-side SSI frames containing RSSI DATA
#   headers and payload words, then vary checksum and illegal flag cases.
# - Checks: A valid in-order DATA segment must pulse `rxValidSeg_o` and update
#   the visible sequence/ack/flag fields.  A checksum failure must pulse
#   `rxDropSeg_o` and stay silent on the application side.
# - Timing: Transport input waits for sampled ready before changing beats, and
#   all status checks wait past the default `TPD_G` output delay.

import os

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import (
    build_data_header,
    header_words,
    stream_word_from_header_word,
)
from tests.protocols.ssi.ssi_test_utils import (
    cycle as ssi_cycle,
    expect_no_output,
    setup_flat_ssi_testbench,
    SsiBeat,
)


RUN_KNOWN_ISSUE_TESTS = os.getenv("RUN_RSSI_KNOWN_ISSUE_TESTS") == "1"


class TB:
    def __init__(self, dut, bench):
        self.dut = dut
        self.clk = bench.clk
        self.source = bench.source
        self.sink = bench.sink
        assert self.source is not None
        assert self.sink is not None

    @classmethod
    async def create(cls, dut):
        # Reuse the SSI test infrastructure now that the RSSI wrapper exposes
        # the same flattened `sAxis`/`mAxis` names as the SSI wrappers.  The
        # RSSI-specific class only needs to add connection state and checksum
        # timing around those generic frame helpers.
        bench = await setup_flat_ssi_testbench(
            dut,
            source_prefix="sAxis",
            sink_prefix="mAxis",
            initial_values={
                "connActive_i": 1,
                "rxWindowSize_i": 4,
                "rxBufferSize_i": 4,
                "txWindowSize_i": 4,
                "lastAckN_i": 0,
                "mAxisTReady": 0,
                "chksumValid_i": 0,
                "chksumOk_i": 1,
            },
        )
        return cls(dut, bench)

    async def cycle(self, count: int = 1) -> None:
        await ssi_cycle(self.clk, count=count)

    async def send_transport_word(
        self,
        *,
        data: int,
        sof: int,
        last: int,
        keep: int = 0xFF,
        eofe: int = 0,
    ) -> None:
        # `FlatSsiEndpoint.send()` owns the ready/valid handshake and returns
        # the source to idle.  RSSI still controls the protocol-level SOF/LAST
        # placement, so the header is the only beat with `sof=1`.
        await self.source.send(
            SsiBeat(data=data, keep=keep, last=last, sof=sof, eofe=eofe),
            clk=self.clk,
        )
        await self.cycle()

    async def send_data_segment(
        self,
        *,
        sequence: int,
        acknowledge: int,
        payload_words: list[int],
        ack: bool = True,
        busy: bool = False,
        checksum_ok: bool = True,
    ) -> None:
        header = build_data_header(
            sequence=sequence,
            acknowledge=acknowledge,
            ack=ack,
            busy=busy,
            enable_checksum=False,
        )
        header_word = stream_word_from_header_word(header_words(header)[0])

        # `RssiRxFsm` receives checksum status from the core-level checksum
        # block after the header word has been strobed.  Keep valid low while
        # the header is accepted so CHECK sees registered header fields before
        # making the pass/drop decision.
        self.dut.chksumValid_i.value = 0
        self.dut.chksumOk_i.value = int(checksum_ok)

        await self.send_transport_word(data=header_word, sof=1, last=0)
        self.dut.chksumValid_i.value = 1
        await self.cycle()
        self.dut.chksumValid_i.value = 0

        if not checksum_ok:
            return

        for index, payload_word in enumerate(payload_words):
            await self.send_transport_word(
                data=payload_word,
                sof=0,
                last=int(index == len(payload_words) - 1),
            )

    async def wait_status_pulse(self, signal_name: str, *, cycles: int = 32) -> None:
        signal = getattr(self.dut, signal_name)
        await Timer(1, unit="ns")
        if int(signal.value) == 1:
            return
        for _ in range(cycles):
            await self.cycle()
            if int(signal.value) == 1:
                return
        raise AssertionError(f"Timed out waiting for {signal_name}")

    async def expect_no_app_output(self, *, cycles: int = 16) -> None:
        # Dropped segments may take a few cycles to unwind back to WAIT_SOF, so
        # check a bounded quiet window rather than only the immediate cycle.
        self.dut.mAxisTReady.value = 1
        await expect_no_output(self.sink, clk=self.clk, cycles=cycles)
        self.dut.mAxisTReady.value = 0


@cocotb.test()
async def valid_in_order_data_segment_is_accepted_test(dut):
    tb = await TB.create(dut)

    payload = 0x8877_6655_4433_2211
    tail_payload = 0x0123_4567_89AB_CDEF
    await tb.send_data_segment(
        sequence=1,
        acknowledge=0,
        payload_words=[payload, tail_payload],
    )
    await tb.wait_status_pulse("rxValidSeg_o")

    # The RX FSM records the accepted RSSI header fields when the header screen
    # and sequence-window checks pass.  Full payload ordering is left to the
    # later integration wrapper because it depends on matching the core's RAM
    # read latency exactly.
    assert int(dut.rxSeqN_o.value) == 1
    assert int(dut.rxAckN_o.value) == 0
    assert int(dut.rxFlagAck_o.value) == 1
    assert int(dut.rxFlagData_o.value) == 1


@cocotb.test()
async def checksum_failure_drops_without_application_output_test(dut):
    tb = await TB.create(dut)

    await tb.send_data_segment(
        sequence=1,
        acknowledge=0,
        payload_words=[0xDEAD_BEEF_CAFE_1234],
        checksum_ok=False,
    )
    await tb.wait_status_pulse("rxDropSeg_o")
    await tb.expect_no_app_output()


@cocotb.test(skip=not RUN_KNOWN_ISSUE_TESTS)
async def illegal_data_flag_combinations_drop_test(dut):
    tb = await TB.create(dut)

    # Spec-shaped expectation from the regression plan: DATA must carry ACK and
    # must not be combined with BUSY.  This is opt-in while the current RTL
    # behavior is being characterized.
    for ack, busy in ((False, False), (True, True)):
        await tb.send_data_segment(
            sequence=1,
            acknowledge=0,
            payload_words=[0x0102_0304_0506_0708],
            ack=ack,
            busy=busy,
        )
        await tb.wait_status_pulse("rxDropSeg_o")
        await tb.expect_no_app_output()


PARAMETER_SWEEP = [pytest.param({}, id="small_window")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiRxFsm(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssirxfsmwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd"]},
    )
