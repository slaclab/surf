##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
##############################################################################

# Test methodology:
# - Sweep: Elaborate and clock each uncovered non-vendor `pgp2fc/core/rtl`
#   entity through a checked-in reusable wrapper.
# - Stimulus: Hold reset for a few cycles, release it, and run briefly.
# - Checks: Each wrapper must elaborate and survive the reset/run window without
#   assertions or runtime failures.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_core_wrapper_elab_test(dut):
    cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
    dut.rst.setimmediatevalue(1)

    for _ in range(4):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

    dut.rst.value = 0

    for _ in range(16):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")


PARAMETER_SWEEP = [
    pytest.param(
        {
            "TOPLEVEL": "surf.crc7rtlwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/CRC7RtlWrapper.vhd",
        },
        id="crc7",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fcalignmentcheckerwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcAlignmentCheckerWrapper.vhd",
        },
        id="alignment_checker",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fcalignmentcontrollerwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcAlignmentControllerWrapper.vhd",
        },
        id="alignment_controller",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fctxwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxWrapper.vhd",
        },
        id="tx",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fcrxwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcRxWrapper.vhd",
        },
        id="rx",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fctxcellwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxCellWrapper.vhd",
        },
        id="tx_cell",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fcrxcellwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcRxCellWrapper.vhd",
        },
        id="rx_cell",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fctxphywrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxPhyWrapper.vhd",
        },
        id="tx_phy",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fcrxphywrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcRxPhyWrapper.vhd",
        },
        id="rx_phy",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp2fctxschedwrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxSchedWrapper.vhd",
        },
        id="tx_sched",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp2fcCoreWrappers(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel=parameters["TOPLEVEL"],
        wrapper_source=parameters["WRAPPER_SOURCE"],
        extra_sources=pgp_family_sources("pgp2fc"),
        extra_env=parameters,
    )
