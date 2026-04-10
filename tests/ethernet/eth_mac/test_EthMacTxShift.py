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
# - Sweep: Cover the enabled byte-remove path and the disabled pass-through
#   path because those are the only externally visible TX modes.
# - Stimulus: Send one short single-beat frame with `txShift=2`.
# - Checks: The enabled mode must remove the first two bytes of the packet
#   while preserving the frame boundary bits, and the disabled mode must leave
#   the packet untouched.
# - Timing: The TX shift stage participates in the AXI handshake, so the sink
#   explicitly raises `TREADY` while consuming the output frame.

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


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxShiftWrapper.vhd"


@cocotb.test()
async def eth_mac_tx_shift_test(dut):
    shift_enabled = env_flag("SHIFT_EN_G", default=True)
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "txShift": 2,
            "mAxisTReady": 0,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    input_bytes = b"\xAA\xBB\x10\x11\x12\x13"
    send_task = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(input_bytes), clk=bench.clk)
    )
    observed_beats = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)
    await send_task

    expected_bytes = input_bytes[2:] if shift_enabled else input_bytes
    assert payload_from_beats(observed_beats) == expected_bytes
    assert observed_beats[-1].last == 1


PARAMETER_SWEEP = [
    parameter_case("shift_enabled", SHIFT_EN_G="true"),
    parameter_case("shift_disabled", SHIFT_EN_G="false"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTxShift(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxshiftwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
