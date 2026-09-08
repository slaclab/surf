##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: 1/8-byte physical groups, all four supported RX messages, depths 1/4,
#   and every final-byte alignment; storage remains bounded for oversized input.
# - Stimulus: Independently encoded frames/FCS, same-key copies with distinct
#   bodies/times, bad CRC, malformed lengths/TLVs, stalls, restart and generation.
# - Checks: Only complete CRC-checked records carry their own SOF capture;
#   overflow and restart suppress same-edge transfer and remove old work.
# - Timing: Model starts at normalized PHY bytes, not GMII/XGMII control codes.
#   No physical adapter, production RTL, CDC, or port-policy claim is made.

from dataclasses import replace
from fractions import Fraction
import random
import zlib

import pytest

from tests.ethernet.PtpCore.ptp_rx_reference import RxBeat, RxFrontend, RxStamp
from tests.ethernet.PtpCore.ptp_reference import e2e


def frame(kind=0, sequence=7, marker=1, tlvs=b"", minor=1):
    # Fixture owns lengths independently of the receiver's dispatch table.
    body_size = {0: 10, 8: 10, 9: 20, 11: 30}[kind]
    ptp = bytearray(34 + body_size)
    ptp[0:2] = bytes((kind, minor << 4 | 2))
    ptp[2:4] = (len(ptp) + len(tlvs)).to_bytes(2, "big")
    ptp[6:8] = b"\x02\x00" if kind == 0 else b"\x00\x00"
    ptp[8:16] = (-17).to_bytes(8, "big", signed=True)
    ptp[20:30] = bytes.fromhex("001122fffe3344550001")
    ptp[30:32] = sequence.to_bytes(2, "big")
    ptp[33] = 0xfd  # Signed -3, rather than unsigned 253.
    ptp[34:44] = marker.to_bytes(10, "big")
    raw = bytes.fromhex("011b1900000000112233445588f7") + ptp + tlvs
    return raw.ljust(60, b"\x00")


def beats(raw, stamp=None, width=8, corrupt=False):
    stamp = stamp or RxStamp(Fraction(100), 12)
    fcs = zlib.crc32(raw).to_bytes(4, "little")
    if corrupt:
        fcs = bytes((fcs[0] ^ 1,)) + fcs[1:]
    wire = raw + fcs
    return [RxBeat(wire[i:i+width], i == 0, i + width >= len(wire),
                   stamp=stamp if i == 0 else None) for i in range(0, len(wire), width)]


def send(rx, raw, **kwargs):
    for beat in beats(raw, **kwargs):
        assert rx.edge(beat) is None


@pytest.mark.parametrize("width,kind,minor", [(1, 0, 0), (8, 0, 1), (8, 8, 0), (1, 9, 1), (8, 11, 1)])
def test_decode_owns_message_and_capture(width, kind, minor):
    rx = RxFrontend()
    stamp = RxStamp(Fraction(100000000000000003, 5), 1234)
    send(rx, frame(kind=kind, minor=minor), stamp=stamp, width=width)
    head = rx.entries[0]
    for _ in range(20):
        assert rx.edge(ready=False) is None
        assert rx.entries[0] == head
    got = rx.edge(ready=True)
    assert got.stamp == stamp  # time_valid=False must still allow acquisition.
    assert got.key == (kind, 0, bytes.fromhex("001122fffe3344550001"), 7)
    assert got.correction == -17 and got.log_interval == -3
    assert got.minor_version == minor
    assert got.body[:10] == (1).to_bytes(10, "big")
    assert len(got.body) == {0: 10, 8: 10, 9: 20, 11: 30}[kind]


def test_bad_crc_duplicate_cannot_supply_timestamp():
    rx = RxFrontend()
    send(rx, frame(marker=1), stamp=RxStamp(Fraction(10), 1), corrupt=True)
    assert not rx.entries and rx.counters["crc"] == 1
    send(rx, frame(marker=2), stamp=RxStamp(Fraction(1050), 2))
    got = rx.edge(ready=True)
    assert got.stamp.time == 1050 and got.body[:10] == (2).to_bytes(10, "big")
    # The valid duplicate is an independent complete record with its own time.
    send(rx, frame(marker=3), stamp=RxStamp(Fraction(2090), 3))
    got2 = rx.edge(ready=True)
    assert got2.key == got.key and got2.stamp.time == 2090


def test_unsteered_byte_phase_survives_decode():
    rx = RxFrontend()
    send(rx, frame(), stamp=RxStamp(Fraction(1070), 10, tick_phase=4))
    got = rx.edge(ready=True)
    # Independent peer: 20 ns each way, local PHC 50 ns ahead. RX and TX
    # message points have different byte phases of a nominal 6.4 ns cycle.
    elapsed = Fraction(179 * 16, 5)  # 89.5 cycles * 6.4 ns.
    t1, t2, t3, t4 = 1000, 1070, 1070 + elapsed, 1040 + elapsed
    tick_span = 100 - got.stamp.ticks - Fraction(got.stamp.tick_phase, 8)
    assert e2e(t1, t2, t3, t4, local_elapsed=tick_span * Fraction(32, 5)) == (20, 50)
    naive = (100 - got.stamp.ticks) * Fraction(32, 5)
    assert e2e(t1, t2, t3, t4, local_elapsed=naive)[0] == Fraction(92, 5)


def test_empty_termination_and_simultaneous_consume_enqueue():
    rx = RxFrontend(depth=2)
    send(rx, frame(marker=1))
    pending = beats(frame(marker=2))  # Exactly 64 bytes including FCS.
    for beat in pending[:-1]:
        rx.edge(beat)
    rx.edge(replace(pending[-1], eof=False))
    assert len(rx.entries) == 1  # No publication before physical termination.
    got = rx.edge(RxBeat(eof=True), ready=True)
    assert got.body[:10] == (1).to_bytes(10, "big") and not rx.abort
    assert rx.edge(ready=True).body[:10] == (2).to_bytes(10, "big")


def test_rejected_completion_does_not_overflow_full_queue():
    rx = RxFrontend(depth=1)
    send(rx, frame(marker=1))
    pending = beats(frame(marker=2), corrupt=True)
    for beat in pending[:-1]:
        rx.edge(beat)
    got = rx.edge(pending[-1], ready=True)
    assert got.body[:10] == (1).to_bytes(10, "big")
    assert not rx.abort and rx.rx_epoch == 0 and not rx.entries


@pytest.mark.parametrize("depth", [1, 4])
def test_overflow_wins_over_consumption(depth):
    rx = RxFrontend(depth=depth)
    for i in range(depth):
        send(rx, frame(marker=i))
    pending = beats(frame(marker=99))
    for beat in pending[:-1]:
        rx.edge(beat)
    assert rx.edge(pending[-1], ready=True) is None
    assert rx.abort and not rx.entries and rx.rx_epoch == 1
    assert rx.generation == 0 and rx.counters["overflow"] == 1
    send(rx, frame(marker=100))
    got = rx.edge(ready=True)
    assert got.rx_epoch == 1 and got.body[:10] == (100).to_bytes(10, "big")


@pytest.mark.parametrize("at_eof", [False, True])
def test_restart_discards_queued_partial_and_same_edge(at_eof):
    rx = RxFrontend()
    send(rx, frame(marker=1))  # Models the old retained head in the MAC experiment.
    pending = beats(frame(marker=2))
    cut = len(pending)-1 if at_eof else 3
    for beat in pending[:cut]:
        rx.edge(beat)
    assert rx.edge(pending[cut], ready=True, restart=True) is None
    assert rx.abort and not rx.entries
    for beat in pending[cut+1:]:
        rx.edge(beat)
    assert not rx.entries
    send(rx, frame(marker=3), stamp=RxStamp(Fraction(333), 33))
    got = rx.edge(ready=True)
    assert got.body[:10] == (3).to_bytes(10, "big") and got.stamp.time == 333


def test_generation_change_on_sof_and_stale_producer():
    rx = RxFrontend()
    pending = beats(frame(), RxStamp(Fraction(100), 1))
    rx.edge(pending[0], generation=1)
    assert rx.abort
    for beat in pending[1:]:
        rx.edge(beat)
    send(rx, frame(), stamp=RxStamp(Fraction(200), 2, generation=0))
    assert not rx.entries
    send(rx, frame(), stamp=RxStamp(Fraction(300), 3, generation=1))
    assert rx.edge(ready=True).stamp.generation == 1


@pytest.mark.parametrize("mutation", ["short", "long", "truncated", "tlv_header", "tlv_value", "ethertype", "version", "error"])
def test_reject_and_recover(mutation):
    rx = RxFrontend()
    raw = bytearray(frame())
    if mutation == "short":
        raw = raw[:59]  # Runt even with a recomputed correct FCS.
    elif mutation == "long":
        raw += bytes(1515 - len(raw))
    elif mutation == "truncated":
        raw[16:18] = (64).to_bytes(2, "big")
    elif mutation == "tlv_header":
        raw = frame(tlvs=b"\x00\x01")
    elif mutation == "tlv_value":
        raw = frame(tlvs=b"\x00\x01\x00\x08\x11\x22")
    elif mutation == "ethertype":
        raw[12:14] = b"\x81\x00"
    elif mutation == "version":
        raw[15] = 0x13
    pending = beats(raw)
    if mutation == "error":
        pending[3] = replace(pending[3], error=True)
    for beat in pending:
        rx.edge(beat)
    assert not rx.entries
    send(rx, frame(marker=55))
    assert rx.edge(ready=True).body[:10] == (55).to_bytes(10, "big")


def test_tlv_boundaries_padding_and_all_termination_positions():
    for extra_padding in range(8):
        rx = RxFrontend()
        # Unknown zero-length and nonempty TLVs: both must be bounded by messageLength.
        raw = frame(tlvs=bytes.fromhex("1234000056780002abcd")) + bytes(extra_padding)
        send(rx, raw)
        got = rx.edge(ready=True)
        assert got.message_length == 54 and len(got.body) == 10
    rx = RxFrontend()
    # Largest allowed untagged frame, most bytes skipped without being stored.
    send(rx, frame(kind=11, tlvs=b"\x12\x34" + (1432).to_bytes(2, "big") + bytes(1432)))
    assert rx.edge(ready=True).message_length == 1500


def test_nested_start_and_unterminated_oversize_remain_bounded():
    rx = RxFrontend()
    pending = beats(frame())
    rx.edge(pending[0])
    rx.edge(pending[0])
    for beat in pending[1:]:
        rx.edge(beat)
    assert not rx.entries
    rx.edge(pending[0])
    for _ in range(10_000):
        rx.edge(RxBeat(bytes(8)))
        assert len(rx.prefix) <= 78 and len(rx.tail) <= 4
        assert len(rx.tlv_header) <= 3 and rx.count <= 1519
    rx.edge(RxBeat(eof=True))
    assert not rx.entries
    send(rx, frame())
    assert rx.edge(ready=True) is not None


def test_random_stalls_loss_and_restarts_preserve_binding():
    rng = random.Random(0x1588)
    rx = RxFrontend(depth=4)
    observed = []
    for identity in range(400):
        stamp = RxStamp(Fraction(identity * 1040 + 3, 5), identity)
        pending = beats(frame(marker=identity), stamp=stamp, corrupt=identity % 7 == 0)
        for beat in pending:
            got = rx.edge(beat, ready=rng.randrange(12) == 0, restart=rng.randrange(200) == 0)
            if got is not None:
                observed.append(got)
    while rx.entries:
        observed.append(rx.edge(ready=True))
    assert len(observed) > 50
    for got in observed:
        identity = int.from_bytes(got.body[:10], "big")
        assert identity % 7 != 0
        assert got.stamp.ticks == identity
        assert got.stamp.time == Fraction(identity * 1040 + 3, 5)
