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
# - Sweep: Dedicated two-entry TX observer, all normalized beat widths.
# - Stimulus: Independent Delay_Req frames with varying partial beat widths,
#   full capture fields, backpressure, generation changes, overflow and flush;
#   sparse keeps and overlong TLVs exercise rejection before bounded storage.
# - Checks: Every decoded field plus capture increment/error survives RAM;
#   physical completions remain visible even with unusable captures or changing
#   PHC generations. Full-before-edge overflow discards the queued tail.
# - Timing: The descriptor FIFO and two-group decoder publish six clocks
#   after EOF. Consume and invalidate during
#   the write/read pipeline, checking pointer wrap and stale-data rejection.

from fractions import Fraction
import os

import cocotb
from cocotb.triggers import Timer
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_rx_reference import RxMessage, RxStamp
from tests.ethernet.PtpCore.ptp_rx_test_utils import beats, frame, pack_record


@cocotb.test()
async def tx_storage(d):
    depth = int(os.environ["FIFO_DEPTH_G"])
    for name in ("clk", "rst", "rxFlush", "generation", "messageReady", "directValid",
                 "directData", "directKeep", "directSof", "directLast", "directError",
                 "directCaptureError", "directPhase", "phcSeconds", "phcNanoseconds",
                 "phcFraction", "phcIncrement", "tickCount", "timeValid"):
        getattr(d, name).value = 0
    d.phyReady.value = 1
    observed = []

    def payload():
        return (int(d.messageData.value), int(d.messageIncrement.value), int(d.messageError.value))

    async def edge(**values):
        d.clk.value = 0
        before = payload() if d.messageData.value.is_resolvable else None
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(4, unit="ns")
        if before is not None:
            assert payload() == before, "queue payload changed before its register edge"
        if not int(d.rst.value) and int(d.messageValid.value) and int(d.messageReady.value) and not int(d.rxAbort.value):
            observed.append(payload())
        d.clk.value = 1
        await Timer(4, unit="ns")

    await edge(rst=1)
    await edge(rst=0)

    async def send(sequence, *, consume_at_eof=False, sparse=False, tlvs=b"", idle_after=True,
                   width=None, mutation=None, corrupt=False):
        # Delay_Req shares the ten-byte timestamp body with Sync. Set its wire
        # kind independently; the RX-only frame helper intentionally excludes it.
        raw = bytearray(frame(sequence=sequence, marker=sequence, two_step=False, tlvs=tlvs))
        raw[14] = 1
        if mutation is not None:
            mutation(raw)
        seconds = (1 << 40)+sequence
        nanos = 123456789+sequence
        fraction = sequence*29 & 0xffff
        ticks = (1 << 62)+sequence
        generation = sequence*7
        increment = (1 << 35)+sequence*0x102030405
        error = sequence & 1
        stamp = RxStamp(Fraction(((seconds*1000000000+nanos) << 16)+fraction, 1 << 16),
                        ticks, generation, bool(sequence & 1), sequence % 8)
        expected = RxMessage(stamp, int(d.rxEpoch.value), bytes(6),
                             (1, raw[18], bytes(raw[34:44]), sequence), 0,
                             0, 0, 0, 0, 0, 0, bytes(30))
        for index, beat in enumerate(beats(bytes(raw), width=width or sequence % 8+1, corrupt=corrupt)):
            keep = (1 << len(beat.data))-1
            if sparse and index == 1:
                keep &= ~1
            await edge(directValid=1, directData=int.from_bytes(beat.data, "little"),
                       directKeep=keep, directSof=int(beat.sof),
                       directLast=int(beat.eof), directError=0, directCaptureError=error,
                       phcSeconds=seconds, phcNanoseconds=nanos, phcFraction=fraction << 16,
                       phcIncrement=increment, tickCount=ticks, generation=generation,
                       timeValid=sequence & 1, directPhase=sequence % 8,
                       messageReady=int(consume_at_eof and beat.eof))
        if idle_after:
            await edge(directValid=0, messageReady=0)
        return pack_record(expected), increment, error

    async def wait_head():
        # Two compact groups plus the two-stage RAM read pipe after descriptor
        # admission; an empty queue additionally crosses the three-edge FIFO.
        for _ in range(7):
            if int(d.messageValid.value):
                return
            await edge(directValid=0)
        assert False, "Delay_Req descriptor exceeded its decode bound"

    # Every completion traverses the FIFO and two-group decoder. Alternating
    # errors prove that unusable captures still retain completion identity.
    for batch in range(4):
        expected = [await send(20+batch*depth+slot) for slot in range(depth)]
        assert int(d.messageValid.value)
        assert not int(d.rxAbort.value), "TX generation changes must not flush completions"
        for _ in range(3):
            await edge(generation=int(d.generation.value)+1)
            assert payload() == expected[0]
        start = len(observed)
        for value in expected:
            await wait_head()
            assert int(d.messageValid.value) and payload() == value
            await edge(messageReady=1)
        assert observed[start:] == expected
        assert not int(d.messageValid.value)
        await edge(messageReady=0)

    # An empty enqueue must pass through the write/read pipeline before valid.
    # Consume the old head immediately after its successor completes: the head
    # stays empty until the successor reaches it, then delivers exactly once.
    for batch in range(depth+1):
        old = await send(60+2*batch, idle_after=False)
        assert not int(d.messageValid.value)
        for delay in range(1, 7):
            await edge(directValid=0, messageReady=0)
            assert bool(int(d.messageValid.value)) == (delay == 6)
        assert int(d.messageValid.value) and payload() == old
        new = await send(61+2*batch, idle_after=False)
        assert int(d.messageValid.value) and payload() == old
        start = len(observed)
        await edge(directValid=0, messageReady=1)
        assert not int(d.messageValid.value)
        await edge(messageReady=1)
        assert not int(d.messageValid.value)
        await wait_head()
        assert int(d.messageValid.value) and payload() == new
        await edge(messageReady=1)
        assert observed[start:] == [old, new]
        assert not int(d.messageValid.value)
        await edge(messageReady=0)

    # Neither malformed length nor a sparse keep may become a valid record.
    for options in ({"sparse": True}, {"tlvs": bytes.fromhex("1234fffe")},
                    {"tlvs": bytes.fromhex("1234ffff")}):
        accepted = int(d.acceptedCount.value)
        dropped = int(d.droppedCount.value)
        await send(20, **options)
        assert int(d.acceptedCount.value) == accepted
        assert int(d.droppedCount.value) == dropped+1
        assert not int(d.messageValid.value)
    expected = await send(21)
    for _ in range(2):
        await edge(directValid=0, messageReady=0)
    await wait_head()
    assert payload() == expected and int(d.messageValid.value)
    await edge(messageReady=1)
    assert observed[-1] == expected
    await edge(messageReady=0)

    # The fixed-body observer must retain full TLV validation. Sweep every
    # header split and payload run length, including high-byte length changes.
    for width in range(1, 9):
        for length in (0, 2, 4, 6, 14, 254, 256):
            tlvs = (bytes.fromhex("1234") + length.to_bytes(2, "big") +
                    bytes((i * 37 + 11) % 256 for i in range(length)) +
                    bytes.fromhex("567800009abc0002abcddef00000"))
            expected = await send(200+width, width=width, tlvs=tlvs)
            await wait_head()
            assert payload() == expected
            await edge(messageReady=1)
            assert observed[-1] == expected
            await edge(messageReady=0)
        for tail in ("56780001ab", "5678ffffabcd", "56780004abcd", "567800"):
            dropped = int(d.droppedCount.value)
            await send(220+width, width=width, tlvs=bytes.fromhex("12340000"+tail))
            assert int(d.droppedCount.value) == dropped+1
            assert not int(d.messageValid.value)

    # Identity and fixed-body guards now reject at the offending header byte.
    # Invalid input still increments dropped exactly once, at physical EOF.
    mutations = ((12, 0), (13, 0), (14, 0), (15, 0x11), (17, 43),
                 (16, 0xff), (17, 0xff))
    for offset, value in mutations:
        dropped = int(d.droppedCount.value)
        await send(240, mutation=lambda raw: raw.__setitem__(offset, value))
        assert int(d.droppedCount.value) == dropped+1
        assert not int(d.messageValid.value)
    dropped = int(d.droppedCount.value)
    await send(241, corrupt=True)
    assert int(d.droppedCount.value) == dropped+1
    assert not int(d.messageValid.value)
    for minor in (0, 1, 15):
        expected = await send(242, mutation=lambda raw: raw.__setitem__(15, minor*16+2))
        await wait_head()
        assert payload() == expected
        await edge(messageReady=1)
        assert observed[-1] == expected
        await edge(messageReady=0)

    # A non-full queue can consume its head and accept a completion on the same
    # EOF edge. The replacement still traverses the FIFO before publication.
    old = await send(160)
    start = len(observed)
    new = await send(161, consume_at_eof=True)
    assert observed[start:] == [old]
    assert not int(d.messageValid.value)
    for _ in range(2):
        await edge(directValid=0, messageReady=0)
    await wait_head()
    assert int(d.messageValid.value) and payload() == new
    await edge(messageReady=1)
    assert observed[-1] == new
    await edge(messageReady=0)

    # A full queue is not rescued by consuming the head on the completion edge.
    expected = [await send(100+slot) for slot in range(depth)]
    start = len(observed)
    epoch = int(d.rxEpoch.value)
    await send(110, consume_at_eof=True)
    assert observed[start:] == expected[:1]
    assert int(d.overflowCount.value) == 1
    assert int(d.rxEpoch.value) == epoch+1
    assert not int(d.messageValid.value)

    # Flush and system reset invalidate every pipeline stage without clearing
    # payload RAM. Sweep from the pending write through read/head publication.
    # Refill/drain after each event must never expose an old memory entry.
    for reset in (False, True):
        for delay in range(7):
            for slot in range(depth):
                await send(120+slot, idle_after=slot != depth-1)
            for _ in range(delay):
                await edge(directValid=0)
            await edge(directValid=0, **({"rst": 1} if reset else {"rxFlush": 1}))
            assert not int(d.messageValid.value)
            await edge(rst=0, rxFlush=0)
            expected = [await send(140+slot) for slot in range(depth)]
            for _ in range(2):
                await edge(directValid=0, messageReady=0)
            start = len(observed)
            for value in expected:
                await wait_head()
                assert int(d.messageValid.value) and payload() == value
                await edge(messageReady=1)
            assert observed[start:] == expected
            assert not int(d.messageValid.value)
            await edge(messageReady=0)


@pytest.mark.parametrize("depth", [2])
def test_ptp_rx_storage(depth):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.ptprxfrontendwrapper",
        parameters={"PHY_TYPE_G": "DIRECT", "FIFO_DEPTH_G": depth, "TX_OBSERVE_G": True},
        extra_env={"FIFO_DEPTH_G": depth},
    )
