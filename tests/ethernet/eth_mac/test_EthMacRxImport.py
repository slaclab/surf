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
# - Sweep: Cover both supported functional PHY mappings in this wrapper,
#   `GMII` and `XGMII`, and include a link-not-ready interval in each run.
# - Stimulus: Send one minimum-size frame, one longer multi-beat frame, one
#   frame while `phyReady=0`, and then one recovery frame after re-enabling the
#   link.
# - Checks: Ready PHY modes must recover the original AXIS bytes and pulse
#   `rxCountEn`, the blocked frame must not appear while the link is down, and
#   the receiver must return to normal operation after `phyReady` is restored.
#   The recovery expectation is PHY-specific: GMII drops traffic presented
#   while the link is down, while the current XGMII loopback path presents that
#   queued frame once `phyReady` returns.
# - Timing: GMII takes many more cycles than XGMII to serialize a frame, so the
#   bench scales its receive timeout to the selected PHY mode.

import cocotb
import os
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.eth_mac.ethmac_test_utils import (
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
async def eth_mac_rx_import_test(dut):
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
        dst_mac=0x020304050607,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=bytes(range(46)),
    )
    min_pulse = cocotb.start_soon(wait_signal_pulse(dut.rxCountEn, clk=bench.clk, timeout_cycles=timeout_cycles))
    min_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(min_frame), clk=bench.clk)
    )
    min_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=timeout_cycles)
    await min_send
    await min_pulse
    assert payload_from_beats(min_observed) == min_frame
    assert int(dut.rxCrcError.value) == 0

    # Drive a second, longer frame so the import path is checked across a
    # multi-beat packet instead of only a minimum-sized transfer.
    long_frame = build_ethernet_frame(
        dst_mac=0x111213141516,
        src_mac=0x212223242526,
        eth_type=0x88B5,
        payload=bytes(range(96)),
    )
    long_pulse = cocotb.start_soon(wait_signal_pulse(dut.rxCountEn, clk=bench.clk, timeout_cycles=timeout_cycles))
    long_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(long_frame), clk=bench.clk)
    )
    long_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=timeout_cycles)
    await long_send
    await long_pulse
    assert payload_from_beats(long_observed) == long_frame
    assert int(dut.rxCrcError.value) == 0

    # A deasserted PHY-ready input resets the import logic, so traffic that
    # arrives in that interval must not leak partial output while the link is
    # down. The current XGMII path replays the blocked frame after recovery,
    # whereas the GMII path discards it.
    dut.phyReady.value = 0
    blocked_frame = build_ethernet_frame(
        dst_mac=0x313233343536,
        src_mac=0x414243444546,
        eth_type=0x9000,
        payload=bytes(range(32)),
    )
    blocked_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(blocked_frame), clk=bench.clk)
    )
    await blocked_send
    await expect_no_output(sink, clk=bench.clk, cycles=(24 if phy_type == "XGMII" else 128))

    dut.phyReady.value = 1
    await cycle(bench.clk, 4)

    recovery_frame = build_ethernet_frame(
        dst_mac=0x515253545556,
        src_mac=0x616263646566,
        eth_type=0x88B5,
        payload=b"link-recovery-frame" + bytes(27),
    )
    recovery_pulse = cocotb.start_soon(wait_signal_pulse(dut.rxCountEn, clk=bench.clk, timeout_cycles=timeout_cycles))
    recovery_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(recovery_frame), clk=bench.clk)
    )
    recovery_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=timeout_cycles)
    await recovery_send
    await recovery_pulse

    if phy_type == "XGMII":
        # The XGMII export/import loopback retains the blocked frame across the
        # ready transition, so the first recovered packet is the stalled one.
        # Because that packet traverses the TX path, it comes back padded to
        # Ethernet's minimum 60-byte frame size.
        assert payload_from_beats(recovery_observed) == pad_ethernet_frame_to_min_size(blocked_frame)
        drained_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=timeout_cycles)
        assert payload_from_beats(drained_observed) == recovery_frame
    else:
        # The GMII path drops the blocked frame entirely, so the next output is
        # the fresh recovery packet.
        assert payload_from_beats(recovery_observed) == recovery_frame

    assert int(dut.rxCrcError.value) == 0


PARAMETER_SWEEP = [
    parameter_case("xgmii_loopback", PHY_TYPE_G="XGMII"),
    parameter_case("gmii_loopback", PHY_TYPE_G="GMII"),
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
