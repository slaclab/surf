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
# - Sweep: Cover both supported functional PHY mappings, `GMII` and `XGMII`,
#   and explicitly exercise the exporter with `phyReady` both high and low.
# - Stimulus: Send one minimum-size frame, one longer multi-beat frame, one
#   frame while the link is marked not ready, and then one recovery frame after
#   the link returns.
# - Checks: Successful transmissions must pulse `txCountEn`, the blocked frame
#   must raise `txLinkNotReady` without producing output data while the link is
#   down, and normal export behavior must recover cleanly after the ready
#   signal is restored. The recovery expectation is PHY-specific because the
#   current XGMII path drains the blocked frame after the link returns, while
#   the GMII path drops it.
# - Timing: The receive timeout is scaled to the chosen PHY because the GMII
#   path serializes one byte per clock while XGMII transmits eight.

import cocotb
import os
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    cycle,
    expect_no_output,
    frame_beats_from_bytes,
    pad_ethernet_frame_to_min_size,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
    wait_signal_pulse,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacImportExportLoopbackWrapper.vhd"


@cocotb.test()
async def eth_mac_tx_export_test(dut):
    phy_type = os.environ["PHY_TYPE_G"]
    timeout_cycles = 512 if phy_type == "XGMII" else 4096

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

    min_frame = build_ethernet_frame(
        dst_mac=0x0C0D0E0F1011,
        src_mac=0x121314151617,
        eth_type=0x9000,
        payload=bytes(range(46)),
    )
    min_pulse = cocotb.start_soon(wait_signal_pulse(dut.txCountEn, clk=bench.clk, timeout_cycles=timeout_cycles))
    min_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(min_frame), clk=bench.clk)
    )
    min_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=timeout_cycles)
    await min_send
    await min_pulse

    assert payload_from_beats(min_observed) == min_frame
    assert int(dut.txUnderRun.value) == 0
    assert int(dut.txLinkNotReady.value) == 0

    long_frame = build_ethernet_frame(
        dst_mac=0x202122232425,
        src_mac=0x303132333435,
        eth_type=0x88B5,
        payload=bytes(range(96)),
    )
    long_pulse = cocotb.start_soon(wait_signal_pulse(dut.txCountEn, clk=bench.clk, timeout_cycles=timeout_cycles))
    long_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(long_frame), clk=bench.clk)
    )
    long_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=timeout_cycles)
    await long_send
    await long_pulse
    assert payload_from_beats(long_observed) == long_frame
    assert int(dut.txUnderRun.value) == 0

    # When the PHY is not ready, the exporter must flag the condition and avoid
    # emitting partial output while the link is down. The exact post-recovery
    # behavior is PHY-specific and is checked below.
    dut.phyReady.value = 0
    blocked_frame = build_ethernet_frame(
        dst_mac=0x404142434445,
        src_mac=0x505152535455,
        eth_type=0x9000,
        payload=bytes(range(32)),
    )
    blocked_pulse = cocotb.start_soon(wait_signal_pulse(dut.txLinkNotReady, clk=bench.clk, timeout_cycles=timeout_cycles))
    blocked_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(blocked_frame), clk=bench.clk)
    )
    await blocked_send
    await blocked_pulse
    await expect_no_output(sink, clk=bench.clk, cycles=(24 if phy_type == "XGMII" else 128))
    assert int(dut.txUnderRun.value) == 0

    dut.phyReady.value = 1
    await cycle(bench.clk, 4)

    recovery_frame = build_ethernet_frame(
        dst_mac=0x606162636465,
        src_mac=0x707172737475,
        eth_type=0x88B5,
        payload=b"post-link-recovery" + bytes(28),
    )
    recovery_pulse = cocotb.start_soon(wait_signal_pulse(dut.txCountEn, clk=bench.clk, timeout_cycles=timeout_cycles))
    recovery_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(recovery_frame), clk=bench.clk)
    )
    recovery_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=timeout_cycles)
    await recovery_send
    await recovery_pulse

    if phy_type == "XGMII":
        # In the XGMII path the held-off frame drains first once the link
        # returns, so the recovery frame arrives second. The stalled frame is
        # padded by the TX path up to Ethernet's minimum non-FCS size.
        assert payload_from_beats(recovery_observed) == pad_ethernet_frame_to_min_size(blocked_frame)
        drained_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=timeout_cycles)
        assert payload_from_beats(drained_observed) == recovery_frame
    else:
        # GMII drops the frame that arrived while the link was down.
        assert payload_from_beats(recovery_observed) == recovery_frame

    assert int(dut.txUnderRun.value) == 0
    assert int(dut.txLinkNotReady.value) == 0


PARAMETER_SWEEP = [
    parameter_case("xgmii_loopback", PHY_TYPE_G="XGMII"),
    parameter_case("gmii_loopback", PHY_TYPE_G="GMII"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTxExport(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacimportexportloopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
