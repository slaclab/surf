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
# - Sweep: Four Stream and two each Memory and SideBand, all concurrent.
# - Stimulus: Give every model a distinct endpoint pair, pulse their shared
#   reset, run the eight idle models, then pulse reset again after socket init.
# - Checks: Representative outputs from every instance must resolve to 0/1.
#   Reaching the checks proves all eight independent states bound their ports;
#   each old singleton backend aborted when its second port appeared.
# - Timing: No external peers and no wait on transport activity.

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb_test.simulator import run

from tests.axi.simlink.simlink_test_utils import build_and_stage_so
from tests.common.regression_utils import cocotb_module_name_from_test_file

HERE = Path(__file__).resolve().parent
GHDL_DIR = HERE.parents[2] / "axi" / "simlink" / "ghdl"

CLK_PERIOD_NS = 10
RST_EDGES = 2
RUN_EDGES = 50
PORTS = (9620, 9622, 9624, 9626, 9628, 9630, 9632, 9634)


@cocotb.test()
async def rogue_vhpi_direct_multi_instance_smoke_test(dut):
    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit="ns").start())

    for name, port in zip(
        (
            "streamPort0",
            "streamPort1",
            "streamPort2",
            "streamPort3",
            "memoryPort0",
            "memoryPort1",
            "sideBandPort0",
            "sideBandPort1",
        ),
        PORTS,
    ):
        getattr(dut, name).value = port

    dut.reset.value = 1
    for _ in range(RST_EDGES):
        await RisingEdge(dut.clock)
    dut.reset.value = 0

    for _ in range(RUN_EDGES):
        await RisingEdge(dut.clock)

    checked_outputs = (
        "streamObValid0",
        "streamIbReady0",
        "streamObValid1",
        "streamIbReady1",
        "streamObValid2",
        "streamIbReady2",
        "streamObValid3",
        "streamIbReady3",
        "memoryArValid0",
        "memoryBReady0",
        "memoryArValid1",
        "memoryBReady1",
        "sideBandRxEn0",
        "sideBandRxEn1",
    )
    for name in checked_outputs:
        assert int(getattr(dut, name).value) in (0, 1), f"{name} is not driven"

    dut.reset.value = 1
    for _ in range(RST_EDGES):
        await RisingEdge(dut.clock)
    dut.reset.value = 0
    for _ in range(RUN_EDGES):
        await RisingEdge(dut.clock)

    for name in checked_outputs:
        assert int(getattr(dut, name).value) in (0, 1), f"{name} is not driven"


def test_rogue_vhpi_direct_multi_instance_smoke():
    sim_build = HERE / "sim_build_RogueVhpiDirectMulti"
    for so_name in (
        "libRogueTcpStream.so",
        "libRogueTcpMemory.so",
        "libRogueSideBand.so",
    ):
        build_and_stage_so(GHDL_DIR, so_name, sim_build)

    run(
        module=cocotb_module_name_from_test_file(Path(__file__)),
        toplevel="roguevhpidirectmultitb",
        toplevel_lang="vhdl",
        vhdl_sources=[
            str(GHDL_DIR / "RogueTcpStream.vhd"),
            str(GHDL_DIR / "RogueTcpMemory.vhd"),
            str(GHDL_DIR / "RogueSideBand.vhd"),
            str(HERE / "RogueVhpiDirectMultiTb.vhd"),
        ],
        sim_build=str(sim_build),
        simulator="ghdl",
        vhdl_compile_args=["--std=08", "-fsynopsys"],
        extra_env={"LD_LIBRARY_PATH": str(GHDL_DIR / "build")},
    )
