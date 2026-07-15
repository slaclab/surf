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
# - Sweep: None -- a single fixed ZMQ port pair (9606/9607); this is a
#   round-trip regression, not a swept parameter matrix.
# - Stimulus: Spawn rogue_tcp_peer.py (--mode memory) as a separate OS
#   process before releasing reset, so the C model's first post-reset edge
#   binds its ZMQ sockets while the peer is already connecting. The peer
#   drives its own deterministic write-then-read transaction set
#   (MEM_TRANSACTIONS) over ZMQ; the DUT's real AXI-Lite master path carries
#   each transaction out onto M_AXI against a cocotbext.axi.AxiLiteRam
#   slave. Word-sized (size=4), proper-length frames only so the green
#   baseline stays clear of the 0-length/short-read uninitialized memcpy.
# - Checks: Every transaction's decoded resp must be OKAY (0); every read
#   transaction's observed data must equal the data written to that address;
#   the write transactions must additionally be cross-checked directly
#   against AxiLiteRam's contents (not just the peer's own bookkeeping); the
#   peer process must exit 0.
# - Timing: No fixed timing contract -- the bench loops RisingEdge(axilClk)
#   up to a bounded edge count, breaking early once the peer process exits.
#   A `finally:` block terminates the peer on every path (including an
#   assertion failure) so nothing leaks across the xdist worker pool.
#
# Exercises the memory round trip (read + write, varied addr/data),
# cocotbext.axi binding the flat wrapper's M_AXI scalar master bus to
# AxiLiteRam, and the separate-process Rogue-TCP peer memory protocol for
# RogueTcpMemoryWrap.

import json
from pathlib import Path
import shutil
import subprocess
import sys

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteRam
import zmq

from tests.axi.simlink.rogue_tcp_peer import MEM_TRANSACTIONS, T_READ, encode_mem_request
from tests.axi.simlink.simlink_test_utils import build_and_stage_so
from tests.common.regression_utils import run_surf_vhdl_test

HERE = Path(__file__).resolve().parent
GHDL_DIR = Path(__file__).resolve().parents[3] / "axi" / "simlink" / "ghdl"
SHARED_DIR = Path(__file__).resolve().parents[3] / "axi" / "simlink" / "shared"
SIM_BUILD = HERE / "sim_build_RogueTcpMemoryWrap"
UNINIT_READ_HARNESS = SIM_BUILD / "uninit_read_recv_harness"

CLK_PERIOD_NS = 10
RST_EDGES = 3
MAX_EDGES = 5000
PORT_NUM = 9606
# Fresh port pair, never used by another test function in this module (a
# separate pytest function is its own xdist-schedulable unit).
UNINIT_READ_PORT_NUM = 9608


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ram = None

        cocotb.start_soon(Clock(dut.axilClk, CLK_PERIOD_NS, unit="ns").start())
        dut.axilRst.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)

    async def reset(self):
        # Pulse reset for a couple of edges, then release it so the DUT's
        # first post-reset edge latches the port and the GHDL-hosted C model
        # calls RogueTcpMemoryRestart (binds ZMQ PULL/PUSH sockets).
        self.dut.axilRst.value = 1
        await self.cycle(RST_EDGES)
        self.dut.axilRst.value = 0
        await self.cycle(RST_EDGES)

    def start_agents(self):
        self.ram = AxiLiteRam(AxiLiteBus.from_prefix(self.dut, "M_AXI"), self.dut.axilClk, self.dut.axilRst, size=2**16)


@cocotb.test()
async def memory_round_trip_test(dut):
    tb = TB(dut)
    result_path = SIM_BUILD / "memory_peer_result.json"

    # Spawn the peer as a genuinely separate OS process before releasing
    # reset -- a blocking pyzmq call inside this coroutine would deadlock
    # the shared GHDL/cocotb thread.
    peer = subprocess.Popen(
        [sys.executable, str(HERE / "rogue_tcp_peer.py"), "--mode", "memory", str(PORT_NUM), str(result_path)]
    )

    try:
        await tb.reset()
        tb.start_agents()

        # Await the round trip: loop clock edges (each edge polls the C
        # model's ZMQ sockets and lets the AXI-Lite master transact against
        # AxiLiteRam) until the peer process exits or the bound is hit.
        for _ in range(MAX_EDGES):
            await RisingEdge(dut.axilClk)
            if peer.poll() is not None:
                break
        else:
            raise TimeoutError(f"peer process did not exit within {MAX_EDGES} clock edges")

        assert peer.returncode == 0, f"peer exited with code {peer.returncode}"

        observed = json.loads(result_path.read_text())
        transactions = observed["transactions"]
        assert len(transactions) == 2 * len(MEM_TRANSACTIONS)

        write_data_by_addr = {txn["addr"]: txn["write_data"] for txn in MEM_TRANSACTIONS}

        for txn in transactions:
            assert txn["resp"] == 0, f"non-OKAY resp on transaction {txn!r}"
            if txn["type"] == T_READ:
                expected = write_data_by_addr[txn["addr"]]
                assert txn["data_hex"] == expected.hex(), f"read-back mismatch on transaction {txn!r}"

        # Cross-check the write transactions landed in the real AxiLiteRam
        # slave via the DUT's AXI-Lite master path, not just the peer's own
        # bookkeeping.
        for addr, write_data in write_data_by_addr.items():
            assert tb.ram.read(addr, 4) == write_data
    finally:
        if peer.poll() is None:
            peer.terminate()
            peer.wait(timeout=5)


def test_RogueTcpMemoryWrap():
    build_and_stage_so(GHDL_DIR, "libRogueTcpMemory.so", SIM_BUILD)

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.roguetcpmemorywrapflatwrapper",
        parameters={"PORT_NUM_G": PORT_NUM},
        extra_env={"LD_LIBRARY_PATH": str(GHDL_DIR / "build")},
        extra_vhdl_sources={
            "surf": ["axi/simlink/wrappers/RogueTcpMemoryWrapFlatWrapper.vhd"],
        },
        sim_build_key=str(SIM_BUILD),
    )


@pytest.mark.skipif(
    sys.platform != "linux" or shutil.which("valgrind") is None,
    reason="uninitialized-read reproduction is Linux-only and needs valgrind on PATH",
)
def test_RogueTcpMemory_uninitialized_read():
    # Standalone (non-cocotb) reproduction of the bug: on a 4-frame memory
    # read request, RogueTcpMemoryRecv() never receives a 5th data frame, so
    # the line-194 memcpy copies data->size bytes from uninitialized stack
    # memory. The full cocotb round trip can never observe this (the AXI-Lite
    # read overwrites the tainted bytes before any response is sent), so this
    # test links the unmodified C model into a narrow harness and watches it
    # under valgrind memcheck instead.
    SIM_BUILD.mkdir(parents=True, exist_ok=True)

    cflags = subprocess.run(
        ["pkg-config", "--cflags", "libzmq"], check=True, capture_output=True, text=True
    ).stdout.split()
    libs = subprocess.run(
        ["pkg-config", "--libs", "libzmq"], check=True, capture_output=True, text=True
    ).stdout.split()

    subprocess.run(
        [
            "gcc", "-Wall", "-g", f"-I{GHDL_DIR}", f"-I{SHARED_DIR}", *cflags,
            str(GHDL_DIR / "RogueTcpMemory.c"), str(HERE / "uninit_read_recv_harness.c"),
            "-o", str(UNINIT_READ_HARNESS), *libs,
        ],
        check=True,
    )

    proc = subprocess.Popen(
        [
            "valgrind", "--tool=memcheck", "--track-origins=yes", "--error-exitcode=99",
            str(UNINIT_READ_HARNESS), str(UNINIT_READ_PORT_NUM),
        ]
    )

    try:
        ctx = zmq.Context()
        push = ctx.socket(zmq.PUSH)
        push.connect(f"tcp://127.0.0.1:{UNINIT_READ_PORT_NUM}")
        # 4-frame T_READ request, no write-data frame -- the exact
        # trigger: msg[4] is never zmq_recvmsg'd on this path.
        push.send_multipart(encode_mem_request(1, 0x0, 4, T_READ))
        push.close()
        ctx.term()

        rc = proc.wait(timeout=30)
        assert rc == 0, f"valgrind flagged an uninitialised-value use (rc={rc}); bug reproduced"
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=5)
