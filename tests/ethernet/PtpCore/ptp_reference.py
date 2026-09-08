##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Executable Phase 0 contracts, independent of any production PTP RTL.

Fractions are the mathematical oracle; the PHC deliberately uses split integer
registers so its carry/rounding behavior can be checked against that oracle.
"""

from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
from fractions import Fraction

NS = 1_000_000_000
Q16 = 1 << 16
Q32 = 1 << 32
MAX_SECONDS = 1 << 48


def nearest(value):
    """Round an exact rational to nearest integer, ties away from zero."""
    value = Fraction(value)
    magnitude = (2 * abs(value.numerator) + value.denominator) // (2 * value.denominator)
    return -magnitude if value < 0 else magnitude


def checked_signed(value, width):
    if not -(1 << (width - 1)) <= value < (1 << (width - 1)):
        raise OverflowError(f"signed {width}-bit range")
    return value


def rate_addend(nominal_q32, rate_ppb_q16):
    return checked_signed(nearest(Fraction(nominal_q32 * rate_ppb_q16, NS * Q16)), 64)


def e2e(t1, t2, t3, t4, c_sync=0, c_delay=0, local_elapsed=None, asymmetry=0):
    """Return path delay and local-minus-master offset, in exact nanoseconds.

    local_elapsed is the elapsed master time between the two local captures,
    reconstructed from an unsteered counter and a qualified rate estimate.
    Omitting it reproduces the equal-rate equation, including its bias.
    """
    elapsed = t3 - t2 if local_elapsed is None else local_elapsed
    delay = Fraction((t4 - c_delay) - (t1 + c_sync) - elapsed, 2)
    offset = t2 - (t1 + c_sync + delay) - asymmetry
    return delay, offset


def estimate_rate(remote_a, remote_b, ticks_a, ticks_b):
    if ticks_b <= ticks_a or remote_b <= remote_a:
        raise ValueError("rate observations must advance")
    return Fraction(remote_b - remote_a, ticks_b - ticks_a)


def e2e_q16(t1, t2, t4, c_sync, c_delay, tick_span, ns_per_tick_q48, asymmetry=0):
    """Fixed-point candidate using a 64-bit span and Q16.48 ns/tick ratio.

    Inputs/outputs other than tick_span and ratio are signed Q16 nanoseconds.
    Each product/difference is explicitly checked before narrowing.
    """
    if not 0 <= tick_span < (1 << 63) or not 0 < ns_per_tick_q48 < (1 << 63):
        raise ValueError("invalid interval or rate ratio")
    product = checked_signed(tick_span * ns_per_tick_q48, 128)
    elapsed = nearest(Fraction(product, Q32))
    forward = checked_signed(t2 - t1 - c_sync, 128)
    remote_span = checked_signed(t4 - c_delay - t1 - c_sync, 128)
    delay = nearest(Fraction(checked_signed(remote_span - elapsed, 128), 2))
    offset = checked_signed(forward - delay - asymmetry, 128)
    return delay, offset


class SnapshotMailbox:
    """Reference transaction identity across independent read/PHC resets.

    Reset cancels the pending request; it does not promise an acknowledgement
    from a stopped clock. A new request uses a fresh token after reset recovery.
    This models the required semantics, not a CDC circuit.
    """

    def __init__(self):
        self.token = 0
        self.pending = None

    def request(self):
        if self.pending is not None:
            raise RuntimeError("snapshot busy")
        self.token += 1
        self.pending = self.token
        return self.token

    def reset(self):
        self.pending = None
        self.token += 1

    def complete(self, token, time_record):
        if token != self.pending:
            return None
        self.pending = None
        return tuple(time_record)


@dataclass(frozen=True)
class Capture:
    key: tuple
    wire_id: int  # Oracle-only identity: never available to a header-key matcher.
    timestamp: Fraction
    generation: int = 0
    valid: bool = True


class KeyedJoin:
    """The rejected live-table-only proposal, kept to reproduce counterexamples."""

    def __init__(self):
        self.events = defaultdict(deque)
        self.frames = defaultdict(deque)
        self.ambiguous = set()

    def event(self, capture):
        if capture.valid:
            self.events[capture.key].append(capture)

    def frame(self, key, oracle_wire_id):
        self.frames[key].append(oracle_wire_id)

    def match(self, key):
        events, frames = self.events[key], self.frames[key]
        if len(events) > 1 or len(frames) > 1:
            self.ambiguous.add(key)
        if key in self.ambiguous or not events or not frames:
            return None
        return events.popleft(), frames.popleft()


class AtomicCaptureQueue:
    """Alternative contract: validated message and capture form one queue item.

    The queue operates at the capture/validation boundary, before any independent
    packet loss. It does not infer wire identity from another, lossy stream.
    Overflow/flush wins over enqueue or dequeue on the same edge.
    """

    def __init__(self, depth=4):
        self.depth = depth
        self.generation = 0
        self.entries = deque()
        self.overflows = 0

    def edge(self, capture=None, ready=False, flush=False):
        if flush or (capture is not None and len(self.entries) == self.depth):
            self.overflows += not flush
            self.generation += 1
            self.entries.clear()
            return None
        result = self.entries.popleft() if ready and self.entries else None
        if capture is not None and capture.valid and capture.generation == self.generation:
            self.entries.append(capture)
        return result


@dataclass(frozen=True)
class PhcCommand:
    kind: str
    value: int
    generation: int


class PhcModel:
    """Split-register Q32 PHC; a command commits at the next tick after submit.

    Tick priority: system reset, accepted command, ordinary increment. Phase
    commands apply to the normally advanced commit-edge time. A capture on a
    discontinuity edge is suppressed. Manual absolute set names commit time.
    """

    def __init__(self, frequency):
        self.nominal = nearest(Fraction(NS * Q32, frequency))
        self.seconds = self.nanoseconds = self.fraction = self.rate = 0
        self.ticks = self.generation = 0
        self.valid = False
        self.pending = None

    @property
    def time_q32(self):
        return ((self.seconds * NS + self.nanoseconds) << 32) + self.fraction

    def submit(self, command):
        if self.pending is not None:
            raise RuntimeError("command busy")
        if command.generation != self.generation:
            return False
        if command.kind not in ("set", "phase", "rate", "valid"):
            raise ValueError("unknown command")
        if command.kind == "phase":
            checked_signed(command.value, 128)  # Wide acquisition delta, Q16 ns.
        if command.kind == "rate" and not 0 < self.nominal + command.value < NS * Q32:
            raise ValueError("unsafe addend")
        if command.kind == "set" and not 0 <= command.value < MAX_SECONDS * NS * Q32:
            raise ValueError("illegal epoch")
        self.pending = command
        return True

    def tick(self, reset=False):
        if reset:
            self.seconds = self.nanoseconds = self.fraction = self.rate = 0
            self.valid = False
            self.pending = None
            self.generation += 1
            self.ticks += 1
            return None, False
        command, self.pending = self.pending, None
        before_seconds = self.seconds
        fraction = self.fraction + self.nominal + self.rate
        ns_carry, self.fraction = divmod(fraction, Q32)
        sec_carry, self.nanoseconds = divmod(self.nanoseconds + ns_carry, NS)
        self.seconds += sec_carry
        self.ticks += 1
        discontinuity = command is not None and command.kind in ("set", "phase")
        if command is not None:
            if command.kind == "set":
                target = command.value
            elif command.kind == "phase":
                target = self.time_q32 + command.value * Q16
            elif command.kind == "rate":
                self.rate = command.value  # First applied on the following tick.
            else:
                self.valid = bool(command.value)
            if discontinuity:
                if not 0 <= target < MAX_SECONDS * NS * Q32:
                    self.valid = False
                    raise OverflowError("PHC epoch")
                whole_ns, self.fraction = divmod(target, Q32)
                self.seconds, self.nanoseconds = divmod(whole_ns, NS)
                self.generation += 1
                self.valid = False
        if self.seconds >= MAX_SECONDS:
            self.valid = False
            raise OverflowError("PHC rollover")
        return (None if discontinuity else self.time_q32), (not discontinuity and self.seconds > before_seconds)


class RequestLedger:
    """Model logical retirement separately from physical TX completion.

    Retired requests lacking a wire completion remain quarantined indefinitely.
    A known completion starts the bounded network-lifetime quarantine. A full
    MAC reset permits bounded startup quarantine; a port reset alone does not.
    """

    def __init__(self, lifetime=100, sequence_bits=16, outstanding_depth=4):
        self.lifetime = lifetime
        self.modulus = 1 << sequence_bits
        self.outstanding_depth = outstanding_depth
        self.next_sequence = 0
        self.generation = 0
        self.requests = {}

    def allocate(self, now):
        self.reap(now)
        # Logical retirement cannot free a physical TX slot whose wire fate
        # is unknown. Persistent pause must stop new admission at a bound.
        if sum(not r["retired"] or r["wire_time"] is None for r in self.requests.values()) >= self.outstanding_depth:
            raise RuntimeError("outstanding requests full")
        for _ in range(self.modulus):
            seq = self.next_sequence
            self.next_sequence = (seq + 1) % self.modulus
            if seq not in self.requests:
                self.requests[seq] = dict(generation=self.generation, retired=False,
                                          wire_time=None, response=None)
                return seq
        raise RuntimeError("wire keys exhausted")

    def retire(self, seq):
        self.requests[seq]["retired"] = True

    def restart(self):
        self.generation += 1
        for request in self.requests.values():
            request["retired"] = True

    def wire(self, seq, now):
        request = self.requests[seq]
        request["wire_time"] = now
        return self._complete(request)

    def response(self, seq, now):
        request = self.requests.get(seq)
        if request is None or request["retired"]:
            return False
        request["response"] = now
        return self._complete(request)

    def _complete(self, request):
        if request["retired"] or request["wire_time"] is None or request["response"] is None:
            return False
        age = request["response"] - request["wire_time"]
        request["retired"] = True
        return 0 <= age <= self.lifetime

    def reap(self, now):
        self.requests = {seq: r for seq, r in self.requests.items()
                         if not (r["retired"] and r["wire_time"] is not None
                                 and now > r["wire_time"] + self.lifetime)}
