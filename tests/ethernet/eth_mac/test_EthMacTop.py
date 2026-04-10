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
# - Sweep: Keep one XGMII top-level loopback case with filtering and pause
#   features disabled so the first bench proves the primary data path cleanly.
# - Stimulus: Send one minimum-size Ethernet frame into the flattened primary
#   AXIS input of the checked-in loopback wrapper.
# - Checks: The primary output frame must match the original bytes, both TX and
#   RX packet counter pulses must assert, and the looped packet must not report
#   a CRC error status pulse.
# - Timing: The wrapper ties the MAC's XGMII TX and RX sides together
#   internally, so the bench waits on the real top-level AXIS output rather
#   than assuming a fixed import/export/FIFO latency.

import cocotb
import pytest
from pathlib import Path

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.eth_mac.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
    wait_signal_pulse,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTopLoopbackWrapper.vhd"
ROCE_RTL_ROOT = Path(__file__).resolve().parents[3] / "ethernet" / "RoCEv2" / "rtl"
ROCE_ANALYSIS_SOURCES = [
    str(ROCE_RTL_ROOT / "RocePkg.vhd"),
    *(
        str(path)
        for path in sorted(ROCE_RTL_ROOT.glob("*.vhd"))
        if path.name != "RocePkg.vhd"
    ),
]


@cocotb.test()
async def eth_mac_top_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "phyReady": 1,
            "mAxisTReady": 0,
            "localMac": 0x001122334455,
            "filtEnable": 0,
            "pauseEnable": 0,
            "pauseTime": 0x0020,
            "pauseThresh": 0x0008,
            "ipCsumEn": 0,
            "tcpCsumEn": 0,
            "udpCsumEn": 0,
            "dropOnPause": 0,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    frame = build_ethernet_frame(
        dst_mac=0x5A0102030405,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        payload=bytes(range(46)),
    )
    tx_pulse = cocotb.start_soon(wait_signal_pulse(dut.txCountEn, clk=bench.clk))
    rx_pulse = cocotb.start_soon(wait_signal_pulse(dut.rxCountEn, clk=bench.clk))
    send_task = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(frame), clk=bench.clk)
    )
    observed_beats = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=256)
    await send_task
    await tx_pulse
    await rx_pulse

    assert payload_from_beats(observed_beats) == frame
    assert int(dut.rxCrcErrorCnt.value) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="xgmii_top_loopback")])
def test_EthMacTop(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactoploopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        # `EthMacTx` and `EthMacRx` reference the RoCE helper entities during
        # analysis even when `ROCEV2_EN_G` is disabled in the loopback wrapper.
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + ROCE_ANALYSIS_SOURCES + [WRAPPER_PATH]},
    )
