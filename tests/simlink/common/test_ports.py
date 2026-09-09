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
# - Sweep: Every centrally declared SimLink test port range.
# - Stimulus: Expand each adjacent base-port allocation into its occupied TCP
#   ports.
# - Checks: Require valid wrapper-compatible bases and no cross-test overlap.
# - Timing: Pure Python validation; no simulator or socket is started.

from tests.simlink.ports import ALL_PORT_RANGES


def test_simlink_port_ranges_are_valid_and_disjoint():
    owners = {}

    for allocation in ALL_PORT_RANGES:
        assert allocation.port_pair(0).first >= 1024
        assert allocation.port_pair(allocation.pair_count - 1).second <= 65535

        for pair in allocation.port_pairs:
            assert pair.second == pair.first + 1

        for port in allocation.occupied_ports:
            assert port not in owners, (
                f"TCP port {port} is allocated by both {owners[port]} "
                f"and {allocation.name}"
            )
            owners[port] = allocation.name
