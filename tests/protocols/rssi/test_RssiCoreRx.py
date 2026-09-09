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
# - Purpose: Exercise RX changes through RssiCore's real checksum, payload RAM,
#   application FIFO, and connection lifecycle with an independent wire peer.
# - DUT shape: Use the existing two-core integration wrapper, leaving its client
#   closed and driving the server's transport input from Python. A second case
#   connects the real client/server pair and checks negotiation without draining
#   either application output.
# - Stimulus: Negotiate SYN/SYN+ACK/ACK, send DATA+BUSY, duplicate DATA and sequence
#   wrap, then close with unread payload and reopen with a different initial SEQ.
# - Checks: Compare every delivered data word and framing field. No pre-test or
#   post-reopen output drain is allowed: any unexpected payload is a failure.
# - Timing: Real checksum bytes, ready/valid transport handshakes, bounded waits,
#   and small windows. Timeout periods allow the directed peer to finish its work.

import cocotb

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.test_RssiCore import TB
from tests.protocols.rssi.rssi_test_utils import (
    RssiParams, build_syn_header, build_ack_header, build_data_header,
    stream_words_from_header, protocol_bytes_from_stream_word, parse_header,
)
from tests.protocols.ssi.ssi_test_utils import SsiBeat, send_contiguous_frame, recv_frame_and_check


async def send_header(tb, header):
    words = stream_words_from_header(header)
    await send_contiguous_frame(tb.srv_tsp_input, [
        SsiBeat(data=word, keep=0xFF, sof=int(i == 0), last=int(i == len(words) - 1))
        for i, word in enumerate(words)
    ], clk=tb.clk)


async def open_server(tb, sequence):
    params = RssiParams(max_outs_seg=4, max_seg_size=32, retrans_tout=256,
                        cumul_ack_tout=4, null_seg_tout=1024, max_retrans=2,
                        max_cum_ack=2, timeout_unit=6)
    response = cocotb.start_soon(tb.recv_transport_frame(
        tb.srv_tsp_output, match=lambda header, beats: header.syn and header.ack))
    tb.dut.srvMTspTReady.value = 1
    await send_header(tb, build_syn_header(sequence=sequence, acknowledge=0, params=params))
    beats = await response
    header = parse_header(b"".join(protocol_bytes_from_stream_word(beat.data) for beat in beats))
    assert header.acknowledge == sequence
    await send_header(tb, build_ack_header(sequence=(sequence + 1) & 0xFF,
                                          acknowledge=header.sequence))
    for _ in range(64):
        await tb.cycle()
        if int(tb.dut.srvConnected_o.value):
            return header.sequence
    raise AssertionError("Server did not open after valid peer handshake")


async def send_data(tb, sequence, ack, payload, *, busy=False):
    header = stream_words_from_header(build_data_header(
        sequence=sequence, acknowledge=ack, busy=busy))[0]
    await send_contiguous_frame(tb.srv_tsp_input, [
        SsiBeat(data=header, keep=0xFF, sof=1, last=0),
        *[SsiBeat(data=word, keep=0x1F if i == len(payload) - 1 else 0xFF,
                  sof=0, last=int(i == len(payload) - 1))
          for i, word in enumerate(payload)],
    ], clk=tb.clk)


async def receive_data(tb, payload):
    await recv_frame_and_check(
        tb.srv_sink, clk=tb.clk, ready_signal=tb.dut.srvMAppTReady,
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(word, 0x1F if i == len(payload) - 1 else 0xFF,
                   int(i == len(payload) - 1), int(i == 0), 0)
                  for i, word in enumerate(payload)], timeout_cycles=256,
    )


@cocotb.test()
async def wire_peer_busy_duplicate_wrap_and_reopen_test(dut):
    tb = await TB.create(dut, start_loopbacks=False, direct_client_open=0)
    ack = await open_server(tb, 0xFE)
    await tb.assert_no_app_output(tb.srv_sink, cycles=16)
    first = [0x1111222233334444, 0x5555666677778888, 0x9999AAAABBBBCCCC]
    await send_data(tb, 0xFF, ack, first, busy=True)
    await receive_data(tb, first)
    await send_data(tb, 0xFF, ack, [0xBAD], busy=True)
    await tb.assert_no_app_output(tb.srv_sink, cycles=24)
    await send_data(tb, 0, ack, [0x123456789ABCDEF0])
    await receive_data(tb, [0x123456789ABCDEF0])

    # Leave a complete old frame unread in the real application FIFO.
    await send_data(tb, 1, ack, [0xDEADDEADDEADDEAD])
    for _ in range(64):
        await tb.cycle()
        if int(dut.srvMAppTValid.value):
            break
    assert int(dut.srvMAppTValid.value)
    dut.srvOpen_i.value = 0
    await tb.pulse("srvClose_i")
    for _ in range(64):
        await tb.cycle()
        if not int(dut.srvConnected_o.value):
            break
    assert not int(dut.srvConnected_o.value)
    await tb.cycle(16)
    dut.srvOpen_i.value = 1
    ack = await open_server(tb, 0x40)
    dut.srvMAppTReady.value = 1
    await tb.assert_no_app_output(tb.srv_sink, cycles=24)
    dut.srvMAppTReady.value = 0
    await send_data(tb, 0x41, ack, [0xCAFEBABE12345678])
    await receive_data(tb, [0xCAFEBABE12345678])


@cocotb.test()
async def core_pair_negotiates_without_application_output_test(dut):
    tb = await TB.create(dut)
    await tb.wait_connected()
    assert int(dut.cltMaxSegSize_o.value) == 32
    assert int(dut.srvMaxSegSize_o.value) == 32
    await tb.assert_no_app_output(tb.clt_sink, cycles=16)
    await tb.assert_no_app_output(tb.srv_sink, cycles=16)


def test_RssiCoreRx():
    parameters = {"RETRANS_TOUT_G": 256, "NULL_TOUT_G": 1024}
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.rssicoreintegrationwrapper",
        parameters=parameters, extra_env=parameters, force_compile=True,
    )
