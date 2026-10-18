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
# - Sweep: The timing-mode GMII EthMacTop wrapper with its forced-abort
#   handshake, in loopback (TX pins to RX pins) or with injected RX traffic.
# - Stimulus: Assert abortReq while idle, while a tokened TX frame is on the
#   pins with more frames queued behind it, and while RX frames sit in the RX
#   FIFO behind a stalled sink. After the acknowledge the bench releases every
#   remaining token, as the port's step-four release does, drops the request
#   and sends fresh traffic.
# - Checks: The acknowledge rises only after the frame on the pins has
#   published its one done with doneError; queued TX frames never produce a
#   start, done or retire; stored RX frames are never delivered; no event
#   names a token after its release; and the MAC then carries new frames with
#   fresh tokens normally.
# - Timing: The monitor samples 2 ns after each rising edge of the 8 ns clock;
#   ordering is checked on the monitor's cycle index.

from __future__ import annotations

import cocotb

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES
from tests.ethernet.EthMacCore.ethmac_timing_utils import (
    TIMING_WRAPPER_PATH,
    RetireBench,
    gmii_wire,
    timing_frame,
)


async def _abort(bench: RetireBench, *, timeout: int = 4000) -> int:
    dut = bench.dut
    dut.abortReq.value = 1
    for _ in range(timeout):
        await bench.edge()
        if int(dut.abortAck.value):
            return bench.cycle
    raise AssertionError("abort was not acknowledged")


async def _release(bench: RetireBench) -> None:
    dut = bench.dut
    dut.abortReq.value = 0
    for _ in range(16):
        await bench.edge()
        if not int(dut.abortAck.value):
            return
    raise AssertionError("acknowledge did not fall with the request")


def _events_after(bench: RetireBench, cycle: int, tokens) -> list:
    return [event for event in bench.log if event[0] > cycle and event[2] in tokens and event[1] != "rx_start"]


@cocotb.test()
async def abort_while_idle(dut):
    bench = RetireBench(dut)
    await bench.start(pause=0)
    dut.rxInject.value = 0
    ack = await _abort(bench, timeout=64)
    await _release(bench)
    assert [e for e in bench.log if e[0] <= ack] == []

    await bench.send_tx(timing_frame(0x10, 100), 0x31)
    await bench.settle(600)
    bench.check_ledger()
    assert bench.tx_dones == [(0x31, 0)]
    assert [data for _, data in bench.delivered] == [timing_frame(0x10, 100)]


@cocotb.test()
async def abort_with_frame_on_pins(dut):
    bench = RetireBench(dut)
    await bench.start(pause=0)
    dut.rxInject.value = 0

    send = cocotb.start_soon(_send_all(bench, [(timing_frame(0x20 + i, 600), 0x41 + i) for i in range(3)]))
    for _ in range(4000):
        await bench.edge()
        if bench.tx_starts:
            break
    await bench.edge(100)
    ack = await _abort(bench)
    released = bench.release_all()
    await send
    await bench.settle(200)

    done_cycles = [cyc for cyc, kind, token in bench.log if kind == "tx_done" and token == 0x41]
    assert bench.tx_dones == [(0x41, 1)], "the frame on the pins ends once with doneError"
    assert done_cycles and done_cycles[0] < ack, "done must precede the acknowledge"
    assert bench.tx_starts == [0x41] and bench.tx_retires == [], "queued frames are flushed silently"
    assert _events_after(bench, ack, released) == []

    await _release(bench)
    await bench.send_tx(timing_frame(0x30, 100), 0x44)
    await bench.settle(800)
    bench.check_ledger()
    assert bench.tx_starts == [0x41, 0x44] and bench.tx_dones[-1] == (0x44, 0)
    assert bench.delivered[-1][1] == timing_frame(0x30, 100)


async def _send_all(bench: RetireBench, frames) -> None:
    # The source may be flushed mid-frame by the abort; stop once it stalls.
    for frame, token in frames:
        await bench.send_tx(frame, token)


@cocotb.test()
async def abort_with_rx_frames_stored(dut):
    bench = RetireBench(dut)
    await bench.start(pause=0)
    dut.mAxisTReady.value = 0
    stored = [timing_frame(0x50 + i, 200) for i in range(3)]
    for frame in stored:
        await bench.inject(gmii_wire(frame))
    await bench.settle(100)
    assert len(bench.allocated) == len(stored)

    ack = await _abort(bench)
    released = bench.release_all()
    dut.mAxisTReady.value = 1
    await bench.settle(400)
    assert bench.delivered == [], "flushed RX frames must never be delivered"
    assert _events_after(bench, ack, released) == []

    await _release(bench)
    fresh = timing_frame(0x60, 120)
    await bench.inject(gmii_wire(fresh))
    await bench.settle(200)
    bench.check_ledger()
    assert [data for _, data in bench.delivered] == [fresh]


def test_EthMacTimingAbort():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactoptimingwrapper",
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [TIMING_WRAPPER_PATH]},
    )
