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
# - Sweep: Bypass, integer/fractional rates, sparse TKEEP, backpressure, two
#   directions, aggregate channels, delayed admission, and interface ceilings.
# - Stimulus: Step a pure integer-credit reference model with AXI Stream
#   valid/ready/keep values; no simulator, wall clock, thread, or ZeroMQ exists.
# - Checks: Pin exact transfer cycles, debit only handshakes, cap idle credit at
#   one beat, share aggregate credit, and reject unrepresentable payload rates.
# - Timing: Every result is in simulation clock cycles. Host arrival delay is
#   modeled only as a frame-admission offset and is excluded from serialization.

import pytest

from tests.simlink.common.stream_pacing_model import (
    interface_ceiling_bps,
    StreamPacingModel,
)


def _transfer_cycles(model, keeps, ready=lambda cycle: True):
    transfers = []
    index = 0
    while index < len(keeps):
        if model.step(keeps[index], ready=ready(model.cycle + 1)):
            transfers.append(model.cycle)
            index += 1
    return transfers


def test_bypass_and_full_rate_preserve_one_beat_per_cycle():
    bypass = StreamPacingModel(clock_hz=100_000_000, payload_bps=0)
    full = StreamPacingModel(
        clock_hz=100_000_000, payload_bps=6_400_000_000
    )
    assert _transfer_cycles(bypass, [0xFF] * 3) == [1, 2, 3]
    assert _transfer_cycles(full, [0xFF] * 3) == [1, 2, 3]


def test_integer_fractional_and_sparse_keep_cycles_are_exact():
    half = StreamPacingModel(
        clock_hz=100_000_000, payload_bps=3_200_000_000
    )
    fractional = StreamPacingModel(
        clock_hz=10, payload_bps=120, max_credit_bytes=3
    )
    sparse = StreamPacingModel(
        clock_hz=100_000_000, payload_bps=800_000_000
    )

    assert _transfer_cycles(half, [0xFF] * 3) == [1, 3, 5]
    assert _transfer_cycles(fractional, [0x07] * 3) == [1, 3, 5]
    assert _transfer_cycles(sparse, [0x81, 0x01, 0x08]) == [1, 2, 3]


def test_backpressure_cannot_bank_more_than_one_beat():
    model = StreamPacingModel(
        clock_hz=100_000_000, payload_bps=3_200_000_000
    )
    cycles = _transfer_cycles(
        model,
        [0xFF, 0xFF],
        ready=lambda cycle: cycle >= 11,
    )
    assert cycles == [11, 13]


def test_directional_and_aggregate_instances_are_independent():
    inbound = StreamPacingModel(clock_hz=10, payload_bps=320)
    outbound = StreamPacingModel(clock_hz=10, payload_bps=640)
    assert _transfer_cycles(inbound, [0xFF] * 3) == [1, 3, 5]
    assert _transfer_cycles(outbound, [0xFF] * 3) == [1, 2, 3]

    aggregate = StreamPacingModel(clock_hz=10, payload_bps=320)
    channels = [0, 1, 0, 1]
    transfers = _transfer_cycles(aggregate, [0xFF] * len(channels))
    assert list(zip(transfers, channels)) == [(1, 0), (3, 1), (5, 0), (7, 1)]


def test_serialization_is_independent_of_host_admission_delay():
    def serialized_offsets(delay):
        model = StreamPacingModel(clock_hz=10, payload_bps=320)
        for _ in range(delay):
            assert not model.step(0, valid=False)
        absolute = _transfer_cycles(model, [0xFF] * 3)
        return [cycle - delay for cycle in absolute]

    assert serialized_offsets(0) == serialized_offsets(100) == [1, 3, 5]


@pytest.mark.parametrize(
    ("clock_hz", "ceiling"),
    ((100_000_000, 6_400_000_000), (156_250_000, 10_000_000_000)),
)
def test_interface_ceiling_is_explicit(clock_hz, ceiling):
    assert interface_ceiling_bps(clock_hz) == ceiling
    StreamPacingModel(clock_hz=clock_hz, payload_bps=ceiling)
    with pytest.raises(ValueError, match="interface ceiling"):
        StreamPacingModel(clock_hz=clock_hz, payload_bps=ceiling + 1)


@pytest.mark.parametrize("payload_bps", (25_000_000_000, 100_000_000_000))
def test_high_rate_profiles_require_a_wider_or_coarser_boundary(payload_bps):
    with pytest.raises(ValueError, match="interface ceiling"):
        StreamPacingModel(clock_hz=156_250_000, payload_bps=payload_bps)
