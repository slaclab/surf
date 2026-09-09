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
# - Sweep: GMII/XGMII autonomous endpoint with an independent Python MAC/wire model.
# - Stimulus: AXI-Lite configuration/commands, independent two-step master,
#   oscillator error, Delay_Req responses, loss and restart.
# - Checks: PHC commands/snapshots, timestamp provenance, acquisition, lock/holdover,
#   valid command sequencing and reacquisition with oscillator error.
# - Timing: The master's clock is simulation time, independent of the DUT PHC.
#   Wire timestamps include XGMII lane phase; every wait has a cycle bound.

from fractions import Fraction
import cocotb
from cocotb.triggers import RisingEdge
from cocotb.utils import get_sim_time
from cocotbext.axi import AxiResp
import pytest
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES, ROCE_ANALYSIS_SOURCES
from tests.ethernet.PtpCore.ptp_reference import NS, Q16, Q32

from tests.ethernet.PtpCore.ptp_endpoint_test_utils import Bench

@cocotb.test()
async def autonomous_endpoint(d):
    b = Bench(d)
    await b.start()
    assert await b.read(0) == 0x20000
    assert (await b.axil.read(0x3F0, 4)).resp == AxiResp.DECERR
    await b.write(0x428, 5, 8)
    await b.write(0x430, NS-100)
    await b.manual(0)
    await b.manual(3, 1)
    await b.snapshot()
    assert await b.read(0x41C) == 1
    assert await b.read(0x408, 8) in (5, 6)
    await b.configure()
    if not b.real_mac:
        b.tasks.append(cocotb.start_soon(b.model_mac()))
        b.tasks.append(cocotb.start_soon(b.model_wire()))
    b.tasks.append(cocotb.start_soon(b.monitor_wire()))
    b.tasks.append(cocotb.start_soon(b.respond()))
    # Start invalid so autonomous acquisition may correct the arbitrary epoch.
    # Configuration changes intentionally do not reset or set the PHC.
    await b.write(0x004, 1)
    await b.commit()
    await b.manual(3, 0)
    await b.write(0x004, 3)
    await b.commit()
    if not b.allow_step:
        await RisingEdge(d.clk)
        local = Fraction(((int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value)) << 32)+int(d.timeFraction.value), Q32)
        b.epoch = local-Fraction(int(get_sim_time(unit="fs")), 1000000)-50
    await b.source(14)
    await b.snapshot()
    counters = [await b.read(0xA00+4*i if i < 7 else 0xE00) for i in range(8)]
    d._log.info("Counters %s", counters)
    assert b.tx_count > 0
    assert counters[5] > 0, "no accepted E2E delay"
    assert not int(d.timeFault.value)
    assert int(d.timeValid.value)
    assert int(d.servoState.value) == 3, "did not acquire lock"
    assert int(d.timeGeneration.value) == (2 if b.allow_step else 1)

    async def check_absolute_phase():
        # Sample the same pre-edge PHC plane used by the physical taps. This
        # compares against independent simulation time, not the DUT's own
        # reported offset or filtered-delay arithmetic.
        await RisingEdge(d.clk)
        local = Fraction(((int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value)) << 32)+int(d.timeFraction.value), Q32)
        master = Fraction(int(get_sim_time(unit="fs")), 1000000)+b.epoch
        error = local-master
        d._log.info("Independent PHC phase error: %.6f ns", float(error))
        assert abs(error) < 100, error

    await check_absolute_phase()
    offset = await b.read(0xD00, 16)
    if offset >> 127:
        offset -= 1 << 128
    assert abs(Fraction(offset, Q16)) < 100
    generation = int(d.timeGeneration.value)
    before = int(d.timeTicks.value)
    d.phyReady.value = 0
    await b.wait(25000)
    assert int(d.timeTicks.value) > before
    assert int(d.timeGeneration.value) == generation
    assert not int(d.timeValid.value)
    d.phyReady.value = 1
    await b.source(12, sequence=100)
    assert int(d.timeValid.value)
    assert int(d.servoState.value) == 3
    await check_absolute_phase()
    b.stop()

@pytest.mark.parametrize("mode,real_mac", [("XGMII", False), ("GMII", False)])
def test_ptp_endpoint(mode, real_mac):
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpendpointloopbackwrapper",
                      parameters={"PHY_TYPE_G": mode, "CLK_FREQ_G": 125000000 if mode == "GMII" else 156250000,
                                  "PACKET_LIFETIME_G": 5000, "MAC_ENABLE_G": real_mac},
                      extra_env={"MODE": mode, "REAL_MAC": int(real_mac), "OSCILLATOR_PPM": 100 if mode == "XGMII" else -100, "ALLOW_STEP": int(mode == "XGMII"), "ABSOLUTE_PHASE_CHECK": 1},
                      extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + ROCE_ANALYSIS_SOURCES})
