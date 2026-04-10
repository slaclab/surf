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
# - Sweep: Keep one XGMII loopback case so the test proves the import path
#   using the most direct checked-in wrapper arrangement.
# - Stimulus: Send one minimum-size Ethernet frame through the shared
#   export-to-import loopback wrapper.
# - Checks: The recovered AXIS frame must match the original bytes and the RX
#   packet counter pulse must assert without any CRC error pulse.
# - Timing: The wrapper loops the PHY-coded stream internally, so the bench
#   launches one contiguous AXIS frame and samples the recovered output frame.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
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


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacImportExportLoopbackWrapper.vhd"


@cocotb.test()
async def eth_mac_rx_import_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "ethClkEn": 1,
            "phyReady": 1,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    frame = build_ethernet_frame(
        dst_mac=0x020304050607,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=bytes(range(46)),
    )
    rx_pulse = cocotb.start_soon(wait_signal_pulse(dut.rxCountEn, clk=bench.clk))
    send_task = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(frame), clk=bench.clk)
    )
    observed_beats = await recv_frame(sink, clk=bench.clk)
    await send_task
    await rx_pulse

    assert payload_from_beats(observed_beats) == frame
    assert int(dut.rxCrcError.value) == 0


PARAMETER_SWEEP = [
    parameter_case("xgmii_loopback", PHY_TYPE_G="XGMII"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacRxImport(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacimportexportloopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
