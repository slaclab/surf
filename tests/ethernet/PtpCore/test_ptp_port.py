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
# - Sweep: Physical GMII/XGMII input through the production validator and port.
# - Stimulus: One-step/mixed-mode traffic, malformed wire frames, Follow_Up
#   before Sync, replay, conflicting Follow_Up, duplicate
#   Sync, foreign identity, invalid timestamp, completed-table replacement,
#   timeout, and configured-source grandmaster/time-property changes.
# - Checks: Exact completed-pair counts, rejected traffic isolation, Announce
#   snapshots, abort-driven restart, and every stalled/drained TX beat.
# - Timing: Servo is disabled to isolate protocol behavior. Per-frame processing
#   and timeout waits are bounded; source timestamps need only be chronological.
#   Association-policy traffic uses the normal receipt timeout on both PHYs;
#   the short receipt-timeout scenario is configured and reacquired separately.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES
from tests.ethernet.PtpCore.ptp_endpoint_test_utils import Bench, LOCAL
from tests.ethernet.PtpCore.ptp_reference import NS

@cocotb.test()
async def adversarial_port(d):
    b = Bench(d)
    await b.start()
    await b.configure()
    await b.write(0x004, 1)
    # Keep the configured 10000-cycle receipt timeout during policy checks.
    # GMII serialization plus the rejected-message sequence exceeds 1000
    # cycles without a fresh accepted Sync. Expiry would correctly flush the
    # conflicting association and invalidate this test's retained-key premise.
    await b.commit()
    generation = int(d.timeGeneration.value)

    async def send(kind, sequence, remote=0, correction=0, patch=None):
        frame = bytearray(b.frame(kind, sequence, remote, correction))
        if patch is not None:
            offset, data = patch
            frame[offset:offset+len(data)] = data
        await b.wire(bytes(frame))
        await b.wait(160)

    async def count():
        await b.snapshot()
        return await b.read(0x2210)

    await send(8, 1, NS)
    await send(0, 1)
    assert await count() == 1
    await send(0, 1)
    await send(8, 1, NS)
    assert await count() == 1
    await send(8, 2, 2*NS)
    await send(8, 2, 2*NS, correction=1)
    await send(0, 2)
    assert await count() == 1
    await send(0, 3)
    await send(0, 3)
    await send(8, 3, 3*NS)
    assert await count() == 1
    # The whole frame has a valid FCS; profile policy, not framing, rejects it.
    await send(0, 4, patch=(34, bytes.fromhex('ffffffffffffffff0001')))
    await send(8, 4, 4*NS)
    assert await count() == 1
    await send(0, 5)
    await send(8, 5, 5*NS, patch=(54, NS.to_bytes(4, 'big')))
    assert await count() == 1
    await send(8, 5, 5*NS)
    assert await count() == 2

    # More than four completed pairs must not exhaust the bounded association
    # table. Completed entries can retire; unmatched entries cannot be evicted.
    for seq in range(10, 18):
        await send(0, seq)
        await send(8, seq, seq*NS)
    assert await count() == 10
    assert int(d.portActive.value)
    # Test receipt expiry separately. Applying the shorter configuration
    # restarts acquisition, so accept a fresh pair before waiting for expiry.
    await b.write(0x2088, 1000, 8)
    await b.commit()
    assert not int(d.portActive.value)
    await send(0, 18)
    await send(8, 18, 18*NS)
    assert await count() == 11
    assert int(d.portActive.value)
    await b.wait(1100)
    assert not int(d.portActive.value)

    def announce(gm, flags=0x3c):
        frame = bytearray(b.frame(11, 200))
        frame[20:22] = flags.to_bytes(2, 'big')
        frame[58:60] = (37).to_bytes(2, 'big')
        frame[67:75] = gm.to_bytes(8, 'big')
        return bytes(frame)

    await b.wire(announce(0x1234567890abcdef))
    await b.wait(20)
    await b.snapshot()
    assert await b.read(0x044) & (1 << 16)
    assert await b.read(0x2130, 8) == 0x1234567890abcdef
    assert await b.read(0x213C) == 37
    await send(0, 100)
    await send(8, 100, 100*NS)
    assert int(d.portActive.value)
    await b.wire(announce(0xfedcba0987654321))
    await b.wait(20)
    assert not int(d.portActive.value), 'grandmaster change did not cancel old source state'
    await b.snapshot()
    assert await b.read(0x2130, 8) == 0xfedcba0987654321
    assert await b.read(0x2140, 32) == int.from_bytes(announce(0xfedcba0987654321)[48:78], 'big')
    await send(0, 101)
    await send(8, 101, 101*NS)
    assert int(d.portActive.value)
    await b.wire(announce(0xfedcba0987654321, flags=0x34))
    await b.wait(20)
    assert not int(d.portActive.value), 'timescale change retained old acquisition state'
    assert int(d.timeGeneration.value) == generation
    await b.wire(announce(0xfedcba0987654321, flags=3))
    await b.wait(20)
    assert not await b.read(0x044) & (1 << 16)
    assert int(d.timeGeneration.value) == generation
    assert not int(d.timeFault.value)

    # Qualify the real rate estimator with independent physical timing, then
    # hold the builder's first beat across a logical restart. Bytes already
    # promised to the MAC belong to its physical lifecycle and must still drain.
    await b.write(0x2088, 10000, 8)
    await b.commit()
    d.modelTxReady.value = 0
    await b.source(3, sequence=300)
    assert int(d.modelTxValid.value)
    held = tuple(int(getattr(d, name).value) for name in
                 ('modelTxData', 'modelTxKeep', 'modelTxLast', 'modelTxSof'))
    d.portRst.value = 1
    for _ in range(17):
        await b.wait(1)
        assert int(d.modelTxValid.value)
        assert held == tuple(int(getattr(d, name).value) for name in
                             ('modelTxData', 'modelTxKeep', 'modelTxLast', 'modelTxSof'))
    d.portRst.value = 0
    d.modelTxReady.value = 1
    request = bytearray()
    for index in range(8):
        await RisingEdge(d.clk)
        assert int(d.modelTxValid.value)
        assert int(d.modelTxSof.value) == int(index == 0)
        assert int(d.modelTxKeep.value) == (3 if index == 7 else 255)
        assert int(d.modelTxLast.value) == int(index == 7)
        request += int(d.modelTxData.value).to_bytes(8, 'little')[:2 if index == 7 else 8]
        await Timer(1.1, unit='ns')
    expected = bytearray(b.frame(0, 0)[:58])
    expected[6:12] = bytes.fromhex('020000000001')
    expected[14] = 1
    expected[20:22] = bytes(2)
    expected[34:44] = LOCAL
    expected[46] = 1
    assert request == expected
    await b.wait(3)
    assert not int(d.modelTxValid.value)
    assert (await b.read(0x2048) >> 16) & 255, 'restart released an unknown physical fate'
    assert int(d.timeGeneration.value) == generation
    b.stop()


@cocotb.test()
async def physical_one_step_policy(d):
    b = Bench(d)
    await b.start()
    try:
        await b.configure()
        await b.write(0x004, 1)  # Drain measurements without steering the PHC.
        await b.write(0x20A0, 1000000, 8)
        await b.write(0x20A8, 1000000, 8)
        await b.commit()

        async def count():
            await b.snapshot()
            return await b.read(0x2210)

        # Per-message mode selection, upper seconds bits, second carry and both
        # XGMII start lanes. No Follow_Up is sent for any one-step sequence.
        accepted = 0
        for i in range(8):
            two_step = bool(i % 2)
            seq = (65532+i) & 0xffff
            remote = (1 << 40)*NS+i*NS+NS-1
            await b.wire(b.frame(0, seq, remote, 32769, two_step=two_step),
                         lane=4*((i//2) % 2) if b.mode == 'XGMII' else 0)
            if two_step:
                await b.wire(b.frame(8, seq, remote, -17))
            await b.wait(160)
            accepted += 1
            assert await count() == accepted

        # FCS, short-body and unsupported-version errors die in the validator.
        # Profile/domain/flags/control errors die in port policy. Neither path
        # may contaminate the following valid copy of the same sequence.
        seq = 100
        for patch, corrupt, truncate in (
                (None, True, False), (None, False, True),
                ((15, b'\x13'), False, False), ((15, b'\x22'), False, False),
                ((14, b'\x10'), False, False), ((18, b'\x01'), False, False),
                ((20, b'\x02\x01'), False, False), ((46, b'\x01'), False, False),
                ((54, NS.to_bytes(4, 'big')), False, False)):
            seq += 1
            remote = ((1 << 40)+seq)*NS
            frame = bytearray(b.frame(0, seq, remote, two_step=False))
            if patch:
                offset, data = patch
                frame[offset:offset+len(data)] = data
            await b.wire(bytes(frame[:50] if truncate else frame), corrupt=corrupt)
            await b.wait(160)
            assert await count() == accepted
            await b.wire(b.frame(0, seq, remote, two_step=False))
            await b.wait(160)
            accepted += 1
            assert await count() == accepted
        assert not int(d.timeFault.value)
    finally:
        b.stop()


@pytest.mark.parametrize('mode', ['XGMII', 'GMII'])
def test_ptp_port(mode):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpendpointloopbackwrapper',
                      parameters={'PHY_TYPE_G': mode, 'CLK_FREQ_G': 125000000 if mode == 'GMII' else 156250000,
                                  'PACKET_LIFETIME_G': 5000, 'MAC_ENABLE_G': False},
                      extra_env={'MODE': mode, 'REAL_MAC': 0},
                      extra_vhdl_sources={'surf': ETHMAC_RTL_SOURCES})
