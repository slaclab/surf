##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Backend-neutral peer specs and orchestration for RogueSvTrafficTb, shared
by the Icarus and Verilator SV traffic runners."""

from tests.simlink.common.peer_orchestration import (
    spawn_peer_group,
    terminate_peers,
    wait_for_peers_ready,
)
from tests.simlink.common.simlink_protocol import (
    MEM_TRANSACTIONS,
    SIDEBAND_RX_OPCODE,
    SIDEBAND_RX_REMDATA,
    SIDEBAND_TX_OPCODE,
    SIDEBAND_TX_REMDATA,
    STREAM_SEND_FRAMES,
)

SV_TRAFFIC_TOP = "RogueSvTrafficTb"
SV_TRAFFIC_BANNER = "RogueSvTrafficTb passed"
SV_TRAFFIC_PAIR_COUNT = 5
# Matches the SIMLINK_MULTI_MAX_TRAFFIC_SECONDS/SIMLINK_PEER_WAIT_SECONDS
# "loaded host" default of 60s already established elsewhere in this test
# suite: under pytest-xdist, peer process startup competes with concurrent
# ruckus builds in sibling workers.
PEER_READY_SECONDS = 60


def sv_traffic_peer_specs(base_port):
    """Peer specs for every RogueSvTrafficTb instance: Stream0 (throttled
    loopback) at base_port+0, Stream1 (direct/sustained loopback) at
    base_port+2, Stream2 (128-byte direct loopback) at base_port+4, Memory0
    at base_port+6, SideBand0 at base_port+8."""
    return (
        ("stream", 0, base_port),
        ("stream", 0, base_port + 2),
        ("stream", 0, base_port + 4),
        ("memory", 0, base_port + 6),
        ("sideband", 0, base_port + 8),
    )


def check_protocol_vectors():
    """Assert that simlink_protocol still matches the values RogueSvTrafficTb
    mirrors in HDL, so a protocol-vector edit cannot silently desync the TB
    from the Python peer without failing loudly here first."""
    lengths = tuple(len(frame["data"]) for frame in STREAM_SEND_FRAMES)
    if lengths != (16, 8, 96):
        raise AssertionError(f"unexpected STREAM_SEND_FRAMES lengths: {lengths}")

    mem_addrs = tuple(txn["addr"] for txn in MEM_TRANSACTIONS)
    mem_sizes = tuple(txn["size"] for txn in MEM_TRANSACTIONS)
    if mem_addrs != (0x0, 0x10) or mem_sizes != (4, 4):
        raise AssertionError(
            f"unexpected MEM_TRANSACTIONS addrs/sizes: {mem_addrs}/{mem_sizes}"
        )

    if (SIDEBAND_RX_OPCODE, SIDEBAND_RX_REMDATA, SIDEBAND_TX_OPCODE, SIDEBAND_TX_REMDATA) != (
        0xA5, 0x3C, 0x5A, 0xC3,
    ):
        raise AssertionError(
            "unexpected SideBand protocol vectors: "
            f"rxOpCode={SIDEBAND_RX_OPCODE:#x} rxRemData={SIDEBAND_RX_REMDATA:#x} "
            f"txOpCode={SIDEBAND_TX_OPCODE:#x} txRemData={SIDEBAND_TX_REMDATA:#x}"
        )


def run_sv_traffic(run_sim, base_port, result_dir, *, env=None):
    """Spawn one peer per sv_traffic_peer_specs() entry, run the simulation
    via run_sim(), and validate the banner plus every peer's exit code."""
    check_protocol_vectors()
    specs = sv_traffic_peer_specs(base_port)
    peers = spawn_peer_group(specs, result_dir, ready=True, env=env)
    try:
        wait_for_peers_ready(peers, PEER_READY_SECONDS)
        result = run_sim()
        output = result.stdout + result.stderr
        print(output)
        if SV_TRAFFIC_BANNER not in output or result.returncode != 0:
            dumps = []
            for peer in peers:
                if peer.result_path.exists():
                    dumps.append(f"{peer.result_path.name}:\n{peer.result_path.read_text()}")
            raise AssertionError(output + "\n\n" + "\n\n".join(dumps))

        for peer in peers:
            rc = peer.wait(30)
            if rc != 0:
                raise AssertionError(f"{peer.mode} peer tag {peer.tag} exited {rc}")
        return result
    finally:
        terminate_peers(peers)
