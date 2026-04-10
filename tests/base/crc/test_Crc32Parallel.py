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
# - Sweep: Sweep parallel lane counts across `1`, `4`, and `8`, mix registered
#   and unregistered input staging, and include synchronous and asynchronous
#   active-low reset cases to cover the supported parallel wrapper modes.
# - Stimulus: Present known parallel words built from deterministic byte
#   streams, interrupt accumulation with a reset override, and inspect the
#   startup CRC state before any traffic.
# - Checks: The parallel CRC result must equal the software fold of the same
#   bytes in the same order, and reset must immediately or synchronously
#   restore the seed depending on configuration.
# - Timing: The bench checks the extra cycle introduced by registered input
#   staging, keeps unregistered cases edge-aligned with the presented word, and
#   separates asynchronous from synchronous reset timing.

import cocotb
import pytest
from cocotb.triggers import FallingEdge, Timer

from tests.base.crc.crc_test_utils import (
    CrcStreamingTB,
    crc_out_from_remainder,
    crc_update,
)
from tests.common.regression_utils import (
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


@cocotb.test()
async def crc_sequence_test(dut):
    tb = CrcStreamingTB(dut)
    await tb.power_on_reset()

    # Start the software model from the same reset remainder value the DUT is
    # currently exposing.
    remainder = int(dut.crcRem.value)

    payloads = [[0x12]]
    if tb.byte_width >= 2:
        payloads.append([0x34, 0x56])
    if tb.byte_width >= 4:
        payloads.append([0xDE, 0xAD, 0xBE, 0xEF][: tb.byte_width])

    for payload in payloads:
        remainder = crc_update(remainder, payload)
        crc_rem, crc_out = await tb.apply_transaction(payload)

        # `crcRem` exposes the internal running remainder, while `crcOut`
        # exposes the byte-reversed and inverted presentation of that remainder.
        assert crc_rem == remainder
        assert crc_out == crc_out_from_remainder(remainder)

    # When no new valid data arrives, the remainder should simply hold.
    previous = int(dut.crcRem.value)
    await tb.cycle(2)
    assert int(dut.crcRem.value) == previous


@cocotb.test()
async def crc_reset_override_test(dut):
    tb = CrcStreamingTB(dut)
    await tb.power_on_reset()

    # Move the CRC away from its reset value first so the override operation has
    # something obvious to change.
    await tb.apply_transaction(([0xAA, 0x55] if tb.byte_width >= 2 else [0xAA]))

    custom_init = 0x13579BDF
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

    # First move the design to a non-reset remainder so the power-on reset has
    # a visible effect when it is asserted.
    await tb.apply_transaction([0x01, 0x23, 0x45, 0x67][: tb.byte_width])
    assert int(dut.crcRem.value) != reset_remainder

    # Assert reset between clock edges so synchronous and asynchronous reset
    # styles can be distinguished by observation.
    await FallingEdge(dut.crcClk)
    await Timer(1, unit="ns")
    dut.crcPwrOnRst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        # Async reset should restore the remainder immediately.
        assert int(dut.crcRem.value) == reset_remainder
    else:
        # Sync reset should wait for the next clock edge before taking effect.
        assert int(dut.crcRem.value) != reset_remainder
        await tb.cycle(1)
        assert int(dut.crcRem.value) == reset_remainder


PARAMETER_SWEEP = [
    parameter_case(
        "byte1_registered_sync",
        BYTE_WIDTH_G="1",
        INPUT_REGISTER_G="true",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "byte4_unregistered_sync",
        BYTE_WIDTH_G="4",
        INPUT_REGISTER_G="false",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "byte8_registered_async_active_low",
        BYTE_WIDTH_G="8",
        INPUT_REGISTER_G="true",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Crc32Parallel(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.crc32parallel",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
