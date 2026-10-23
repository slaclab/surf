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
# - Sweep: Sweep `BYTE_WIDTH_G` across `4` and `8`, `INPUT_REGISTER_G` across
#   registered and direct input capture, the IEEE/Castagnoli/Koopman
#   polynomials, and synchronous vs asynchronous active-high/low reset so the
#   wrapper covers the supported datapath shapes.
# - Stimulus: Drive fixed multi-byte words into the wrapper, assert the
#   explicit CRC reset override in the middle of a stream, and sample the
#   power-on state before any valid data arrives.
# - Checks: The remainder and output CRC must match the Python model for each
#   width and polynomial, and the reset override must discard partial
#   accumulation and restart from the seed.
# - Timing: Registered-input cases are checked one cycle later than
#   unregistered cases, while asynchronous active-low reset is expected to take
#   effect immediately and synchronous reset only on the next clock edge.

import cocotb
import pytest
from cocotb.triggers import FallingEdge, Timer

from tests.base.crc.crc_test_utils import (
    CrcStreamingTB,
    crc_out_from_remainder,
    crc_update,
)
from tests.common.regression_utils import (
    parameter_case,
    run_surf_vhdl_test,
)


@cocotb.test()
async def crc_sequence_test(dut):
    tb = CrcStreamingTB(dut)
    await tb.power_on_reset()

    remainder = int(dut.crcRem.value)

    payloads = [[0x89]]
    if tb.byte_width >= 2:
        payloads.append([0xAB, 0xCD])
    if tb.byte_width >= 4:
        payloads.append([0x10, 0x32, 0x54, 0x76][: tb.byte_width])

    for payload in payloads:
        remainder = crc_update(remainder, payload, poly=tb.crc_poly)
        crc_rem, crc_out = await tb.apply_transaction(payload)
        assert crc_rem == remainder
        assert crc_out == crc_out_from_remainder(remainder)

    previous = int(dut.crcRem.value)
    await tb.cycle(2)
    assert int(dut.crcRem.value) == previous


@cocotb.test()
async def crc_reset_override_test(dut):
    tb = CrcStreamingTB(dut)
    await tb.power_on_reset()

    await tb.apply_transaction(([0xFE, 0xDC] if tb.byte_width >= 2 else [0xFE]))

    custom_init = 0x2468ACE0
    crc_rem, crc_out = await tb.apply_transaction(
        [],
        init_override=custom_init,
        request_crc_reset=True,
    )

    assert crc_rem == custom_init
    assert crc_out == crc_out_from_remainder(custom_init)


@cocotb.test()
async def power_on_reset_behavior_test(dut):
    tb = CrcStreamingTB(dut)
    await tb.power_on_reset()
    reset_remainder = int(dut.crcRem.value)

    await tb.apply_transaction([0x11, 0x22, 0x33, 0x44][: tb.byte_width])
    assert int(dut.crcRem.value) != reset_remainder

    await FallingEdge(dut.crcClk)
    await Timer(1, unit="ns")
    dut.crcPwrOnRst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.crcRem.value) == reset_remainder
    else:
        assert int(dut.crcRem.value) != reset_remainder
        await tb.cycle(1)
        assert int(dut.crcRem.value) == reset_remainder


PARAMETER_SWEEP = [
    parameter_case(
        "byte4_registered_sync_ieee",
        BYTE_WIDTH_G="4",
        INPUT_REGISTER_G="true",
        CRC_POLY_G="0x04C11DB7",
        CRC_POLY_INT_G="79764919",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "byte8_unregistered_sync_castagnoli",
        BYTE_WIDTH_G="8",
        INPUT_REGISTER_G="false",
        CRC_POLY_G="0x1EDC6F41",
        CRC_POLY_INT_G="517762881",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "byte4_registered_async_active_low_koopman",
        BYTE_WIDTH_G="4",
        INPUT_REGISTER_G="true",
        CRC_POLY_G="0x741B8CD7",
        CRC_POLY_INT_G="1947962583",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Crc32(parameters):
    # The cocotb model still wants the human-readable hexadecimal polynomial in
    # the environment, but the simulator-facing wrapper generic uses an integer
    # so GHDL can elaborate the testcase reliably.
    hdl_parameters = {
        "BYTE_WIDTH_G": parameters["BYTE_WIDTH_G"],
        "INPUT_REGISTER_G": parameters["INPUT_REGISTER_G"],
        "CRC_POLY_INT_G": parameters["CRC_POLY_INT_G"],
        "RST_ASYNC_G": parameters["RST_ASYNC_G"],
        "RST_POLARITY_G": parameters["RST_POLARITY_G"],
    }

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.crc32polywrapper",
        parameters=hdl_parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["base/crc/wrappers/Crc32PolyWrapper.vhd"],
        },
    )
