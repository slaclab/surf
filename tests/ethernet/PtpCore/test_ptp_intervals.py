#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: Every signed wire exponent for Announce with large/small receipt caps;
#   representative Sync bounds, invalid/unspecified values and negative rounding.
# - Stimulus: Validated records into the production protocol engine at 125 MHz;
#   raw ticks jump to the inclusive receipt deadline and one tick beyond it.
# - Checks: Live AXI status and rejection counts against Python integer periods;
#   invalid intervals use the cap, and 0x7f does not increment rejections.
# - Timing: No idle seconds are simulated. Frozen raw time isolates receipt
#   policy; production RAM, AXI, configuration and arithmetic clocks still run.

import cocotb

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.test_ptp_port_samples import Bench, NS, Q16

HZ = 125000000


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def receipt_intervals(d):
    b = Bench(d)
    await b.start()
    try:
        async def status():
            result = await b.axil.read(0x044, 4)
            assert int(result.resp) == 0
            return int.from_bytes(result.data, 'little')

        for cap in (1 << 60, 500000):
            await b.write(0x088, cap)
            d.prepare.value = 1
            await b.wait()
            d.prepare.value = 0
            await b.wait_config()
            assert int(d.configValid.value)
            await b.pulse('applyConfig')
            for kind, exponents, bit, limit in (
                    (11, range(-128, 128), 1, 2*cap),
                    (0, (-128, -11, -10, -3, 0, 22, 23, 127), 0, cap)):
                for exponent in exponents:
                    await b.pulse('restart')
                    before = b.counts()[1]
                    d.rxLogInterval.value = exponent & 255
                    await b.send(kind, exponent & 255, NS,
                                 flags=0x3c if kind == 11 else 0, control=0)
                    capture = b.now
                    if kind == 0:
                        await b.result(exponent & 255, 123*Q16+7)
                        await b.drain()
                    valid = -10 <= exponent <= 22
                    assert b.counts()[1] == before+int(not valid and exponent != 127)
                    period = HZ*(1 << exponent) if exponent >= 0 else HZ//(1 << -exponent)
                    deadline = min(3*period, limit) if valid else limit
                    d.ticks.value = capture+deadline
                    await b.wait(3)
                    assert (await status() >> bit) & 1, (kind, cap, exponent, deadline)
                    d.ticks.value = capture+deadline+1
                    await b.wait(3)
                    assert not ((await status() >> bit) & 1), (kind, cap, exponent, deadline)
    finally:
        b.stop()


def test_ptp_intervals():
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpprotocolenginewrapper')
