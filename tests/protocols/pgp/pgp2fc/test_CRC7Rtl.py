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
# - Sweep: Keep one `CRC7Rtl` wrapper instance.
# - Stimulus: Reset the CRC register, then clock in two 16-bit words with
#   `crcEn` asserted.
# - Checks: The registered and combinational CRC outputs must match a direct
#   Python model of the VHDL equations.
# - Timing: Compare the registered value one cycle after each enabled update.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, crc7_step, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def crc7_rtl_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()

    # Reset seeds the CRC state to all ones in this implementation.
    assert signal_int(dut, "crcOutReg") == 0xFF

    expected = 0xFF
    for word in (0x1234, 0xABCD):
        dut.dataIn.value = word
        dut.crcEn.value = 1
        expected = crc7_step(expected, word)
        await tb.cycle()
        assert signal_int(dut, "crcOutReg") == expected
        dut.crcEn.value = 0
        await tb.cycle()
        assert signal_int(dut, "crcOut") == expected


def test_CRC7Rtl():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.crc7rtlwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/CRC7RtlWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
