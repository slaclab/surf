##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from __future__ import annotations

from collections.abc import Iterable, Sequence

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


CLOCK_PERIOD_NS = 5.0


async def initialize_line_code_dut(dut) -> None:
    dut.rst.value = 1
    dut.validIn.value = 0
    dut.dataIn.value = 0
    dut.dataKIn.value = 0

    # All three line-code wrappers use the same single-clock launch/observe
    # pattern, so one shared startup helper keeps the family benches aligned.
    cocotb.start_soon(Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start())
    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def drive_line_code_symbol(dut, data_in: int, data_k_in: int) -> None:
    # Present one input symbol for exactly one cycle so the wrapper benches
    # behave like the original single-beat VHDL testbeds.
    dut.dataIn.value = data_in
    dut.dataKIn.value = data_k_in
    dut.validIn.value = 1
    await RisingEdge(dut.clk)
    dut.validIn.value = 0

    # Wait on the wrapper's registered decode result instead of hard-coding a
    # specific pipeline depth for each family.
    while int(dut.validOut.value) != 1:
        await RisingEdge(dut.clk)


def assert_line_code_round_trip(dut, data_in: int, data_k_in: int) -> None:
    assert int(dut.dataOut.value) == data_in
    assert int(dut.dataKOut.value) == data_k_in
    assert int(dut.codeErr.value) == 0
    assert int(dut.dispErr.value) == 0


async def run_line_code_round_trip_test(
    dut,
    *,
    normal_symbols: Iterable[int],
    k_symbols: Iterable[int],
    extra_sequences: Sequence[tuple[int, int]] = (),
) -> None:
    await initialize_line_code_dut(dut)

    # Sweep the ordinary data space first so each family proves the full
    # non-control payload range before checking the legal K-symbol subset.
    for data_in in normal_symbols:
        await drive_line_code_symbol(dut, data_in, 0)
        assert_line_code_round_trip(dut, data_in, 0)

    for data_in in k_symbols:
        await drive_line_code_symbol(dut, data_in, 1)
        assert_line_code_round_trip(dut, data_in, 1)

    # Some families carry historical alignment or training patterns that are
    # worth preserving as explicit integration sequences beyond the pure sweep.
    for data_in, data_k_in in extra_sequences:
        await drive_line_code_symbol(dut, data_in, data_k_in)
        assert_line_code_round_trip(dut, data_in, data_k_in)


def default_wrapper_parameter_sweep():
    return [parameter_case("default_configuration")]


def run_line_code_wrapper_test(
    *,
    test_file: str,
    toplevel: str,
    wrapper_source: str,
    parameters: dict[str, object],
) -> None:
    run_surf_vhdl_test(
        test_file=test_file,
        toplevel=toplevel,
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": [wrapper_source]},
    )


async def settle_combinational_line_code_wrapper() -> None:
    # Package-level wrappers are purely combinational, so a zero-delay yield is
    # enough in principle, but cocotb 2 requires a strictly positive timer.
    await Timer(1, unit="ps")
