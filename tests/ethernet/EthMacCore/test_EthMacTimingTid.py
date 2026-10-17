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
# - Sweep: Build the same XGMII loopback twice, once with the default MAC
#   internal stream configuration and once with EMAC_TIMING_AXIS_CONFIG_C, so
#   the opt-in TID carrier is proven both present and absent by construction.
# - Stimulus: Send frames whose every beat carries a distinct nonzero tId,
#   back to back and across a stalled sink, plus one frame with tId zero.
# - Checks: In timing mode every delivered beat must carry the tId of its own
#   frame through TX FIFO, checksum cache, exporter, importer and RX FIFO; in
#   default mode the same frames must still arrive but with tId truncated to
#   zero, proving the default configuration is unchanged.
# - Timing: The bench waits on visible AXIS behaviour; the FIFO stall confirms
#   the packed FIFO word, not only the register-copy stages, carries TID.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    cycle,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    payload_from_beats,
    recv_frame,
    send_frame_burst,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTopTidLoopbackWrapper.vhd"

LOCAL_MAC_WIRE = 0x001122334455
LOCAL_MAC_CFG = mac_config_word_from_wire(LOCAL_MAC_WIRE)


def _frame(seed: int, length: int) -> bytes:
    return build_ethernet_frame(
        dst_mac=0x5A0102030405,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        payload=bytes(((seed + index) & 0xFF) for index in range(length - 14)),
    )


def _tagged_beats(frame: bytes, tid: int):
    beats = frame_beats_from_bytes(frame)
    for beat in beats:
        beat.tid = tid
    return beats


def _expected_tid(dut, tid: int) -> int:
    # The wrapper truncates TID to zero bits unless timing mode is selected.
    return tid if str(dut.TIMING_EN_G.value).lower() == "true" else 0


@cocotb.test()
async def eth_mac_timing_tid_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "phyReady": 1,
            "mAxisTReady": 0,
            "localMac": LOCAL_MAC_CFG,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    frames = [
        (_frame(0x10, 64), 0x5A),
        (_frame(0x20, 200), 0xA5),
        (_frame(0x30, 90), 0x00),
        (_frame(0x40, 1514), 0x01),
    ]

    # Hold the sink stalled while the first two frames are sent so both sit
    # in the RX FIFO together; a TID that survives only register stages would
    # be lost or mixed here.
    burst = cocotb.start_soon(
        send_frame_burst(
            source,
            [_tagged_beats(frame, tid) for frame, tid in frames[:2]],
            clk=bench.clk,
        )
    )
    await sink.wait_valid(clk=bench.clk, timeout_cycles=512)
    await cycle(bench.clk, 32)
    await burst

    for frame, tid in frames[:2]:
        observed = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=512)
        assert payload_from_beats(observed) == frame
        assert [beat.tid for beat in observed] == [_expected_tid(dut, tid)] * len(observed), (
            f"tId not preserved on every beat for tid={tid:#x}: {[beat.tid for beat in observed]}"
        )

    # Then the remaining frames one at a time, including the zero token and a
    # maximum-length frame that exercises the full FIFO word path.
    for frame, tid in frames[2:]:
        send = cocotb.start_soon(
            send_frame_burst(source, [_tagged_beats(frame, tid)], clk=bench.clk)
        )
        observed = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=1024)
        await send
        assert payload_from_beats(observed) == frame
        assert [beat.tid for beat in observed] == [_expected_tid(dut, tid)] * len(observed)

    assert int(dut.rxCrcErrorCnt.value) == 0
    assert int(dut.rxFifoDropCnt.value) == 0


PARAMETER_SWEEP = [
    parameter_case("default_config_truncates_tid", TIMING_EN_G="false"),
    parameter_case("timing_config_carries_tid", TIMING_EN_G="true"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTimingTid(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactoptidloopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
