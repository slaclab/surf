##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Backend-neutral eight-instance orchestration for RogueSvMultiInstanceTb,
shared by the Icarus and Verilator runners."""

from tests.simlink.common.peer_orchestration import (
    spawn_peer_group,
    terminate_peers,
    wait_for_peers_ready,
)
from tests.simlink.common.simlink_multi_scenario import (
    MEMORY_INSTANCE_COUNT,
    multi_instance_peer_specs,
    SIDEBAND_INSTANCE_COUNT,
    STREAM_INSTANCE_COUNT,
    validate_multi_instance_peer_result,
)
from tests.simlink.common.simlink_protocol import (
    memory_instance_transactions,
    sideband_instance_vectors,
    stream_instance_vectors,
)

SV_MULTI_TOP = "RogueSvMultiInstanceTb"
SV_MULTI_BANNER = "RogueSvMultiInstanceTb passed"
PEER_READY_SECONDS = 30


def _expected_specs(base):
    stream = [("stream-instance", tag, base + 2 * tag) for tag in range(4)]
    memory = [("memory-instance", tag, base + 8 + 2 * tag) for tag in range(2)]
    sideband = [("sideband-instance", tag, base + 12 + 2 * tag) for tag in range(2)]
    return tuple(stream + memory + sideband)


def check_multi_vectors():
    """Assert that simlink_multi_scenario/simlink_protocol still match the
    layout and per-tag values RogueSvMultiInstanceTb hardcodes in HDL, so an
    oracle edit cannot silently desync the TB from the Python peers without
    failing loudly here first."""
    if (STREAM_INSTANCE_COUNT, MEMORY_INSTANCE_COUNT, SIDEBAND_INSTANCE_COUNT) != (4, 2, 2):
        raise AssertionError(
            "unexpected instance counts: "
            f"stream={STREAM_INSTANCE_COUNT} memory={MEMORY_INSTANCE_COUNT} "
            f"sideband={SIDEBAND_INSTANCE_COUNT}"
        )

    for base in (0, 20000):
        specs = multi_instance_peer_specs(base)
        expected = _expected_specs(base)
        if specs != expected:
            raise AssertionError(f"unexpected peer spec layout for base={base}: {specs} != {expected}")

    for tag in range(4):
        peer_to_dut, dut_to_peer = stream_instance_vectors(tag)
        if peer_to_dut[0]["data"] != bytes([0x10 + tag, 0x20 + tag, 0x30 + tag, 0x40 + tag]):
            raise AssertionError(f"unexpected stream peer->DUT data for tag {tag}: {peer_to_dut}")
        if dut_to_peer[0]["data"] != bytes([0x80 + tag, 0x90 + tag, 0xA0 + tag, 0xB0 + tag]):
            raise AssertionError(f"unexpected stream DUT->peer data for tag {tag}: {dut_to_peer}")

    for tag in range(2):
        txn = memory_instance_transactions(tag)[0]
        if txn["addr"] != 0x100 + 0x10 * tag:
            raise AssertionError(f"unexpected memory address for tag {tag}: {txn}")
        if txn["write_data"] != bytes([0x40 + tag, 0x50 + tag, 0x60 + tag, 0x70 + tag]):
            raise AssertionError(f"unexpected memory write data for tag {tag}: {txn}")

    for tag in range(2):
        peer_to_dut, dut_opcode, dut_remdata = sideband_instance_vectors(tag)
        if peer_to_dut[0]["opCode"] != 0x20 + tag or peer_to_dut[1]["remData"] != 0x40 + tag:
            raise AssertionError(f"unexpected sideband peer->DUT vectors for tag {tag}: {peer_to_dut}")
        if dut_opcode != 0x60 + tag or dut_remdata != 0x70 + tag:
            raise AssertionError(
                "unexpected sideband DUT->peer vectors for tag "
                f"{tag}: opcode={dut_opcode:#x} remdata={dut_remdata:#x}"
            )


def run_sv_multi(run_sim, base_port, result_dir, *, env=None):
    """Spawn one peer per multi_instance_peer_specs() entry, run the
    simulation via run_sim(), and validate the banner plus every peer's exit
    code and result."""
    check_multi_vectors()
    specs = multi_instance_peer_specs(base_port)
    peers = spawn_peer_group(specs, result_dir, ready=True, env=env)
    try:
        wait_for_peers_ready(peers, PEER_READY_SECONDS)
        result = run_sim()
        output = result.stdout + result.stderr
        print(output)
        if SV_MULTI_BANNER not in output or result.returncode != 0:
            dumps = []
            for peer in peers:
                if peer.result_path.exists():
                    dumps.append(f"{peer.result_path.name}:\n{peer.result_path.read_text()}")
            raise AssertionError(output + "\n\n" + "\n\n".join(dumps))

        for peer in peers:
            rc = peer.wait(30)
            if rc != 0:
                raise AssertionError(f"{peer.mode} peer tag {peer.tag} exited {rc}")
            validate_multi_instance_peer_result(peer.mode, peer.tag, peer.read_result())
        return result
    finally:
        terminate_peers(peers)
