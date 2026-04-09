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

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

PGP4_VERSION = 0x04

PGP4_IDLE = 0x99
PGP4_SOF = 0xAA
PGP4_EOF = 0x55
PGP4_SOC = 0xCC
PGP4_EOC = 0x33
PGP4_SKP = 0x66
PGP4_USER = 0x78

PGP4_D_HEADER = 0b01
PGP4_K_HEADER = 0b10


class Pgp4FlatTB:
    def __init__(self, dut, *, clk_name: str = "clk", rst_name: str = "rst"):
        self.dut = dut
        self.clk = getattr(dut, clk_name)
        self.rst = getattr(dut, rst_name)
        cocotb.start_soon(Clock(self.clk, 5.0, unit="ns").start())

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.clk)
            await Timer(1, unit="ns")

    async def reset(self, *, hold_cycles: int = 4, settle_cycles: int = 4):
        self.rst.setimmediatevalue(1)
        await self.cycle(hold_cycles)
        self.rst.value = 0
        await self.cycle(settle_cycles)


def signal_int(dut, name: str) -> int:
    return int(getattr(dut, name).value)


async def wait_for_signal(tb: Pgp4FlatTB, name: str, value: int = 1, cycles: int = 256):
    for _ in range(cycles):
        if signal_int(tb.dut, name) == value:
            return
        await tb.cycle()
    raise AssertionError(f"Timed out waiting for {name}={value}")


def _bit_reverse(value: int, width: int) -> int:
    result = 0
    for bit in range(width):
        if (value >> bit) & 0x1:
            result |= 1 << (width - 1 - bit)
    return result


def pgp4_kcode_crc(word: int) -> int:
    data = (word & ((1 << 48) - 1)) | (((word >> 56) & 0xFF) << 48)
    data = _bit_reverse(data, 56)

    crc = 0xFF
    for bit in range(56):
        feedback = ((crc >> 7) & 0x1) ^ ((data >> bit) & 0x1)
        crc = ((crc << 1) & 0xFF) | feedback
        if feedback:
            crc ^= 0x07

    return (~_bit_reverse(crc, 8)) & 0xFF


def pgp4_link_info(*, rem_link_ready: int = 1, pause_mask: int = 0, version: int = PGP4_VERSION) -> int:
    return (version & 0xFF) | ((rem_link_ready & 0x1) << 8) | ((pause_mask & 0xFFFF) << 16)


def pgp4_kword(btf: int, payload: int = 0) -> int:
    word = ((btf & 0xFF) << 56) | (payload & ((1 << 48) - 1))
    return word | (pgp4_kcode_crc(word) << 48)


def pgp4_idle_word(*, rem_link_ready: int = 1, pause_mask: int = 0, overflow_mask: int = 0) -> int:
    payload = pgp4_link_info(rem_link_ready=rem_link_ready, pause_mask=pause_mask)
    payload |= (overflow_mask & 0xFFFF) << 32
    return pgp4_kword(PGP4_IDLE, payload)


def pgp4_skip_word(skip_data: int) -> int:
    return pgp4_kword(PGP4_SKP, skip_data)


def pgp4_sof_word(*, vc: int = 0, seq: int = 0, rem_link_ready: int = 1, pause_mask: int = 0) -> int:
    payload = pgp4_link_info(rem_link_ready=rem_link_ready, pause_mask=pause_mask)
    payload |= (vc & 0xF) << 32
    payload |= (seq & 0xFFF) << 36
    return pgp4_kword(PGP4_SOF, payload)


def pgp4_eof_word(*, tuser: int = 0, bytes_last: int = 8, crc: int = 0) -> int:
    payload = tuser & 0xFF
    payload |= (bytes_last & 0xF) << 12
    payload |= (crc & 0xFFFFFFFF) << 16
    return pgp4_kword(PGP4_EOF, payload)


def pgp4_user_word(opcode: int) -> int:
    return pgp4_kword(PGP4_USER, opcode)
