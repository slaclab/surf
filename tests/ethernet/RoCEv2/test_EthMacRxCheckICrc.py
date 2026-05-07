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
# - Sweep: Cover the VHDL-only `EthMacRxCheckICrc` leaf with one zero-CRC frame
#   and one non-zero-CRC frame so the bench proves both the good and bad frame
#   markers plus frame-to-frame CRC-state reset.
# - Stimulus: Drive flattened EMAC beats on the main stream and a single-beat
#   CRC word on the side stream through a thin checked-in wrapper, keeping the
#   CRC payload stable after the one accepted CRC handshake so later beats see
#   the same sampled result.
# - Checks: The main stream must pass through unchanged, the CRC side stream
#   must only be consumed once per frame, zero CRC must clear the exported
#   error flag on every beat, non-zero CRC must assert the exported error flag
#   on every beat, and a second frame must accept a fresh CRC word after the
#   previous frame's `TLAST`.
# - Timing: The bench waits on visible ready/valid handshakes and whole-frame
#   capture because the leaf is a registered stream joiner with one CRC sample
#   per frame.

from __future__ import annotations

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    assert_beat_list,
    frame_beats_from_bytes,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
    wait_signal_pulse,
)


WRAPPER_PATH = "ethernet/RoCEv2/wrappers/EthMacRxCheckICrcWrapper.vhd"
DUT_PATH = "ethernet/RoCEv2/rtl/EthMacRxCheckICrc.vhd"


async def send_crc_word(dut, *, data: int, clk) -> None:
    dut.sCrcTData.value = data
    dut.sCrcTValid.value = 1
    await wait_sampled_ready(dut.sCrcTReady, clk=clk)
    dut.sCrcTValid.value = 0


async def capture_crc_errors(dut, *, clk, timeout_cycles: int = 64) -> list[int]:
    errors = []

    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if int(dut.mAxisTValid.value) == 1 and int(dut.mAxisTReady.value) == 1:
            errors.append(int(dut.mAxisCrcError.value))
            if int(dut.mAxisTLast.value) == 1:
                return errors

    raise AssertionError("Timed out waiting for end of checked EMAC frame")


@cocotb.test()
async def eth_mac_rx_check_icrc_flags_good_and_bad_frames_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "mAxisTReady": 0,
            "sCrcTValid": 0,
            "sCrcTData": 0,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    # First prove the good-frame path: the CRC sideband should be consumed
    # once, the payload should pass through untouched, and the exported error
    # marker must stay clear for the whole frame.
    good_frame = frame_beats_from_bytes(
        bytes(range(0x20)),
        dest=0x11,
        frag=1,
        eofe=1,
    )
    good_crc_send = cocotb.start_soon(send_crc_word(dut, data=0x00000000, clk=bench.clk))
    good_frame_send = cocotb.start_soon(send_contiguous_frame(source, good_frame, clk=bench.clk))
    good_error_task = cocotb.start_soon(capture_crc_errors(dut, clk=bench.clk, timeout_cycles=128))
    await wait_signal_pulse(dut.sCrcTReady, clk=bench.clk, timeout_cycles=64)
    good_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=128,
    )
    good_errors = await good_error_task
    await good_crc_send
    await good_frame_send

    assert_beat_list(good_observed, good_frame)
    assert good_errors == [0] * len(good_observed)

    # Then send a second frame with a non-zero CRC word. This proves both the
    # bad-frame marker and the fact that `TLAST` resets the one-CRC-per-frame
    # internal state so the leaf accepts a fresh CRC word on the next frame.
    bad_frame = frame_beats_from_bytes(
        bytes(range(0x40, 0x60)),
        dest=0x41,
        eofe=1,
    )
    bad_crc_send = cocotb.start_soon(send_crc_word(dut, data=0xDEADBEEF, clk=bench.clk))
    bad_frame_send = cocotb.start_soon(send_contiguous_frame(source, bad_frame, clk=bench.clk))
    bad_error_task = cocotb.start_soon(capture_crc_errors(dut, clk=bench.clk, timeout_cycles=128))
    await wait_signal_pulse(dut.sCrcTReady, clk=bench.clk, timeout_cycles=64)
    bad_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=128,
    )
    bad_errors = await bad_error_task
    await bad_crc_send
    await bad_frame_send

    assert_beat_list(bad_observed, bad_frame)
    assert bad_errors == [1] * len(bad_observed)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="eth_mac_rx_check_icrc_wrapper")])
def test_EthMacRxCheckICrc(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxcheckicrcwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [DUT_PATH, WRAPPER_PATH]},
    )
