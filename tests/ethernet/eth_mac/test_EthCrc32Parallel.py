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
# - Sweep: Cover every supported byte width from 1 through 16 with the logic
#   implementation.
# - Stimulus: Present a short transaction, a small partial-width transaction,
#   and two chained wider transactions before checking idle hold and reset.
# - Checks: Every emitted CRC must match the software Ethernet CRC fold over
#   the same byte stream, chained transactions must continue the prior
#   remainder, the CRC must hold during idle cycles, and reset must restore the
#   all-ones seed presentation.
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
        list(range(0x30, 0x30 + min(byte_width, 2))),
        list(range(0x50, 0x50 + byte_width)),
        list(range(0x90, 0x90 + byte_width)),
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
    *[parameter_case(f"byte{byte_width}", BYTE_WIDTH_G=str(byte_width), USE_DSP_G="false") for byte_width in range(1, 17)],
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthCrc32Parallel(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethcrc32parallel",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES},
        sim_build_key="tests/sim_build/ethernet/eth_mac/test_EthCrc32Parallel.shared",
    )
