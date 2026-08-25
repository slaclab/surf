##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from dataclasses import dataclass


@dataclass
class StreamPacingModel:
    """Exact-integer payload token bucket used to prototype SimLink pacing."""

    clock_hz: int
    payload_bps: int
    data_bytes: int = 8
    max_credit_bytes: int = 8

    def __post_init__(self):
        if self.clock_hz <= 0:
            raise ValueError("clock_hz must be positive")
        if self.payload_bps < 0:
            raise ValueError("payload_bps must be nonnegative")
        if self.data_bytes <= 0:
            raise ValueError("data_bytes must be positive")
        if not 0 < self.max_credit_bytes <= self.data_bytes:
            raise ValueError("credit must be between one byte and one beat")
        ceiling = 8 * self.data_bytes * self.clock_hz
        if self.payload_bps > ceiling:
            raise ValueError("payload rate exceeds the interface ceiling")

        # Credit units are bit*Hz. Adding payload_bps once per cycle and
        # charging payload_bits*clock_hz keeps fractional bits/cycle exact.
        self._credit_max = 8 * self.max_credit_bytes * self.clock_hz
        self._credit = self._credit_max
        self.cycle = 0

    @property
    def bypass(self):
        return self.payload_bps == 0

    def step(self, keep, valid=True, ready=True):
        if keep < 0 or keep >= (1 << self.data_bytes):
            raise ValueError("keep is outside the configured data width")

        self.cycle += 1
        if self.bypass:
            return bool(valid and ready)

        self._credit = min(
            self._credit_max,
            self._credit + self.payload_bps,
        )
        cost = 8 * keep.bit_count() * self.clock_hz
        transfer = bool(valid and ready and cost <= self._credit)
        if transfer:
            self._credit -= cost
        return transfer


def interface_ceiling_bps(clock_hz, data_bytes=8):
    return 8 * data_bytes * clock_hz
