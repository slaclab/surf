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
# - Sweep: Keep one simulation-mode `Pgp4RxLiteLowSpeedLane` wrapper with a
#   checked-in reverse-gearbox transmit helper.
# - Stimulus: Allow the lane to lock on continuous internal IDLE traffic, then
#   send a pair of single-word frames through the integrated `Pgp4TxLite`
#   helper.
# - Checks: The lane must assert `locked`, settle to a stable delay setting,
#   and stay locked without reissuing `bitSlip`/`dlyLoad` pulses while user
#   traffic is present.
# - Timing: The bench waits for gearbox lock, leaves additional cycles for the
#   lite RX path to settle, and then checks a bounded post-traffic window for
#   relock-free operation.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    Pgp4FlatTB,
    initialize_flat_tx_inputs,
    send_single_word_frame,
    signal_int,
    wait_for_signal,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


async def assert_locked_window(tb: Pgp4FlatTB, *, cycles: int, expected_dly_cfg: int):
    # Once the wrapper has trained, the delay setting should stop moving and
    # the alignment controls should stay quiet through user traffic.
    for _ in range(cycles):
        assert signal_int(tb.dut, "locked") == 1
        assert signal_int(tb.dut, "dlyCfg") == expected_dly_cfg
        assert signal_int(tb.dut, "bitSlip") == 0
        assert signal_int(tb.dut, "dlyLoad") == 0
        await tb.cycle()


@cocotb.test()
async def pgp4_rx_lite_low_speed_lane_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_flat_tx_inputs(dut)
    await tb.reset()

    await wait_for_signal(tb, "locked", cycles=512)
    await tb.cycle(1400)

    baseline_dly_cfg = signal_int(dut, "dlyCfg")
    assert 0 <= baseline_dly_cfg <= 0x1FF

    await assert_locked_window(tb, cycles=64, expected_dly_cfg=baseline_dly_cfg)

    await send_single_word_frame(tb, payload=0x0F1E2D3C4B5A6978)
    await send_single_word_frame(tb, payload=0x8877665544332211, eofe=1)

    await assert_locked_window(tb, cycles=256, expected_dly_cfg=baseline_dly_cfg)


PARAMETER_SWEEP = [parameter_case("integrated_low_speed_lane_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxLiteLowSpeedLane(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxlitelowspeedlanewrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxLiteLowSpeedLaneWrapper.vhd",
        extra_env=parameters,
    )
