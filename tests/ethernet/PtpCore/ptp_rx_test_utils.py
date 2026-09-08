##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Independent RX fixtures and packed-record comparison helpers."""

from fractions import Fraction
import zlib

from tests.ethernet.PtpCore.ptp_rx_reference import RxBeat, RxStamp


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



def unpack_time(value):
    return Fraction(((value >> 48) * 1_000_000_000 + ((value >> 16) & 0xffffffff)) * 65536 + (value & 65535), 65536)


def pack_record(record):
    stamp = record.stamp
    time_q16 = int(stamp.time * 65536)
    seconds, nsfrac = divmod(time_q16, 1_000_000_000 * 65536)
    kind, domain, source, sequence = record.key
    fields = [
        (96, (seconds << 48) | nsfrac), (64, stamp.ticks), (3, stamp.tick_phase),
        (32, stamp.generation), (1, stamp.time_valid), (32, record.rx_epoch),
        (48, int.from_bytes(record.destination, "big")), (80, int.from_bytes(source, "big")),
        (16, sequence), (8, domain), (4, kind), (4, record.minor_version),
        (4, record.transport_specific), (16, record.message_length), (16, record.flags),
        (64, record.correction), (8, record.control), (8, record.log_interval),
        (240, int.from_bytes(record.body.ljust(30, b"\x00"), "big")),
    ]
    result = 0
    for width, value in fields:
        result = result << width | (int(value) & ((1 << width)-1))
    return result
