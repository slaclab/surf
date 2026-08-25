##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from tests.simlink.common.simlink_protocol import (
    memory_instance_transactions,
    sideband_instance_vectors,
    stream_instance_vectors,
)

STREAM_INSTANCE_COUNT = 4
MEMORY_INSTANCE_COUNT = 2
SIDEBAND_INSTANCE_COUNT = 2


def multi_instance_peer_specs(base_port):
    """Return the common eight-instance scenario on adjacent port pairs."""
    stream = [
        ("stream-instance", tag, base_port + 2 * tag)
        for tag in range(STREAM_INSTANCE_COUNT)
    ]
    memory_base = base_port + 2 * STREAM_INSTANCE_COUNT
    memory = [
        ("memory-instance", tag, memory_base + 2 * tag)
        for tag in range(MEMORY_INSTANCE_COUNT)
    ]
    sideband_base = memory_base + 2 * MEMORY_INSTANCE_COUNT
    sideband = [
        ("sideband-instance", tag, sideband_base + 2 * tag)
        for tag in range(SIDEBAND_INSTANCE_COUNT)
    ]
    return tuple(stream + memory + sideband)


def validate_multi_instance_peer_result(mode, tag, observed):
    """Validate one peer result against the backend-neutral tagged contract."""
    if mode == "stream-instance":
        own = stream_instance_vectors(tag)[1][0]["data"].hex()
        received = observed["received"]
        assert received, (tag, observed)
        assert all(frame["data_hex"] == own for frame in received), (
            tag,
            observed,
        )
        return

    if mode == "memory-instance":
        expected = memory_instance_transactions(tag)[0]
        own = expected["write_data"].hex()
        transactions = observed["transactions"]
        assert len(transactions) == 2, (tag, observed)
        assert all(txn["resp"] == 0 for txn in transactions), (tag, observed)
        assert all(txn["addr"] == expected["addr"] for txn in transactions), (
            tag,
            observed,
        )
        reads = [txn for txn in transactions if txn["type"] == 0x1]
        assert len(reads) == 1 and reads[0]["data_hex"] == own, (
            tag,
            observed,
        )
        foreign = {
            memory_instance_transactions(other)[0]["write_data"].hex()
            for other in range(MEMORY_INSTANCE_COUNT)
            if other != tag
        }
        assert all(txn["data_hex"] not in foreign for txn in transactions), (
            tag,
            observed,
        )
        return

    if mode == "sideband-instance":
        _, own_opcode, own_remdata = sideband_instance_vectors(tag)
        received = observed["received"]
        assert any(
            frame["opCodeEn"] == 1 and frame["opCode"] == own_opcode
            for frame in received
        ), (tag, observed)
        assert any(
            frame["remDataChanged"] == 1
            and frame["remData"] == own_remdata
            for frame in received
        ), (tag, observed)
        for other in range(SIDEBAND_INSTANCE_COUNT):
            if other == tag:
                continue
            _, foreign_opcode, foreign_remdata = sideband_instance_vectors(
                other
            )
            assert not any(
                frame["opCodeEn"] == 1
                and frame["opCode"] == foreign_opcode
                for frame in received
            ), (tag, other, observed)
            assert not any(
                frame["remDataChanged"] == 1
                and frame["remData"] == foreign_remdata
                for frame in received
            ), (tag, other, observed)
        return

    raise AssertionError(f"unknown peer mode {mode}")
