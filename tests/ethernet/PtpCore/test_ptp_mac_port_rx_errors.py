#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: production timing-port composition, GMII/XGMII, checksum checks on.
# - Stimulus: valid IPv4/UDP frames with a corrupted Ethernet FCS between two
#   good frames, while the controller stalls the first frame. Repeat beyond
#   the token-table depth to exercise reuse. Frame bytes/FCS come from Python.
# - Checks: only the two good frames and their own captures reach the controller;
#   each bad frame releases/counts once despite the legacy RX checksum stage's
#   EOFE overwrite. Completion is established by the public retirement counters.
# - Timing: the shared port fixture owns clocks, PHC and physical stimulus;
#   all waits for the expected public state are bounded.

import os

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES, build_ipv4_udp_frame
from tests.ethernet.PtpCore.ptp_mac_port_test_utils import PortBench, fcs


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def bad_fcs_with_checksums(dut):
    bench = PortBench(dut, phy=os.environ["PHY_TYPE_G"])
    await bench.start()
    expected = []
    for batch in range(6):
        frames = [build_ipv4_udp_frame(
            dst_mac=0x001122334455, src_mac=0x660102030405,
            src_ip="192.168.1.10", dst_ip="192.168.1.20", src_port=1234, dst_port=5678,
            payload=bytes([3 * batch + index]) * length,
        ) for index, length in enumerate((36, 60, 76))]
        dut.mAxisTReady.value = 0
        await bench.inject(frames[0])
        await bench.wait_for(lambda: int(dut.mAxisTValid.value), what="stalled good frame")
        crc = fcs(frames[1])
        await bench.inject(frames[1], fcs_bytes=bytes([crc[0] ^ 1]) + crc[1:])
        await bench.inject(frames[2])
        dut.mAxisTReady.value = 1
        await bench.wait_for(
            lambda: bench.counters()["rxDelivered"] + bench.counters()["rxDropped"] == 3 * (batch + 1),
            what="all three RX owners retired",
        )
        expected.extend((frames[0], frames[2]))
        assert [frame["data"] for frame in bench.obs.rx_frames] == expected, "bad-FCS frame escaped the timing port"
        assert bench.counters()["rxDelivered"] == 2 * (batch + 1)
        assert bench.counters()["rxDropped"] == batch + 1
        assert int(dut.faults.value) == 0
    captures = {capture.ticks: capture for _, capture in bench.obs.rx_oracle}
    for frame in bench.obs.rx_frames:
        assert frame["meta"].capture == captures[frame["meta"].capture.ticks]
        assert frame["eofe"] == 0 and frame["tids"] == {0}


@pytest.mark.parametrize("phy", ["GMII", "XGMII"])
def test_ptp_mac_port_rx_errors(phy):
    parameters = {"PHY_TYPE_G": phy, "CSUM_EN_G": True}
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.PtpMacPortEthMacWrapper",
        parameters=parameters, extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES +
                            ["ethernet/PtpCore/wrappers/PtpMacPortEthMacWrapper.vhd"]},
    )
