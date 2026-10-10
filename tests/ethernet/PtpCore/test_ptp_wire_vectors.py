#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: PTP-S01/S02 common-header anchors for minor versions 0/1 and both
#   Sync modes; PTP-S06 hand-worked equal-rate and rate-corrected E2E examples.
# - Stimulus: Literal Ethernet headers/messages/padding independent of the shared
#   encoder, and fixed timestamp numbers independent of the E2E solver.
# - Checks: Every fixture byte, including endian order, correction, upper
#   seconds bits and padding; exact 100 ns delay and +40 ns receiver offset.
# - Timing: Pure oracle-anchor tests; these do not execute RTL or establish
#   2019/profile conformance. See specification-coverage.md for source limits.
#   Common 2008 header offsets are independently documented in NISTIR 8002,
#   Appendix C; 2019 header/version fields are checked against 13.3/19.2.
#   These are hand-authored vectors,
#   not published IEEE test vectors.

from fractions import Fraction

import pytest

from tests.ethernet.PtpCore.ptp_reference import Q16, e2e, e2e_q16
from tests.ethernet.PtpCore.ptp_rx_test_utils import frame


# Each literal includes the 14-byte Ethernet header and two padding octets,
# but excludes preamble and FCS (the physical driver owns those). Deliberately
# do not build expected packets with to_bytes(), field-offset writes, or frame().
SYNC_VECTORS = [
    pytest.param(0, False, bytes.fromhex(
        '011b1900000000112233445588f7'
        '0002002c00000000ffffffffffffffef00000000'
        '001122fffe3344550001123400fd010203040506075bcd150000'), id='v20-one-step'),
    pytest.param(0, True, bytes.fromhex(
        '011b1900000000112233445588f7'
        '0002002c00000200ffffffffffffffef00000000'
        '001122fffe3344550001123400fd010203040506075bcd150000'), id='v20-two-step'),
    pytest.param(1, False, bytes.fromhex(
        '011b1900000000112233445588f7'
        '0012002c00000000ffffffffffffffef00000000'
        '001122fffe3344550001123400fd010203040506075bcd150000'), id='v21-one-step'),
    pytest.param(1, True, bytes.fromhex(
        '011b1900000000112233445588f7'
        '0012002c00000200ffffffffffffffef00000000'
        '001122fffe3344550001123400fd010203040506075bcd150000'), id='v21-two-step'),
]


@pytest.mark.parametrize('minor,two_step,expected', SYNC_VECTORS)
def test_literal_sync_frame(minor, two_step, expected):
    # Timestamp = seconds 0x010203040506, nanoseconds 123456789. The two-step
    # body's nonzero value is intentional; protocol policy must ignore it.
    actual = frame(kind=0, sequence=0x1234,
                   marker=(0x010203040506 << 32) | 123456789,
                   minor=minor, two_step=two_step)
    assert len(expected) == 60
    assert actual == expected


@pytest.mark.parametrize('t2,t3,t4,c_sync,c_delay,elapsed', [
    pytest.param(1140, 1440, 1500, 0, 0, None, id='uncorrected'),
    pytest.param(Fraction('1153.5'), Fraction('1453.5'), 1520,
                 Fraction('13.5'), Fraction('6.5'), None, id='fractional-corrections'),
    pytest.param(Fraction('1153.5'), Fraction('1453.53'), 1520,
                 Fraction('13.5'), Fraction('6.5'), 300, id='rate-corrected'),
])
def test_hand_worked_e2e(t2, t3, t4, c_sync, c_delay, elapsed):
    # t1=1000 ns. Corrected forward/reverse differences are 140/60 ns,
    # hence (140+60)/2=100 ns delay and (140-60)/2=+40 ns offset.
    # The last case advances the receiver 300.03 ns during 300 master ns;
    # use its independently supplied raw-counter/master-rate elapsed time.
    assert e2e(1000, t2, t3, t4, c_sync, c_delay, local_elapsed=elapsed) == (100, 40)
    assert e2e_q16(1000*Q16, int(t2*Q16), t4*Q16,
                   int(c_sync*Q16), int(c_delay*Q16),
                   tick_span=300, ns_per_tick_q48=1 << 48) == (100*Q16, 40*Q16)
