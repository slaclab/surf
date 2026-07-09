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
# - Sweep: Cover the VHDL-only `EthMacPrepareForICrc` leaf with one multi-beat
#   frame that exercises each beat-local rewrite stage and one follow-on frame
#   that proves the internal beat counter resets on `TLAST`.
# - Stimulus: Drive flattened EMAC beats through a thin checked-in wrapper,
#   using realistic SOF/FRAG/EOFE sideband bits and handshake-driven frame
#   transfer rather than fixed delays.
# - Checks: The first frame must mask the MAC, IP, UDP, and BTH fields exactly
#   as the RTL specifies on beats 0, 1, and 2 while preserving the remaining
#   payload bytes and sideband signals. The second frame must re-enter the
#   beat-0 rewrite pattern instead of continuing the previous frame count.
# - Timing: The bench waits on visible stream handshakes and whole-frame
#   capture because the leaf is a registered single-stage transformer.

from __future__ import annotations

from dataclasses import replace

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    EmacBeat,
    assert_beat_list,
    frame_beats_from_bytes,
    keep_mask,
    pack_bytes,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/RoCEv2/wrappers/EthMacPrepareForICrcWrapper.vhd"
DUT_PATH = "ethernet/RoCEv2/rtl/EthMacPrepareForICrc.vhd"


def expected_prepare_beats(beats: list[EmacBeat]) -> list[EmacBeat]:
    expected = []
    beat_index = 0

    for beat in beats:
        lanes = bytearray((beat.data >> (8 * lane)) & 0xFF for lane in range(16))
        keep = beat.keep

        if beat_index == 0:
            version_ihl = lanes[14]
            lanes[0:8] = b"\xFF" * 8
            lanes[8] = version_ihl
            lanes[9] = 0xFF
            lanes[10:16] = b"\x00" * 6
            keep = keep_mask(10)
        elif beat_index == 1:
            lanes[6] = 0xFF
            lanes[8] = 0xFF
            lanes[9] = 0xFF
        elif beat_index == 2:
            lanes[8] = 0xFF
            lanes[9] = 0xFF
            lanes[14] = 0xFF

        expected.append(
            replace(
                beat,
                data=pack_bytes(bytes(lanes), lane_bytes=16),
                keep=keep,
            )
        )

        if beat.last == 1:
            beat_index = 0
        elif beat_index != 3:
            beat_index += 1

    return expected


@cocotb.test()
async def eth_mac_prepare_for_icrc_masks_selected_header_fields_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={"mAxisTReady": 0},
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    # Start with a three-beat frame so the bench sees every rewrite stage that
    # the leaf applies before the counter saturates.
    first_frame = frame_beats_from_bytes(
        bytes(range(48)),
        dest=0x23,
        frag=1,
        eofe=1,
    )
    first_send = cocotb.start_soon(send_contiguous_frame(source, first_frame, clk=bench.clk))
    first_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=128,
    )
    await first_send

    assert_beat_list(first_observed, expected_prepare_beats(first_frame))

    # Follow with a fresh two-beat frame to prove the internal beat counter
    # resets on `TLAST` instead of carrying the previous frame's state.
    second_frame = frame_beats_from_bytes(
        bytes(range(0x40, 0x54)),
        dest=0x7A,
        eofe=1,
    )
    second_send = cocotb.start_soon(send_contiguous_frame(source, second_frame, clk=bench.clk))
    second_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=64,
    )
    await second_send

    assert_beat_list(second_observed, expected_prepare_beats(second_frame))


@pytest.mark.parametrize("parameters", [pytest.param({}, id="eth_mac_prepare_for_icrc_wrapper")])
def test_EthMacPrepareForICrc(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacprepareforicrcwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [DUT_PATH, WRAPPER_PATH]},
    )
