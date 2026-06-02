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

from collections import deque

from cocotb.triggers import RisingEdge, Timer

SIM_SETTLE_NS = 2


async def tick(clk, *, count: int = 1, settle_ns: int = SIM_SETTLE_NS) -> None:
    for _ in range(count):
        await RisingEdge(clk)
        await Timer(settle_ns, unit="ns")


def signed_samples(width: int) -> list[int]:
    minimum = -(1 << (width - 1))
    maximum = (1 << (width - 1)) - 1
    candidates = {
        minimum,
        minimum + 1,
        -3,
        -2,
        -1,
        0,
        1,
        2,
        3,
        maximum - 1,
        maximum,
    }
    return sorted(value for value in candidates if minimum <= value <= maximum)


def to_unsigned(value: int, width: int) -> int:
    return value & ((1 << width) - 1)


def to_signed_int(raw: int, width: int) -> int:
    sign_bit = 1 << (width - 1)
    masked = raw & ((1 << width) - 1)
    if masked & sign_bit:
        return masked - (1 << width)
    return masked


def truncate_signed(value: int, width: int) -> int:
    return to_signed_int(value, width)


def arithmetic_shift_truncate(value: int, *, shift: int, width: int) -> int:
    shifted = value if shift == 0 else (value >> shift)
    return truncate_signed(shifted, width)


def fir_direct_outputs(samples: list[int], coeffs: list[int], *, data_width: int, coeff_width: int) -> list[int]:
    history = deque([0] * len(coeffs), maxlen=len(coeffs))
    outputs: list[int] = []
    for sample in samples:
        history.appendleft(sample)
        accum = sum(history[index] * coeffs[index] for index in range(len(coeffs)))
        outputs.append(
            arithmetic_shift_truncate(
                accum,
                shift=max(0, coeff_width - 1),
                width=data_width,
            )
        )
    return outputs


def boxcar_reference(
    samples: list[int],
    *,
    window_size: int,
    signed: bool,
    data_width: int,
    addr_width: int,
) -> list[tuple[int, int, int]]:
    history = deque([], maxlen=window_size)
    outputs: list[tuple[int, int, int]] = []
    accum_width = data_width + addr_width

    for index, sample in enumerate(samples, start=1):
        history.append(sample)
        total = sum(history)
        outputs.append(
            (
                truncate_signed(total, accum_width),
                int(index >= window_size),
                int(index % window_size == 0),
            )
        )

    if not signed:
        return outputs

    return [
        (truncate_signed(total, accum_width), full, period)
        for total, full, period in outputs
    ]


def boxcar_filter_reference(
    samples: list[int],
    *,
    window_size: int,
    signed: bool,
    data_width: int,
    addr_width: int,
) -> list[tuple[int, int, int]]:
    return [
        (
            arithmetic_shift_truncate(total, shift=addr_width, width=data_width),
            full,
            period,
        )
        for total, full, period in boxcar_reference(
            samples,
            window_size=window_size,
            signed=signed,
            data_width=data_width,
            addr_width=addr_width,
        )
    ]


def pack_words_le(words: list[int], *, word_width: int) -> bytes:
    word_bytes = (word_width + 7) // 8
    return b"".join(to_unsigned(word, word_width).to_bytes(word_bytes, "little") for word in words)


def unpack_words_le(data: bytes, *, word_width: int, count: int) -> list[int]:
    word_bytes = (word_width + 7) // 8
    return [
        int.from_bytes(data[index * word_bytes : (index + 1) * word_bytes], "little")
        for index in range(count)
    ]
