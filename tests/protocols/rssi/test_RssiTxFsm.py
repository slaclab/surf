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
# - Sweep: Run `RssiTxFsm` through a thin wrapper with small transmit window,
#   deterministic header checksum input, a real `RssiHeaderReg`, and a small
#   behavioral segment RAM.
# - Stimulus: Start from an active connection, issue directed segment requests,
#   and use flattened SSI handshakes on the application and transport sides.
# - Checks: Standalone ACK emits exactly one RSSI ACK segment with the expected
#   sequence/ack fields and checksum while preserving the current TX sequence;
#   DATA, NULL, and RST emit expected headers and consume one sequence number.
# - Timing: Output checks start with `TREADY` asserted, then present checksum
#   valid only after the DUT asks for a checksum so the header RAM path is
#   sampled after its registered update.

import cocotb
import os
import pytest
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import (
    RssiParams,
    build_ack_header,
    build_data_header,
    build_null_header,
    build_rst_header,
    build_syn_header,
    parse_header,
)
from tests.protocols.ssi.ssi_test_utils import (
    SsiBeat,
    cycle as ssi_cycle,
    recv_frame_and_check,
    send_contiguous_frame,
    setup_flat_ssi_testbench,
    wait_signal_pulse,
)


def _protocol_bytes_from_stream_word(word: int) -> bytes:
    # `RssiTxFsm` byte-swaps protocol-order header words onto the 64-bit stream
    # port.  Reverse the emitted stream word before parsing with the shared RSSI
    # protocol helper.
    return word.to_bytes(8, "big")[::-1]


def _stream_word_from_header(header: bytes) -> int:
    return int.from_bytes(header[::-1], "big")


def _header_with_test_checksum(header: bytes) -> bytes:
    return header[:-2] + bytes.fromhex("beef")


def _stream_words_from_header(header: bytes) -> list[int]:
    return [
        _stream_word_from_header(header[index : index + 8])
        for index in range(0, len(header), 8)
    ]


def _run_known_issue_tests() -> bool:
    return os.getenv("RUN_RSSI_KNOWN_ISSUE_TESTS") == "1"


class TB:
    def __init__(self, dut, bench):
        self.dut = dut
        self.clk = bench.clk
        self.source = bench.source
        self.sink = bench.sink
        assert self.source is not None
        assert self.sink is not None

    @classmethod
    async def create(cls, dut, *, connected: bool = True, tx_ack_flag: int = 1):
        bench = await setup_flat_ssi_testbench(
            dut,
            source_prefix="sAxis",
            sink_prefix="mAxis",
            initial_values={
                "connActive_i": int(connected),
                "closed_i": 0,
                "injectFault_i": 0,
                "sndSyn_i": 0,
                "sndAck_i": 0,
                "sndRst_i": 0,
                "sndResend_i": 0,
                "sndNull_i": 0,
                "windowSize_i": 4,
                "bufferSize_i": 4,
                "initSeqN_i": 0x12,
                "txAckFlag_i": tx_ack_flag,
                "rxAckN_i": 0x34,
                "localBusy_i": 0,
                "ack_i": 0,
                "ackN_i": 0,
                "mAxisTReady": 0,
                "chksumValid_i": 0,
                "chksum_i": 0xBEEF,
            },
        )
        tb = cls(dut, bench)
        # Let INIT -> DISS_CONN -> CONN settle after reset so the first request
        # is accepted from the connected-state request decoder.
        await tb.cycle(4)
        return tb

    async def cycle(self, count: int = 1) -> None:
        await ssi_cycle(self.clk, count=count)

    async def pulse(self, signal_name: str) -> None:
        signal = getattr(self.dut, signal_name)
        signal.value = 1
        await self.cycle()
        signal.value = 0

    async def provide_checksum_after_strobe(self) -> None:
        await wait_signal_pulse(self.dut.chksumStrobe_o, clk=self.clk)
        self.dut.chksumValid_i.value = 1

    async def finish_checksum(self) -> None:
        self.dut.chksumValid_i.value = 0
        await self.cycle()

    async def recv_frame_selected_fields(
        self,
        *,
        fields: tuple[str, ...],
        timeout_cycles: int = 128,
    ) -> list[dict[str, int]]:
        self.dut.mAxisTReady.value = 1
        beats = []
        try:
            for _ in range(timeout_cycles):
                await FallingEdge(self.clk)
                await Timer(1, unit="ns")
                if int(self.dut.mAxisTValid.value) == 1:
                    beat = {}
                    for field in fields:
                        beat[field] = int(getattr(self.dut, field).value)
                    beats.append(beat)
                    await RisingEdge(self.clk)
                    await Timer(1, unit="ns")
                    if beat.get("mAxisTLast", 0) == 1:
                        return beats
                else:
                    await RisingEdge(self.clk)
                    await Timer(1, unit="ns")
        finally:
            self.dut.mAxisTReady.value = 0
        raise AssertionError("Timed out waiting for selected mAxis frame fields")


def _assert_non_syn_header(
    beat,
    *,
    sequence: int,
    acknowledge: int,
    ack: bool,
    rst: bool = False,
    nul: bool = False,
) -> None:
    parsed = parse_header(_protocol_bytes_from_stream_word(beat.data))
    assert parsed.ack is ack
    assert not parsed.syn
    assert parsed.rst is rst
    assert parsed.nul is nul
    assert parsed.sequence == sequence
    assert parsed.acknowledge == acknowledge
    assert parsed.checksum == 0xBEEF


@cocotb.test()
async def standalone_ack_emits_one_header_without_sequence_consumption_test(dut):
    tb = await TB.create(dut)

    initial_seq = int(dut.txSeqN_o.value)
    expected_header = _header_with_test_checksum(
        build_ack_header(
            sequence=initial_seq,
            acknowledge=0x34,
            enable_checksum=False,
        )
    )
    expected_stream_word = _stream_word_from_header(expected_header)

    recv_task = cocotb.start_soon(
        recv_frame_and_check(
            tb.sink,
            clk=tb.clk,
            ready_signal=dut.mAxisTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[
                (expected_stream_word, 0xFF, 1, 1, 0),
            ],
        )
    )

    await tb.pulse("sndAck_i")
    await tb.provide_checksum_after_strobe()

    [beat] = await recv_task
    assert beat.data == expected_stream_word
    await tb.finish_checksum()

    _assert_non_syn_header(beat, sequence=initial_seq, acknowledge=0x34, ack=True)

    # ACK-only segments acknowledge peer traffic but do not allocate a local
    # sequence number in the RSSI profile.
    await tb.cycle(2)
    assert int(dut.txSeqN_o.value) == initial_seq


@cocotb.test()
async def syn_emits_three_word_header_and_consumes_sequence_test(dut):
    tb = await TB.create(dut, connected=False, tx_ack_flag=0)

    initial_seq = int(dut.txSeqN_o.value)
    expected_header = _header_with_test_checksum(
        build_syn_header(
            sequence=initial_seq,
            acknowledge=0x34,
            ack=False,
            params=RssiParams(
                version=0,
                chksum_en=0,
                max_outs_seg=0,
                max_seg_size=0,
                retrans_tout=0,
                cumul_ack_tout=0,
                null_seg_tout=0,
                max_retrans=0,
                max_cum_ack=0,
                max_outofseq=0,
                timeout_unit=0,
                connection_id=0,
            ),
            enable_checksum=False,
        )
    )
    expected_words = _stream_words_from_header(expected_header)

    recv_task = cocotb.start_soon(
        recv_frame_and_check(
            tb.sink,
            clk=tb.clk,
            ready_signal=dut.mAxisTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[
                (expected_words[0], 0xFF, 0, 1, 0),
                (expected_words[1], 0xFF, 0, 0, 0),
                (expected_words[2], 0xFF, 1, 0, 0),
            ],
        )
    )

    await tb.pulse("sndSyn_i")
    await tb.provide_checksum_after_strobe()

    beats = await recv_task
    await tb.finish_checksum()

    parsed = parse_header(b"".join(_protocol_bytes_from_stream_word(beat.data) for beat in beats))
    assert parsed.syn
    assert not parsed.ack
    assert parsed.sequence == initial_seq
    assert parsed.acknowledge == 0x34
    assert parsed.checksum == 0xBEEF
    assert parsed.params == RssiParams(
        version=0,
        chksum_en=0,
        max_outs_seg=0,
        max_seg_size=0,
        retrans_tout=0,
        cumul_ack_tout=0,
        null_seg_tout=0,
        max_retrans=0,
        max_cum_ack=0,
        max_outofseq=0,
        timeout_unit=0,
        connection_id=0,
    )

    await tb.cycle(2)
    assert int(dut.txSeqN_o.value) == (initial_seq + 1) & 0xFF


@cocotb.test()
async def one_word_data_ack_and_resend_sequence_test(dut):
    tb = await TB.create(dut)

    initial_seq = int(dut.txSeqN_o.value)
    expected_header = _header_with_test_checksum(
        build_data_header(
            sequence=initial_seq,
            acknowledge=0x34,
            enable_checksum=False,
        )
    )
    expected_stream_word = _stream_word_from_header(expected_header)
    payload_word = 0x1122_3344_5566_7788

    recv_task = cocotb.start_soon(
        tb.recv_frame_selected_fields(
            fields=("mAxisTData", "mAxisTLast", "mAxisSof", "mAxisEofe"),
        )
    )

    await send_contiguous_frame(
        tb.source,
        [SsiBeat(data=payload_word, keep=0xFF, last=1, sof=1, eofe=0)],
        clk=tb.clk,
    )
    await tb.provide_checksum_after_strobe()

    header_beat, payload_beat = await recv_task
    await tb.finish_checksum()

    assert header_beat == {
        "mAxisTData": expected_stream_word,
        "mAxisTLast": 0,
        "mAxisSof": 1,
        "mAxisEofe": 0,
    }
    assert payload_beat == {
        "mAxisTData": payload_word,
        "mAxisTLast": 1,
        "mAxisSof": 0,
        "mAxisEofe": 0,
    }

    parsed = parse_header(_protocol_bytes_from_stream_word(header_beat["mAxisTData"]))
    assert parsed.ack
    assert not parsed.syn
    assert not parsed.rst
    assert not parsed.nul
    assert parsed.sequence == initial_seq
    assert parsed.acknowledge == 0x34
    assert parsed.checksum == 0xBEEF

    await tb.cycle(2)
    assert int(dut.txSeqN_o.value) == (initial_seq + 1) & 0xFF
    assert int(dut.bufferEmpty_o.value) == 0

    resend_task = cocotb.start_soon(
        tb.recv_frame_selected_fields(
            fields=("mAxisTData", "mAxisTLast", "mAxisSof", "mAxisEofe"),
        )
    )

    await tb.pulse("sndResend_i")
    await tb.provide_checksum_after_strobe()

    resend_header_beat, resend_payload_beat = await resend_task
    await tb.finish_checksum()

    assert resend_header_beat == {
        "mAxisTData": expected_stream_word,
        "mAxisTLast": 0,
        "mAxisSof": 1,
        "mAxisEofe": 0,
    }
    assert resend_payload_beat == {
        "mAxisTData": payload_word,
        "mAxisTLast": 1,
        "mAxisSof": 0,
        "mAxisEofe": 0,
    }

    await tb.cycle(2)
    assert int(dut.txSeqN_o.value) == (initial_seq + 1) & 0xFF
    assert int(dut.bufferEmpty_o.value) == 0

    dut.ackN_i.value = initial_seq
    await tb.pulse("ack_i")
    await tb.cycle(4)
    assert int(dut.lastAckN_o.value) == initial_seq
    assert int(dut.bufferEmpty_o.value) == 1


@cocotb.test(skip=not _run_known_issue_tests())
async def one_word_data_tkeep_known_issue_test(dut):
    tb = await TB.create(dut)

    initial_seq = int(dut.txSeqN_o.value)
    expected_header = _header_with_test_checksum(
        build_data_header(
            sequence=initial_seq,
            acknowledge=0x34,
            enable_checksum=False,
        )
    )
    expected_stream_word = _stream_word_from_header(expected_header)
    payload_word = 0x1122_3344_5566_7788

    recv_task = cocotb.start_soon(
        recv_frame_and_check(
            tb.sink,
            clk=tb.clk,
            ready_signal=dut.mAxisTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[
                (expected_stream_word, 0xFF, 0, 1, 0),
                (payload_word, 0xFF, 1, 0, 0),
            ],
        )
    )

    await send_contiguous_frame(
        tb.source,
        [SsiBeat(data=payload_word, keep=0xFF, last=1, sof=1, eofe=0)],
        clk=tb.clk,
    )
    await tb.provide_checksum_after_strobe()

    await recv_task


@cocotb.test()
async def null_segment_emits_ack_header_and_consumes_sequence_test(dut):
    tb = await TB.create(dut)

    initial_seq = int(dut.txSeqN_o.value)
    expected_header = _header_with_test_checksum(
        build_null_header(
            sequence=initial_seq,
            acknowledge=0x34,
            enable_checksum=False,
        )
    )
    expected_stream_word = _stream_word_from_header(expected_header)

    recv_task = cocotb.start_soon(
        recv_frame_and_check(
            tb.sink,
            clk=tb.clk,
            ready_signal=dut.mAxisTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[
                (expected_stream_word, 0xFF, 1, 1, 0),
            ],
        )
    )

    await tb.pulse("sndNull_i")
    await tb.provide_checksum_after_strobe()

    [beat] = await recv_task
    await tb.finish_checksum()

    _assert_non_syn_header(beat, sequence=initial_seq, acknowledge=0x34, ack=True, nul=True)

    await tb.cycle(2)
    assert int(dut.txSeqN_o.value) == (initial_seq + 1) & 0xFF
    assert int(dut.bufferEmpty_o.value) == 0


@cocotb.test()
async def rst_segment_emits_header_and_consumes_sequence_without_buffering_test(dut):
    tb = await TB.create(dut)

    initial_seq = int(dut.txSeqN_o.value)
    expected_header = _header_with_test_checksum(
        build_rst_header(
            sequence=initial_seq,
            acknowledge=0x34,
            enable_checksum=False,
        )
    )
    expected_stream_word = _stream_word_from_header(expected_header)

    recv_task = cocotb.start_soon(
        recv_frame_and_check(
            tb.sink,
            clk=tb.clk,
            ready_signal=dut.mAxisTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[
                (expected_stream_word, 0xFF, 1, 1, 0),
            ],
        )
    )

    await tb.pulse("sndRst_i")
    await tb.provide_checksum_after_strobe()

    [beat] = await recv_task
    await tb.finish_checksum()

    _assert_non_syn_header(beat, sequence=initial_seq, acknowledge=0x34, ack=False, rst=True)

    await tb.cycle(2)
    assert int(dut.txSeqN_o.value) == (initial_seq + 1) & 0xFF
    assert int(dut.bufferEmpty_o.value) == 1


PARAMETER_SWEEP = [pytest.param({}, id="small_window")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiTxFsm(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssitxfsmwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd"]},
    )
