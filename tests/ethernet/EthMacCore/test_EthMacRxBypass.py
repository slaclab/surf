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
# - Stimulus: Send one multi-beat frame with the configured bypass EtherType
#   and one multi-beat frame with a normal EtherType.
# - Checks: When bypass is enabled the configured EtherType must route the
#   entire frame to the bypass output and all other traffic must stay on the
#   primary output; when bypass is disabled, even the bypass-tagged frame must
#   pass through the primary output while the bypass output stays idle.
# - Timing: The test waits on complete frames from each exposed output so the
#   route decision and frame-hold behavior are checked together.

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
    expect_no_output,
    frame_beats_from_bytes,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxBypassWrapper.vhd"


@cocotb.test()
async def eth_mac_rx_bypass_routing_test(dut):
    bypass_enabled = os.environ["BYP_EN_G"].lower() == "true"
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
    )
    source = bench.source
    assert source is not None

    prim_sink = FlatEmacEndpoint(dut, prefix="mPrim")
    byp_sink = FlatEmacEndpoint(dut, prefix="mByp")

    bypass_frame = build_ethernet_frame(
        dst_mac=0x101112131415,
        src_mac=0x202122232425,
        eth_type=0x9000,
        payload=bytes(range(48)),
    )
    bypass_expected = frame_beats_from_bytes(bypass_frame, dest=0x23, eofe=1)
    bypass_send = cocotb.start_soon(send_contiguous_frame(source, bypass_expected, clk=bench.clk))

    if bypass_enabled:
        bypass_observed = await recv_frame(byp_sink, clk=bench.clk, timeout_cycles=64)
        await bypass_send
        assert_beat_list(bypass_observed, bypass_expected)
        await expect_no_output(prim_sink, clk=bench.clk, cycles=8)
    else:
        primary_observed = await recv_frame(prim_sink, clk=bench.clk, timeout_cycles=64)
        await bypass_send
        assert_beat_list(primary_observed, bypass_expected)
        await expect_no_output(byp_sink, clk=bench.clk, cycles=8)

    primary_frame = build_ethernet_frame(
        dst_mac=0x313233343536,
        src_mac=0x414243444546,
        eth_type=0x88B5,
        payload=b"ethmac-rx-bypass-primary-path" + bytes(range(17)),
    )
    primary_expected = frame_beats_from_bytes(primary_frame, dest=0x5A)
    primary_send = cocotb.start_soon(send_contiguous_frame(source, primary_expected, clk=bench.clk))
    primary_observed = await recv_frame(prim_sink, clk=bench.clk, timeout_cycles=64)
    await primary_send
    assert_beat_list(primary_observed, primary_expected)
    await expect_no_output(byp_sink, clk=bench.clk, cycles=8)


PARAMETER_SWEEP = [
    parameter_case("bypass_enabled", BYP_EN_G=True),
    parameter_case("bypass_disabled", BYP_EN_G=False),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacRxBypass(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxbypasswrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
