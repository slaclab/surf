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
# - Sweep: Cover both the enabled RX-shift datapath and the disabled bypass
#   path, then vary the runtime shift count inside each run.
# - Stimulus: Exercise a zero-shift control-bit case, a one-beat non-zero
#   shift, and a near-lane-width multi-beat shift (`rxShift=14`).
# - Checks: The enabled mode must prepend zero bytes to the payload, the
#   disabled mode must leave payloads untouched, and the visible boundary bits
#   (`SOF`, `EOFE`, and `last`) must match the current shift contract on both
#   short and multi-beat packets.
# - Timing: The RX shift block has no sink-side backpressure, so the frame is
#   launched continuously and the test samples the visible output beats.

from __future__ import annotations

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


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxShiftWrapper.vhd"


@cocotb.test()
async def eth_mac_rx_shift_test(dut):
    shift_enabled = env_flag("SHIFT_EN_G", default=True)
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={"rxShift": 0},
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    test_cases = [
        {
            "name": "zero_shift_control_bits",
            "shift": 0,
            "payload": b"\x10\x11\x12\x13\x14",
            "eofe": 1,
        },
        {
            "name": "one_beat_shift1",
            "shift": 1,
            "payload": b"\x20\x21\x22\x23\x24",
            "eofe": 0,
        },
        {
            "name": "multi_beat_shift14",
            "shift": 14,
            "payload": bytes(range(17)),
            "eofe": 1,
        },
    ]

    for index, case in enumerate(test_cases):
        if index != 0:
            # `AxiStreamShift` returns to IDLE one cycle after the previous
            # frame drains, so leave a small gap before changing the runtime
            # shift count for the next packet.
            await cycle(bench.clk, 2)

        # `AxiStreamShift` samples the shift count while it is idle, so set the
        # runtime port before driving the next packet.
        dut.rxShift.value = case["shift"]
        await cycle(bench.clk, 1)

        send_task = cocotb.start_soon(
            send_contiguous_frame(
                source,
                frame_beats_from_bytes(case["payload"], eofe=case["eofe"]),
                clk=bench.clk,
            )
        )
        # The RX shift path can take noticeably longer to flush a packet than
        # the simple leaf blocks because the left-shift engine inserts bytes and
        # drains its delayed word state before asserting `tLast`.
        observed_beats = await recv_frame(sink, clk=bench.clk, timeout_cycles=256)
        await send_task

        expected_bytes = case["payload"] if not shift_enabled else (bytes(case["shift"]) + case["payload"])
        assert payload_from_beats(observed_beats) == expected_bytes, case["name"]

        # The wrapper exposes the lane-0 SOF bit. That remains visible on
        # pass-through or zero-shift transfers, but a non-zero shift moves the
        # first payload byte away from lane 0 and the visible SOF bit drops.
        expected_sof = 1 if (not shift_enabled or case["shift"] == 0) else 0
        assert observed_beats[0].sof == expected_sof, case["name"]
        assert observed_beats[-1].last == 1, case["name"]
        assert observed_beats[-1].eofe == case["eofe"], case["name"]


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
