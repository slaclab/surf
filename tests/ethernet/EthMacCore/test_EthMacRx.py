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
# - Sweep: Use one pause-enabled, filter-enabled, bypass-enabled loopback
#   instance so the assembly bench covers the externally meaningful RX modes in
#   one build.
# - Stimulus: Feed the real RX assembly from a checked-in TX export wrapper,
#   then send a valid local IPv4/UDP frame, one bypass-EtherType frame, one
#   pause frame, and one bad-UDP frame.
# - Checks: Local traffic must emerge on the primary output without checksum
#   errors, bypass traffic must emerge on the bypass output, pause frames must
#   be consumed internally while pulsing the pause request, and bad UDP must
#   propagate to the primary output with `UDPERR` and `EOFE` asserted.
# - Timing: The bench waits on visible AXIS/status behavior rather than fixed
#   internal latency because the DUT chains import, pause, checksum, bypass,
#   and filter stages.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    build_ethernet_frame,
    build_ipv4_udp_frame,
    build_pause_frame,
    expect_no_output,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
    wait_signal_pulse,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxLoopbackWrapper.vhd"
LOCAL_MAC_WIRE = 0x001122334455
LOCAL_MAC_CFG = mac_config_word_from_wire(LOCAL_MAC_WIRE)


@cocotb.test()
async def eth_mac_rx_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix=None,
        initial_values={
            "ethClkEn": 1,
            "phyReady": 1,
            "mPrimPause": 0,
            "dropOnPause": 0,
            "macAddress": LOCAL_MAC_CFG,
            "filtEnable": 1,
            "ipCsumEn": 1,
            "tcpCsumEn": 0,
            "udpCsumEn": 1,
        },
    )
    source = bench.source
    prim_sink = FlatEmacEndpoint(dut, prefix="mPrim")
    byp_sink = FlatEmacEndpoint(dut, prefix="mByp")
    assert source is not None

    # First prove the straight-through RX assembly path on a valid local IPv4
    # packet that exercises the checksum checker without triggering errors.
    valid_frame = build_ipv4_udp_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=0x0A0B0C0D0E0F,
        src_ip="192.168.10.1",
        dst_ip="192.168.10.2",
        src_port=0x1234,
        dst_port=0x5678,
        payload=bytes(range(48)),
    )
    valid_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(valid_frame), clk=bench.clk)
    )
    valid_observed = await recv_frame(prim_sink, clk=bench.clk, timeout_cycles=256)
    await valid_send
    assert payload_from_beats(valid_observed) == valid_frame
    assert valid_observed[-1].iperr == 0
    assert valid_observed[-1].udperr == 0
    assert valid_observed[-1].eofe == 0
    await expect_no_output(byp_sink, clk=bench.clk, cycles=8)

    # The bypass route sits ahead of the MAC filter, so a foreign destination
    # with the configured EtherType must still emerge on the bypass output.
    bypass_frame = build_ethernet_frame(
        dst_mac=0xDEADBEEF1234,
        src_mac=0x111213141516,
        eth_type=0x88B5,
        payload=bytes(range(46)),
    )
    bypass_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(bypass_frame), clk=bench.clk)
    )
    bypass_observed = await recv_frame(byp_sink, clk=bench.clk, timeout_cycles=256)
    await bypass_send
    assert payload_from_beats(bypass_observed) == bypass_frame
    await expect_no_output(prim_sink, clk=bench.clk, cycles=8)

    # A standards-compliant pause frame should be consumed internally and only
    # expose the pause request/value side effects to software.
    pause_value = 0x0020
    pause_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(build_pause_frame(pause_value)), clk=bench.clk)
    )
    await wait_signal_pulse(dut.rxPauseReq, clk=bench.clk, timeout_cycles=128)
    await pause_send
    assert int(dut.rxPauseValue.value) == pause_value
    await expect_no_output(prim_sink, clk=bench.clk, cycles=8)
    await expect_no_output(byp_sink, clk=bench.clk, cycles=8)

    # Finish with a bad UDP checksum to prove the integrated pause and filter
    # stages do not hide the RX checksum error reporting on the primary output.
    bad_udp_frame = build_ipv4_udp_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=0x202122232425,
        src_ip="10.0.0.10",
        dst_ip="10.0.0.20",
        src_port=0x1111,
        dst_port=0x2222,
        payload=b"rx-assembly-bad-udp" + bytes(19),
        udp_checksum_override=0x0001,
    )
    bad_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(bad_udp_frame), clk=bench.clk)
    )
    bad_observed = await recv_frame(prim_sink, clk=bench.clk, timeout_cycles=256)
    await bad_send
    assert payload_from_beats(bad_observed) == bad_udp_frame
    assert bad_observed[-1].iperr == 0
    assert bad_observed[-1].udperr == 1
    assert bad_observed[-1].eofe == 1


@pytest.mark.parametrize("parameters", [pytest.param({}, id="rx_assembly_loopback")])
def test_EthMacRx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxloopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
