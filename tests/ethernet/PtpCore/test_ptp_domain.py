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
# - Sweep: Non-isolated sdoId=000 domains 0/127 permitted and 128/255 reserved.
# - Stimulus: Production protocol configuration prepare/vote/apply over AXI.
# - Checks: IEEE 1588-2019 7.1.4/Table 2 boundaries; valid domains admit Sync;
#   a rejected candidate cannot replace the active domain, and recovery works.
# - Timing: Controlled raw ticks; bounded configuration and measurement waits.

import cocotb
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.test_ptp_port_samples import Bench, NS, Q16


@cocotb.test()
async def domain_boundaries(d):
    b = Bench(d)
    await b.start()
    try:
        active = 0
        for sequence, domain in enumerate((127, 128, 255, 0)):
            await b.write(0x008, 0x100 | domain, 4)
            d.prepare.value = 1
            await b.wait()
            d.prepare.value = 0
            await b.wait_config()
            assert bool(int(d.configValid.value)) == (domain < 128), f'domain {domain} candidate validity'
            if domain < 128:
                await b.pulse('applyConfig')
                active = domain
            await b.send(0, sequence, (sequence+1)*NS, domain=active)
            await b.result(sequence, 123*Q16+7)
            await b.drain()
    finally:
        b.stop()


def test_ptp_domain():
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpprotocolenginewrapper',
                      extra_vhdl_sources={'surf': ['ethernet/PtpCore/wrappers/PtpProtocolEngineWrapper.vhd']})
