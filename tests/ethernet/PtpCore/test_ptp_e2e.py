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
# - Sweep: Epoch offsets, corrections, lane phases, signed ingress/egress latency,
#   PHC rate replacements, negative/oversized path delay and arithmetic abort.
# - Stimulus: Integer wire timestamps and independently reconstructed master time.
# - Checks: Full signed 128-bit forward/path delay, rejection and stalled outputs.
# - Timing: Five sequential operations must finish within 700 cycles; cancellation
#   invalidates a result before its ready edge.

from fractions import Fraction
import random
import cocotb
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import Q16, Q32, NS, nearest
from tests.ethernet.PtpCore.ptp_endpoint_reference import Q48, elapsed_master_q16

MASK = (1 << 128)-1
INGRESS = 475136
EGRESS = -229376

def timestamp(value, fraction=False):
    if fraction:
        sec, nsfrac = divmod(value, NS*Q16)
        return (sec << 48) | nsfrac
    sec, ns = divmod(value, NS)
    return (sec << 32) | ns

@cocotb.test()
async def corrected_exchange(d):
    async def edge(**values):
        d.clk.value = 0
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(3.2, unit="ns")
        d.clk.value = 1
        await Timer(3.2, unit="ns")
    for name in ("clk", "cancel", "inputValid", "syncTime", "syncTicks", "syncPhase", "syncIncrement",
                 "syncRemote", "syncCorrection", "txTicks", "txPhase", "txIncrement", "responseRemote",
                 "responseCorrection", "ratio", "maxPathDelay", "resultReady"):
        getattr(d, name).value = 0
    await edge(rst=1)
    await edge(rst=0)
    rng = random.Random(1588)
    for index in range(24):
        ppm = (-100, 0, 100)[index % 3]
        ratio = nearest(Fraction(32, 5)/(1+Fraction(ppm, 1000000))*Q48)
        rx_inc = nearest(Fraction(32, 5)*Q32)
        tx_inc = nearest(Fraction(32, 5)*(1+Fraction(77, 1000000))*Q32)
        rx, tx = 8000+4*(index % 2), 8*1563500+4*((index+1) % 2)
        elapsed = elapsed_master_q16(rx, tx, ratio, INGRESS, EGRESS, rx_inc, tx_inc)
        remote1 = (1 << 39)*NS+1234
        correction1 = rng.randrange(-100*Q16, 100*Q16)
        correction4 = rng.randrange(-100*Q16, 100*Q16)
        wanted_delay = (-10, 100, 2000000)[index % 3]*Q16
        remote4 = nearest(Fraction(remote1*Q16+correction1+correction4+elapsed+2*wanted_delay, Q16))
        local2 = ((1 << 40)*NS+4567)*Q16+13
        expected_delay = nearest(Fraction(remote4*Q16-correction4-remote1*Q16-correction1-elapsed, 2))
        expected_forward = local2-remote1*Q16-correction1
        await edge(inputValid=1, syncTime=timestamp(local2, True), syncTicks=rx//8, syncPhase=rx % 8,
                   syncIncrement=rx_inc, syncRemote=timestamp(remote1), syncCorrection=correction1 & MASK,
                   txTicks=tx//8, txPhase=tx % 8, txIncrement=tx_inc, responseRemote=timestamp(remote4),
                   responseCorrection=correction4 & ((1 << 64)-1), ratio=ratio, maxPathDelay=1000000*Q16,
                   resultReady=0)
        await edge(inputValid=0)
        for _ in range(700):
            if int(d.resultValid.value):
                break
            await edge()
        else:
            assert False, "E2E completion timeout"
        assert int(d.delayValue.value) == expected_delay & MASK
        assert int(d.forwardValue.value) == expected_forward & MASK
        assert bool(d.resultError.value) == (not 0 <= expected_delay <= 1000000*Q16)
        for _ in range(3):
            await edge()
            assert int(d.resultValid.value)
            assert int(d.delayValue.value) == expected_delay & MASK
        await edge(resultReady=1)
    await edge(inputValid=1, resultReady=0)
    await edge(inputValid=0)
    for _ in range(50):
        await edge()
    await edge(cancel=1, resultReady=1)
    assert not int(d.resultValid.value)
    await edge(cancel=0)
    assert int(d.inputReady.value)


def test_ptp_e2e():
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpe2ewrapper", parameters={
        "INGRESS_LATENCY_G": format(INGRESS, "064b"),
        "EGRESS_LATENCY_G": format(EGRESS & ((1 << 64)-1), "064b")})
