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

from collections.abc import Sequence

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import sample_after_tpd

from tests.common.regression_utils import (
    env_flag,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


CLOCK_PERIOD_NS = 5.0
INTEGRATION_VALID_OUT_TIMEOUT_CYCLES = 64

K_SYMBOLS_8B10B = [
    0x1C, 0x3C, 0x5C, 0x7C, 0x9C, 0xBC, 0xDC, 0xFC, 0xF7, 0xFB, 0xFD, 0xFE,
]
K_SYMBOLS_10B12B = [
    0x07C, 0x17C, 0x27C, 0x0BC, 0x0DC, 0x13C, 0x15C, 0x19C, 0x1BC,
    0x1DC, 0x23C, 0x25C, 0x29C, 0x2BC, 0x2DC, 0x33C, 0x35C,
]
K_SYMBOLS_12B14B = [
    0x078, 0x0F8, 0x178, 0x1F8, 0x278, 0x3F8, 0x478, 0x5F8,
    0x878, 0x9F8, 0xBF8, 0xC78, 0xDF8, 0xEF8, 0xF78, 0xFF8,
]
DISPARITY_SEEDS_1BIT = [0, 1]
DISPARITY_SEEDS_12B14B = {
    -2: 0b10,
    0: 0b11,
    2: 0b00,
    4: 0b01,
}
TRANSITION_SMOKE_SEQUENCE_12B14B = [
    (0x000, 0), (0xFFF, 0), (0x0BD, 0), (0xEAD, 0), (0x5F8, 1), (0x078, 1),
    (0x1F8, 1), (0x800, 0), (0x555, 0), (0xAAA, 0), (0xFF8, 1),
]
TRAINING_PATTERN_12B14B = [
    (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
    (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
    (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x078, 1), (0x5F8, 1), (0xEAD, 0),
    (0x0BD, 0), (0xEAD, 0), (0x1BD, 0), (0xEAD, 0), (0x2BD, 0), (0xEAD, 0),
    (0x3BD, 0), (0xEAD, 0), (0x4BD, 0), (0xEAD, 0), (0x5BD, 0), (0xEAD, 0),
    (0x6BD, 0), (0xEAD, 0), (0x7BD, 0), (0xEAD, 0), (0x8BD, 0), (0xEAD, 0),
    (0x9BD, 0), (0xEAD, 0), (0xABD, 0), (0xEAD, 0), (0xBBD, 0), (0x5F8, 1),
    (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
]


def default_parameter_sweep():
    return [parameter_case("default_configuration")]


def run_line_code_entity_test(
    *,
    test_file: str,
    toplevel: str,
    parameters: dict[str, object],
) -> None:
    run_surf_vhdl_test(
        test_file=test_file,
        toplevel=toplevel,
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )


def run_line_code_package_test(
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


def run_line_code_integration_test(
    *,
    test_file: str,
    toplevel: str,
    parameters: dict[str, object],
) -> None:
    run_surf_vhdl_test(
        test_file=test_file,
        toplevel=toplevel,
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )


class ClockedLineCodeTB:
    def __init__(self, dut):
        self.dut = dut
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)

        self._set_if_present("rst", self.reset_active_value())
        self._set_if_present("clkEn", 1)
        self._set_if_present("validIn", 0)
        self._set_if_present("readyOut", 1)
        self._set_if_present("dispIn", 0)
        self._set_if_present("dataIn", 0)
        self._set_if_present("dataKIn", 0)

        cocotb.start_soon(Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start())

    def _set_if_present(self, name: str, value: int) -> None:
        signal = getattr(self.dut, name, None)
        if signal is not None:
            signal.value = value

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        self._set_if_present("rst", self.reset_active_value())
        self._set_if_present("validIn", 0)
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(2)
        self._set_if_present("rst", self.reset_inactive_value())
        await self.cycle(1)


async def settle_combinational_line_code_wrapper() -> None:
    await Timer(1, unit="ps")


def signal_width(signal) -> int:
    return len(signal)


def all_ones(signal) -> int:
    return (1 << signal_width(signal)) - 1


def read_signal(dut, *names: str) -> int:
    for name in names:
        signal = getattr(dut, name, None)
        if signal is not None:
            return int(signal.value)
    raise AttributeError(f"None of the signals exist: {names}")


def error_detected(dut) -> bool:
    return (
        read_signal(dut, "codeErr", "codeError") != 0
        or read_signal(dut, "dispErr", "dispError") != 0
    )


async def drive_integration_symbol(dut, *, data_in: int, data_k_in: int) -> None:
    dut.dataIn.value = data_in
    dut.dataKIn.value = data_k_in
    dut.validIn.value = 1
    await RisingEdge(dut.clk)
    dut.validIn.value = 0

    for _ in range(INTEGRATION_VALID_OUT_TIMEOUT_CYCLES):
        if int(dut.validOut.value) == 1:
            return
        await sample_after_tpd(dut.clk)

    raise AssertionError(
        f"Timed out waiting for validOut after {INTEGRATION_VALID_OUT_TIMEOUT_CYCLES} cycles"
    )


def assert_integration_round_trip(dut, *, data_in: int, data_k_in: int) -> None:
    assert int(dut.dataOut.value) == data_in
    assert int(dut.dataKOut.value) == data_k_in
    assert read_signal(dut, "codeErr", "codeError") == 0
    assert read_signal(dut, "dispErr", "dispError") == 0


async def run_integration_round_trip_test(
    dut,
    *,
    sequences: Sequence[tuple[int, int]],
) -> None:
    tb = ClockedLineCodeTB(dut)
    await tb.reset()

    for data_in, data_k_in in sequences:
        await drive_integration_symbol(dut, data_in=data_in, data_k_in=data_k_in)
        assert_integration_round_trip(dut, data_in=data_in, data_k_in=data_k_in)


async def _drive_package_encode(dut, *, disp_in: int, data_in: int, data_k_in: int) -> None:
    dut.encDispIn.value = disp_in
    dut.encDataIn.value = data_in
    dut.encDataKIn.value = data_k_in
    await settle_combinational_line_code_wrapper()


async def package_encode(dut, *, disp_in: int, data_in: int, data_k_in: int) -> tuple[int, int]:
    await _drive_package_encode(dut, disp_in=disp_in, data_in=data_in, data_k_in=data_k_in)
    return (
        int(dut.encDataOut.value),
        int(dut.encDispOut.value),
    )


async def package_encode_with_invalid_k(
    dut,
    *,
    disp_in: int,
    data_in: int,
    data_k_in: int,
) -> tuple[int, int, int]:
    await _drive_package_encode(dut, disp_in=disp_in, data_in=data_in, data_k_in=data_k_in)
    if not hasattr(dut, "invalidK"):
        raise AttributeError("Package wrapper does not expose invalidK")
    return (
        int(dut.encDataOut.value),
        int(dut.encDispOut.value),
        int(dut.invalidK.value),
    )


async def package_decode(dut, *, disp_in: int, encoded_data: int) -> None:
    dut.decDispIn.value = disp_in
    dut.decDataIn.value = encoded_data
    await settle_combinational_line_code_wrapper()


def assert_package_decode_matches(dut, *, data_in: int, data_k_in: int, expected_disp: int) -> None:
    assert int(dut.decDataOut.value) == data_in
    assert int(dut.decDataKOut.value) == data_k_in
    assert read_signal(dut, "codeErr", "codeError") == 0
    assert read_signal(dut, "dispErr", "dispError") == 0
    assert int(dut.decDispOut.value) == expected_disp
