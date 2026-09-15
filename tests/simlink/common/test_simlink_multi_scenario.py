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
# - Sweep: Common eight-instance peer port allocation and all three tagged
#   Stream, Memory, and SideBand result contracts.
# - Stimulus: Construct deterministic successful peer JSON and one foreign-tag
#   result for each link family without starting a simulator or ZeroMQ.
# - Checks: The shared validator accepts the common vectors and rejects
#   cross-instance traffic for every family.
# - Timing: Pure scenario-definition tests have no simulated-time behavior.

import pytest

from tests.simlink.common.simlink_protocol import (
    memory_instance_transactions,
    sideband_instance_vectors,
    stream_instance_vectors,
)
from tests.simlink.common.simlink_multi_scenario import (
    multi_instance_peer_specs,
    validate_multi_instance_peer_result,
)


def test_common_multi_instance_port_plan():
    assert multi_instance_peer_specs(12000) == (
        ("stream-instance", 0, 12000),
        ("stream-instance", 1, 12002),
        ("stream-instance", 2, 12004),
        ("stream-instance", 3, 12006),
        ("memory-instance", 0, 12008),
        ("memory-instance", 1, 12010),
        ("sideband-instance", 0, 12012),
        ("sideband-instance", 1, 12014),
    )


def _valid_result(mode, tag):
    if mode == "stream-instance":
        own = stream_instance_vectors(tag)[1][0]["data"].hex()
        return {"received": [{"data_hex": own}]}
    if mode == "memory-instance":
        expected = memory_instance_transactions(tag)[0]
        return {
            "transactions": [
                {
                    "type": 0x2,
                    "addr": expected["addr"],
                    "data_hex": expected["write_data"].hex(),
                    "resp": 0,
                },
                {
                    "type": 0x1,
                    "addr": expected["addr"],
                    "data_hex": expected["write_data"].hex(),
                    "resp": 0,
                },
            ]
        }
    peer_to_dut, own_opcode, own_remdata = sideband_instance_vectors(tag)
    assert peer_to_dut
    return {
        "received": [
            {
                "opCodeEn": 1,
                "opCode": own_opcode,
                "remDataChanged": 0,
                "remData": 0,
            },
            {
                "opCodeEn": 0,
                "opCode": 0,
                "remDataChanged": 1,
                "remData": own_remdata,
            },
        ]
    }


@pytest.mark.parametrize(
    ("mode", "tag"),
    (
        ("stream-instance", 0),
        ("memory-instance", 0),
        ("sideband-instance", 0),
    ),
)
def test_common_multi_instance_result_contract_accepts_own_tag(mode, tag):
    validate_multi_instance_peer_result(mode, tag, _valid_result(mode, tag))


@pytest.mark.parametrize(
    ("mode", "tag"),
    (
        ("stream-instance", 0),
        ("memory-instance", 0),
        ("sideband-instance", 0),
    ),
)
def test_common_multi_instance_result_contract_rejects_foreign_tag(mode, tag):
    foreign = _valid_result(mode, 1)
    with pytest.raises(AssertionError):
        validate_multi_instance_peer_result(mode, tag, foreign)
