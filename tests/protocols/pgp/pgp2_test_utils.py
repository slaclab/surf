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

K_COM = 0xBC
K_LTS = 0x3C
K_FCD = 0xBC
D_102 = 0x4A
D_215 = 0xB5
K_SKP = 0x1C
K_OTS = 0x7C
K_SOC = 0xFB
K_SOF = 0xF7
K_EOF = 0xFD
K_EOFE = 0xFE
K_EOC = 0x5C
PGP2B_ID = 0x5
PGP2FC_ID = 0x7


class PgpModuleTB:
    """Minimal clock/reset harness for leaf PGP2 unit tests.

    Most `pgp2b` and `pgp2fc` leaf benches run directly against one wrapper
    clock domain.  This helper keeps that setup tiny while still making the
    test intent obvious to readers who are not already comfortable with
    cocotb's coroutine model.
    """

    def __init__(self, dut, *, clk_name: str = "clk", rst_name: str = "rst"):
        self.dut = dut
        self.clk = getattr(dut, clk_name)
        self.rst = getattr(dut, rst_name)
        cocotb.start_soon(Clock(self.clk, 5.0, unit="ns").start())

    async def cycle(self, count: int = 1):
        # Sample one nanosecond after each edge so registered outputs have
        # time to reflect the DUT's default `TPD_G`.
        for _ in range(count):
            await RisingEdge(self.clk)
            await Timer(1, unit="ns")

    async def reset(self, *, hold_cycles: int = 4, settle_cycles: int = 4):
        # Using an explicit reset coroutine keeps every test's startup sequence
        # consistent and avoids accidental time-zero races.
        self.rst.setimmediatevalue(1)
        await self.cycle(hold_cycles)
        self.rst.value = 0
        await self.cycle(settle_cycles)


def _int(value) -> int:
    return int(value.value)


def p2b_lts_words(*, rem_link_ready: int = 1, rem_data: int = 0x5A) -> tuple[int, int]:
    word_a = (D_102 << 8) | K_LTS
    word_b = (rem_link_ready << 15) | (0 << 14) | (0 << 12) | (PGP2B_ID << 8) | rem_data
    return word_a, word_b


def p2fc_lts_words(*, rem_link_ready: int = 1, rem_data: int = 0x5A, fc_words: int = 1) -> tuple[int, int]:
    word_a = (D_102 << 8) | K_LTS
    word_b = (
        (rem_link_ready << 15)
        | (((fc_words - 1) & 0x7) << 12)
        | (PGP2FC_ID << 8)
        | rem_data
    )
    return word_a, word_b


async def drive_rx_word(
    tb: PgpModuleTB,
    *,
    data: int,
    data_k: int,
    disp_err: int = 0,
    dec_err: int = 0,
):
    tb.dut.phyRxData.value = data
    tb.dut.phyRxDataK.value = data_k
    tb.dut.phyRxDispErr.value = disp_err
    tb.dut.phyRxDecErr.value = dec_err
    await tb.cycle()


async def wait_for_signal(
    tb: PgpModuleTB,
    signal_name: str,
    *,
    value: int = 1,
    cycles: int = 32,
):
    """Poll a DUT signal for a bounded number of clock cycles.

    cocotb tests should not wait forever.  A bounded helper like this gives a
    clear failure message when a protocol event never arrives, and it also
    keeps the actual test body focused on the protocol story instead of on loop
    mechanics.
    """

    for _ in range(cycles):
        if signal_int(tb.dut, signal_name) == value:
            return
        await tb.cycle()
    raise AssertionError(f"Timed out waiting for {signal_name}={value}")


async def train_p2b_rx_link(tb: PgpModuleTB, *, rem_link_ready: int = 1, rem_data: int = 0x5A, count: int = 256):
    word_a, word_b = p2b_lts_words(rem_link_ready=rem_link_ready, rem_data=rem_data)
    for _ in range(count):
        await drive_rx_word(tb, data=word_a, data_k=0b01)
        await drive_rx_word(tb, data=word_b, data_k=0b00)
    await drive_rx_word(tb, data=0x0000, data_k=0b00)
    await tb.cycle()


async def train_p2fc_rx_link(tb: PgpModuleTB, *, rem_link_ready: int = 1, rem_data: int = 0x5A, fc_words: int = 1, count: int = 256):
    word_a, word_b = p2fc_lts_words(rem_link_ready=rem_link_ready, rem_data=rem_data, fc_words=fc_words)
    for _ in range(count):
        await drive_rx_word(tb, data=word_a, data_k=0b01)
        await drive_rx_word(tb, data=word_b, data_k=0b00)
    await drive_rx_word(tb, data=0x0000, data_k=0b00)
    await tb.cycle()


async def collect_cell_snapshots(
    tb: PgpModuleTB,
    words: list[tuple[int, int]],
    *,
    extra_cycles: int = 4,
):
    """Record wrapper-visible cell markers while a short stream is driven.

    Several receive-path benches need the same style of observation: drive a
    small list of PHY words, then inspect whether `SOF`, `EOC`, payload data,
    or `EOFE` ever became visible.  Packaging that here removes duplicated
    nested snapshot functions from each test file.
    """

    snapshots = []

    def snapshot():
        snapshots.append(
            {
                "sof": signal_int(tb.dut, "cellRxSOF"),
                "soc": signal_int(tb.dut, "cellRxSOC"),
                "eoc": signal_int(tb.dut, "cellRxEOC"),
                "eof": signal_int(tb.dut, "cellRxEOF"),
                "eofe": signal_int(tb.dut, "cellRxEOFE"),
                "data": signal_int(tb.dut, "cellRxData"),
            }
        )

    for data, data_k in words:
        await drive_rx_word(tb, data=data, data_k=data_k)
        snapshot()

    for _ in range(extra_cycles):
        await tb.cycle()
        snapshot()

    return snapshots


def crc7_step(crc: int, data_word: int) -> int:
    q = [(crc >> i) & 1 for i in range(8)]
    d = [(data_word >> i) & 1 for i in range(16)]
    c = [0] * 8
    c[0] = q[2] ^ q[3] ^ q[6] ^ d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[6] ^ d[10] ^ d[11] ^ d[14]
    c[1] = q[3] ^ q[4] ^ q[7] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[7] ^ d[11] ^ d[12] ^ d[15]
    c[2] = q[0] ^ q[4] ^ q[5] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[8] ^ d[12] ^ d[13]
    c[3] = q[1] ^ q[2] ^ q[3] ^ q[5] ^ d[0] ^ d[1] ^ d[2] ^ d[5] ^ d[7] ^ d[9] ^ d[10] ^ d[11] ^ d[13]
    c[4] = q[0] ^ q[2] ^ q[3] ^ q[4] ^ q[6] ^ d[1] ^ d[2] ^ d[3] ^ d[6] ^ d[8] ^ d[10] ^ d[11] ^ d[12] ^ d[14]
    c[5] = q[1] ^ q[3] ^ q[4] ^ q[5] ^ q[7] ^ d[2] ^ d[3] ^ d[4] ^ d[7] ^ d[9] ^ d[11] ^ d[12] ^ d[13] ^ d[15]
    c[6] = q[0] ^ q[2] ^ q[4] ^ q[5] ^ q[6] ^ d[3] ^ d[4] ^ d[5] ^ d[8] ^ d[10] ^ d[12] ^ d[13] ^ d[14]
    c[7] = q[1] ^ q[2] ^ q[5] ^ q[7] ^ d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[5] ^ d[9] ^ d[10] ^ d[13] ^ d[15]
    return sum(bit << i for i, bit in enumerate(c))


def build_p2fc_fc_frame(payload_word: int, *, seed: int = 0x00) -> list[tuple[int, int]]:
    crc = crc7_step(seed, (payload_word & 0x00FF) << 8 | K_FCD)
    crc = crc7_step(crc, (payload_word >> 8) & 0x00FF)
    return [
        ((payload_word & 0x00FF) << 8 | K_FCD, 0b01),
        (((crc & 0xFF) << 8) | ((payload_word >> 8) & 0xFF), 0b00),
    ]


def signal_int(dut, name: str) -> int:
    return _int(getattr(dut, name))
