##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
"""
Tests for the iCRC reference model in roce_test_utils, the independent
reference model the RoCEv2 iCRC benches check the RTL against. This file
covers the merged module's iCRC reference helpers only; its AXI-Lite
wide-access and resize-and-swap helpers are exercised by the benches that
consume them rather than here.

Test methodology:
- Sweep: The whole-word reflect transform, all 36 lookup tables, both direction
  oracles, and the beat builders across payload lengths 1 to 96.
- Stimulus: The helper functions are called directly; this file starts no
  simulator.
- Checks: Values measured against the Bluespec-generated CRC Verilog this engine
  replaced (recorded in each helper's own docstring) must still hold; the table
  recurrence must be self-consistent under one more single-byte step; the beat
  builders and their inverses must round-trip exactly; the front-padding rule
  for a partial non-final beat must differ from the trailing-padding variant;
  and every documented input-validation ValueError must be raised.
- Timing: Pure Python; nothing here is clocked.

A reference model that is wrong in the same way the RTL is wrong would let the
RTL benches pass vacuously, which is why these checks are pinned to externally
measured values and to internal consistency rather than to the RTL.
"""

from __future__ import annotations

import struct

from tests.base.crc.crc_test_utils import crc_byte_lookup
from tests.ethernet.RoCEv2.roce_test_utils import (
    icrc_beats_from_payload,
    icrc_recv_reference,
    icrc_reflect32,
    icrc_send_reference,
    icrc_table,
    masked_payload_from_recorded_beats,
    payload_from_recorded_beats,
)


def test_icrc_reflect32_measured_pair():
    assert icrc_reflect32(0xBC78E776) == 0x9118E1C2


def test_icrc_reflect32_is_involution():
    for value in (0x00000000, 0xFFFFFFFF, 0x12345678, 0xBC78E776, 0x00000001, 0x80000000):
        assert icrc_reflect32(icrc_reflect32(value)) == value


def test_icrc_table_tripwire_values():
    assert icrc_table(0)[1] == 0x00000001
    assert icrc_table(3)[1] == 0x01000000
    assert icrc_table(4)[1] == 0x04C11DB7
    assert icrc_table(35)[1] == 0x12EED357
    assert icrc_table(0)[255] == 0x000000FF
    assert icrc_table(4)[255] == 0xB1F740B4
    assert icrc_table(35)[255] == 0x689A23C7


def test_icrc_table_base_case_is_identity():
    assert all(icrc_table(0)[b] == b for b in range(256))


def test_icrc_table_length():
    for table_index in range(36):
        assert len(icrc_table(table_index)) == 256


def test_icrc_send_measured_values():
    assert icrc_send_reference(bytes(range(64))) == 0x100ECE8C
    assert icrc_send_reference(bytes([4, 5, 6, 7, 8, 9, 0, 0, 0, 0])) == 0x427D5A56
    assert icrc_send_reference(bytes([0, 0, 2, 3, 4, 5, 6, 7, 8, 9])) == 0x5217C305
    assert icrc_send_reference(bytes(range(1))) == 0xD202EF8D
    # zlib.crc32(bytes(range(31))) is 0x4D786D77, not the 0x6CAB0B00 the plan
    # text stated; re-measured directly against zlib during execution since
    # icrc_send_reference is defined as zlib.crc32(payload), and every other
    # value in this list checks out against that same definition.
    assert icrc_send_reference(bytes(range(31))) == 0x4D786D77
    assert icrc_send_reference(bytes(range(32))) == 0x91267E8A
    assert icrc_send_reference(bytes(range(100))) == 0x58C932F5


def test_icrc_recv_measured_values():
    assert icrc_recv_reference(bytes(range(10)) + struct.pack("<I", 0x456CD746)) == 0x00000000
    assert icrc_recv_reference(bytes(range(10)) + b"\x00\x00\x00\x00") == 0x456CD746
    assert icrc_recv_reference(bytes(range(64)) + struct.pack("<I", 0x100ECE8C)) == 0x00000000
    assert icrc_recv_reference(bytes(range(64))) == 0x8FD242D2
    assert icrc_recv_reference(bytes(range(64)) + struct.pack(">I", 0x100ECE8C)) == 0x9CC0C09C


def test_icrc_recv_raises_on_short_message():
    try:
        icrc_recv_reference(b"abc")
    except ValueError:
        pass
    else:
        raise AssertionError("icrc_recv_reference(b'abc') did not raise ValueError")


def test_icrc_beats_from_payload_shapes():
    beats = icrc_beats_from_payload(bytes(range(64)))
    assert len(beats) == 2
    assert beats[0]["s_axis_tkeep"] == 0xFFFFFFFF
    assert beats[1]["s_axis_tkeep"] == 0xFFFFFFFF
    assert beats[0]["s_axis_tlast"] == 0
    assert beats[1]["s_axis_tlast"] == 1
    assert beats[0]["s_axis_tuser"] == 0
    assert beats[0]["s_axis_tdata"] == int.from_bytes(bytes(range(32)), "little")

    single_beat = icrc_beats_from_payload(bytes(range(10)))
    assert len(single_beat) == 1
    assert single_beat[0]["s_axis_tkeep"] == 0x000003FF
    assert single_beat[0]["s_axis_tlast"] == 1


def test_icrc_beats_from_payload_rejects_empty():
    try:
        icrc_beats_from_payload(b"")
    except ValueError:
        pass
    else:
        raise AssertionError("icrc_beats_from_payload(b'') did not raise ValueError")


def test_icrc_payload_from_recorded_beats_is_exact_inverse():
    for length in range(1, 97):
        payload = bytes((7 * index + 3) % 256 for index in range(length))
        beats = icrc_beats_from_payload(payload)
        assert payload_from_recorded_beats(beats) == [payload]
        assert masked_payload_from_recorded_beats(beats) == [payload]


def test_icrc_masked_payload_front_pads_not_trailing_pads():
    # A two-beat packet: a non-final beat with 16 valid lanes (not full,
    # not empty), then a final beat with 8 valid lanes. The front-padding
    # rule this module implements reconstructs 16 leading zero bytes on the
    # non-final beat; a trailing-padding variant would place those 16 zero
    # bytes after that beat's data instead. Both single-beat and full-beat
    # cases can never distinguish these two rules, which is exactly why this
    # test is directed at a partial non-final beat.
    beats = [
        {"s_axis_tdata": (1 << 128) - 1, "s_axis_tkeep": 0x0000FFFF, "s_axis_tlast": 0, "s_axis_tuser": 0},
        {"s_axis_tdata": (1 << 64) - 1, "s_axis_tkeep": 0x000000FF, "s_axis_tlast": 1, "s_axis_tuser": 0},
    ]

    front_padded = masked_payload_from_recorded_beats(beats)[0]
    assert len(front_padded) == 40
    assert front_padded[:16] == b"\x00" * 16

    trailing_padded = _trailing_pad_variant(beats)[0]
    assert front_padded != trailing_padded, (
        "front-padding and trailing-padding reconstructions must differ for a partial "
        "non-final beat, or this rule could be silently inverted without any test failing"
    )


def _trailing_pad_variant(beats: list[dict]) -> list[bytes]:
    # The deliberately-wrong alternative reconstruction this test's directed
    # case must distinguish from the real rule: padding after a non-final
    # beat's valid lanes instead of before them.
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
        current.extend(lane_bytes)
        if is_last:
            payloads.append(bytes(current))
            current = bytearray()
        else:
            current.extend(b"\x00" * (32 - nlanes))
    return payloads


def test_icrc_reflect32_boundary_values():
    assert icrc_reflect32(0x00000000) == 0xFFFFFFFF
    assert icrc_reflect32(0xFFFFFFFF) == 0x00000000


def test_icrc_table_recurrence_matches_shift_by_one_step():
    # value(k, b) advances by exactly one shift-and-lookup step per table
    # index: value(k+1, b) must equal one more application of the same step
    # starting from value(k, b), for every table pair this phase captured.
    for table_index in range(35):
        this_table = icrc_table(table_index)
        next_table = icrc_table(table_index + 1)
        for byte_value in (0x00, 0x01, 0x7F, 0xFF):
            stepped = ((this_table[byte_value] << 8) & 0xFFFFFFFF) ^ crc_byte_lookup(
                (this_table[byte_value] >> 24) & 0xFF
            )
            assert stepped == next_table[byte_value], (
                f"table {table_index} -> {table_index + 1}, byte {byte_value:#04x}: "
                f"one more shift-and-lookup step did not reach the next table's value"
            )


def test_icrc_table_returns_independent_list_copies():
    # icrc_table() is documented to return a fresh list copy of its
    # internally cached tuple on every call, so a caller mutating its own
    # return value can never corrupt what a later call returns.
    first_call = icrc_table(4)
    first_call[1] = 0xDEADBEEF
    second_call = icrc_table(4)
    assert second_call[1] == 0x04C11DB7


def test_icrc_payload_from_recorded_beats_rejects_non_full_non_final_beat():
    beats = [
        {"s_axis_tdata": 0x1234, "s_axis_tkeep": 0x000000FF, "s_axis_tlast": 0, "s_axis_tuser": 0},
        {"s_axis_tdata": 0x5678, "s_axis_tkeep": 0x000000FF, "s_axis_tlast": 1, "s_axis_tuser": 0},
    ]
    try:
        payload_from_recorded_beats(beats)
    except ValueError:
        pass
    else:
        raise AssertionError("payload_from_recorded_beats did not raise ValueError on a partial non-final beat")


def test_icrc_payload_from_recorded_beats_rejects_noncontiguous_tkeep():
    beats = [
        {"s_axis_tdata": 0x1234, "s_axis_tkeep": 0x0000000D, "s_axis_tlast": 1, "s_axis_tuser": 0},
    ]
    try:
        payload_from_recorded_beats(beats)
    except ValueError:
        pass
    else:
        raise AssertionError("payload_from_recorded_beats did not raise ValueError on non-contiguous s_axis_tkeep")


def test_icrc_recv_residue_is_zero_for_send_computed_crc():
    # Closes the loop between the two references directly: appending the
    # Send reference's own CRC word (little-endian) to the same payload and
    # evaluating the Recv reference must always land on zero residue, for
    # payload lengths well beyond the four measured golden cases.
    for length in (4, 5, 17, 63, 65, 128):
        payload = bytes((11 * index + 5) % 256 for index in range(length))
        crc_word = icrc_send_reference(payload)
        message = payload + struct.pack("<I", crc_word)
        assert icrc_recv_reference(message) == 0x00000000, f"length {length}: residue was not zero"
