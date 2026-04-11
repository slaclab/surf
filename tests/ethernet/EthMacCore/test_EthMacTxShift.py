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
# - Sweep: Cover both the enabled TX-shift datapath and the disabled bypass
#   path, then vary the runtime shift count inside each run.
# - Stimulus: Exercise a zero-shift control-bit case, a one-beat non-zero
#   shift, and a near-lane-width multi-beat shift (`txShift=15`).
# - Checks: The enabled mode must remove the requested leading bytes from the
#   payload, the disabled mode must leave payloads untouched, and the visible
#   boundary bits (`SOF`, `EOFE`, and `last`) must match the current shift
#   contract on both short and multi-beat packets.
# - Timing: The TX shift stage participates in the AXI handshake, so the sink
#   explicitly raises `TREADY` while consuming the output frame.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    cycle,
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
            "txShift": 0,
            "mAxisTReady": 0,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    test_cases = [
        {
            "name": "zero_shift_control_bits",
            "shift": 0,
            "payload": b"\xAA\xBB\x10\x11\x12\x13",
            "eofe": 1,
        },
        {
            "name": "one_beat_shift1",
            "shift": 1,
            "payload": b"\x31\x32\x33\x34\x35\x36",
            "eofe": 0,
        },
        {
            "name": "multi_beat_shift15",
            "shift": 15,
            "payload": bytes(range(32)),
            "eofe": 1,
        },
    ]

    for index, case in enumerate(test_cases):
        if index != 0:
            # Mirror the RX bench spacing so each runtime shift update is
            # sampled from a clean IDLE state.
            await cycle(bench.clk, 2)

        # The TX shift block latches the runtime shift while idle, so update it
        # before launching each frame.
        dut.txShift.value = case["shift"]
        await cycle(bench.clk, 1)

        send_task = cocotb.start_soon(
            send_contiguous_frame(
                source,
                frame_beats_from_bytes(case["payload"], eofe=case["eofe"]),
                clk=bench.clk,
            )
        )
        observed_beats = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)
        await send_task

        expected_bytes = case["payload"] if not shift_enabled else case["payload"][case["shift"] :]
        assert payload_from_beats(observed_beats) == expected_bytes, case["name"]

        # As with RX shift, the wrapper only exposes the lane-0 SOF bit. It
        # stays visible on pass-through or zero-shift transfers and drops once
        # a non-zero right shift removes the original lane-0 byte.
        expected_sof = 1 if (not shift_enabled or case["shift"] == 0) else 0
        assert observed_beats[0].sof == expected_sof, case["name"]
        assert observed_beats[-1].last == 1, case["name"]
        assert observed_beats[-1].eofe == case["eofe"], case["name"]


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
