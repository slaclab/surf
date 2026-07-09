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

from pathlib import Path

from tests.axi.utils import axil_read_u32, axil_write_u32


ROCE_RTL_ROOT = Path(__file__).resolve().parents[3] / "ethernet" / "RoCEv2" / "rtl"
ROCE_PKG_SOURCE = str(ROCE_RTL_ROOT / "RoCEv2Pkg.vhd")


def roce_rtl_sources(*filenames: str) -> list[str]:
    sources = [ROCE_PKG_SOURCE]
    sources.extend(str(ROCE_RTL_ROOT / filename) for filename in filenames)
    return sources


ROCE_RTL_SOURCES = roce_rtl_sources(
    *(
        path.name
        for path in sorted(ROCE_RTL_ROOT.glob("*.vhd"))
        if path.name != "RoCEv2Pkg.vhd"
    )
)


def range_chunks(data: bytes, *, chunk_bytes: int) -> list[bytes]:
    return [data[index : index + chunk_bytes] for index in range(0, len(data), chunk_bytes)]


def expected_resize_and_swap_bytes(
    data: bytes,
    *,
    slave_bytes: int,
    master_bytes: int,
    swap_endian: bool,
    little_endian: bool,
) -> bytes:
    if slave_bytes == master_bytes:
        chunks = range_chunks(data, chunk_bytes=slave_bytes)
        if swap_endian:
            chunks = [chunk[::-1] for chunk in chunks]
        return b"".join(chunks)

    output_chunks: list[bytes] = []

    if master_bytes > slave_bytes:
        ratio = master_bytes // slave_bytes
        input_chunks = range_chunks(data, chunk_bytes=slave_bytes)
        for index in range(0, len(input_chunks), ratio):
            group = input_chunks[index : index + ratio]
            if swap_endian:
                group = [chunk[::-1] for chunk in group]
            if not little_endian:
                group = list(reversed(group))
            output_chunks.extend(group)
    else:
        ratio = slave_bytes // master_bytes
        input_chunks = range_chunks(data, chunk_bytes=slave_bytes)
        for chunk in input_chunks:
            group = range_chunks(chunk, chunk_bytes=master_bytes)
            if swap_endian:
                group = [part[::-1] for part in group]
            if not little_endian:
                group = list(reversed(group))
            output_chunks.extend(group)

    return b"".join(output_chunks)


def split_u32_words(value: int, *, total_bits: int) -> list[int]:
    word_count = (total_bits + 31) // 32
    return [(value >> (32 * index)) & 0xFFFF_FFFF for index in range(word_count)]


def join_u32_words(words: list[int], *, total_bits: int) -> int:
    value = 0
    for index, word in enumerate(words):
        value |= (word & 0xFFFF_FFFF) << (32 * index)
    if total_bits % 32:
        value &= (1 << total_bits) - 1
    return value


async def axil_write_wide(master, base_address: int, value: int, *, total_bits: int) -> None:
    for index, word in enumerate(split_u32_words(value, total_bits=total_bits)):
        await axil_write_u32(master, base_address + (4 * index), word)


async def axil_read_wide(master, base_address: int, *, total_bits: int) -> int:
    words = []
    for index in range((total_bits + 31) // 32):
        words.append(await axil_read_u32(master, base_address + (4 * index)))
    return join_u32_words(words, total_bits=total_bits)
