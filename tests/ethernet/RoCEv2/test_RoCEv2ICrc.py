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
# - Sweep: Both directions of the engine, SEND_MODE_G true and false, against
#   the same stimulus. SEND_MODE_G is the only generic that changes behaviour
#   (it selects three lookup-table base offsets); everything else in the
#   datapath is fixed, so two cases cover the configuration space.
# - Stimulus: Seven scenarios per direction, each driving whole packets through
#   the slave port and reading the single CRC word each packet produces.
#   Single-beat packets at every valid-lane count from 1 to 32; multi-beat
#   packets including one whose non-final beat is partial; packets with a hole
#   punched in s_axis_tkeep; seeded random payloads and seeded random tkeep;
#   a packet driven while the output side is back-pressured; a reset asserted
#   mid-packet; and a message carrying its own trailing CRC word.
# - Checks: Every packet's CRC word is compared against an independent Python
#   reference that shares no code with the RTL -- icrc_send_reference() is
#   CPython's zlib.crc32 and icrc_recv_reference() is the residue closed form,
#   so a misunderstanding shared between the RTL and a from-scratch Python
#   transliteration of that same RTL cannot pass vacuously. Each packet must
#   produce exactly one word. IcrcProtocolChecker runs for the whole of every
#   scenario and must report no handshake violation. The back-pressure
#   scenario additionally asserts s_axis_tready falls while the output holds,
#   checks the held word's value on every stalled cycle rather than at the
#   accepting edge (samples land 2 ns past the edge, by which point a
#   registered output that was just accepted has already deasserted), and
#   the Recv residue case asserts a message carrying its own correct CRC
#   little-endian yields exactly zero, which is the pass condition
#   EthMacRxCheckICrc.vhd consumes.
# - Timing: The engine is an eight-stage pipeline, so a packet's CRC word
#   appears eight clocks after its tlast beat is accepted; each scenario
#   drains DRAIN_CYCLES past the last beat rather than assuming a fixed
#   latency. Every sample is taken 2 ns past the rising edge, not 1 ns,
#   because sampling exactly at the entity's own default TPD_G of 1 ns can
#   race its `r <= rin after TPD_G` register update. s_axis_tready is
#   combinational from m_crc_stream_ready, so stalling the output stalls the
#   input in the same cycle.

from __future__ import annotations

import random
import zlib

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.ethernet.RoCEv2.roce_test_utils import (
    IcrcProtocolChecker,
    collect_icrc_words,
    drive_icrc_beats,
    icrc_beats_from_payload,
    icrc_recv_reference,
    icrc_send_reference,
    masked_payload_from_recorded_beats,
)

CLK_NS = 10.0
RESET_HOLD_CYCLES = 4
# Eight pipeline stages plus margin, so a packet's word is always observed
# within one drain window after its last beat is accepted.
DRAIN_CYCLES = 24
# The Recv reference splits a trailing four-byte CRC word off the message, so
# it is undefined below four bytes. The Send sweep starts at one byte.
RECV_MIN_BYTES = 4
AXIS_LANES = 32


def beat(lane_bytes: bytes, *, tkeep: int, tlast: int) -> dict[str, int]:
    """Build one slave-side beat from explicit lane bytes and an arbitrary
    tkeep, for the shapes icrc_beats_from_payload() cannot express: a partial
    non-final beat, or a tkeep with a hole in it.

    Lane `j` of `lane_bytes` lands at bits 8*j+7 downto 8*j of s_axis_tdata,
    the same little-endian packing icrc_beats_from_payload() uses. Bytes in
    lanes that tkeep masks off are still driven; masking them off is the
    engine's job, and driving something nonzero there is what makes the mask
    observable.
    """
    return {
        "s_axis_tdata": int.from_bytes(lane_bytes.ljust(AXIS_LANES, b"\x00"), "little"),
        "s_axis_tkeep": tkeep,
        "s_axis_tlast": tlast,
        "s_axis_tuser": 0,
    }


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.send_mode = env_flag("SEND_MODE_G", default=True)

        # Drive every input to a known state before time begins.
        dut.s_axis_tvalid.setimmediatevalue(0)
        dut.s_axis_tdata.setimmediatevalue(0)
        dut.s_axis_tkeep.setimmediatevalue(0)
        dut.s_axis_tlast.setimmediatevalue(0)
        dut.s_axis_tuser.setimmediatevalue(0)
        dut.m_crc_stream_ready.setimmediatevalue(1)
        dut.RST_N.setimmediatevalue(0)

        cocotb.start_soon(Clock(dut.CLK, CLK_NS, unit="ns").start())

        # The checker watches every cycle of the scenario, including the reset
        # window, and is inspected once at the end of each test.
        self.checker = IcrcProtocolChecker(dut, dut.CLK)
        self.checker.start()

    async def reset(self) -> None:
        self.dut.RST_N.value = 0
        for _ in range(RESET_HOLD_CYCLES):
            await RisingEdge(self.dut.CLK)
        self.dut.RST_N.value = 1
        await RisingEdge(self.dut.CLK)

    def reference(self, payload: bytes) -> int:
        """The expected CRC word for `payload` in whichever direction this
        build selected. Both references are independent of the RTL.
        """
        return icrc_send_reference(payload) if self.send_mode else icrc_recv_reference(payload)

    async def crc_word(self, beats: list[dict[str, int]]) -> int:
        """Drive one packet and return the single CRC word it produces.

        Packets are driven one at a time rather than back to back so a
        mismatch names the packet that caused it. The eight idle drain cycles
        between packets cost nothing measurable and keep the word-to-packet
        mapping unambiguous.
        """
        await drive_icrc_beats(self.dut, beats)
        words = await collect_icrc_words(self.dut, DRAIN_CYCLES)
        assert len(words) == 1, (
            f"expected exactly one CRC word per packet, got {len(words)}: "
            f"{[f'{word:#010x}' for word in words]}"
        )
        return words[0]

    async def check_packet(self, beats: list[dict[str, int]], *, label: str) -> None:
        """Drive one packet and compare its word against the reference payload
        reconstructed from the very beats that were driven.
        """
        payloads = masked_payload_from_recorded_beats(beats)
        assert len(payloads) == 1, f"{label}: beat list does not describe exactly one packet"
        expected = self.reference(payloads[0])
        word = await self.crc_word(beats)
        assert word == expected, (
            f"{label}: CRC word {word:#010x} does not equal the reference {expected:#010x} "
            f"for the {len(payloads[0])}-byte effective payload"
        )

    def direction(self) -> str:
        return "Send" if self.send_mode else "Recv"


@cocotb.test()
async def rocev2icrc_single_beat_width_sweep_test(dut):
    """Every single-beat valid-lane count the engine can be handed.

    The shift amount the first pipeline stage derives from tkeep is a distinct
    value for each of these, and a single-beat packet is also the only shape
    that fires the Recv-only four-byte addition to the intermediate-CRC shift
    (the isFirst-and-isLast-together branch), so this sweep is what covers
    that branch.
    """
    tb = TB(dut)
    await tb.reset()

    first_width = 1 if tb.send_mode else RECV_MIN_BYTES
    for width in range(first_width, AXIS_LANES + 1):
        payload = bytes(range(width))
        await tb.check_packet(
            icrc_beats_from_payload(payload),
            label=f"{tb.direction()} single beat, {width} valid lane(s)",
        )

    violations = tb.checker.report()
    assert not violations, "; ".join(violations)


@cocotb.test()
async def rocev2icrc_multi_beat_test(dut):
    """Packets spanning more than one beat, including one whose non-final beat
    is partial.

    That last shape is the one that distinguishes the real datapath from a
    plausible wrong model of it: a non-final beat with n valid lanes
    contributes 32 - n zero bytes *before* its data, because the running CRC
    advances a full 32 byte positions per beat regardless of tkeep. Padding at
    the trailing end instead passes every single-beat and every full-beat case
    and fails only here.
    """
    tb = TB(dut)
    await tb.reset()

    # Two full beats, then three beats with a six-lane tail.
    await tb.check_packet(
        icrc_beats_from_payload(bytes(range(64))),
        label=f"{tb.direction()} 64 bytes over two full beats",
    )
    await tb.check_packet(
        icrc_beats_from_payload(bytes(range(70))),
        label=f"{tb.direction()} 70 bytes over three beats",
    )

    # Sixteen valid lanes on the non-final beat and eight on the final beat:
    # a 40-byte effective payload of 16 leading zeros, 16 data bytes, then 8.
    partial_first = [
        beat(bytes(range(16)), tkeep=0xFFFF, tlast=0),
        beat(bytes(range(16, 24)), tkeep=0x00FF, tlast=1),
    ]
    await tb.check_packet(
        partial_first,
        label=f"{tb.direction()} partial non-final beat (16 lanes) then 8-lane final beat",
    )

    violations = tb.checker.report()
    assert not violations, "; ".join(violations)


@cocotb.test()
async def rocev2icrc_noncontiguous_keep_test(dut):
    """tkeep with a hole in it, single-beat and multi-beat.

    A masked lane below the highest set tkeep bit is a zero data byte, not a
    skipped byte: the effective payload keeps its position and takes the value
    zero. Driving nonzero data into the masked lane is what makes the mask
    observable rather than coincidentally correct.
    """
    tb = TB(dut)
    await tb.reset()

    # Ten lanes with lane 1 masked off. The effective payload is bytes 0..9
    # with byte 1 replaced by zero.
    await tb.check_packet(
        [beat(bytes(range(10)), tkeep=0x03FD, tlast=1)],
        label=f"{tb.direction()} single beat, tkeep hole at lane 1",
    )

    # A hole on the non-final beat as well, so the front-padding rule and the
    # masking rule are exercised together rather than one at a time.
    await tb.check_packet(
        [
            beat(bytes(range(20)), tkeep=0x000FBFFF, tlast=0),
            beat(bytes(range(20, 32)), tkeep=0x00000FFB, tlast=1),
        ],
        label=f"{tb.direction()} multi-beat, tkeep holes on both beats",
    )

    violations = tb.checker.report()
    assert not violations, "; ".join(violations)


@cocotb.test()
async def rocev2icrc_random_test(dut):
    """Seeded random payloads and seeded random tkeep.

    The seed is fixed so a failure is reproducible from the test name alone.
    Beat counts, lane counts, and tkeep holes are all drawn, which is what
    catches an interaction between the shift amount and the accumulator that
    a curated list would have to anticipate to cover.
    """
    tb = TB(dut)
    await tb.reset()

    rng = random.Random(0x1C5EED)

    for packet_index in range(24):
        beat_count = rng.randint(1, 4)
        beats = []
        for beat_index in range(beat_count):
            is_last = beat_index == beat_count - 1
            nlanes = rng.randint(1, AXIS_LANES)
            # A random tkeep over the low nlanes bits with the top valid lane
            # forced set, so nlanes is exactly what the engine derives.
            tkeep = rng.getrandbits(nlanes) | (1 << (nlanes - 1))
            beats.append(
                beat(bytes(rng.randrange(256) for _ in range(nlanes)), tkeep=tkeep, tlast=1 if is_last else 0)
            )

        payloads = masked_payload_from_recorded_beats(beats)
        if len(payloads[0]) < RECV_MIN_BYTES and not tb.send_mode:
            # No CRC trailer to split off; the Recv reference is undefined.
            continue

        await tb.check_packet(beats, label=f"{tb.direction()} random packet {packet_index} ({beat_count} beat(s))")

    violations = tb.checker.report()
    assert not violations, "; ".join(violations)


@cocotb.test()
async def rocev2icrc_backpressure_test(dut):
    """A packet driven while the output side refuses the word.

    Only the single output holding register is elastic, so when
    m_crc_stream_ready is low with a word waiting, every stage holds and
    s_axis_tready falls in the same cycle. This is the scenario that makes the
    checker's hold-while-stalled properties do real work, and it proves the
    word survives the stall rather than being dropped or recomputed.
    """
    tb = TB(dut)
    await tb.reset()

    payload = bytes(range(48))
    expected = tb.reference(masked_payload_from_recorded_beats(icrc_beats_from_payload(payload))[0])

    # Refuse the word before the packet is driven, so the stall is already in
    # place by the time the pipeline reaches the output register.
    dut.m_crc_stream_ready.value = 0
    await drive_icrc_beats(dut, icrc_beats_from_payload(payload))

    # Wait for the word to reach the output register and observe the stall.
    stalled_ready_low = False
    for _ in range(DRAIN_CYCLES):
        await RisingEdge(dut.CLK)
        await Timer(2, unit="ns")
        if int(dut.m_crc_stream_valid.value) == 1:
            assert int(dut.m_crc_stream_data.value) == expected, (
                f"stalled CRC word {int(dut.m_crc_stream_data.value):#010x} does not equal the "
                f"reference {expected:#010x}"
            )
            if int(dut.s_axis_tready.value) == 0:
                stalled_ready_low = True

    assert stalled_ready_low, (
        "s_axis_tready never fell while a CRC word was waiting with m_crc_stream_ready low; "
        "the stall path was not exercised"
    )

    # Release the stall. The word's value was already asserted above on every
    # stalled cycle, so all that is left to prove is that it gets accepted,
    # which is visible as m_crc_stream_valid falling. Acceptance cannot be
    # observed by sampling for a valid-and-ready cycle here: the handshake
    # completes on the edge, and these samples land 2 ns past it, by which
    # point the registered output has already deasserted.
    dut.m_crc_stream_ready.value = 1
    accepted = False
    for _ in range(DRAIN_CYCLES):
        await RisingEdge(dut.CLK)
        await Timer(2, unit="ns")
        if int(dut.m_crc_stream_valid.value) == 0:
            accepted = True
            break

    assert accepted, (
        "m_crc_stream_valid never fell after m_crc_stream_ready returned high; the held CRC "
        "word was never accepted"
    )

    violations = tb.checker.report()
    assert not violations, "; ".join(violations)


@cocotb.test()
async def rocev2icrc_reset_recovery_test(dut):
    """A reset asserted mid-packet, then a complete fresh packet.

    The running accumulator only updates four stages after a beat is accepted
    (preProcess -> shiftInput -> readCrcTab -> reduceCrc -> accuCrc), so the
    bench idles six cycles after the partial beat to be sure the accumulator
    genuinely holds a nonzero partial-packet value before reset lands. Without
    that wait the reset could land before the beat ever reached the register,
    which would make this scenario a no-op.
    """
    tb = TB(dut)
    await tb.reset()

    # Drive the first beat only of a two-beat packet, leaving the pipeline
    # mid-packet with isFirstFlag already advanced past its post-reset '1'.
    first_beat = icrc_beats_from_payload(bytes(range(64)))[0]
    await drive_icrc_beats(dut, [first_beat])
    for _ in range(6):
        await RisingEdge(dut.CLK)

    dut.RST_N.value = 0
    for _ in range(2):
        await RisingEdge(dut.CLK)
    dut.RST_N.value = 1

    # A complete, fresh packet must now produce exactly one correct word.
    await tb.check_packet(
        icrc_beats_from_payload(bytes(range(64))),
        label=f"{tb.direction()} 64 bytes after a mid-packet reset",
    )

    violations = tb.checker.report()
    assert not violations, "; ".join(violations)


@cocotb.test()
async def rocev2icrc_recv_residue_test(dut):
    """A message carrying its own correct CRC little-endian.

    In the Recv direction the residue must be exactly zero, which is the
    condition EthMacRxCheckICrc.vhd tests with
    `or_reduce(ibCrcM.tData(31 downto 0)) = '0'`. Trailer byte order is load
    bearing: the same payload with its CRC appended big-endian does not give
    zero. The Send direction drives the identical stimulus and is held to its
    own reference, so both builds exercise the same bytes.
    """
    tb = TB(dut)
    await tb.reset()

    for payload_length in (6, 32, 64):
        payload = bytes(range(payload_length))
        message = payload + (zlib.crc32(payload) & 0xFFFFFFFF).to_bytes(4, "little")

        beats = icrc_beats_from_payload(message)
        word = await tb.crc_word(beats)
        expected = tb.reference(masked_payload_from_recorded_beats(beats)[0])
        assert word == expected, (
            f"{tb.direction()} {len(message)}-byte self-checking message: CRC word {word:#010x} "
            f"does not equal the reference {expected:#010x}"
        )
        if not tb.send_mode:
            assert word == 0, (
                f"Recv residue for a {len(message)}-byte message carrying its own correct CRC "
                f"little-endian is {word:#010x}, not zero"
            )

    violations = tb.checker.report()
    assert not violations, "; ".join(violations)


PARAMETER_SWEEP = [
    parameter_case("send", SEND_MODE_G="true"),
    parameter_case("recv", SEND_MODE_G="false"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RoCEv2ICrc(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rocev2icrc",
        parameters=parameters,
        extra_env=parameters,
    )
