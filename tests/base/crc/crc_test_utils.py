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

import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import env_flag, env_hex, env_sl


CRC32_POLY = 0x04C11DB7


def reverse_bits(value: int, width: int) -> int:
    result = 0
    for bit in range(width):
        if value & (1 << bit):
            result |= 1 << (width - 1 - bit)
    return result


def crc_byte_lookup(byte_value: int, *, poly: int = CRC32_POLY) -> int:
    # This mirrors the VHDL `crcByteLookup()` helper directly instead of using a
    # library CRC call. That keeps the Python model aligned with SURF's exact
    # byte ordering and polynomial handling.
    crc = (byte_value & 0xFF) << 24
    for _ in range(8):
        if crc & 0x80000000:
            crc = ((crc << 1) & 0xFFFFFFFF) ^ poly
        else:
            crc = (crc << 1) & 0xFFFFFFFF
    return crc


def crc_update(remainder: int, data_bytes: list[int], *, poly: int = CRC32_POLY) -> int:
    # The VHDL first reverses the bits within each active byte and only then
    # feeds the transformed bytes through the CRC recurrence.
    crc = remainder & 0xFFFFFFFF
    for byte_value in data_bytes:
        reflected_byte = reverse_bits(byte_value & 0xFF, 8)
        byte_xor = ((crc >> 24) & 0xFF) ^ reflected_byte
        crc = ((crc << 8) & 0xFFFFFFFF) ^ crc_byte_lookup(byte_xor, poly=poly)
    return crc


def crc_out_from_remainder(remainder: int) -> int:
    # The RTL keeps each byte in place, reverses the bit order within that byte,
    # and then inverts the result before driving `crcOut`.
    output_word = 0
    for output_byte in range(4):
        internal_byte = (remainder >> (8 * output_byte)) & 0xFF
        transformed = reverse_bits((~internal_byte) & 0xFF, 8)
        output_word |= transformed << (8 * output_byte)
    return output_word


def pack_active_bytes(data_bytes: list[int], *, byte_width: int) -> int:
    # When the CRC blocks process fewer bytes than the full bus width, they
    # expect the active bytes in the most-significant lanes of the input bus.
    value = 0
    for index, byte_value in enumerate(data_bytes):
        shift = 8 * (byte_width - 1 - index)
        value |= (byte_value & 0xFF) << shift
    return value


class CrcStreamingTB:
    def __init__(self, dut):
        self.dut = dut
        self.byte_width = int(os.environ["BYTE_WIDTH_G"])
        self.input_register = env_flag("INPUT_REGISTER_G", default=True)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.crc_poly = env_hex("CRC_POLY_G", default=CRC32_POLY)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        # Drive all inputs to a known starting state before time begins.
        dut.crcPwrOnRst.value = self.reset_active_value()
        dut.crcDataValid.value = 0
        dut.crcDataWidth.value = 0
        dut.crcIn.value = 0
        dut.crcInit.value = 0xFFFFFFFF
        dut.crcReset.value = 0

        # All three CRC-style tests use the same clocking pattern, so the
        # shared helper starts the free-running clock once.
        cocotb.start_soon(Clock(dut.crcClk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        # These RTL blocks schedule output updates using `TPD_G => 1 ns`, so a
        # short post-edge pause keeps the assertions from sampling too early.
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.crcClk)
            await self.settle()

    async def power_on_reset(self) -> None:
        # This helper exercises the dedicated power-on reset input that clears
        # the registered remainder state.
        self.dut.crcPwrOnRst.value = self.reset_active_value()

        if self.async_reset:
            await Timer(2, unit="ns")
            await self.cycle(3)
        else:
            await self.cycle(3)

        self.dut.crcPwrOnRst.value = self.reset_inactive_value()
        await self.cycle(1)

    async def apply_transaction(
        self,
        data_bytes: list[int],
        *,
        init_override: int | None = None,
        request_crc_reset: bool = False,
    ) -> tuple[int, int]:
        # Put the selected byte payload into the most-significant active byte
        # lanes exactly the way the VHDL expects to see it.
        self.dut.crcDataValid.value = 1 if data_bytes else 0
        self.dut.crcDataWidth.value = max(len(data_bytes) - 1, 0)
        self.dut.crcIn.value = pack_active_bytes(data_bytes, byte_width=self.byte_width)
        self.dut.crcReset.value = 1 if request_crc_reset else 0

        if init_override is not None:
            self.dut.crcInit.value = init_override

        # The transaction itself is accepted on a clock edge.
        await RisingEdge(self.dut.crcClk)

        # Drop the one-cycle strobes immediately after the active edge so the
        # next operation starts from a clean idle state.
        self.dut.crcDataValid.value = 0
        self.dut.crcReset.value = 0
        await self.settle()

        # When `INPUT_REGISTER_G` is enabled, the input word is first captured
        # into an internal register and only consumed on the following cycle.
        if self.input_register:
            await self.cycle(1)

        return int(self.dut.crcRem.value), int(self.dut.crcOut.value)
