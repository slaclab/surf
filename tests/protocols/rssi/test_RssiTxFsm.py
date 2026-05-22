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
#   sequence/ack fields and checksum while preserving the current TX sequence.
# - Timing: Output checks start with `TREADY` asserted, then present checksum
#   valid only after the DUT asks for a checksum so the header RAM path is
#   sampled after its registered update.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import (
    build_ack_header,
    parse_header,
)
from tests.protocols.ssi.ssi_test_utils import (
    cycle as ssi_cycle,
    recv_frame_and_check,
    setup_flat_ssi_testbench,
    wait_signal_pulse,
)


def _protocol_bytes_from_stream_word(word: int) -> bytes:
    # `RssiTxFsm` byte-swaps protocol-order header words onto the 64-bit stream
    # port.  Reverse the emitted stream word before parsing with the shared RSSI
    # protocol helper.
    return word.to_bytes(8, "big")[::-1]


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
        bench = await setup_flat_ssi_testbench(
            dut,
            source_prefix="sAxis",
            sink_prefix="mAxis",
            initial_values={
                "connActive_i": 1,
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
                "txAckFlag_i": 1,
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


@cocotb.test()
async def standalone_ack_emits_one_header_without_sequence_consumption_test(dut):
    tb = await TB.create(dut)

    initial_seq = int(dut.txSeqN_o.value)
    expected_header = (
        build_ack_header(
            sequence=initial_seq,
            acknowledge=0x34,
            enable_checksum=False,
        )[:6]
        + bytes.fromhex("beef")
    )
    expected_stream_word = int.from_bytes(expected_header[::-1], "big")

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
    await wait_signal_pulse(dut.chksumStrobe_o, clk=tb.clk)
    dut.chksumValid_i.value = 1

    [beat] = await recv_task
    assert beat.data == expected_stream_word
    dut.chksumValid_i.value = 0

    parsed = parse_header(_protocol_bytes_from_stream_word(beat.data))
    assert parsed.ack
    assert not parsed.syn
    assert not parsed.rst
    assert not parsed.nul
    assert parsed.sequence == initial_seq
    assert parsed.acknowledge == 0x34
    assert parsed.checksum == 0xBEEF

    # ACK-only segments acknowledge peer traffic but do not allocate a local
    # sequence number in the RSSI profile.
    await tb.cycle(2)
    assert int(dut.txSeqN_o.value) == initial_seq


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
