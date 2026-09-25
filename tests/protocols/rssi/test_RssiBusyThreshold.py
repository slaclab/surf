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
# - Purpose: Characterize RX delivery pause versus advertised BUSY with the
#   Warm-TDM 1024-byte segment storage geometry. This records current behavior,
#   not a passing assertion that backpressure is handled correctly.
# - DUT: Production RssiCore, inferred RAM/FIFOs, independent Python wire peer.
# - Stimulus: Four 256-byte-class segments with application delivery stalled,
#   followed by release of the sink. Timers are accelerated; Ethernet, the
#   packetizer and SRP are outside this test boundary.
# - Checks: Observe cumulative ACK and BUSY on accepted transport headers;
#   verify exact payload/framing after releasing the sink. No output is drained
#   or discarded. Every finite monitor is awaited.

import cocotb
from cocotb.triggers import FallingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.test_RssiCore import TB
from tests.protocols.rssi.test_RssiCoreRx import send_header, send_data, receive_data
from tests.protocols.rssi.rssi_test_utils import (
    RssiParams, build_syn_header, build_ack_header, parse_header,
    protocol_bytes_from_stream_word,
)


@cocotb.test(timeout_time=100, timeout_unit="us")
async def stalled_rx_ack_without_busy_characterization(dut):
    tb = await TB.create(dut, start_loopbacks=False, direct_client_open=0)
    params = RssiParams(max_outs_seg=8, max_seg_size=1024, retrans_tout=256,
                        cumul_ack_tout=4, null_seg_tout=10000, max_retrans=16,
                        max_cum_ack=2, timeout_unit=6)
    response = cocotb.start_soon(tb.recv_transport_frame(
        tb.srv_tsp_output, match=lambda header, beats: header.syn and header.ack))
    dut.srvMTspTReady.value = 1
    await send_header(tb, build_syn_header(sequence=0x40, acknowledge=0, params=params))
    beats = await response
    syn = parse_header(b"".join(protocol_bytes_from_stream_word(b.data) for b in beats))
    await send_header(tb, build_ack_header(sequence=0x41, acknowledge=syn.sequence))
    await tb.cycle(32)
    assert int(dut.srvConnected_o.value)

    headers = []

    async def monitor():
        for _ in range(1800):
            await FallingEdge(tb.clk)
            await Timer(1, unit="ns")
            if int(dut.srvMTspTValid.value) and int(dut.srvMTspTReady.value):
                beat = tb.srv_tsp_output.snapshot()
                if beat.sof:
                    headers.append(parse_header(protocol_bytes_from_stream_word(beat.data)))

    monitor_task = cocotb.start_soon(monitor())
    payloads = [[(seq << 32) | word for word in range(32)] for seq in range(0x41, 0x45)]
    for seq, payload in zip(range(0x41, 0x45), payloads):
        await send_data(tb, seq, syn.sequence, payload)
    await tb.cycle(256)
    stalled = list(headers)
    assert int(dut.srvMAppTValid.value), "No application payload reached the stalled sink"
    assert stalled, "No transport ACKs observed"
    assert max(h.acknowledge for h in stalled) == 0x43, "Expected final segment ACK to stall"
    assert not any(h.busy for h in stalled), "Characterized missing-BUSY behavior changed"
    assert not (int(dut.srvStatusReg_o.value) & (1 << 7)), "Local BUSY was asserted"
    dut._log.info("STALLED: ACK=0x43, pending segment=0x44, wire BUSY=0, local BUSY=0")

    for payload in payloads:
        await receive_data(tb, payload)
    await tb.cycle(32)
    await monitor_task
    assert any(h.acknowledge == 0x44 for h in headers), "ACK failed to advance after release"
    assert int(dut.srvConnected_o.value)
    dut._log.info("RELEASED: all four payloads intact, ACK=0x44, connection still open")


def test_RssiBusyThreshold():
    parameters = dict(WINDOW_ADDR_SIZE_G=3, SEGMENT_ADDR_SIZE_G=7,
                      MAX_NUM_OUTS_SEG_G=8, MAX_SEG_SIZE_G=1024,
                      RETRANS_TOUT_G=256, NULL_TOUT_G=10000, MAX_RETRANS_CNT_G=16)
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.rssicoreintegrationwrapper",
                       parameters=parameters, extra_env=parameters)
