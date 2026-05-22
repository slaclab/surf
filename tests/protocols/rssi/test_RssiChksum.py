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
# - Sweep: Run the 64-bit RSSI/RUDP checksum engine with its production data
#   and checksum widths.
# - Stimulus: Feed fixed ACK/DATA/SYN header words, complete headers with
#   checksum fields, disabled-enable gaps, and reset interruptions.
# - Checks: The RTL checksum must match the Python one's-complement oracle,
#   valid headers must assert `check_o`, corrupted headers must not, and low
#   enable/reset must restart accumulation.
# - Timing: The bench drives one 64-bit word per strobe, then waits for the
#   registered `valid_o` response before sampling `chksum_o` and `check_o`.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import (
    RssiParams,
    build_ack_header,
    build_data_header,
    build_syn_header,
    checksum_is_valid,
    header_without_checksum,
    header_words,
    ones_complement_checksum,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        # The checksum block is a simple registered datapath, so a single free
        # running clock is enough for all tests in this module.
        cocotb.start_soon(Clock(dut.clk_i, 5.0, unit="ns").start())

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk_i)
            # Most RSSI RTL uses `after TPD_G`; wait past the default 1 ns
            # transport delay before sampling outputs.
            await Timer(2, unit="ns")

    async def reset(self) -> None:
        # Hold all data/control inputs in a benign state during reset so the
        # first transaction starts from only the explicit init value.
        self.dut.rst_i.setimmediatevalue(1)
        self.dut.enable_i.setimmediatevalue(0)
        self.dut.strobe_i.setimmediatevalue(0)
        self.dut.length_i.setimmediatevalue(1)
        self.dut.init_i.setimmediatevalue(0)
        self.dut.data_i.setimmediatevalue(0)
        await self.cycle(4)
        self.dut.rst_i.value = 0
        await self.cycle(2)

    async def run_words(self, words: list[int], *, init: int = 0) -> tuple[int, int]:
        # Load the initial checksum state while enable is low, then present one
        # strobe per 64-bit header word.
        self.dut.enable_i.value = 0
        self.dut.strobe_i.value = 0
        self.dut.init_i.value = init
        self.dut.length_i.value = len(words)
        await self.cycle()

        self.dut.enable_i.value = 1
        for word in words:
            # The RTL sums all four 16-bit lanes in a 64-bit word whenever
            # strobe is high, so keep the word stable for the accepting edge.
            self.dut.data_i.value = word
            self.dut.strobe_i.value = 1
            await self.cycle()

        self.dut.strobe_i.value = 0
        await with_timeout(self.wait_valid(), 1, "us")
        return int(self.dut.chksum_o.value), int(self.dut.check_o.value)

    async def wait_valid(self) -> None:
        # Valid remains asserted once the requested word count has been
        # accumulated; the caller bounds this wait with `with_timeout`.
        while int(self.dut.valid_o.value) != 1:
            await self.cycle()


@cocotb.test()
async def known_header_vectors_test(dut):
    tb = TB(dut)
    await tb.reset()

    vectors = [
        build_ack_header(sequence=0x12, acknowledge=0x34),
        build_data_header(sequence=0x56, acknowledge=0x78, ack=True, busy=True),
        build_syn_header(
            sequence=0x9A,
            acknowledge=0xBC,
            ack=True,
            params=RssiParams(
                version=1,
                chksum_en=1,
                max_outs_seg=7,
                max_seg_size=0x05DC,
                retrans_tout=0x0123,
                cumul_ack_tout=0x0045,
                null_seg_tout=0x0678,
                max_retrans=9,
                max_cum_ack=10,
                max_outofseq=0,
                timeout_unit=4,
                connection_id=0x89AB_CDEF,
            ),
        ),
    ]

    for header in vectors:
        # Generation mode feeds the header with the checksum bytes cleared and
        # expects `chksum_o` to produce the value that belongs in those bytes.
        expected = ones_complement_checksum(header_without_checksum(header))
        observed, check_ok = await tb.run_words(header_words(header_without_checksum(header)))
        assert observed == expected
        assert check_ok == 0


@cocotb.test()
async def validation_mode_accepts_good_and_rejects_bad_headers_test(dut):
    tb = TB(dut)
    await tb.reset()

    good_header = build_syn_header(sequence=0x01, acknowledge=0x02)
    assert checksum_is_valid(good_header)

    # Validation mode feeds the complete header, including checksum.  A correct
    # header should reduce to zero after the RTL's final one's complement.
    observed, check_ok = await tb.run_words(header_words(good_header))
    assert observed == 0
    assert check_ok == 1

    bad_header = bytearray(good_header)
    # Flip a negotiated field without updating the checksum; the same length and
    # structure should now fail only the checksum validation.
    bad_header[5] ^= 0x20
    observed, check_ok = await tb.run_words(header_words(bytes(bad_header)))
    assert observed != 0
    assert check_ok == 0


@cocotb.test()
async def enable_low_and_reset_restart_accumulation_test(dut):
    tb = TB(dut)
    await tb.reset()

    first = header_words(header_without_checksum(build_ack_header(sequence=0x01, acknowledge=0x02)))
    second = header_words(header_without_checksum(build_ack_header(sequence=0xAA, acknowledge=0x55)))

    observed, _ = await tb.run_words(first)
    assert observed == ones_complement_checksum(header_without_checksum(build_ack_header(sequence=0x01, acknowledge=0x02)))

    # Leaving enable low between transactions must discard the previous sum.
    observed, _ = await tb.run_words(second)
    assert observed == ones_complement_checksum(header_without_checksum(build_ack_header(sequence=0xAA, acknowledge=0x55)))

    self_test_header = build_data_header(sequence=0x33, acknowledge=0x44, ack=True)
    self_test_words = header_words(header_without_checksum(self_test_header))
    self_test_expected = ones_complement_checksum(header_without_checksum(self_test_header))

    self_test_word = self_test_words[0]
    # Start a transaction, interrupt it with reset, then prove the next complete
    # transaction is independent of any partial sum.
    dut.enable_i.value = 0
    dut.length_i.value = 1
    dut.init_i.value = 0
    await tb.cycle()
    dut.enable_i.value = 1
    dut.strobe_i.value = 1
    dut.data_i.value = self_test_word
    await tb.cycle()
    dut.rst_i.value = 1
    dut.strobe_i.value = 0
    await tb.cycle(2)
    dut.rst_i.value = 0
    await tb.cycle(2)

    observed, _ = await tb.run_words(self_test_words)
    assert observed == self_test_expected


PARAMETER_SWEEP = [pytest.param({}, id="rssi_64b_checksum")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiChksum(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssichksum",
        parameters=parameters,
        extra_env=parameters,
    )
