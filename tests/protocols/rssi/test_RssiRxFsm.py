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

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import (
    RssiParams,
    RSSI_FLAG_BUSY,
    RSSI_FLAG_EACK,
    RSSI_FLAG_NULL,
    RSSI_FLAG_RST,
    build_ack_header,
    build_null_header,
    build_data_header,
    build_syn_header,
    header_words,
    stream_words_from_header,
    stream_word_from_header_word,
)
from tests.protocols.ssi.ssi_test_utils import (
    cycle as ssi_cycle,
    expect_no_output,
    recv_frame_and_check,
    setup_flat_ssi_testbench,
    SsiBeat,
)


class TB:
    def __init__(self, dut, bench):
        self.dut = dut
        self.clk = bench.clk
        self.source = bench.source
        self.sink = bench.sink
        assert self.source is not None
        assert self.sink is not None

    @classmethod
    async def create(cls, dut, *, connected: bool = True):
        # Reuse the SSI test infrastructure now that the RSSI wrapper exposes
        # the same flattened `sAxis`/`mAxis` names as the SSI wrappers.  The
        # RSSI-specific class only needs to add connection state and checksum
        # timing around those generic frame helpers.
        bench = await setup_flat_ssi_testbench(
            dut,
            source_prefix="sAxis",
            sink_prefix="mAxis",
            initial_values={
                "connActive_i": int(connected),
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
        extra_flags: int = 0,
        checksum_ok: bool = True,
        send_payload_after_bad_checksum: bool = False,
    ) -> None:
        header = bytearray(
            build_data_header(
                sequence=sequence,
                acknowledge=acknowledge,
                ack=ack,
                busy=busy,
                enable_checksum=False,
            )
        )
        header[0] |= extra_flags
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

        if not checksum_ok and not send_payload_after_bad_checksum:
            return

        for index, payload_word in enumerate(payload_words):
            await self.send_transport_word(
                data=payload_word,
                sof=0,
                last=int(index == len(payload_words) - 1),
            )

    async def send_single_word_header(
        self,
        header: bytes,
        *,
        checksum_ok: bool = True,
        eofe: int = 0,
    ) -> None:
        # Non-DATA control segments are one RSSI header word.  The receive FSM
        # still waits for the core checksum result before accepting or dropping
        # the segment.
        header_word = stream_word_from_header_word(header_words(header)[0])
        self.dut.chksumValid_i.value = 0
        self.dut.chksumOk_i.value = int(checksum_ok)

        await self.send_transport_word(data=header_word, sof=1, last=1, eofe=eofe)
        self.dut.chksumValid_i.value = 1
        await self.cycle()
        self.dut.chksumValid_i.value = 0

    async def send_syn_segment(
        self,
        *,
        sequence: int,
        acknowledge: int,
        ack: bool = False,
        extra_flags: int = 0,
        extra_payload_words: list[int] | None = None,
        checksum_ok: bool = True,
    ) -> None:
        params = RssiParams(connection_id=0xA5A5_1234)
        header = bytearray(
            build_syn_header(
                sequence=sequence,
                acknowledge=acknowledge,
                ack=ack,
                params=params,
                enable_checksum=False,
            )
        )
        header[0] |= extra_flags
        words = stream_words_from_header(bytes(header))
        payload_words = extra_payload_words or []

        self.dut.chksumValid_i.value = 0
        self.dut.chksumOk_i.value = int(checksum_ok)

        for index, word in enumerate(words):
            is_last = index == len(words) - 1 and not payload_words
            await self.send_transport_word(
                data=word,
                sof=int(index == 0),
                last=int(is_last),
            )

        self.dut.chksumValid_i.value = 1
        await self.cycle()
        self.dut.chksumValid_i.value = 0

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
    # and sequence-window checks pass.
    assert int(dut.rxSeqN_o.value) == 1
    assert int(dut.rxAckN_o.value) == 0
    assert int(dut.rxFlagAck_o.value) == 1
    assert int(dut.rxFlagData_o.value) == 1

    await recv_frame_and_check(
        tb.sink,
        clk=tb.clk,
        ready_signal=dut.mAxisTReady,
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[
            (payload, 0xFF, 0, 1, 0),
            (tail_payload, 0xFF, 1, 0, 0),
        ],
    )


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


@cocotb.test()
async def checksum_failed_data_payload_is_flushed_before_retransmit_test(dut):
    tb = await TB.create(dut)

    bad_payload = 0xDEAD_BEEF_CAFE_1234
    retransmit_payload = 0x1234_5678_9ABC_DEF0

    drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
    await tb.send_data_segment(
        sequence=1,
        acknowledge=0,
        payload_words=[bad_payload],
        checksum_ok=False,
        send_payload_after_bad_checksum=True,
    )
    await drop_wait
    await tb.expect_no_app_output()

    await tb.send_data_segment(
        sequence=1,
        acknowledge=0,
        payload_words=[retransmit_payload],
    )
    await tb.wait_status_pulse("rxValidSeg_o")
    await recv_frame_and_check(
        tb.sink,
        clk=tb.clk,
        ready_signal=dut.mAxisTReady,
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(retransmit_payload, 0xFF, 1, 1, 0)],
    )


@cocotb.test()
async def null_segment_is_accepted_without_application_output_test(dut):
    tb = await TB.create(dut)

    await tb.send_single_word_header(
        build_null_header(sequence=1, acknowledge=0, enable_checksum=False)
    )
    await tb.wait_status_pulse("rxValidSeg_o")

    assert int(dut.rxSeqN_o.value) == 1
    assert int(dut.rxAckN_o.value) == 0
    assert int(dut.rxFlagAck_o.value) == 1
    assert int(dut.rxFlagNull_o.value) == 1
    assert int(dut.rxFlagData_o.value) == 0
    await tb.expect_no_app_output()


@cocotb.test()
async def valid_data_payload_delivery_test(dut):
    tb = await TB.create(dut)

    payload = 0x8877_6655_4433_2211
    tail_payload = 0x0123_4567_89AB_CDEF
    await tb.send_data_segment(
        sequence=1,
        acknowledge=0,
        payload_words=[payload, tail_payload],
    )
    await tb.wait_status_pulse("rxValidSeg_o")

    await recv_frame_and_check(
        tb.sink,
        clk=tb.clk,
        ready_signal=dut.mAxisTReady,
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[
            (payload, 0xFF, 0, 1, 0),
            (tail_payload, 0xFF, 1, 0, 0),
        ],
    )


@cocotb.test()
async def illegal_data_flag_combinations_drop_test(dut):
    tb = await TB.create(dut)

    # DATA must carry ACK and must not be combined with BUSY or unsupported EACK.
    for ack, busy, extra_flags in (
        (False, False, 0),
        (True, True, 0),
        (True, False, RSSI_FLAG_EACK),
    ):
        drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
        await tb.send_data_segment(
            sequence=1,
            acknowledge=0,
            payload_words=[0x0102_0304_0506_0708],
            ack=ack,
            busy=busy,
            extra_flags=extra_flags,
        )
        await drop_wait
        await tb.expect_no_app_output()


@cocotb.test()
async def standalone_eack_segment_drops_test(dut):
    tb = await TB.create(dut)

    # EACK is reserved by the SURF RSSI v1 profile.  Even when combined with
    # ACK as in the RUDP lineage, hardware should reject it rather than treat
    # it as a supported extended acknowledgment.
    header = bytearray(
        build_ack_header(sequence=1, acknowledge=0, enable_checksum=False)
    )
    header[0] |= RSSI_FLAG_EACK

    drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
    await tb.send_single_word_header(bytes(header))
    await drop_wait
    await tb.expect_no_app_output()


@cocotb.test()
async def malformed_header_and_ack_window_violations_drop_test(dut):
    tb = await TB.create(dut)

    malformed_header = bytearray(
        build_null_header(sequence=1, acknowledge=0, enable_checksum=False)
    )
    malformed_header[1] = 9
    drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
    await tb.send_single_word_header(bytes(malformed_header))
    await drop_wait
    await tb.expect_no_app_output()

    drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
    await tb.send_data_segment(
        sequence=1,
        acknowledge=5,
        payload_words=[0x0102_0304_0506_0708],
    )
    await drop_wait
    await tb.expect_no_app_output()


@cocotb.test()
async def valid_syn_segment_is_accepted_and_captures_parameters_test(dut):
    tb = await TB.create(dut, connected=False)

    await tb.send_syn_segment(sequence=0x22, acknowledge=0x00)
    await tb.wait_status_pulse("rxValidSeg_o")

    assert int(dut.rxSeqN_o.value) == 0x22
    assert int(dut.rxFlagSyn_o.value) == 1
    assert int(dut.rxFlagNull_o.value) == 0
    assert int(dut.rxFlagBusy_o.value) == 0
    assert int(dut.paramVersion_o.value) == 1
    assert int(dut.paramChksumEn_o.value) == 1
    assert int(dut.paramConnId_o.value) == 0xA5A5_1234


@cocotb.test()
async def illegal_syn_flag_combinations_drop_test(dut):
    tb = await TB.create(dut, connected=False)

    # The RSSI profile keeps SYN separate from extended ACK, RST, BUSY, and NUL
    # semantics.
    for extra_flags in (
        RSSI_FLAG_EACK,
        RSSI_FLAG_BUSY,
        RSSI_FLAG_RST,
        RSSI_FLAG_NULL,
    ):
        drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
        await tb.send_syn_segment(
            sequence=0x31,
            acknowledge=0x00,
            extra_flags=extra_flags,
        )
        await drop_wait
        assert int(dut.rxValidSeg_o.value) == 0
        assert int(dut.paramConnId_o.value) == 0


@cocotb.test()
async def syn_with_extra_payload_drops_test(dut):
    tb = await TB.create(dut, connected=False)

    drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
    await tb.send_syn_segment(
        sequence=0x42,
        acknowledge=0x00,
        extra_payload_words=[0x1122_3344_5566_7788],
    )
    await drop_wait
    assert int(dut.rxValidSeg_o.value) == 0
    assert int(dut.paramConnId_o.value) == 0
    await tb.expect_no_app_output()


@cocotb.test()
async def out_of_order_data_drops_then_in_order_retransmit_accepts_test(dut):
    tb = await TB.create(dut)

    out_of_order_payload = 0x2222_2222_2222_2222
    in_order_payload = 0x1111_1111_1111_1111

    drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
    await tb.send_data_segment(
        sequence=2,
        acknowledge=0,
        payload_words=[out_of_order_payload],
    )
    await drop_wait
    assert int(dut.rxValidSeg_o.value) == 0
    assert int(dut.rxSeqN_o.value) == 2
    await tb.expect_no_app_output()

    await tb.send_data_segment(
        sequence=1,
        acknowledge=0,
        payload_words=[in_order_payload],
    )
    await tb.wait_status_pulse("rxValidSeg_o")
    assert int(dut.rxSeqN_o.value) == 1


@cocotb.test()
async def duplicate_data_after_delivery_drops_without_second_output_test(dut):
    tb = await TB.create(dut)

    payload = 0x1357_9BDF_2468_ACE0
    await tb.send_data_segment(
        sequence=1,
        acknowledge=0,
        payload_words=[payload],
    )
    await tb.wait_status_pulse("rxValidSeg_o")
    await recv_frame_and_check(
        tb.sink,
        clk=tb.clk,
        ready_signal=dut.mAxisTReady,
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(payload, 0xFF, 1, 1, 0)],
    )

    drop_wait = cocotb.start_soon(tb.wait_status_pulse("rxDropSeg_o"))
    await tb.send_data_segment(
        sequence=1,
        acknowledge=0,
        payload_words=[payload],
    )
    await drop_wait
    await tb.expect_no_app_output()


PARAMETER_SWEEP = [pytest.param({}, id="small_window")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiRxFsm(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssirxfsmwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/rssi/v1/rtl/RssiRxFsm.vhd",
                "protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd",
            ],
        },
        force_compile=True,
    )
