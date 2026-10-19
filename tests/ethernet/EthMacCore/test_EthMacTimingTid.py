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
# - Sweep: Build the EthMacTop loopback with the default MAC configuration
#   (XGMII, zero TID bits) and with timing mode (GMII and XGMII,
#   EMAC_TIMING_AXIS_CONFIG_C and the timing leaves), so the opt-in token
#   carrier is proven absent and present by construction.
# - Stimulus: Send frames whose every TX beat carries a distinct tId, two of
#   them while the RX sink is stalled so both sit in the RX FIFO together,
#   plus one frame with tId zero and one maximum-length frame. In timing mode
#   a bench allocator offers a fresh RX token after every RX start, as the
#   port's registered nextToken would.
# - Checks: Default mode must deliver every frame unchanged with tId zero.
#   Timing mode must show each nonzero TX token at the exporter's start and
#   done (through TX FIFO, checksum cache and exporter), token zero with no
#   done, and every delivered RX beat carrying the token its frame received
#   at the importer (through the RX FIFO, including across the stall), with
#   distinct tokens per frame. Generated pause frames, if any, appear as
#   token-zero TX starts and are not delivered.
# - Timing: Expectations come from the pytest parameter, not from reading a
#   VHDL generic back through the simulator; the bench waits on visible AXIS
#   and event behaviour with PHY-scaled timeouts.

from __future__ import annotations

import os

import cocotb
from cocotb.triggers import RisingEdge, Timer
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

RX_TOKENS = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA]


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


class EventLog:
    def __init__(self):
        self.rx_starts: list[int] = []
        self.tx_starts: list[int] = []
        self.tx_dones: list[tuple[int, int]] = []


async def _allocate_and_log(dut, log: EventLog) -> None:
    """Lifetime agent: bench-owned allocator. Propagation sampling: events at +2 ns."""
    # Offer the next token after each RX start, like the port's registered
    # nextToken; log TX events for comparison with the sent tIds.
    tokens = iter(RX_TOKENS)
    dut.rxNextToken.value = next(tokens)
    while True:
        await RisingEdge(dut.ethClk)
        await Timer(2, unit="ns")
        if int(dut.rxStart.value):
            log.rx_starts.append(int(dut.rxStartToken.value))
            dut.rxNextToken.value = next(tokens, 0)
        if int(dut.txStart.value):
            log.tx_starts.append(int(dut.txStartToken.value))
        if int(dut.txDone.value):
            log.tx_dones.append((int(dut.txDoneToken.value), int(dut.txDoneError.value)))


@cocotb.test()
async def eth_mac_timing_tid_test(dut):
    timing = os.environ["TIMING_EN_G"] == "true"
    phy = os.environ["PHY_TYPE_G"]
    scale = 1 if phy == "XGMII" else 10

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

    log = EventLog()
    if timing:
        bench.timing_monitor = cocotb.start_soon(_allocate_and_log(dut, log))

    frames = [
        (_frame(0x10, 64), 0x5A),
        (_frame(0x20, 200), 0xA5),
        (_frame(0x30, 90), 0x00),
        (_frame(0x40, 1514), 0x01),
    ]

    # Hold the sink stalled while the first two frames are sent so both sit
    # in the RX FIFO together; a TID that survives only register stages would
    # be lost or mixed here.
    await send_frame_burst(source, [_tagged_beats(frame, tid) for frame, tid in frames[:2]], clk=bench.clk)
    await sink.wait_valid(clk=bench.clk, timeout_cycles=512 * scale)
    await cycle(bench.clk, 64 * scale)

    observed = []
    for _ in frames[:2]:
        observed.append(await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=512 * scale))

    # Then the remaining frames one at a time, including the zero token and a
    # maximum-length frame that exercises the full FIFO word path.
    for frame, tid in frames[2:]:
        send = cocotb.start_soon(send_frame_burst(source, [_tagged_beats(frame, tid)], clk=bench.clk))
        observed.append(await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=2048 * scale))
        await send
    await cycle(bench.clk, 64 * scale)

    for beats, (frame, _) in zip(observed, frames):
        assert payload_from_beats(beats) == frame

    delivered = [{beat.tid for beat in beats} for beats in observed]
    if not timing:
        assert delivered == [{0}] * len(frames), f"default configuration must truncate tId: {delivered}"
        # Terminal scenario: payload and default TID truncation were checked.
        return

    # RX: one token per frame, on every beat, as allocated at the importer
    assert all(len(tids) == 1 for tids in delivered), f"tId changed within a frame: {delivered}"
    rx_tokens = [next(iter(tids)) for tids in delivered]
    assert len(set(rx_tokens)) == len(rx_tokens) and 0 not in rx_tokens
    position = iter(log.rx_starts)
    assert all(token in position for token in rx_tokens), (
        f"delivered tokens {rx_tokens} are not the importer allocations {log.rx_starts} in order"
    )

    # TX: each token reached the exporter; token zero has no done
    sent = [tid for _, tid in frames]
    assert [token for token in log.tx_starts if token != 0] == [tid for tid in sent if tid != 0]
    assert log.tx_starts.count(0) >= 1
    assert log.tx_dones == [(tid, 0) for tid in sent if tid != 0]

    assert int(dut.rxCrcErrorCnt.value) == 0
    assert int(dut.rxFifoDropCnt.value) == 0


PARAMETER_SWEEP = [
    parameter_case("default_config_truncates_tid", PHY_TYPE_G="XGMII", TIMING_EN_G="false"),
    parameter_case("gmii_timing_carries_tokens", PHY_TYPE_G="GMII", TIMING_EN_G="true"),
    parameter_case("xgmii_timing_carries_tokens", PHY_TYPE_G="XGMII", TIMING_EN_G="true"),
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
