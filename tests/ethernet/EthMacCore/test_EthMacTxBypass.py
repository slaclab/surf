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
# - Sweep: Exercise both `BYP_EN_G=true` and `BYP_EN_G=false`.
# - Stimulus: Start primary and bypass traffic together to test selection from
#   idle, then launch a bypass frame while a primary frame is already active.
# - Checks: With bypass enabled the bypass frame must win arbitration at idle
#   but must not preempt an already-active primary frame; with bypass disabled
#   the primary path must pass through unchanged and bypass traffic must be
#   dropped.
# - Timing: The bench uses real ready/valid handshakes on both sources so the
#   mux arbitration is checked under the DUT's own acceptance rules.

from __future__ import annotations

import cocotb
import os
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    assert_beat_list,
    build_ethernet_frame,
    cycle,
    expect_no_output,
    frame_beats_from_bytes,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxBypassWrapper.vhd"


@cocotb.test()
async def eth_mac_tx_bypass_arbitration_test(dut):
    bypass_enabled = os.environ["BYP_EN_G"].lower() == "true"
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix=None,
        initial_values={
            "mAxisTReady": 0,
        },
    )
    prim_source = FlatEmacEndpoint(dut, prefix="sPrim")
    byp_source = FlatEmacEndpoint(dut, prefix="sByp")
    sink = FlatEmacEndpoint(dut, prefix="mAxis")
    prim_source.set_idle()
    byp_source.set_idle()

    primary_frame = build_ethernet_frame(
        dst_mac=0x010203040506,
        src_mac=0x111213141516,
        eth_type=0x88B5,
        payload=b"tx-bypass-primary-idle" + bytes(range(28)),
    )
    bypass_frame = build_ethernet_frame(
        dst_mac=0x212223242526,
        src_mac=0x313233343536,
        eth_type=0x9000,
        payload=b"tx-bypass-wins-idle" + bytes(range(29)),
    )
    primary_expected = frame_beats_from_bytes(primary_frame, dest=0x31)
    bypass_expected = frame_beats_from_bytes(bypass_frame, dest=0x72, eofe=1)

    primary_send = cocotb.start_soon(send_contiguous_frame(prim_source, primary_expected, clk=bench.clk))
    bypass_send = cocotb.start_soon(send_contiguous_frame(byp_source, bypass_expected, clk=bench.clk))
    first_observed = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=96)

    if bypass_enabled:
        assert_beat_list(first_observed, bypass_expected)
        second_observed = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=96)
        assert_beat_list(second_observed, primary_expected)
    else:
        assert_beat_list(first_observed, primary_expected)
        await expect_no_output(sink, clk=bench.clk, cycles=8)

    await primary_send
    await bypass_send

    long_primary = build_ethernet_frame(
        dst_mac=0x414243444546,
        src_mac=0x515253545556,
        eth_type=0x88B5,
        payload=bytes(range(80)),
    )
    late_bypass = build_ethernet_frame(
        dst_mac=0x616263646566,
        src_mac=0x717273747576,
        eth_type=0x9000,
        payload=b"late-bypass-frame" + bytes(range(24)),
    )
    long_primary_expected = frame_beats_from_bytes(long_primary, dest=0x44)
    late_bypass_expected = frame_beats_from_bytes(late_bypass, dest=0x55)

    long_primary_send = cocotb.start_soon(send_contiguous_frame(prim_source, long_primary_expected, clk=bench.clk))
    await cycle(bench.clk, 2)
    late_bypass_send = cocotb.start_soon(send_contiguous_frame(byp_source, late_bypass_expected, clk=bench.clk))
    first_sequence = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=128)
    assert_beat_list(first_sequence, long_primary_expected)

    if bypass_enabled:
        second_sequence = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=96)
        assert_beat_list(second_sequence, late_bypass_expected)
    else:
        await expect_no_output(sink, clk=bench.clk, cycles=8)

    await long_primary_send
    await late_bypass_send


PARAMETER_SWEEP = [
    parameter_case("bypass_enabled", BYP_EN_G=True),
    parameter_case("bypass_disabled", BYP_EN_G=False),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTxBypass(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxbypasswrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
