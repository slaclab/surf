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
# - Sweep: Cover the enabled byte-insert path and the disabled pass-through
#   path because those are the only meaningful modes of this wrapper.
# - Stimulus: Send one short single-beat frame with `rxShift=2`.
# - Checks: The enabled mode must prepend two zero bytes to the packet while
#   preserving the frame boundary bits, and the disabled mode must leave the
#   packet untouched.
# - Timing: The RX shift block has no sink-side backpressure, so the frame is
#   launched continuously and the test samples the visible output beats.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.ethernet.eth_mac.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxShiftWrapper.vhd"


@cocotb.test()
async def eth_mac_rx_shift_test(dut):
    shift_enabled = env_flag("SHIFT_EN_G", default=True)
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={"rxShift": 2},
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    input_bytes = b"\x10\x11\x12\x13\x14"
    send_task = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(input_bytes), clk=bench.clk)
    )
    observed_beats = await recv_frame(sink, clk=bench.clk)
    await send_task

    expected_bytes = (b"\x00\x00" + input_bytes) if shift_enabled else input_bytes
    assert payload_from_beats(observed_beats) == expected_bytes
    assert observed_beats[-1].last == 1


PARAMETER_SWEEP = [
    parameter_case("shift_enabled", SHIFT_EN_G="true"),
    parameter_case("shift_disabled", SHIFT_EN_G="false"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacRxShift(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxshiftwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
