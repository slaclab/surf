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
# - Drive one VCS Memory leaf for one phase of the persistent-peer relaunch
#   scenario, with the phase/result selected by environment variables.
# - Accept one AXI-Lite write and return OKAY; the external peer supplies the
#   request and writes its completion result only after receiving the response.
# - Check the address/data against that peer result so both sides of the foreign
#   boundary agree before allowing this simulator process to exit.
# - Bound reset, request, and result-file waits by a fixed clock-edge budget.

import json
import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


MAX_EDGES = 200_000


@cocotb.test()
async def memory_relaunch_phase(dut):
    result_path = Path(os.environ["SIMLINK_RELAUNCH_RESULT"])
    expected_value = int(os.environ["SIMLINK_RELAUNCH_VALUE"], 0)
    port = int(os.environ["SIMLINK_RELAUNCH_PORT"])

    dut.portNum.setimmediatevalue(port)
    dut.reset.setimmediatevalue(1)
    dut.arready.setimmediatevalue(0)
    dut.rdata.setimmediatevalue(0)
    dut.rresp.setimmediatevalue(0)
    dut.rvalid.setimmediatevalue(0)
    dut.awready.setimmediatevalue(0)
    dut.wready.setimmediatevalue(0)
    dut.bresp.setimmediatevalue(0)
    dut.bvalid.setimmediatevalue(0)
    cocotb.start_soon(Clock(dut.clock, 10, unit="ns").start())

    for _ in range(3):
        await RisingEdge(dut.clock)
    dut.reset.value = 0
    dut.awready.value = 1
    dut.wready.value = 1

    address = None
    value = None
    response_started = False
    for _ in range(MAX_EDGES):
        await RisingEdge(dut.clock)
        if dut.awvalid.value:
            address = int(dut.awaddr.value)
        if dut.wvalid.value:
            value = int(dut.wdata.value)
        if address is not None and value is not None and not response_started:
            dut.bvalid.value = 1
            response_started = True
        elif response_started and dut.bready.value:
            dut.bvalid.value = 0
        if result_path.exists():
            break
    else:
        raise TimeoutError("persistent peer did not complete this VCS run")

    result = json.loads(result_path.read_text())
    assert result["value"] == expected_value
    assert address == result["address"]
    assert value == expected_value
