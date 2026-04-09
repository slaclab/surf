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
    """Single-clock helper for the direct PGP4 leaf wrappers.

    The PGP4 leaf tests mostly interact with wrappers that expose a flat set of
    scalar ports instead of AXI record types.  This helper keeps the common
    clock/reset logic in one place so each test can spend its lines on the
    actual protocol behavior under test.
    """

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


def initialize_flat_tx_inputs(dut, *, include_opcode: bool = False):
    """Drive the common flat PGP4 transmit inputs to a known idle state."""

    dut.txValid.setimmediatevalue(0)
    dut.txData.setimmediatevalue(0)
    dut.txSof.setimmediatevalue(0)
    dut.txEof.setimmediatevalue(0)
    dut.txEofe.setimmediatevalue(0)
    if include_opcode:
        dut.opCodeEn.setimmediatevalue(0)
        dut.opCodeData.setimmediatevalue(0)


async def send_single_word_frame(tb, *, payload: int, eofe: int = 0, ready_name: str = "txReady", cycles: int = 64):
    """Drive one single-beat SSI-style frame into a flat wrapper interface.

    Even though the source frame is only one word wide, the helper still
    respects the DUT's `txReady` handshake.  That makes the code match the real
    interface contract and keeps the tests robust if internal buffering changes.
    """

    tb.dut.txValid.value = 1
    tb.dut.txData.value = payload
    tb.dut.txSof.value = 1
    tb.dut.txEof.value = 1
    tb.dut.txEofe.value = eofe
    await wait_for_signal(tb, ready_name, cycles=cycles)
    await tb.cycle()
    tb.dut.txValid.value = 0
    tb.dut.txSof.value = 0
    tb.dut.txEof.value = 0
    tb.dut.txEofe.value = 0


async def send_single_word_frame_and_capture(
    tb,
    *,
    payload: int,
    eofe: int = 0,
    rx_valid_name: str = "rxValid",
    rx_data_name: str = "rxData",
    rx_last_name: str = "rxLast",
    ready_name: str = "txReady",
    cycles: int = 1024,
) -> tuple[int, int]:
    """Send one beat and capture the first returned flat RX beat.

    The receive pulse can be much narrower than the user's mental model of a
    "frame completed" event.  Sampling during the handshake window avoids the
    common beginner mistake of checking the receive side too late and missing a
    valid one-cycle indication.
    """

    tb.dut.txValid.value = 1
    tb.dut.txData.value = payload
    tb.dut.txSof.value = 1
    tb.dut.txEof.value = 1
    tb.dut.txEofe.value = eofe

    accepted = False
    captured = None
    for _ in range(cycles):
        await tb.cycle()
        if signal_int(tb.dut, rx_valid_name) == 1:
            captured = (
                signal_int(tb.dut, rx_data_name),
                signal_int(tb.dut, rx_last_name),
            )
        if not accepted and signal_int(tb.dut, ready_name) == 1:
            accepted = True
            tb.dut.txValid.value = 0
            tb.dut.txSof.value = 0
            tb.dut.txEof.value = 0
            tb.dut.txEofe.value = 0
        if accepted and captured is not None:
            return captured

    raise AssertionError("Timed out waiting for RX frame capture")


def btf(word: int) -> int:
    return (word >> 56) & 0xFF


def is_non_idle_protocol_word(header: int, data: int) -> bool:
    """Return True when a protocol word is meaningful test traffic.

    Direct protocol wrappers emit background IDLE words between the events we
    actually care about.  Filtering those out keeps the test assertions focused
    on opcodes and frame words instead of on wrapper-specific background noise.
    """

    return header == PGP4_D_HEADER or btf(data) != PGP4_IDLE


async def wait_for_non_idle_protocol_word(tb, *, cycles: int = 256) -> tuple[int, int]:
    for _ in range(cycles):
        await tb.cycle()
        if signal_int(tb.dut, "protTxValid") != 1:
            continue
        header = signal_int(tb.dut, "protTxHeader")
        data = signal_int(tb.dut, "protTxData")
        if is_non_idle_protocol_word(header, data):
            return header, data
    raise AssertionError("Timed out waiting for non-IDLE protocol word")


async def send_single_word_frame_and_collect_protocol_words(
    tb,
    *,
    payload: int,
    eofe: int = 0,
    count: int = 3,
    cycles: int = 64,
) -> list[tuple[int, int]]:
    """Send one beat and collect the visible non-IDLE protocol words it emits."""

    tb.dut.txValid.value = 1
    tb.dut.txData.value = payload
    tb.dut.txSof.value = 1
    tb.dut.txEof.value = 1
    tb.dut.txEofe.value = eofe

    accepted = False
    words = []
    for _ in range(cycles):
        await tb.cycle()
        if signal_int(tb.dut, "protTxValid") == 1:
            header = signal_int(tb.dut, "protTxHeader")
            data = signal_int(tb.dut, "protTxData")
            if is_non_idle_protocol_word(header, data):
                words.append((header, data))
        if not accepted and signal_int(tb.dut, "txReady") == 1:
            accepted = True
            tb.dut.txValid.value = 0
            tb.dut.txSof.value = 0
            tb.dut.txEof.value = 0
            tb.dut.txEofe.value = 0
        if accepted and len(words) >= count:
            return words[:count]

    raise AssertionError("Timed out collecting protocol words")


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
