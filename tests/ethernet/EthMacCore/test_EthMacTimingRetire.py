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
# - Sweep: A timing-mode GMII EthMacTop with the address filter, pause and a
#   configurable RX FIFO depth. Two parameter cases select an 11-bit FIFO for
#   disposition tests and a 9-bit FIFO for overflow.
# - Stimulus: RX wire traffic is injected symbol by symbol (good, bad-FCS,
#   filtered, pause and back-to-back maximum-length frames with the sink
#   stalled); TX traffic enters as tokened AXIS frames, including one marked
#   EOFE. A bench ledger acts as the port: it offers the lowest free RX token
#   after every start and reclaims it on delivery or retire.
# - Checks: Every allocated RX token must resolve exactly once, either at the
#   last delivered beat or by one retire owner, with the owner matching the
#   frame's disposition (filter, pause regardless of FCS, FIFO outbound for a
#   CRC error or a mid-frame overflow, FIFO inbound only when the SOF beat was
#   swallowed). A retire for an unallocated token, or a second resolution,
#   fails. TX: the EOFE frame retires through the checksum owner and never
#   reaches the pins. A received pause quantum must stop holding TX frames
#   once the link drops, so the held frame is transmitted after link return.
# - Timing: The monitor samples 2 ns after each rising edge of the 8 ns clock.

from __future__ import annotations

import os

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES, build_pause_frame
from tests.ethernet.EthMacCore.ethmac_timing_utils import (
    OTHER_MAC,
    TIMING_WRAPPER_PATH,
    RetireBench,
    gmii_wire,
    timing_frame,
)


# Each scenario applies to one FIFO depth; the other case skips it explicitly.
_FIFO_BITS = os.environ.get("FIFO_ADDR_WIDTH_G", "11")
SKIP_UNLESS_DEEP = _FIFO_BITS != "11"
SKIP_UNLESS_SHALLOW = _FIFO_BITS != "9"


@cocotb.test(skip=SKIP_UNLESS_DEEP)
async def rx_dispositions_retire_once(dut):
    bench = RetireBench(dut)
    await bench.start(filt=1)

    good = timing_frame(0x10, 100)
    multicast = timing_frame(0x11, 80, dst=0x01005E000001)
    bad = timing_frame(0x12, 90)
    after_bad = timing_frame(0x13, 64)
    await bench.inject(gmii_wire(good))
    await bench.inject(gmii_wire(timing_frame(0x14, 100, dst=OTHER_MAC)))
    await bench.inject(gmii_wire(multicast))
    await bench.inject(gmii_wire(build_pause_frame(0x0001)))
    await bench.inject(gmii_wire(build_pause_frame(0x0001), fcs=b"\x00\x00\x00\x00"))
    # A CRC error immediately followed by a good frame at minimum spacing
    await bench.inject(gmii_wire(bad, fcs=b"\x01\x02\x03\x04"), ifg=1)
    await bench.inject(gmii_wire(after_bad))
    await bench.settle()

    bench.check_ledger()
    assert [how for _, how in bench.resolutions] == [
        "delivered", "filter", "delivered", "pause", "pause", "fifo_ob", "delivered",
    ]
    assert [data for _, data in bench.delivered] == [good, multicast, after_bad]


@cocotb.test(skip=SKIP_UNLESS_SHALLOW)
async def rx_fifo_overflow_retires_once(dut):
    bench = RetireBench(dut)
    await bench.start()

    # A 512-word FIFO holds five maximum-length frames. With the sink stalled
    # the sixth overflows mid-frame and later ones lose their SOF beat.
    dut.mAxisTReady.value = 0
    frames = [timing_frame(0x20 + index, 1514) for index in range(9)]
    for frame in frames:
        await bench.inject(gmii_wire(frame))
    await bench.settle(200)
    stored = len(bench.allocated)
    dut.mAxisTReady.value = 1
    await bench.settle(1200)

    bench.check_ledger()
    kinds = [how for _, how in bench.resolutions]
    assert stored == len(frames) - kinds.count("fifo_ib"), "inbound retires happen before the sink is released"
    assert kinds.count("fifo_ib") >= 1, f"no SOF-swallowed frame: {kinds}"
    assert kinds.count("fifo_ob") >= 1, f"no stored partial frame: {kinds}"
    assert set(kinds) <= {"delivered", "fifo_ib", "fifo_ob"}
    assert len(kinds) == len(frames)
    assert [data for _, data in bench.delivered] == frames[: kinds.count("delivered")]


@cocotb.test(skip=SKIP_UNLESS_DEEP)
async def tx_eofe_frame_retires_through_checksum(dut):
    bench = RetireBench(dut)
    # Without pause, no generated (token-zero) pause frame can loop back and
    # hold this bench's own TX for a full quantum.
    await bench.start(pause=0)
    dut.rxInject.value = 0

    await bench.send_tx(timing_frame(0x30, 100), 0x21)
    await bench.send_tx(timing_frame(0x31, 100), 0x22, eofe=1)
    await bench.send_tx(timing_frame(0x32, 100), 0x23)
    await bench.settle(1000)

    bench.check_ledger()
    assert bench.tx_retires == [("csum", 0x22)]
    assert bench.tx_starts == [0x21, 0x23]
    assert bench.tx_dones == [(0x21, 0), (0x23, 0)]
    assert [data for _, data in bench.delivered] == [timing_frame(0x30, 100), timing_frame(0x32, 100)]


@cocotb.test(skip=SKIP_UNLESS_DEEP)
async def tx_pause_quantum_ends_with_link(dut):
    bench = RetireBench(dut)
    await bench.start()

    # A maximum quantum holds TX for 65535 x 64 cycles
    await bench.inject(gmii_wire(build_pause_frame(0xFFFF)))
    send = cocotb.start_soon(bench.send_tx(timing_frame(0x40, 100), 0x31))
    await bench.settle(2000)
    # Generated pause frames carry token zero and are not owned
    assert [t for t in bench.tx_starts if t] == [] and bench.tx_retires == [], "frame must be held by the pause quantum"

    dut.phyReady.value = 0
    await bench.edge(2)
    dut.phyReady.value = 1
    await send
    await bench.settle(2000)

    bench.check_ledger()
    assert [t for t in bench.tx_starts if t] == [0x31] and bench.tx_dones == [(0x31, 0)]
    assert [how for _, how in bench.resolutions] == ["pause"]


PARAMETER_SWEEP = [
    parameter_case("fifo_2048_words", FIFO_ADDR_WIDTH_G="11"),
    parameter_case("fifo_512_words", FIFO_ADDR_WIDTH_G="9"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTimingRetire(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactoptimingwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [TIMING_WRAPPER_PATH]},
    )
