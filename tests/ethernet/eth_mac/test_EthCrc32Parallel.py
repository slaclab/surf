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
# - Sweep: Cover a smaller and larger byte-lane configuration so the Ethernet-
#   specific CRC wrapper logic proves both narrow and full-width paths.
# - Stimulus: Present deterministic byte groups, leave the block idle for one
#   cycle to prove hold behavior, and then assert the CRC reset input.
# - Checks: Each emitted CRC must match the software Ethernet CRC fold over the
#   same byte sequence, the CRC must hold during idle cycles, and reset must
#   restore the all-ones seed presentation.
# - Timing: `EthCrc32Parallel` consumes the presented word on one clock and
#   updates the internal remainder on the next, so each transaction waits for
#   that two-cycle cadence explicitly.

from __future__ import annotations

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.base.crc.crc_test_utils import crc_out_from_remainder, crc_update, pack_active_bytes
from tests.common.regression_utils import hdl_parameters_from, parameter_case, run_surf_vhdl_test
from tests.ethernet.eth_mac.ethmac_test_utils import ETHMAC_RTL_SOURCES


async def cycle(clk, count: int = 1) -> None:
    for _ in range(count):
        await RisingEdge(clk)
        # The CRC block registers state with `after TPD_G`, so leave a small
        # margin beyond that delay before sampling outputs in Python.
        await Timer(2, unit="ns")


async def apply_word(dut, *, clk, byte_width: int, payload: list[int]) -> int:
    dut.crcDataValid.value = 1
    dut.crcDataWidth.value = len(payload) - 1
    dut.crcIn.value = pack_active_bytes(payload, byte_width=byte_width)

    # The input control word is captured on this edge.
    await RisingEdge(clk)
    dut.crcDataValid.value = 0
    await Timer(2, unit="ns")

    # The resulting CRC is available on the following edge.
    await RisingEdge(clk)
    await Timer(2, unit="ns")
    return int(dut.crcOut.value)


@cocotb.test()
async def eth_crc32_parallel_test(dut):
    byte_width = int(os.environ["BYTE_WIDTH_G"])

    cocotb.start_soon(Clock(dut.crcClk, 5.0, unit="ns").start())
    dut.crcReset.setimmediatevalue(1)
    dut.crcDataValid.setimmediatevalue(0)
    dut.crcDataWidth.setimmediatevalue(0)
    dut.crcIn.setimmediatevalue(0)

    await cycle(dut.crcClk, 3)
    dut.crcReset.value = 0
    await cycle(dut.crcClk, 1)

    remainder = 0xFFFFFFFF
    assert int(dut.crcOut.value) == crc_out_from_remainder(remainder)

    payloads = [
        [0x12],
        [0x34, 0x56, 0x78][: min(byte_width, 3)],
        list(range(0x90, 0x90 + min(byte_width, 6))),
    ]

    for payload in payloads:
        remainder = crc_update(remainder, payload)
        observed_crc = await apply_word(dut, clk=dut.crcClk, byte_width=byte_width, payload=payload)
        assert observed_crc == crc_out_from_remainder(remainder)

    # When no new valid word is presented, the CRC output should simply hold.
    held_value = int(dut.crcOut.value)
    await cycle(dut.crcClk, 2)
    assert int(dut.crcOut.value) == held_value

    # The Ethernet block uses `crcReset` as a synchronous accumulator reset.
    dut.crcReset.value = 1
    await cycle(dut.crcClk, 1)
    dut.crcReset.value = 0
    await cycle(dut.crcClk, 1)
    assert int(dut.crcOut.value) == crc_out_from_remainder(0xFFFFFFFF)


PARAMETER_SWEEP = [
    parameter_case("byte4", BYTE_WIDTH_G="4", USE_DSP_G="false"),
    parameter_case("byte16", BYTE_WIDTH_G="16", USE_DSP_G="false"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthCrc32Parallel(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethcrc32parallel",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES},
    )
