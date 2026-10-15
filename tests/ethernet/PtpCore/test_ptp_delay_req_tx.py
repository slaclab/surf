#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: Cancellation before reservation, on its accepting edge, and while
#   each of eight Delay_Req beats is stalled, using the production protocol/ledger.
# - Stimulus: Real Sync qualification followed by raw-tick advances; observe the
#   ledger handshake only to position restart. AXI outputs supply the byte oracle.
# - Checks: No frame without a reservation; an accepted reservation survives
#   same-edge restart; held beats and remaining frame bytes survive logical abort
#   and AXI reset; disabled/restarted scheduling emits no additional requests.
# - Timing: Sample handshakes before TPD and payloads afterward. Raw time jumps
#   skip idle seconds, while ordinary protocol, RAM and arithmetic clocks run.

import cocotb
import pytest
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import (
    cancel_and_join_tasks, cocotb_filtered_env, cocotb_test_filter, run_surf_vhdl_test)
from tests.ethernet.PtpCore.test_ptp_exchange import ExchangeBench, HZ


def beat(d):
    return tuple(int(getattr(d, name).value) for name in
                 ('txValid', 'txData', 'txKeep', 'txLast', 'txSof', 'txEofe'))


async def reservation_edge(b, *, accepted):
    # The first frame has drained. Jump within the qualified ratio/receipt ages
    # beyond every possible jitter interval, then locate the next reservation.
    b.now += 2*HZ
    b.d.ticks.value = b.now
    for _ in range(512):
        await FallingEdge(b.d.clk)
        if int(b.d.u_dut.allocate.value) and bool(int(b.d.u_dut.allocateready.value)) == accepted:
            assert not int(b.d.txValid.value)
            sequence = int(b.d.u_dut.allocatesequence.value)
            b.d.restart.value = 1
            await RisingEdge(b.d.clk)
            await Timer(1.1, unit='ns')
            return sequence
    assert False, 'reservation phase was not observed'


@cocotb.test(timeout_time=2, timeout_unit='ms')
async def cancel_before_reservation(d):
    b = ExchangeBench(d)
    try:
        await b.setup()
        await b.qualify()
        await b.request()
        await reservation_edge(b, accepted=False)
        await b.wait(12)
        d.restart.value = 0
        for _ in range(256):
            await b.wait()
            assert not int(d.txValid.value), 'unaccepted reservation emitted a frame'
    finally:
        if b.clock is not None:
            await cancel_and_join_tasks([b.clock])


@cocotb.test(timeout_time=2, timeout_unit='ms')
async def cancel_at_reservation(d):
    b = ExchangeBench(d)
    try:
        await b.setup()
        await b.qualify()
        first = await b.request()
        sequence = await reservation_edge(b, accepted=True)
        assert sequence != first
        assert int(d.txValid.value), 'accepted reservation was lost on restart'
        held = beat(d)
        for _ in range(12):
            await b.wait()
            assert beat(d) == held
        assert await b.request() == sequence
        d.restart.value = 0
        for _ in range(32):
            await b.wait()
            assert not int(d.txValid.value)
    finally:
        if b.clock is not None:
            await cancel_and_join_tasks([b.clock])


@cocotb.test(timeout_time=2, timeout_unit='ms')
async def stalled_frame_survives_abort(d):
    b = ExchangeBench(d)
    try:
        await b.setup()
        await b.qualify()
        for _ in range(512):
            if int(d.txValid.value):
                break
            await b.wait()
        assert int(d.txValid.value)
        packet = bytearray()
        for index in range(8):
            held = beat(d)
            assert held[0] and held[2:] == (3 if index == 7 else 255,
                                           int(index == 7), int(index == 0), 0)
            # Controls change between edges; none may change an offered beat.
            await FallingEdge(d.clk)
            d.restart.value = 1
            d.regRst.value = 1
            await Timer(1, unit='ns')
            assert beat(d) == held
            for _ in range(3):
                await b.wait()
                assert beat(d) == held
            d.restart.value = 0
            d.regRst.value = 0
            await b.wait(2)
            assert beat(d) == held
            packet.extend(held[1].to_bytes(8, 'little')[:2 if index == 7 else 8])
            d.txReady.value = 1
            await b.wait()
            d.txReady.value = 0
        # Literal wire fields independent of the RTL request builder.
        assert packet[:14] == bytes.fromhex('011b1900000002000000000188f7')
        assert packet[14:20] == bytes.fromhex('0112002c0000')
        assert packet[20:34] == bytes(14)
        assert packet[34:44] == bytes.fromhex('020000fffe0000010001')
        assert packet[46:] == bytes((0, 127))+bytes(10)
        await b.wait(32)
        assert not int(d.txValid.value)
    finally:
        if b.clock is not None:
            await cancel_and_join_tasks([b.clock])


@pytest.mark.parametrize('scenario', [
    'cancel_before_reservation', 'cancel_at_reservation', 'stalled_frame_survives_abort'])
def test_ptp_delay_req_tx(scenario):
    run_surf_vhdl_test(
        test_file=__file__, toplevel='surf.ptpprotocolenginewrapper',
        extra_vhdl_sources={'surf': ['ethernet/PtpCore/wrappers/PtpProtocolEngineWrapper.vhd']},
        extra_env=cocotb_filtered_env({}, cocotb_test_filter(scenario)))
