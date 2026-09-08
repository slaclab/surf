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
# - Sweep: Real XGMII MAC CRC rejection, 512-word FIFO loss, and independent
#   frontend/bypass consumers, with both legal start lanes and identical keys.
# - Stimulus: Original adversarial loss patterns feed the MAC and actual RX RTL
#   simultaneously; PHY-edge PHC inputs come from independent simulator time.
# - Checks: Each admitted RX record has its own wire capture and body; MAC loss
#   cannot remove or retime it. Frontend overflow/flush cannot revive MAC data.
# - Timing: Pre-edge handshake observation includes rxAbort. No production PHC,
#   protocol policy, TX completion implementation, or CDC claim is made here.

from fractions import Fraction

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb.utils import get_sim_time

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES, ROCE_ANALYSIS_SOURCES
from tests.ethernet.PtpCore.ptp_wire_utils import MacBench
from tests.ethernet.PtpCore.ptp_rx_test_utils import frame, unpack_time


@cocotb.test(timeout_time=100, timeout_unit="us")
async def atomic_rx_beside_real_mac(dut):
    bench = MacBench(dut)
    await bench.start()
    records = []
    aborts = []

    async def drive_time():
        tick = 0
        while True:
            await FallingEdge(dut.ethClk)
            # The following rising edge is exactly 3.2 ns later.
            now = Fraction(int(get_sim_time(unit="fs")) + 3_200_000, 1_000_000)
            q32 = int(now * (1 << 32))
            dut.ptpSeconds.value = 100
            dut.ptpNanoseconds.value = q32 >> 32
            dut.ptpFraction.value = q32 & 0xffffffff
            dut.ptpTicks.value = tick
            tick += 1

    async def observe():
        while True:
            await RisingEdge(dut.ethClk)
            if int(dut.ptpAbort.value):
                aborts.append(bench.cycles)
            elif int(dut.ptpValid.value) and int(dut.ptpReady.value):
                value = int(dut.ptpMessage.value)
                timestamp = unpack_time(value >> 648)
                body = (value & ((1 << 240)-1)).to_bytes(30, "big")
                records.append((timestamp, int.from_bytes(body[:10], "big")))

    time_task = cocotb.start_soon(drive_time())
    monitor_task = cocotb.start_soon(observe())
    await bench.wait(4)
    await bench.send(frame(marker=1), corrupt_crc=True)
    await bench.wait(40)
    assert not records
    await bench.send(frame(marker=2), lane=4)
    await bench.until(lambda: len(records) == 1)
    assert records[0][1] == 2
    expected = 100_000_000_000 + bench.rx_wire.frames[-1].capture.timestamp
    assert abs(records[0][0] - expected) <= Fraction(1, 65536)
    assert bench.pulses["rxCrcErrorCnt"]

    # Stop only the MAC bypass consumer. The passive validator continues to
    # receive every valid frame with no dependence on the full MAC FIFO.
    dut.mBypTReady.value = 0
    before = len(records)
    wire_start = len(bench.rx_wire.frames)
    for index in range(240):
        await bench.send(frame(marker=index+100), lane=4*(index % 2))
    await bench.wait(40)
    assert len(records) == before+240
    assert bench.pulses["rxFifoDrop"] and int(dut.ptpOverflow.value) == 0
    for index, (timestamp, marker) in enumerate(records[before:]):
        assert marker == index+100
        expected = 100_000_000_000 + bench.rx_wire.frames[wire_start+index].capture.timestamp
        assert abs(timestamp-expected) <= Fraction(1, 65536)

    # Keep the old MAC head stalled across a frontend restart. Only the fresh
    # frame may supply the next decoded message/capture pair.
    dut.ptpReady.value = 0
    await bench.send(frame(marker=900))
    await bench.until(lambda: int(dut.ptpValid.value) == 1)
    dut.ptpFlush.value = 1
    await bench.wait(2)
    dut.ptpFlush.value = 0
    dut.ptpReady.value = 1
    before = len(records)
    await bench.send(frame(marker=901), lane=4)
    await bench.until(lambda: len(records) == before+1)
    assert records[-1][1] == 901 and aborts
    dut.mBypTReady.value = 1
    await bench.wait(2400)
    assert len(bench.frames["mByp"]) < len(records)
    assert len(records) == before+1  # Draining the MAC cannot publish old PTP.

    # Independently overflow the four-entry frontend queue and recover.
    dut.ptpReady.value = 0
    for index in range(5):
        await bench.send(frame(marker=950+index))
    await bench.wait(10)
    assert int(dut.ptpOverflow.value) == 1 and not int(dut.ptpValid.value)
    dut.ptpReady.value = 1
    await bench.send(frame(marker=999))
    await bench.until(lambda: records[-1][1] == 999)
    dut._log.info("ATOMIC RX: all 240 records retained under real MAC FIFO loss; CRC alias, retained-head restart, and frontend overflow passed")
    time_task.cancel()
    monitor_task.cancel()


def test_ptp_rx_mac():
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.ethmacptpexperimentwrapper",
        parameters={"PTP_RX_EN_G": True, "FIFO_ADDR_WIDTH_G": 9},
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + ROCE_ANALYSIS_SOURCES +
                            ["ethernet/EthMacCore/wrappers/EthMacPtpExperimentWrapper.vhd"]},
    )
