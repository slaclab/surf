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
# - Sweep: Four Stream and two each Memory and SideBand, all concurrent.
# - Stimulus: Start one tagged ZeroMQ peer per instance, drive unique outbound
#   Stream frames and SideBand events, and emulate two independent AXI-Lite
#   slaves for the Memory peers' tagged write/read transactions.
# - Checks: Every peer receives only its tagged DUT traffic; cocotb receives
#   each peer's tagged Stream/SideBand traffic on the matching flattened lane;
#   both Memory peers read back their own independent stores. Reset is pulsed
#   again after traffic to prove native instance/socket ownership survives it.
# - Timing: Every peer signals socket readiness before the model binds, the
#   wait for peer completion is wall-clock bounded, and all transaction loops
#   use bounded clock counts; every peer is terminated in finally cleanup if
#   the test fails.

import os
from pathlib import Path
import time

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, Timer

from tests.simlink.common.peer_orchestration import (
    spawn_peer_group,
    terminate_peers,
    wait_for_peers_ready,
)
from tests.simlink.common.simlink_protocol import (
    sideband_instance_vectors,
    stream_instance_vectors,
)
from tests.simlink.common.simlink_multi_scenario import (
    multi_instance_peer_specs,
    validate_multi_instance_peer_result,
)
from tests.simlink.ports import GHDL_MULTI

RESULT_DIR = Path(os.environ["SIMLINK_MULTI_INSTANCE_RESULT_DIR"])

CLK_PERIOD_NS = 10
RST_EDGES = 2
RUN_EDGES = 50
# Wall-clock budget for the eight peer processes to start up and report that
# their ZeroMQ sockets are configured. Spent before the clock runs, so it never
# competes with the traffic budget below.
PEER_READY_SECONDS = 30
# Wall-clock budget for all peers to finish their tagged exchange. Peer exit is
# a real-time event, so an edge-denominated budget made the allowance scale
# with host simulation speed: 10000 edges was only ~5 s on a loaded CI runner,
# which a slow-starting peer could miss. Kept below the 120 s VCS run timeout
# so a stuck peer trips its own 30 s RCVTIMEO/connect timeout first and reports
# a specific reason. Env-overridable (mirroring
# SURF_SIMLINK_TRANSPORT_TIMEOUT_MS) without recompiling.
MAX_TRAFFIC_SECONDS = float(os.environ.get("SIMLINK_MULTI_MAX_TRAFFIC_SECONDS", "60"))
BASE_PORT = int(os.environ.get("SIMLINK_MULTI_BASE_PORT", GHDL_MULTI.port_pair(0).first))
PEER_SPECS = multi_instance_peer_specs(BASE_PORT)
PORTS = tuple(port for _, _, port in PEER_SPECS)


def _lane(value, index, width):
    return (int(value) >> (index * width)) & ((1 << width) - 1)


def _pack(values, width):
    result = 0
    for index, value in enumerate(values):
        result |= int(value) << (index * width)
    return result


async def _memory_slaves(dut):
    stores = [{}, {}]
    read_countdown = [0, 0]
    read_data = [0, 0]

    while True:
        await RisingEdge(dut.clock)
        await ReadOnly()

        if not all(
            signal.value.is_resolvable
            for signal in (
                dut.memoryAwValid,
                dut.memoryWValid,
                dut.memoryArValid0,
                dut.memoryArValid1,
            )
        ):
            continue

        aw_valid = int(dut.memoryAwValid.value)
        w_valid = int(dut.memoryWValid.value)
        ar_valid = int(dut.memoryArValid0.value) | (int(dut.memoryArValid1.value) << 1)
        next_b_valid = 0

        for index in range(2):
            if ((aw_valid >> index) & 1) and ((w_valid >> index) & 1):
                address = _lane(dut.memoryAwAddr.value, index, 32)
                stores[index][address] = _lane(dut.memoryWData.value, index, 32)
                next_b_valid |= 1 << index

            if (ar_valid >> index) & 1:
                address = _lane(dut.memoryArAddr.value, index, 32)
                read_data[index] = stores[index].get(address, 0)
                read_countdown[index] = 2

        next_r_valid = 0
        for index in range(2):
            if read_countdown[index] > 0:
                next_r_valid |= 1 << index
                read_countdown[index] -= 1

        await Timer(1, unit="ns")
        dut.memoryBValid.value = next_b_valid
        dut.memoryRValid.value = next_r_valid
        dut.memoryRData.value = _pack(read_data, 32)


async def _receive_monitor(dut, stream_received, sideband_opcodes, sideband_remdata):
    while True:
        await RisingEdge(dut.clock)
        await ReadOnly()

        if dut.streamObData.value.is_resolvable and dut.streamObKeep.value.is_resolvable:
            for index in range(4):
                valid = getattr(dut, f"streamObValid{index}").value
                if stream_received[index] is None and valid.is_resolvable and int(valid):
                    keep = _lane(dut.streamObKeep.value, index, 8)
                    data = _lane(dut.streamObData.value, index, 64)
                    stream_received[index] = bytes(
                        (data >> (8 * byte)) & 0xFF for byte in range(8) if (keep >> byte) & 1
                    )

        if dut.sideBandRxCode.value.is_resolvable and dut.sideBandRxData.value.is_resolvable:
            for index in range(2):
                enable = getattr(dut, f"sideBandRxEn{index}").value
                if enable.is_resolvable and int(enable):
                    sideband_opcodes[index] = _lane(dut.sideBandRxCode.value, index, 8)
                sideband_remdata[index] = _lane(dut.sideBandRxData.value, index, 8)


@cocotb.test()
async def rogue_simlink_multi_instance_traffic_test(dut):
    for name, port in zip(
        (
            "streamPort0",
            "streamPort1",
            "streamPort2",
            "streamPort3",
            "memoryPort0",
            "memoryPort1",
            "sideBandPort0",
            "sideBandPort1",
        ),
        PORTS,
    ):
        getattr(dut, name).value = port

    dut.streamObReady.value = 0xF
    dut.streamIbValid.value = 0
    dut.streamIbData.value = 0
    dut.streamIbKeep.value = 0
    dut.streamIbLast.value = 0
    dut.memoryArReady.value = 0x3
    dut.memoryRData.value = 0
    dut.memoryRResp.value = 0
    dut.memoryRValid.value = 0
    dut.memoryAwReady.value = 0x3
    dut.memoryWReady.value = 0x3
    dut.memoryBResp.value = 0
    dut.memoryBValid.value = 0
    dut.sideBandTxCode.value = 0
    dut.sideBandTxEn.value = 0
    dut.sideBandTxData.value = 0
    dut.reset.value = 1

    peers = spawn_peer_group(PEER_SPECS, RESULT_DIR, ready=True)

    memory_task = cocotb.start_soon(_memory_slaves(dut))
    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit="ns").start())
    stream_received = [None] * 4
    sideband_opcodes = [None] * 2
    sideband_remdata = [None] * 2
    monitor_task = cocotb.start_soon(
        _receive_monitor(dut, stream_received, sideband_opcodes, sideband_remdata)
    )

    try:
        # Keep peer process startup out of the traffic budget. Blocking here is
        # safe: no sim time passes until this coroutine awaits again, so the
        # model still binds on the first post-reset edge below, after every
        # peer has issued its connect(). Without this, a peer still importing
        # pyzmq races the DUT's first outbound frame.
        wait_for_peers_ready(peers, PEER_READY_SECONDS)

        for _ in range(RST_EDGES):
            await RisingEdge(dut.clock)
        dut.reset.value = 0
        for _ in range(10):
            await RisingEdge(dut.clock)

        stream_to_peer = [stream_instance_vectors(tag)[1][0]["data"] for tag in range(4)]
        dut.streamIbData.value = _pack(
            (int.from_bytes(payload, byteorder="little") for payload in stream_to_peer),
            64,
        )
        dut.streamIbKeep.value = _pack(((1 << len(payload)) - 1 for payload in stream_to_peer), 8)
        dut.streamIbLast.value = 0xF
        dut.streamIbValid.value = 0xF

        sideband_vectors = [sideband_instance_vectors(tag) for tag in range(2)]
        dut.sideBandTxCode.value = _pack((vectors[1] for vectors in sideband_vectors), 8)
        dut.sideBandTxData.value = _pack((vectors[2] for vectors in sideband_vectors), 8)
        dut.sideBandTxEn.value = 0x3

        await RisingEdge(dut.clock)
        await Timer(1, unit="ns")
        dut.streamIbValid.value = 0
        dut.streamIbLast.value = 0
        dut.sideBandTxEn.value = 0

        deadline = time.monotonic() + MAX_TRAFFIC_SECONDS
        while True:
            await RisingEdge(dut.clock)
            await ReadOnly()

            if all(peer.poll() is not None for peer in peers):
                break
            if time.monotonic() >= deadline:
                pending = [
                    (peer.mode, peer.tag, peer.port)
                    for peer in peers
                    if peer.poll() is None
                ]
                raise TimeoutError(
                    f"multi-instance peers did not finish within "
                    f"{MAX_TRAFFIC_SECONDS}s: {pending}"
                )

        for peer in peers:
            assert peer.returncode == 0, f"peer exited with code {peer.returncode}"

        for tag in range(4):
            expected_from_peer = stream_instance_vectors(tag)[0][0]["data"]
            assert stream_received[tag] == expected_from_peer

        for tag in range(2):
            peer_to_dut, _, _ = sideband_vectors[tag]
            assert sideband_opcodes[tag] == peer_to_dut[0]["opCode"]
            assert sideband_remdata[tag] == peer_to_dut[1]["remData"]

        for peer in peers:
            validate_multi_instance_peer_result(
                peer.mode, peer.tag, peer.read_result()
            )

        await Timer(1, unit="ns")
        dut.sideBandTxData.value = 0
        dut.reset.value = 1
        for _ in range(RST_EDGES):
            await RisingEdge(dut.clock)
        dut.reset.value = 0
        for _ in range(RUN_EDGES):
            await RisingEdge(dut.clock)
    finally:
        memory_task.cancel()
        monitor_task.cancel()
        terminate_peers(peers)
