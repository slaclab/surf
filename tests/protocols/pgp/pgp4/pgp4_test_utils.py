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

from tests.common.regression_utils import sample_after_tpd

from tests.axi.utils import wait_sampled_ready

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
            await sample_after_tpd(self.clk)

    async def reset(self, *, hold_cycles: int = 4, settle_cycles: int = 4):
        self.rst.setimmediatevalue(1)
        await self.cycle(hold_cycles)
        self.rst.value = 0
        await self.cycle(settle_cycles)


def signal_int(dut, name: str) -> int:
    return int(getattr(dut, name).value)


def initialize_signals(dut, **values):
    """Drive a set of DUT inputs to known startup values immediately.

    Cocotb beginners often repeat small blocks of `setimmediatevalue()` calls
    at the top of every test.  Centralizing that pattern keeps the individual
    benches focused on behavior and makes it obvious which ports are part of
    the wrapper's external contract.
    """

    for name, value in values.items():
        getattr(dut, name).setimmediatevalue(value)


async def wait_for_signal(tb: Pgp4FlatTB, name: str, value: int = 1, cycles: int = 256):
    for _ in range(cycles):
        if signal_int(tb.dut, name) == value:
            return
        await tb.cycle()
    raise AssertionError(f"Timed out waiting for {name}={value}")


def initialize_flat_tx_inputs(dut, *, include_opcode: bool = False):
    """Drive the common flat PGP4 transmit inputs to a known idle state."""

    initialize_signals(
        dut,
        txValid=0,
        txData=0,
        txSof=0,
        txEof=0,
        txEofe=0,
    )
    if include_opcode:
        initialize_signals(dut, opCodeEn=0, opCodeData=0)


def tb_sample_clk(tb):
    clk = getattr(tb, "clk", None)
    if clk is not None:
        return clk

    clk = getattr(tb, "cycle_clk", None)
    if clk is not None:
        return clk

    raise AttributeError(f"{type(tb).__name__} does not expose a sampling clock handle")


async def send_opcode(tb: Pgp4FlatTB, opcode: int):
    """Pulse one opcode request through the flat PGP4 wrapper interface."""

    tb.dut.opCodeData.value = opcode
    tb.dut.opCodeEn.value = 1
    await tb.cycle()
    tb.dut.opCodeEn.value = 0


async def collect_valid_beats(
    tb,
    *,
    valid_name: str,
    field_names: tuple[str, ...],
    count: int,
    cycles: int = 256,
    predicate=None,
) -> list[tuple[int, ...]]:
    """Collect a bounded number of visible valid beats from a flat wrapper.

    Many PGP4 wrappers expose pulse-style outputs rather than queue-like
    interfaces.  This helper samples those outputs once per local clock and
    returns the named fields for each cycle where `valid_name` was asserted.
    An optional `predicate` can filter out background IDLE traffic.
    """

    beats = []
    for _ in range(cycles):
        await tb.cycle()
        if signal_int(tb.dut, valid_name) != 1:
            continue
        beat = tuple(signal_int(tb.dut, name) for name in field_names)
        if predicate is not None and not predicate(*beat):
            continue
        beats.append(beat)
        if len(beats) >= count:
            return beats[:count]
    raise AssertionError(f"Timed out collecting {count} beats from {valid_name}")


async def wait_for_nonzero_output(
    tb,
    *,
    valid_name: str,
    data_name: str,
    cycles: int = 256,
) -> int:
    """Wait for the first valid beat whose payload is non-zero."""

    beats = await collect_valid_beats(
        tb,
        valid_name=valid_name,
        field_names=(data_name,),
        count=1,
        cycles=cycles,
        predicate=lambda data: data != 0,
    )
    return beats[0][0]


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
    await wait_sampled_ready(getattr(tb.dut, ready_name), clk=tb_sample_clk(tb), timeout_cycles=cycles)
    tb.dut.txValid.value = 0
    tb.dut.txSof.value = 0
    tb.dut.txEof.value = 0
    tb.dut.txEofe.value = 0


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
    words = await collect_valid_beats(
        tb,
        valid_name="protTxValid",
        field_names=("protTxHeader", "protTxData"),
        count=1,
        cycles=cycles,
        predicate=is_non_idle_protocol_word,
    )
    return words[0]


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
