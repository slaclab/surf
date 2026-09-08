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
# - Sweep: XGMII starts on lanes 0/4, CRC loss, RX FIFO overflow, primary/bypass
#   routing, independent consumers, and repeated received pause.
# - Stimulus: Inject real wire frames into unchanged EthMacTop. A Python passive
#   observer supplies timestamps; model event delivery is independently stalled.
# - Checks: Demonstrate the rejected header-key rule pairing a surviving copy
#   with a dropped copy's timestamp; record actual MAC drops and late TX.
# - Timing: 156.25 MHz; monitors sample accepted AXI transfers before TPD updates.
#   Every stimulus wait is bounded. No production PTP RTL is claimed by this test.

import cocotb
from dataclasses import replace
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES, ROCE_ANALYSIS_SOURCES, build_pause_frame,
    frame_beats_from_bytes, send_contiguous_frame,
)
from tests.ethernet.PtpCore.ptp_reference import KeyedJoin, RequestLedger
from tests.ethernet.PtpCore.ptp_wire_utils import MacBench, ptp_frame, ptp_key

WRAPPER = "ethernet/EthMacCore/wrappers/EthMacPtpExperimentWrapper.vhd"


@cocotb.test(timeout_time=100, timeout_unit="us")
async def crc_drop_duplicate_and_byte_order(dut):
    bench = MacBench(dut)
    await bench.start()
    wrong = ptp_frame(ethertype=b"\xf7\x88")
    await bench.send(wrong, lane=4)
    await bench.until(lambda: len(bench.frames["mAxis"]) == 1)
    assert bench.frames["mAxis"] == [wrong] and not bench.frames["mByp"]

    # Frame A leaves a physical timestamp but no MAC-delivered PTP packet.
    frame = ptp_frame(sequence=42)
    await bench.send(frame, corrupt_crc=True)
    await bench.wait(150)
    assert bench.pulses["rxCrcErrorCnt"] and not bench.frames["mByp"]
    capture_a = bench.rx_wire.frames[-1].capture
    keyed = KeyedJoin()
    # A header/coding tap has no CRC result. Do not pass oracle knowledge into it.
    keyed.event(replace(capture_a, valid=True))

    # Hold the packet consumer independently, then release B before delivering B's event.
    dut.mBypTReady.value = 0
    await bench.send(frame, lane=4)
    await bench.wait(150)
    assert not bench.frames["mByp"]
    dut.mBypTReady.value = 1
    await bench.until(lambda: len(bench.frames["mByp"]) == 1)
    capture_b = bench.rx_wire.frames[-1].capture
    assert capture_b.valid and bench.frames["mByp"] == [frame]
    keyed.frame(ptp_key(bench.frames["mByp"][0]), capture_b.wire_id)
    chosen, actual_id = keyed.match(capture_b.key)
    assert chosen.wire_id != actual_id
    assert chosen.timestamp < capture_b.timestamp
    dut._log.info("COUNTEREXAMPLE CRC: selected wire %d for wire %d; timestamp error %s ns; FIFO-drop pulses=%d",
                  chosen.wire_id, actual_id, chosen.timestamp - capture_b.timestamp, len(bench.pulses["rxFifoDrop"]))


@cocotb.test(timeout_time=100, timeout_unit="us")
async def fifo_drop_and_identical_retry(dut):
    bench = MacBench(dut)
    await bench.start()
    dut.mBypTReady.value = 0
    # Fill the real 512-word RX FIFO. These valid same-key packets are legal
    # Ethernet; losses result from downstream pressure, not injected drop flags.
    frame = ptp_frame(sequence=99)
    for index in range(240):
        await bench.send(frame, lane=4 if index % 2 else 0)
        if index == 0:
            await bench.until(lambda: int(dut.mBypTValid.value) == 1)
    await bench.wait(150)
    assert bench.pulses["rxOverFlow"] or bench.pulses["rxFifoDrop"]
    assert all(item.capture.valid for item in bench.rx_wire.frames)
    dut.mBypTReady.value = 1
    await bench.wait(2500)
    delivered = len(bench.frames["mByp"])
    assert 0 < delivered < 240
    assert all(packet == frame for packet in bench.frames["mByp"])
    # Flushing only timestamp associations is also unsafe: the old frame at
    # the stopped RX FIFO head remains. A fresh same-key capture can pair with
    # that old frame after the timestamp side restarts, reversing the CRC case.
    restarted_join = KeyedJoin()
    restarted_join.event(bench.rx_wire.frames[-1].capture)
    restarted_join.frame(ptp_key(bench.frames["mByp"][0]), 0)
    chosen, actual_id = restarted_join.match(ptp_key(frame))
    assert chosen.wire_id != actual_id
    # Timestamp and frame streams now have different cardinalities. Even if
    # all live duplicates are discarded, a header key cannot identify the loss.
    assert len(bench.rx_wire.frames) == 240
    await bench.send(ptp_frame(sequence=100), lane=4)
    await bench.until(lambda: len(bench.frames["mByp"]) == delivered + 1)
    assert ptp_key(bench.frames["mByp"][-1])[-1] == 100
    dut._log.info("FIFO LOSS: %d captures, %d delivered duplicates, %d drop pulses; fresh-key recovery passed",
                  240, delivered, len(bench.pulses["rxFifoDrop"]))
    dut._log.info("COUNTEREXAMPLE FLUSH: new capture %d matched retained FIFO-head frame %d", chosen.wire_id, actual_id)


@cocotb.test(timeout_time=100, timeout_unit="us")
async def paused_request_survives_logical_restart(dut):
    bench = MacBench(dut)
    await bench.start()
    dut._log.info("TX lifecycle: reset complete")
    dut.pauseEnable.value = 1
    await bench.send(build_pause_frame(30))
    await bench.until(lambda: len(bench.pulses["rxPauseCnt"]) > 0)
    dut._log.info("TX lifecycle: pause received")
    await bench.wait(30)
    ledger = RequestLedger(lifetime=100)
    seq = ledger.allocate(bench.cycles)
    request = ptp_frame(sequence=seq, message_type=1)[:58]
    await with_timeout(send_contiguous_frame(bench.source, frame_beats_from_bytes(request), clk=dut.ethClk), 10, "us")
    dut._log.info("TX lifecycle: request accepted by MAC")
    assert not bench.tx_wire.frames
    # A protocol restart is software/model state only; resetting the MAC would
    # destroy primary traffic and would not test the proposed partition.
    ledger.restart()
    for _ in range(3):
        await bench.wait(30)
        await bench.send(build_pause_frame(30))
        assert not bench.tx_wire.frames
    await bench.until(lambda: bool(bench.tx_wire.frames), cycles=600)
    sent = bench.tx_wire.frames[0]
    assert sent.frame == request + bytes(2) and sent.capture.valid
    assert not ledger.wire(seq, bench.cycles)
    assert not ledger.response(seq, bench.cycles + 1)
    dut._log.info("LATE TX: retired request %d reached wire after logical restart and repeated pause", seq)


def test_ptp_mac_association():
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ethmacptpexperimentwrapper",
                       parameters={"PAUSE_EN_G": True, "FIFO_ADDR_WIDTH_G": 9},
                       extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + ROCE_ANALYSIS_SOURCES + [WRAPPER]})
