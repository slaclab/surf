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
# - Sweep: PTP-S01/S02 literal common headers through the production RX frontend;
#   PTP-S04/S05 signed corrections and two-step Follow_Up through the real engine.
#   S08 emitted request bytes in both versions; S09 control/reserved bits/TLVs.
# - Stimulus: Hand-authored packets, one-field length/version mutations, bad FCS,
#   and fixed Sync/Follow_Up records; no shared encoder builds the golden packets.
# - Checks: Actual RTL record fields against independent constants; malformed
#   framing emits no record and the next valid packet recovers. Exact fractional
#   forward measurement, Sync capture provenance, and no premature completion.
#   All receive minor versions, ignored fields, and complete request data and
#   sidebands under backpressure are checked without a shared packet encoder.
# - Timing: Short, independently selected fixtures with bounded waits; no
#   closed-loop servo or MAC lifecycle regression. Reuse existing bench mechanics.
# - Authority: IEEE 1588-2019 13.2/13.3 (headers), 19.2 (minor versions),
#   7.1.2.1 (non-isolated SDO), 14.1/14.4.2 (TLVs), 11.2 (Sync equation),
#   11.3.2/13.6 (Delay_Req), Annex F (Ethernet); 2008 interpretations 11/25.
#   See specification-coverage.md#source-backed-directed-checks for scope and
#   receiver policies. No default-profile conformance is claimed.

import cocotb
import pytest

from tests.common.regression_utils import cocotb_filtered_env, cocotb_test_filter, run_surf_vhdl_test
from tests.ethernet.PtpCore.test_ptp_port_samples import Bench as ProtocolBench
from tests.ethernet.PtpCore.test_ptp_rx_rtl import Bench as RxBench


# Complete destination-MAC-through-padding bytes, excluding FCS. Expected fields
# are stated separately, not decoded from these packets or built by frame().
WIRE_VECTORS = [
    ('sync', bytes.fromhex(
        '011b1900000000112233445588f7'
        '0002002c00000000fffffffffffe800000000000'
        '001122fffe3344550001123400fd010203040506075bcd150000'),
     0, 44, 0, -98304, 0, -3, '010203040506075bcd15'),
    ('follow-up', bytes.fromhex(
        '011b1900000000112233445588f7'
        '0802002c00000000fffffffffffe800000000000'
        '001122fffe3344550001123402fd010203040506075bcd150000'),
     8, 44, 0, -98304, 2, -3, '010203040506075bcd15'),
    ('delay-response', bytes.fromhex(
        '011b1900000000112233445588f7'
        '0902003600000000fffffffffffe800000000000'
        '001122fffe33445500011234037f010203040506075bcd15'
        '020000fffe0000010001'),
     9, 54, 0, -98304, 3, 127, '010203040506075bcd15020000fffe0000010001'),
    ('announce', bytes.fromhex(
        '011b1900000000112233445588f7'
        '0b0200400000003c000000000000000000000000'
        '001122fffe33445500011234057f00000000000000000000'
        '00250080f8feffff8001020304050607080001a0'),
     11, 64, 0x003c, 0, 5, 127,
     '0000000000000000000000250080f8feffff8001020304050607080001a0'),
]


def decoded_header(value):
    # The wrapper's record ABI, LSB first. This decoder does not use the RX
    # model or its pack_record(), so common encoder/model mistakes cannot
    # supply the expected header. Capture/provenance is tested by the RX suite.
    fields = {}
    for name, width in (
        ('body', 240), ('interval', 8), ('control', 8), ('correction', 64),
        ('flags', 16), ('length', 16), ('transport', 4), ('minor', 4),
        ('kind', 4), ('domain', 8), ('sequence', 16), ('source', 80), ('destination', 48),
    ):
        fields[name] = value & ((1 << width)-1)
        value >>= width
    for name, width in (('interval', 8), ('correction', 64)):
        if fields[name] & (1 << (width-1)):
            fields[name] -= 1 << width
    fields['body'] = fields['body'].to_bytes(30, 'big')
    return fields


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def literal_rx_headers(d):
    b = RxBench(d)
    await b.reset()
    await b.wait(messageReady=0)
    for name, raw, kind, length, flags, correction, control, interval, body in WIRE_VECTORS:
        expected = dict(kind=kind, length=length, flags=flags, correction=correction,
                        control=control, interval=interval, body=bytes.fromhex(body).ljust(30, b'\x00'),
                        transport=0, domain=0, sequence=0x1234,
                        source=0x001122fffe3344550001, destination=0x011b19000000)
        for minor in (0, 1):
            packet = bytearray(raw)
            packet[15] = (minor << 4) | 2
            # Ethernet padding is outside messageLength, even when its bytes
            # resemble an incomplete TLV. It must not enter the fixed body.
            packet.extend(bytes.fromhex('abcdffff'))
            await b.direct(packet)
            await b.wait()
            assert int(d.messageValid.value), (name, minor)
            assert decoded_header(int(d.messageData.value)) == dict(expected, minor=minor), (name, minor)
            await b.wait(1, messageReady=1)
            await b.wait(messageReady=0)
            assert not int(d.messageValid.value)

        malformed = []
        for declared in (length-1, len(raw)-14+1):
            packet = bytearray(raw)
            packet[16:18] = declared.to_bytes(2, 'big')
            malformed.append((packet, False))
        wrong_version = bytearray(raw)
        wrong_version[15] = 3
        malformed.extend(((wrong_version, False), (raw, True)))
        for packet, corrupt in malformed:
            before = int(d.acceptedCount.value), int(d.droppedCount.value)
            await b.direct(packet, corrupt=corrupt)
            await b.wait()
            assert not int(d.messageValid.value), name
            assert (int(d.acceptedCount.value), int(d.droppedCount.value)) == (before[0], before[1]+1)
            await b.direct(raw)
            await b.wait()
            assert int(d.messageValid.value), name
            assert decoded_header(int(d.messageData.value)) == dict(expected, minor=0), name
            await b.wait(1, messageReady=1)
            await b.wait(messageReady=0)


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def interpreted_two_step_correction(d):
    b = ProtocolBench(d)
    await b.start()
    try:
        # IEEE 2008 interpretation 11: a TC-generated Follow_Up clears
        # twoStepFlag, while the corresponding Sync sets it. The Sync body is
        # deliberately unrelated; only the Follow_Up timestamp defines t1.
        # Interpretation 25 permits signed correction. Here 10.5 + (-2.25)
        # ns = 8.25 ns; t2=1040, t1=1000 => forward=31.75 ns = 2080768 Q16.
        for follow_first in (False, True):
            await b.pulse('restart')
            before, rejected = b.counts()
            if follow_first:
                await b.send(8, 0x1234, 1000, -147456, flags=0)
                await b.no_result()
            await b.send(0, 0x1234, 987654321, 688128, two_step=True,
                         local=68157440, ticks=b.now+100)
            sync_ticks = b.now
            if not follow_first:
                await b.no_result()
                # Rejecting this malformed Follow_Up is endpoint policy, not
                # a receiver action prescribed by interpretation 11. It must
                # leave the valid Sync available for the corrected Follow_Up.
                await b.send(8, 0x1234, 1000, -147456, flags=0x200)
                await b.no_result()
                rejected += 1
                assert b.counts() == (before, rejected)
                await b.send(8, 0x1234, 1000, -147456, flags=0)
            await b.result(0x1234, 2080768, sync_ticks)
            assert b.counts() == (before+1, rejected)
            await b.drain()
    finally:
        b.stop()


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def minor_versions(d):
    # IEEE 1588-2019 19.2: matching major version, any minor version.
    b = RxBench(d)
    await b.reset()
    await b.wait(messageReady=0)
    for minor in range(16):
        packet = bytearray(WIRE_VECTORS[0][1])
        packet[15] = minor << 4 | 2
        # 13.3.2.10: messageTypeSpecific is ignored. For sdoId=000 and
        # isolation disabled, 7.1.2.1 matches majorSdoId/domain only.
        packet[19] = 0xa5
        packet[30:34] = bytes.fromhex('12345678')
        await b.direct(packet)
        await b.wait()
        assert int(d.messageValid.value), f'minorVersionPTP={minor} was rejected'
        got = decoded_header(int(d.messageData.value))
        assert (got['minor'], got['sequence'], got['correction']) == (minor, 0x1234, -98304)
        await b.wait(1, messageReady=1)
        await b.wait(messageReady=0)


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def tlv_suffix(d):
    # 5.3.8 / 14.1 / 14.1.2: even TLV value lengths; skip unsupported
    # well-formed TLVs and continue parsing the suffix. Odd-length rejection
    # is our malformed-input policy; the standard defines valid encodings.
    b = RxBench(d)
    await b.reset()
    await b.wait(messageReady=0)
    for suffix, accepted in (
        ('20040002234580080000', True),       # Experimental + empty PAD.
        ('200400022345800800020000', True),   # Unsupported then nonempty PAD.
        ('200400012380080000', False),        # Odd first TLV length.
        ('20040002234580080001ab', False),    # Odd second TLV length.
        ('20040002234580080004abcd', False),  # Truncated second value.
        ('2004000223458008', False),          # Partial second header.
        ('80080000', True),                  # Recovery.
    ):
        packet = bytearray(WIRE_VECTORS[1][1][:58]) + bytes.fromhex(suffix)
        packet[16:18] = (len(packet)-14).to_bytes(2, 'big')
        before = int(d.acceptedCount.value), int(d.droppedCount.value)
        await b.direct(packet)
        await b.wait()
        assert bool(int(d.messageValid.value)) == accepted, suffix
        assert int(d.acceptedCount.value) == before[0]+accepted
        assert int(d.droppedCount.value) == before[1]+(not accepted)
        if accepted:
            got = decoded_header(int(d.messageData.value))
            assert got['body'] == bytes.fromhex('010203040506075bcd15').ljust(30, b'\x00')
            assert got['length'] == len(packet)-14
            await b.wait(1, messageReady=1)
            await b.wait(messageReady=0)


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def receive_control(d):
    # 13.3.2.13: Layer-2 receivers ignore controlField, including the 2019
    # zero encoding and the legacy 2008 values. Test arbitrary values too.
    b = ProtocolBench(d)
    await b.start()
    try:
        for control in (0, 1, 2, 3, 5, 0xff):
            await b.pulse('restart')
            before, rejected = b.counts()
            await b.send(0, 7, 1000, two_step=True, local=1040*65536, control=control)
            ticks = b.now
            await b.no_result()
            await b.send(8, 7, 1000, control=control)
            await b.result(7, 40*65536, ticks)
            assert b.counts() == (before+1, rejected)
            await b.drain()
            # Body defaults are sufficient to test these messages' header
            # admission. This does not assert successful Delay_Resp matching.
            await b.send(9, 8, 1000, control=control)
            await b.send(11, 9, 0, control=control, flags=0x3c)
            assert b.counts() == (before+1, rejected)
    finally:
        b.stop()


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def reserved_flags(d):
    # 13.2 and 13.3.2.8/Table 37: the unassigned bits 3/4/7 of octet 0,
    # and bit 7 of octet 1, are reserved and ignored on receipt.
    b = ProtocolBench(d)
    await b.start()
    try:
        for reserved in (0x0800, 0x1000, 0x8000, 0x0080, 0x9880):
            await b.pulse('restart')
            before, rejected = b.counts()
            await b.send(0, 7, 1000, flags=reserved)
            await b.result(7, 123*65536+7)
            await b.drain()
            await b.send(0, 8, 0, flags=reserved | 0x200, local=2040*65536)
            await b.send(8, 8, 2000, flags=reserved)
            await b.result(8, 40*65536)
            await b.drain()
            await b.send(9, 9, 1000, flags=reserved, control=3)
            await b.send(11, 10, 0, flags=reserved | 0x3c, control=5)
            assert b.counts() == (before+2, rejected)
    finally:
        b.stop()


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def delay_request_headers(d):
    # S01/S02/S08: IEEE 1588-2019 13.3/13.6 and Annex F. Compare all bytes
    # before MAC padding/FCS. 13.3.2.13 requires zero controlField in 2019;
    # the explicitly selected 2008-compatible encoding retains Delay_Req=1.
    b = ProtocolBench(d)
    d.txReady.value = 0
    await b.start()
    try:
        for minor, control in ((0, 1), (1, 0)):
            await b.pulse('rst')
            await b.write(0x008, minor << 8, 4)
            await b.configure(min_span=100)
            # Expire the ledger's 5000-tick post-reset quarantine. The bench
            # advances raw time explicitly; waiting on the clock alone cannot.
            b.now += 10000
            d.ticks.value = b.now
            await b.wait(3)
            for i in range(3):
                ticks = b.now+1000
                await b.send(0, i, ticks*8, ticks=ticks)
                got = await b.result(i, 123*65536+7, ticks)
                if i == 2:
                    assert got[4:] == (8 << 48, 1)
                await b.drain()
            for _ in range(20):
                if int(d.txValid.value):
                    break
                await b.wait()
            assert int(d.txValid.value), 'qualified port did not emit Delay_Req'
            packet = bytearray()
            for beat in range(8):
                assert int(d.txValid.value)
                held = tuple(int(getattr(d, name).value) for name in
                             ('txData', 'txKeep', 'txLast', 'txSof', 'txEofe'))
                await b.wait(3)
                assert held == tuple(int(getattr(d, name).value) for name in
                                     ('txData', 'txKeep', 'txLast', 'txSof', 'txEofe'))
                data, keep, last, sof, eofe = held
                assert (keep, last, sof, eofe) == (3 if beat == 7 else 255,
                                                 int(beat == 7), int(beat == 0), 0)
                packet.extend(data.to_bytes(8, 'little')[:2 if last else 8])
                d.txReady.value = 1
                await b.wait()
                d.txReady.value = 0
            expected = bytes.fromhex(
                '011b1900000002000000000188f7'  # Ethernet destination/source/type.
                '0102002c00000000000000000000000000000000'
                '020000fffe00000100010000017f'  # Identity, initial sequence, interval.
                '00000000000000000000')        # Zero originTimestamp.
            expected = bytearray(expected)
            expected[15] = minor << 4 | 2
            expected[46] = control
            assert packet == expected, (packet.hex(), expected.hex())
            assert not int(d.txValid.value)
    finally:
        b.stop()


def test_ptp_specification_rx():
    run_surf_vhdl_test(
        test_file=__file__, toplevel='surf.ptprxfrontendwrapper',
        parameters={'PHY_TYPE_G': 'DIRECT', 'FIFO_DEPTH_G': 4},
        extra_env=cocotb_filtered_env({'PHY_TYPE_G': 'DIRECT', 'FIFO_DEPTH_G': 4},
                                      cocotb_test_filter('literal_rx_headers')),
    )


def test_ptp_specification_protocol():
    run_surf_vhdl_test(
        test_file=__file__, toplevel='surf.ptpportwrapper',
        extra_env=cocotb_filtered_env({}, cocotb_test_filter('interpreted_two_step_correction')),
    )


@pytest.mark.parametrize('scenario', ['minor_versions', 'tlv_suffix'])
def test_ptp_specification_rx_rules(scenario):
    run_surf_vhdl_test(
        test_file=__file__, toplevel='surf.ptprxfrontendwrapper',
        parameters={'PHY_TYPE_G': 'DIRECT', 'FIFO_DEPTH_G': 4},
        extra_env=cocotb_filtered_env({'PHY_TYPE_G': 'DIRECT', 'FIFO_DEPTH_G': 4},
                                      cocotb_test_filter(scenario)),
    )


@pytest.mark.parametrize('scenario', ['receive_control', 'reserved_flags', 'delay_request_headers'])
def test_ptp_specification_protocol_rules(scenario):
    run_surf_vhdl_test(
        test_file=__file__, toplevel='surf.ptpportwrapper',
        extra_env=cocotb_filtered_env({}, cocotb_test_filter(scenario)),
    )
