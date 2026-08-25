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


@dataclass(frozen=True)
class PortPair:
    """The two adjacent TCP ports owned by one SimLink endpoint."""

    first: int
    second: int


@dataclass(frozen=True)
class PortRange:
    """A named allocation containing one or more SimLink port pairs."""

    name: str
    start: int
    pair_count: int = 1

    def port_pair(self, index: int) -> PortPair:
        if not 0 <= index < self.pair_count:
            raise IndexError(f"{self.name} pair index {index} is out of range")
        first = self.start + (2 * index)
        return PortPair(first=first, second=first + 1)

    @property
    def port_pairs(self) -> tuple[PortPair, ...]:
        return tuple(self.port_pair(index) for index in range(self.pair_count))

    @property
    def occupied_ports(self) -> tuple[int, ...]:
        return tuple(
            port
            for pair in self.port_pairs
            for port in (pair.first, pair.second)
        )


# GHDL/VHPIDIRECT tests. The first block assigns one pair to each scalar,
# wrapper-width, and pacing case in ascending order.
GHDL_CASES = PortRange("ghdl-cases", 9600, 10)
GHDL_MULTI = PortRange("ghdl-multi", 9620, 8)
GHDL_LIFECYCLE = PortRange("ghdl-lifecycle", 9640, 5)
GHDL_ROGUE_MEMORY = PortRange("ghdl-rogue-memory", 9660)
# Real-Rogue Stream and SideBand contracts (one client TcpClient pair each),
# placed in the free gap after GHDL_ROGUE_MEMORY (9660/9661) and before
# GHDL_LIFECYCLE_HARNESS (9670).
GHDL_ROGUE_STREAM = PortRange("ghdl-rogue-stream", 9662)
GHDL_ROGUE_SIDEBAND = PortRange("ghdl-rogue-sideband", 9664)
GHDL_RELOAD = PortRange("ghdl-reload", 9666)
GHDL_LIFECYCLE_HARNESS = PortRange("ghdl-lifecycle-harness", 9670, 4)
# One pair per malformed-request case in test_RogueTcpMemory_malformed_requests_rejected,
# so each harness process binds a statically-reserved pair instead of racing a
# bind/close/rebind probe.
GHDL_MEMORY_MALFORMED = PortRange("ghdl-memory-malformed", 9680, 6)
# Non-power-of-two channel count for the RogueTcpStreamWrap channelMap overflow
# regression. CHAN_COUNT_G=3 makes the wrap bind three core port pairs based at
# PORT_NUM_G, so reserve three pairs (only the base is passed in).
GHDL_STREAM_MULTICHAN = PortRange("ghdl-stream-multichan", 9692, 3)

# VCS uses the same topology as GHDL but a distinct range so both runners can
# be selected in one xdist session without competing for sockets.
VCS_MULTI = PortRange("vcs-multi", 9700, 8)
VCS_RELAUNCH = PortRange("vcs-relaunch", 9716)

# Native DPI tests occupy one contiguous backend-private range. Individual
# allocations stay disjoint because pytest-xdist schedules parameter cases
# independently, even when they originate in the same module.
NATIVE_DPI_CONTEXTS = PortRange("native-dpi-contexts", 19600, 8)
NATIVE_DPI_WIDE = PortRange("native-dpi-wide", 19616, 2)
NATIVE_DPI_ACTIVE = PortRange("native-dpi-active", 19620, 8)
NATIVE_DPI_SIDEBAND_FLAGS = PortRange("native-dpi-sideband-flags", 19636)
NATIVE_DPI_MEMORY_PROBE = PortRange("native-dpi-memory-probe", 19638)
NATIVE_DPI_MEMORY_ERRORS = PortRange("native-dpi-memory-errors", 19640, 8)
NATIVE_DPI_MEMORY_MULTIWORD = PortRange("native-dpi-memory-multiword", 19656, 2)
NATIVE_DPI_VALIDATION = PortRange("native-dpi-validation", 19660, 4)
NATIVE_DPI_RELOAD = PortRange("native-dpi-reload", 19668)

# xsim testbench ports are HDL constants mirrored here for collision checking.
XSIM_MULTI = PortRange("xsim-multi", 19700, 8)
XSIM_DUPLICATE = PortRange("xsim-duplicate", 19720)
XSIM_TRAFFIC = PortRange("xsim-traffic", 19740, 8)

NATIVE_STREAM_OVERLOAD = PortRange("native-stream-overload", 19800, 9)
NATIVE_TRANSPORT = PortRange("native-transport", 19900, 9)

ALL_PORT_RANGES = (
    GHDL_CASES,
    GHDL_MULTI,
    GHDL_LIFECYCLE,
    GHDL_ROGUE_MEMORY,
    GHDL_ROGUE_STREAM,
    GHDL_ROGUE_SIDEBAND,
    GHDL_RELOAD,
    GHDL_LIFECYCLE_HARNESS,
    GHDL_MEMORY_MALFORMED,
    GHDL_STREAM_MULTICHAN,
    VCS_MULTI,
    VCS_RELAUNCH,
    NATIVE_DPI_CONTEXTS,
    NATIVE_DPI_WIDE,
    NATIVE_DPI_ACTIVE,
    NATIVE_DPI_SIDEBAND_FLAGS,
    NATIVE_DPI_MEMORY_PROBE,
    NATIVE_DPI_MEMORY_ERRORS,
    NATIVE_DPI_MEMORY_MULTIWORD,
    NATIVE_DPI_VALIDATION,
    NATIVE_DPI_RELOAD,
    XSIM_MULTI,
    XSIM_DUPLICATE,
    XSIM_TRAFFIC,
    NATIVE_STREAM_OVERLOAD,
    NATIVE_TRANSPORT,
)
