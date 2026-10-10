#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

"""Source-backed multicast master packets, separate from accelerated legacy traffic.

IEEE 1588-2019 13.2, 13.3/Table 35, Table 37, Table 42, 13.5--13.8,
Annex F. Minor zero selects the existing 2008 controlField compatibility mode.
The tests anchor these bytes independently; this is not a profile/BMCA model.
"""

SOURCE = bytes.fromhex('001122fffe3344550001')
LOCAL = bytes.fromhex('020000fffe0000010001')


def master_frame(kind, sequence, remote=0, correction=0, *, minor=1, two_step=False,
                 interval=None, requester=LOCAL):
    size = {0: 44, 8: 44, 9: 54, 11: 64}[kind]
    message = bytearray(size)
    message[0:4] = bytes((kind, minor << 4 | 2))+size.to_bytes(2, 'big')
    # Arbitrary timescale, untraceable free-running GM: no leap/UTC claims.
    message[6:8] = (0x200 if kind == 0 and two_step else 0).to_bytes(2, 'big')
    message[8:16] = correction.to_bytes(8, 'big', signed=True)
    message[20:30] = SOURCE
    message[30:32] = sequence.to_bytes(2, 'big')
    message[32] = {0: 0, 8: 2, 9: 3, 11: 5}[kind] if minor == 0 else 0
    message[33] = ({0: 0, 8: 0, 9: 0, 11: 1}[kind] if interval is None else interval) & 255
    seconds, ns = divmod(remote, 1000000000)
    message[34:44] = seconds.to_bytes(6, 'big')+ns.to_bytes(4, 'big')
    if kind == 9:
        message[44:54] = requester
    elif kind == 11:
        # UTC offset 0/invalid, priority1=128, class=248, accuracy unknown,
        # variance=ffff, priority2=128, GM identity, stepsRemoved=0,
        # timeSource INTERNAL_OSCILLATOR. Reserved and origin fields stay zero.
        message[44:64] = bytes.fromhex('00000080f8feffff80')+SOURCE[:8]+bytes.fromhex('0000a0')
    return (bytes.fromhex('011b1900000000112233445588f7')+message).ljust(60, b'\x00')
