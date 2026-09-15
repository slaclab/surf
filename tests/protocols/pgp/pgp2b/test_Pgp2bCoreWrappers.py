##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
##############################################################################

# Test methodology:
# - Sweep: Elaborate and clock each uncovered non-vendor `pgp2b/core/rtl`
#   entity through a checked-in reusable wrapper.
# - Stimulus: Hold reset for a few cycles, release it, and run briefly.
# - Checks: Each wrapper must elaborate and survive the reset/run window without
#   assertions or runtime failures.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd

from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_core_wrapper_elab_test(dut):
    cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
    dut.rst.setimmediatevalue(1)

    for _ in range(4):
        await sample_after_tpd(dut.clk)

    dut.rst.value = 0

    for _ in range(16):
        await sample_after_tpd(dut.clk)


PARAMETER_SWEEP = [
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2btxwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2b/core/wrappers/Pgp2bTxWrapper.vhd",
        },
        id="tx",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2brxwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2b/core/wrappers/Pgp2bRxWrapper.vhd",
        },
        id="rx",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2btxcellwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2b/core/wrappers/Pgp2bTxCellWrapper.vhd",
        },
        id="tx_cell",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2brxcellwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2b/core/wrappers/Pgp2bRxCellWrapper.vhd",
        },
        id="rx_cell",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2btxphywrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2b/core/wrappers/Pgp2bTxPhyWrapper.vhd",
        },
        id="tx_phy",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2brxphywrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2b/core/wrappers/Pgp2bRxPhyWrapper.vhd",
        },
        id="rx_phy",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2btxschedwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2b/core/wrappers/Pgp2bTxSchedWrapper.vhd",
        },
        id="tx_sched",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp2bCoreWrappers(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel=parameters["TOPLEVEL"],
        wrapper_source=parameters["WRAPPER_SOURCE"],
        extra_sources=pgp_family_sources("pgp2b"),
        extra_env=parameters,
    )
