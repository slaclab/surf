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

import functools
import zlib

import cocotb
from cocotb.triggers import RisingEdge, Timer

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.base.crc.crc_test_utils import crc_byte_lookup, reverse_bits


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


# The helpers below are the independent correctness reference for the native
# VHDL iCRC engine. They share no code with the VHDL package or the engine:
# the Send-direction path is CPython stdlib `zlib.crc32` precisely so a
# misunderstanding shared between the RTL and a from-scratch Python
# transliteration of that same RTL can never pass a check vacuously. Only two
# helpers are reused from
# `tests.base.crc.crc_test_utils`, both of which mirror the VHDL byte-level
# primitives directly rather than any higher-level CRC transform:
# `crc_byte_lookup` (the single-byte shift-and-XOR step) and `reverse_bits`
# (a plain bit-order reversal over an arbitrary width).

CRC32_POLY = 0x04C11DB7


def icrc_reflect32(value: int) -> int:
    """Reflect a 32-bit CRC remainder the way the whole-word final output
    transform does: reverse all 32 bits end to end, then invert the result.

    This is deliberately not `tests.base.crc.crc_test_utils.crc_out_from_remainder`,
    which reflects each of the four bytes in place (bit 7 of byte 0 swaps
    with bit 0 of byte 0, never with a bit of byte 3) and therefore never
    reorders the bytes themselves; the two are a byte swap apart. Measured
    on remainder `0xbc78e776`: this function returns `0x9118e1c2`, that
    helper returns `0xc2e11891`. `zlib.crc32` and the Bluespec-generated CRC
    Verilog this engine replaced both use the whole-word transform this
    function implements, which is why the Send and Recv references below are
    built on `zlib.crc32` rather than on the per-byte helper.
    """
    value &= 0xFFFFFFFF
    return (~reverse_bits(value, 32)) & 0xFFFFFFFF


@functools.lru_cache(maxsize=None)
def _icrc_table_cached(tab_index: int) -> tuple[int, ...]:
    values = []
    for byte_value in range(256):
        word = byte_value
        # Zero iterations for tab_index == 0: table 0 is the recurrence's
        # base case and is the identity map, value(0, b) == b. Iterating
        # tab_index + 1 times instead of tab_index times computes
        # value(tab_index + 1, b), which is the off-by-one this recurrence
        # must not reproduce; it elaborates cleanly and yields a wrong CRC
        # for every packet.
        for _ in range(tab_index):
            word = ((word << 8) & 0xFFFFFFFF) ^ crc_byte_lookup((word >> 24) & 0xFF)
        values.append(word)
    return tuple(values)


def icrc_table(tab_index: int) -> list[int]:
    """Return table `tab_index`'s 256 entries, `value(tab_index, b)` for
    `b` in 0 through 255, where `value(k, b)` starts from `v = b` and
    iterates `v = ((v << 8) & 0xFFFFFFFF) ^ crc_byte_lookup((v >> 24) & 0xFF)`
    exactly `k` times (zero iterations for `k == 0`). Equivalently,
    `value(k, b)` is `b * x**(8*k) mod 0x104C11DB7` over GF(2).

    The underlying computation is cached (`functools.lru_cache`) so the
    9,216-value recurrence proof does not recompute every table on every
    call; each call here returns a fresh list copy of the cached tuple so a
    caller mutating its own return value can never corrupt the cache.
    """
    return list(_icrc_table_cached(tab_index))


def icrc_send_reference(payload: bytes) -> int:
    """Return the Send-direction iCRC word for `payload`, the CRC-32 of the
    wire-byte payload exactly as `zlib.crc32` computes it.

    Measured against the Bluespec-generated Send CRC Verilog this engine
    replaced, before that source was retired from this repository: a
    64-byte payload `bytes(range(64))` over two full beats gives
    `0x100ece8c`; a single beat with `s_axis_tkeep = 0x000003ff` carrying
    wire bytes `04 05 06 07 08 09 00 00 00 00` gives `0x427d5a56`; a single
    beat with a non-contiguous `s_axis_tkeep = 0x000003fd` over wire bytes
    `00 01 ... 09` gives `0x5217c305`, which equals `zlib.crc32` of the same
    payload with byte 1 replaced by zero. All three equal `zlib.crc32` of
    the corresponding payload.
    """
    return zlib.crc32(payload) & 0xFFFFFFFF


def icrc_recv_reference(message: bytes) -> int:
    """Return the Recv-direction iCRC residue for `message`, a message
    carrying its own trailing four-byte CRC word.

    The closed form is `zlib.crc32(message[:-4]) XOR
    int.from_bytes(message[-4:], "little")`. Measured against the
    Bluespec-generated Recv CRC Verilog this engine replaced, before that
    source was retired from this repository: `bytes(range(10))` plus its
    own correct CRC little-endian gives `0x00000000`; the same ten bytes
    plus four zero bytes instead gives `0x456cd746`, the plain checksum;
    `bytes(range(64))` plus its own correct CRC little-endian gives
    `0x00000000`; `bytes(range(64))` alone gives `0x8fd242d2`.

    The all-zero residue for a message carrying its own correct CRC
    little-endian is exactly what `EthMacRxCheckICrc.vhd`'s
    `or_reduce(ibCrcM.tData(31 downto 0)) = '0'` pass condition tests, and
    appending four zero bytes instead is a different, equally valid use of
    the same mode: it returns the plain checksum of the message. Byte order
    is load-bearing here: appending the same 64-byte payload's correct CRC
    big-endian instead of little-endian gives `0x9cc0c09c`, not zero, so
    nothing may change that trailer byte order.

    Raises `ValueError` naming the message length when `message` is shorter
    than 4 bytes: there is no CRC trailer to split off.
    """
    if len(message) < 4:
        raise ValueError(f"message must be at least 4 bytes to hold a CRC trailer, got {len(message)}")
    trailer = int.from_bytes(message[-4:], "little")
    return (zlib.crc32(message[:-4]) ^ trailer) & 0xFFFFFFFF


def icrc_beats_from_payload(payload: bytes) -> list[dict[str, int]]:
    """Chunk `payload` into 32-byte AXI-Stream beats.

    Wire byte `j` of each chunk is placed at bits `8*j+7 downto 8*j` of
    `s_axis_tdata` (little-endian packing). `s_axis_tkeep` is `(1 << n) - 1`
    for an `n`-byte chunk (`0xFFFFFFFF` for a full 32-byte beat).
    `s_axis_tlast` is 1 only on the final beat, 0 otherwise.
    `s_axis_tuser` is always 0.

    Raises `ValueError` for an empty payload: there is no beat to emit.
    """
    if not payload:
        raise ValueError("payload must hold at least one byte")
    beats = []
    for offset in range(0, len(payload), 32):
        chunk = payload[offset : offset + 32]
        is_last = offset + 32 >= len(payload)
        beats.append(
            {
                "s_axis_tdata": int.from_bytes(chunk, "little"),
                "s_axis_tkeep": (1 << len(chunk)) - 1,
                "s_axis_tlast": 1 if is_last else 0,
                "s_axis_tuser": 0,
            }
        )
    return beats


def payload_from_recorded_beats(beats: list[dict[str, int]]) -> list[bytes]:
    """Reconstruct one payload per packet from a beat list shaped like
    `icrc_beats_from_payload`'s own output: contiguous `s_axis_tkeep`
    starting at lane 0, with every non-final beat full (`s_axis_tkeep ==
    0xFFFFFFFF`). This is the exact inverse of `icrc_beats_from_payload`
    across every payload length it can produce.

    Splits the beat list into one payload per packet at each beat carrying
    `s_axis_tlast == 1`, masking `s_axis_tdata` by `s_axis_tkeep` and taking
    the kept bytes in ascending lane order.

    Raises `ValueError` naming the beat index when a non-final beat's
    `s_axis_tkeep` is not all ones, or when any beat's `s_axis_tkeep` is not
    contiguous from lane 0. Use `masked_payload_from_recorded_beats` instead
    for an arbitrary `s_axis_tkeep`.
    """
    payloads = []
    current = bytearray()
    for index, beat in enumerate(beats):
        tkeep = beat["s_axis_tkeep"] & 0xFFFFFFFF
        is_last = bool(beat.get("s_axis_tlast", 0))
        nlanes = tkeep.bit_length()
        if tkeep != (1 << nlanes) - 1:
            raise ValueError(f"beat {index}: s_axis_tkeep {tkeep:#010x} is not contiguous from lane 0")
        if not is_last and tkeep != 0xFFFFFFFF:
            raise ValueError(f"beat {index}: non-final beat has non-full s_axis_tkeep {tkeep:#010x}")
        chunk = beat["s_axis_tdata"].to_bytes(32, "little")[:nlanes]
        current.extend(chunk)
        if is_last:
            payloads.append(bytes(current))
            current = bytearray()
    return payloads


def masked_payload_from_recorded_beats(beats: list[dict[str, int]]) -> list[bytes]:
    """Reconstruct one payload per packet from a beat list carrying an
    **arbitrary** `s_axis_tkeep`, the byte string the engine effectively
    computes over.

    Within a beat, lane `i` of the shifted word carries the byte at that
    beat's own message position counted back from the end of the beat's own
    32-byte window, and the running CRC advances by exactly 32 byte
    positions on every beat regardless of how many lanes were valid. So a
    non-final beat with `nlanes` valid lanes (one plus the index of the
    highest set `s_axis_tkeep` bit, or 0 when `s_axis_tkeep` is zero)
    contributes `32 - nlanes` zero bytes **before** its valid bytes, not
    after them, with every masked lane within those `nlanes` replaced by
    zero. On the packet's final beat, the intermediate-CRC shift in the
    last pipeline stage cancels those leading zeros, so the final beat
    contributes only its `nlanes` valid lanes with masked lanes zeroed.

    Padding at the trailing end instead of the leading end is a defect that
    passes every single-beat and every full-beat case and fails only on a
    multi-beat packet with a partial non-final beat, which is exactly why
    this rule was measured against the real datapath rather than reasoned
    about: 400 random multi-beat streams with fully random 32-bit
    `s_axis_tkeep` on every beat gave 0 mismatches against `zlib.crc32` for
    Send and 0 mismatches against the Recv closed form over 200 contiguous-
    keep streams, while the trailing-padding variant mismatched on 159 of
    300 streams.

    Agrees with `payload_from_recorded_beats` whenever every beat's
    `s_axis_tkeep` is contiguous and every non-final beat is full, the only
    shape `icrc_beats_from_payload` produces.
    """
    payloads = []
    current = bytearray()
    for beat in beats:
        tkeep = beat["s_axis_tkeep"] & 0xFFFFFFFF
        tdata = beat["s_axis_tdata"]
        is_last = bool(beat.get("s_axis_tlast", 0))
        nlanes = tkeep.bit_length()
        lane_bytes = bytearray(nlanes)
        for lane in range(nlanes):
            if tkeep & (1 << lane):
                lane_bytes[lane] = (tdata >> (8 * lane)) & 0xFF
        if is_last:
            current.extend(lane_bytes)
            payloads.append(bytes(current))
            current = bytearray()
        else:
            current.extend(b"\x00" * (32 - nlanes))
            current.extend(lane_bytes)
    return payloads


def _bit_string(value) -> str:
    # A scalar signal resolves to cocotb's single-value `Logic` type rather
    # than `LogicArray`, which has no `.binstr`; `str()` gives the same bit
    # string either way.
    return value.binstr if hasattr(value, "binstr") else str(value)


def _is_defined(bits: str) -> bool:
    return all(bit in "01" for bit in bits)


class IcrcProtocolChecker:
    """Bench-side AXI-Stream-like protocol legality checker for
    RoCEv2ICrc's handshake pair.

    Comparing each packet's CRC word against a reference proves the value is
    right, but it cannot see a handshake that is illegal in a way that never
    disturbs that value: valid glitching to X, valid withdrawn before its own
    acceptance, the payload changing while valid waits, or more than one word
    produced per packet. This class samples the DUT every cycle and records a
    violation string for each such event; it asserts nothing itself, so a
    caller can inspect every violation found rather than stopping at the first.

    Deliberately not in tests/common/: this class's own one-word-per-tlast
    property is specific to this engine's non-AXI-Stream output side, a bare
    valid/ready/data triple rather than a full AXI-Stream master.

    Hardcodes RoCEv2ICrc's own port names (s_axis_tvalid, s_axis_tready,
    s_axis_tlast, m_crc_stream_valid, m_crc_stream_ready, m_crc_stream_data,
    RST_N) rather than taking them as constructor arguments: this checker
    is specific to this one engine, not a general AXI-Stream helper.
    """

    # Sampling this checker's own signals can observe a different, possibly
    # still-transitioning value on a cycle where the RTL's own `after TPD_G`
    # register update lands exactly at the default 1.0 ns sample point, which
    # is a bench sampling-margin artifact rather than a protocol violation
    # (measured by bisection against RoCEv2ICrc.vhd's genuine
    # hold-while-stalled transition). A caller that samples elsewhere should
    # pass a matching settle_ns.
    _SETTLE_NS = 1.0

    def __init__(self, dut, clk, *, settle_ns: float | None = None) -> None:
        self._dut = dut
        self._clk = clk
        self._settle_ns = settle_ns if settle_ns is not None else self._SETTLE_NS
        self._violations: list[str] = []
        self._cycle = 0
        self._reset_seen = False
        self._prev_valid: bool | None = None
        self._prev_ready: bool | None = None
        self._prev_data: str | None = None
        self._accepted_outputs = 0
        self._accepted_input_tlasts = 0

    def start(self) -> None:
        cocotb.start_soon(self._monitor())

    def report(self) -> list[str]:
        return list(self._violations)

    async def _monitor(self) -> None:
        while True:
            await RisingEdge(self._clk)
            await Timer(self._settle_ns, unit="ns")
            cycle = self._cycle
            self._cycle += 1

            rst_n_bits = _bit_string(self._dut.RST_N.value)
            if not (self._reset_seen or (_is_defined(rst_n_bits) and rst_n_bits == "1")):
                # Still inside (or before) the reset hold window: none of
                # the four properties below is checked against a cycle before
                # reset has ever deasserted.
                continue
            self._reset_seen = True

            s_ready_bits = _bit_string(self._dut.s_axis_tready.value)
            m_valid_bits = _bit_string(self._dut.m_crc_stream_valid.value)
            m_ready_bits = _bit_string(self._dut.m_crc_stream_ready.value)
            m_data_bits = _bit_string(self._dut.m_crc_stream_data.value)
            s_valid_bits = _bit_string(self._dut.s_axis_tvalid.value)
            s_last_bits = _bit_string(self._dut.s_axis_tlast.value)

            # Property 1: s_axis_tready / m_crc_stream_valid never glitch to
            # a value other than 0 or 1.
            if not _is_defined(s_ready_bits):
                self._violations.append(
                    f"cycle {cycle}: s_axis_tready resolved to {s_ready_bits!r}, neither 0 nor 1"
                )
            if not _is_defined(m_valid_bits):
                self._violations.append(
                    f"cycle {cycle}: m_crc_stream_valid resolved to {m_valid_bits!r}, neither 0 nor 1"
                )

            valid_now = m_valid_bits == "1"
            ready_now = _is_defined(m_ready_bits) and m_ready_bits == "1"

            if self._prev_valid is not None:
                # Property 2: valid never withdrawn before its own
                # acceptance, that is, dropped without the paired ready
                # having sampled 1 on the cycle valid was last high.
                if self._prev_valid and not self._prev_ready and not valid_now:
                    self._violations.append(
                        f"cycle {cycle}: m_crc_stream_valid dropped between cycle {cycle - 1} and "
                        f"{cycle} without m_crc_stream_ready sampling 1 at cycle {cycle - 1} "
                        "(valid withdrawn before its own acceptance)"
                    )
                # Property 3: the payload held stable while valid waits,
                # that is, m_crc_stream_data must not change across two
                # cycles where valid stayed high and ready was low on the
                # first of the two.
                if (
                    self._prev_valid
                    and not self._prev_ready
                    and valid_now
                    and self._prev_data is not None
                    and m_data_bits != self._prev_data
                ):
                    self._violations.append(
                        f"cycle {cycle}: m_crc_stream_data changed from {self._prev_data!r} to "
                        f"{m_data_bits!r} while m_crc_stream_valid stayed high across cycle "
                        f"{cycle - 1} and {cycle} with m_crc_stream_ready low at cycle {cycle - 1}"
                    )

            # Property 4: the running count of accepted output words must
            # never exceed the running count of accepted input beats
            # carrying tlast, that is, at most one CRC word per packet.
            if valid_now and ready_now:
                self._accepted_outputs += 1
            if s_valid_bits == "1" and s_ready_bits == "1" and s_last_bits == "1":
                self._accepted_input_tlasts += 1
            if self._accepted_outputs > self._accepted_input_tlasts:
                self._violations.append(
                    f"cycle {cycle}: accepted output word count {self._accepted_outputs} exceeds "
                    f"accepted input tlast count {self._accepted_input_tlasts}; more than one CRC "
                    "word was produced for a packet"
                )

            self._prev_valid = valid_now
            self._prev_ready = ready_now
            self._prev_data = m_data_bits


# Both helpers below are written by hand rather than through the AXI-Stream
# cocotb extension library: RoCEv2ICrc's input side is a plain three-line
# valid/ready/payload handshake, not a full AXI-Stream bus, and its output
# side is not an AXI-Stream bus at all, so a short explicit driver has fewer
# moving parts than half a library.
async def drive_icrc_beats(dut, beats: list[dict[str, int]]) -> None:
    """Presents each beat of `beats` (each a dict shaped like
    `icrc_beats_from_payload`'s own output, keyed by `s_axis_tdata`,
    `s_axis_tkeep`, `s_axis_tlast`, and `s_axis_tuser`) on `RoCEv2ICrc`'s
    slave input side, holding `s_axis_tvalid` high throughout and advancing
    to the next beat only on a rising edge where `s_axis_tready` samples 1
    on that same edge. Deasserts `s_axis_tvalid` once every beat has been
    accepted.

    Samples 2 ns after the rising edge, not the more common 1 ns used
    elsewhere in this tree: sampling exactly at `RoCEv2ICrc.vhd`'s own
    default `TPD_G=1ns` can race its `r <= rin after TPD_G` register update
    on the one cycle a transition lands exactly at the sample point.
    """
    dut.s_axis_tvalid.value = 1
    for beat in beats:
        dut.s_axis_tdata.value = beat["s_axis_tdata"]
        dut.s_axis_tkeep.value = beat["s_axis_tkeep"]
        dut.s_axis_tlast.value = beat["s_axis_tlast"]
        dut.s_axis_tuser.value = beat.get("s_axis_tuser", 0)
        while True:
            await RisingEdge(dut.CLK)
            await Timer(2, unit="ns")
            if int(dut.s_axis_tready.value) == 1:
                break
    dut.s_axis_tvalid.value = 0


async def collect_icrc_words(dut, cycles: int) -> list[int]:
    """Returns the ordered list of `m_crc_stream_data` values observed over
    the next `cycles` rising edges, on any cycle where both
    `m_crc_stream_valid` and `m_crc_stream_ready` sample 1. Same 2 ns
    post-edge sample delay as `drive_icrc_beats`, for the identical reason.
    """
    words: list[int] = []
    for _ in range(cycles):
        await RisingEdge(dut.CLK)
        await Timer(2, unit="ns")
        if int(dut.m_crc_stream_valid.value) == 1 and int(dut.m_crc_stream_ready.value) == 1:
            words.append(int(dut.m_crc_stream_data.value))
    return words
