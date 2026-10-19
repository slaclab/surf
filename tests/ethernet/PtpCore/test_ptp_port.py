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
# - Timing: Servo is disabled to isolate protocol behavior. Observe actual RX
#   retirement and poll expected counter publication with bounded deadlines.
#   Wire rejection must retire in the frontend without reaching the engine.
#   Receipt expiry uses a separate short interval; TX qualification retains
#   physical clocks and spacing above the configured minimum rate span.
#   Scenarios are independently selectable; owned monitor/clock tasks are joined.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from tests.common.regression_utils import (
    cancel_and_join_tasks, cocotb_filtered_env, cocotb_test_filter, run_surf_vhdl_test)
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES
from tests.ethernet.PtpCore.ptp_endpoint_test_utils import Bench as EndpointBench, LOCAL
from tests.ethernet.PtpCore.ptp_reference import NS

# Keep the former service allowance as a failure bound, not an unconditional
# delay. This fixture has one frame in flight and no background master traffic.
SERVICE_BOUND = 9000


class Bench(EndpointBench):
    async def start(self):
        self.retired = 0
        await super().start()
        self.tasks.append(cocotb.start_soon(self.monitor_rx()))

    async def monitor_rx(self):
        # Observe the real frontend/engine transfer. Internal handshakes position
        # the stimulus; AXI counters and literal bytes remain the result oracles.
        rx = self.d.gen_model
        while True:
            await RisingEdge(self.d.clk)
            if int(rx.rxvalid.value) and int(rx.rxready.value) and not int(rx.rxabort.value):
                self.retired += 1

    async def counter(self, address, expected=None):
        start = int(self.d.timeTicks.value)
        while int(self.d.timeTicks.value)-start < SERVICE_BOUND:
            await self.snapshot()
            value = await self.read(address)
            if expected is None or value == expected:
                return value
            assert value < expected, (hex(address), value, expected)
        assert False, ('counter completion timeout', hex(address), value, expected)

    async def wire(self, frame, *, dropped=False, rejected=False, **kwargs):
        assert not (dropped and rejected), 'a frame has one rejection owner'
        retired = self.retired
        address = 0x2204 if dropped else 0x220C
        before = await self.counter(address) if dropped or rejected else None
        capture = await super().wire(frame, **kwargs)
        if dropped:
            assert await self.counter(0x2204, before+1) == before+1
            assert self.retired == retired, 'rejected wire frame reached the protocol engine'
        else:
            for _ in range(SERVICE_BOUND):
                if self.retired != retired:
                    break
                await self.wait(1)
            assert self.retired == retired+1, 'RX frame was not consumed'
            # Rejection diagnostics cross one registered stage after admission.
            await self.wait(2)
            if rejected:
                assert await self.counter(address, before+1) == before+1
        return capture

    async def close(self):
        await cancel_and_join_tasks(self.tasks)


@cocotb.test(timeout_time=2, timeout_unit='ms')
async def adversarial_port(d):
    b = Bench(d)
    try:
        await b.start()
        await b.configure()
        await b.write(0x004, 1)
        await b.write(0x4004, 0)  # AXI owns the PHC; the servo only drains.
        # Keep receipt expiry out of association-policy checks; each frame retires
        # through the real frontend/engine handshake before the next is injected.
        await b.write(0x2088, 200000, 8)
        await b.commit()
        generation = int(d.timeGeneration.value)

        async def send(kind, sequence, remote=0, correction=0, patch=None):
            frame = bytearray(b.frame(kind, sequence, remote, correction))
            if patch is not None:
                offset, data = patch
                frame[offset:offset+len(data)] = data
            await b.wire(bytes(frame))

        async def count(expected=None):
            return await b.counter(0x2210, expected)

        await send(8, 1, NS)
        await send(0, 1)
        assert await count(1) == 1
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
        assert await count(2) == 2

        # More than four completed pairs must not exhaust the bounded association
        # table. Completed entries can retire; unmatched entries cannot be evicted.
        for seq in range(10, 18):
            await send(0, seq)
            await send(8, seq, seq*NS)
        assert await count(10) == 10
        assert int(d.portActive.value)
        # Test receipt expiry separately. Applying the shorter configuration
        # restarts acquisition, so accept a fresh pair before waiting for expiry.
        await b.write(0x2088, 2048, 8)
        await b.commit()
        assert not int(d.portActive.value)
        await send(0, 18)
        await send(8, 18, 18*NS)
        assert await count(11) == 11
        assert int(d.portActive.value)
        for _ in range(2049):
            if not int(d.portActive.value):
                break
            await b.wait(1)
        assert not int(d.portActive.value), 'receipt timeout did not expire'
        assert int(d.timeGeneration.value) == generation

        await b.write(0x2088, 200000, 8)
        await b.commit()

        def announce(gm, flags=0x3c):
            frame = bytearray(b.frame(11, 200))
            frame[20:22] = flags.to_bytes(2, 'big')
            frame[58:60] = (37).to_bytes(2, 'big')
            frame[67:75] = gm.to_bytes(8, 'big')
            return bytes(frame)

        await b.wire(announce(0x1234567890abcdef))
        # Nine decoder groups + four publication stages, twelve immutable words,
        # acknowledgement and registered control propagation fit 32 clocks.
        await b.wait(32)
        await b.snapshot()
        assert await b.read(0x044) & (1 << 16)
        assert await b.read(0x2130, 8) == 0x1234567890abcdef
        assert await b.read(0x213C) == 37
        await send(0, 100)
        await send(8, 100, 100*NS)
        assert await count(12) == 12
        assert int(d.portActive.value)
        await b.wire(announce(0xfedcba0987654321))
        await b.wait(32)
        assert not int(d.portActive.value), 'grandmaster change did not cancel old source state'
        await b.snapshot()
        assert await b.read(0x2130, 8) == 0xfedcba0987654321
        assert await b.read(0x2140, 32) == int.from_bytes(announce(0xfedcba0987654321)[48:78], 'big')
        await send(0, 101)
        await send(8, 101, 101*NS)
        assert await count(13) == 13
        assert int(d.portActive.value)
        await b.wire(announce(0xfedcba0987654321, flags=0x34))
        await b.wait(32)
        assert not int(d.portActive.value), 'timescale change retained old acquisition state'
        assert int(d.timeGeneration.value) == generation
        await b.wire(announce(0xfedcba0987654321, flags=3))
        await b.wait(32)
        assert not await b.read(0x044) & (1 << 16)
        assert int(d.timeGeneration.value) == generation
        assert not int(d.timeFault.value)

    finally:
        await b.close()


@cocotb.test(timeout_time=2, timeout_unit='ms')
async def tx_restart(d):
    b = Bench(d)
    try:
        await b.start()
        await b.configure()
        await b.write(0x004, 1)
        await b.write(0x4004, 0)  # AXI owns the PHC; the servo only drains.
        generation = int(d.timeGeneration.value)
        # Qualify the real rate estimator with independent physical timing, then
        # hold the builder's first beat across a logical restart. Bytes already
        # promised to the MAC belong to its physical lifecycle and must still drain.
        await b.write(0x2088, 100000, 8)
        await b.commit()
        d.modelTxReady.value = 0
        # 1,000 idle clocks exceeds configured MinRateSpan=800. wire() waits for
        # ingress retirement; TX validity below is a bounded completion condition.
        await b.source(3, sequence=300, spacing_cycles=1000)
        for _ in range(SERVICE_BOUND):
            if int(d.modelTxValid.value):
                break
            await b.wait(1)
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
        expected[46] = 0  # Default minor version 1: 2019 Layer-2 controlField.
        assert request == expected
        await b.wait(3)
        assert not int(d.modelTxValid.value)
        assert (await b.read(0x2048) >> 16) & 255, 'restart released an unknown physical fate'
        assert int(d.timeGeneration.value) == generation

    finally:
        await b.close()


@cocotb.test(timeout_time=2, timeout_unit='ms')
async def physical_one_step_policy(d):
    b = Bench(d)
    try:
        await b.start()
        await b.configure()
        await b.write(0x004, 1)  # Drain measurements without steering the PHC.
        await b.write(0x4004, 0)
        await b.write(0x20A0, 1000000, 8)
        await b.write(0x20A8, 1000000, 8)
        await b.commit()

        async def count(expected=None):
            return await b.counter(0x2210, expected)

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
            accepted += 1
            assert await count(accepted) == accepted

        # FCS, short-body and unsupported-version errors die in the validator.
        # Profile/domain/flags/source errors die in port policy. Neither path
        # may contaminate the following valid copy of the same sequence.
        seq = 100
        for patch, corrupt, truncate in (
                (None, True, False), (None, False, True),
                ((15, b'\x13'), False, False), ((15, b'\x11'), False, False),
                ((14, b'\x10'), False, False), ((18, b'\x01'), False, False),
                ((20, b'\x02\x01'), False, False), ((34, b'\x80'), False, False),
                ((54, NS.to_bytes(4, 'big')), False, False)):
            seq += 1
            remote = ((1 << 40)+seq)*NS
            frame = bytearray(b.frame(0, seq, remote, two_step=False))
            if patch:
                offset, data = patch
                frame[offset:offset+len(data)] = data
            dropped = corrupt or truncate or (patch is not None and patch[0] == 15)
            await b.wire(bytes(frame[:50] if truncate else frame), corrupt=corrupt,
                         dropped=dropped, rejected=not dropped)
            assert await count() == accepted
            await b.wire(b.frame(0, seq, remote, two_step=False))
            accepted += 1
            assert await count(accepted) == accepted
        assert not int(d.timeFault.value)
    finally:
        await b.close()


@pytest.mark.parametrize('mode', ['XGMII', 'GMII'])
@pytest.mark.parametrize('scenario', ['adversarial_port', 'physical_one_step_policy', 'tx_restart'])
def test_ptp_port(mode, scenario):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpendpointloopbackwrapper',
                      parameters={'PHY_TYPE_G': mode, 'CLK_FREQ_G': 125000000 if mode == 'GMII' else 156250000,
                                  'PACKET_LIFETIME_G': 5000, 'MAC_ENABLE_G': False},
                      extra_env=cocotb_filtered_env({'MODE': mode, 'REAL_MAC': 0}, cocotb_test_filter(scenario)),
                      extra_vhdl_sources={'surf': ETHMAC_RTL_SOURCES + ["ethernet/PtpCore/wrappers/PtpEndpointLoopbackWrapper.vhd"]})
