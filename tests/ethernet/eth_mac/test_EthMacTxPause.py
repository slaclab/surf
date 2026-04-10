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
# - Sweep: Use one pause-enabled instance with a short pause quanta setting so
#   the bench focuses on the visible transmit behavior instead of long waits.
# - Stimulus: Pulse `clientPause` while the link is ready, then send one normal
#   frame after the generated pause frame has completed.
# - Checks: The emitted pause frame bytes must match the documented Ethernet
#   MAC-control format, `pauseTx` must pulse once, and ordinary client traffic
#   must still pass through unchanged when no pause frame is being emitted.
# - Timing: The sink uses explicit `TREADY` handshakes so the four-beat pause
#   frame and the later pass-through frame are both consumed deliberately.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.eth_mac.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    build_pause_frame,
    cycle,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
    wait_signal_pulse,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxPauseWrapper.vhd"


@cocotb.test()
async def eth_mac_tx_pause_test(dut):
    pause_time = 0x0030
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "mAxisTReady": 0,
            "clientPause": 0,
            "rxPauseReq": 0,
            "rxPauseValue": 0,
            "phyReady": 1,
            "pauseEnable": 1,
            "pauseTime": pause_time,
            "macAddress": 0x001122334455,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    pause_pulse = cocotb.start_soon(wait_signal_pulse(dut.pauseTx, clk=bench.clk))
    dut.clientPause.value = 1
    await cycle(bench.clk, 1)
    dut.clientPause.value = 0

    pause_frame = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)
    await pause_pulse
    assert payload_from_beats(pause_frame) == build_pause_frame(pause_time)

    # Once the one-shot pause transmission is complete, the TX path should
    # revert to ordinary client traffic forwarding.
    payload_frame = build_ethernet_frame(
        dst_mac=0x020304050607,
        src_mac=0x08090A0B0C0D,
        eth_type=0x9000,
        payload=bytes(range(24)),
    )
    payload_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(payload_frame), clk=bench.clk)
    )
    observed_frame = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)
    await payload_send
    assert payload_from_beats(observed_frame) == payload_frame


PARAMETER_SWEEP = [
    parameter_case("pause_generator", PAUSE_512BITS_G="1"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTxPause(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxpausewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
