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
# - Sweep: None -- the cocotb round trip uses a centrally allocated pair, while
#   the standalone malformed-request checks select unused local pairs to remain
#   rerunnable after each intentionally aborting server. This is not a swept
#   parameter matrix.
# - Stimulus: Spawn rogue_tcp_peer.py (--mode memory) as a separate OS
#   process before releasing reset, so the C model's first post-reset edge
#   binds its ZMQ sockets while the peer is already connecting. The peer
#   drives its own deterministic write-then-read transaction set
#   (MEM_TRANSACTIONS) over ZMQ; the DUT's real AXI-Lite master path carries
#   each transaction out onto M_AXI against a cocotbext.axi.AxiLiteRam
#   slave. The round trip uses well-formed word-sized requests; focused
#   negative tests separately cover malformed transaction shapes and
#   read-buffer safety.
# - Checks: Every transaction's decoded result must be AXI OKAY (0); every
#   read transaction's observed data must equal the data written to that
#   address;
#   the write transactions must additionally be cross-checked directly
#   against AxiLiteRam's contents (not just the peer's own bookkeeping); the
#   peer process must exit 0. Malformed transaction types, frame counts, and
#   data sizes must terminate the standalone receiver with the expected
#   diagnostic.
# - Timing: No fixed timing contract -- the bench loops RisingEdge(axilClk)
#   up to a bounded edge count, breaking early once the peer process exits.
#   A `finally:` block terminates the peer on every path (including an
#   assertion failure) so nothing leaks across the xdist worker pool.
#
# Exercises the memory round trip (read + write, varied addr/data),
# cocotbext.axi binding the flat wrapper's M_AXI scalar master bus to
# AxiLiteRam, the separate-process Rogue-TCP peer memory protocol for
# RogueTcpMemoryWrap, strict request-shape validation, and read-buffer
# initialization under valgrind when available.

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

from tests.simlink.common.peer_orchestration import managed_peer, terminate_process
from tests.simlink.common.simlink_protocol import (
    encode_mem_request,
    MEM_TRANSACTIONS,
    T_POST,
    T_READ,
    T_VERIFY,
    T_WRITE,
)
from tests.simlink.ghdl.simlink_test_utils import run_simlink_surf_test
from tests.simlink.paths import (
    GHDL_SOURCE_DIR,
    SHARED_SOURCE_DIR,
    SIMLINK_TEST_ROOT,
    sim_build_dir,
)
from tests.simlink.ports import GHDL_CASES, GHDL_MEMORY_MALFORMED

HERE = SIMLINK_TEST_ROOT / "ghdl"
GHDL_DIR = GHDL_SOURCE_DIR
SHARED_DIR = SHARED_SOURCE_DIR
SIM_BUILD = sim_build_dir("ghdl", "RogueTcpMemoryWrap")
UNINIT_READ_HARNESS = SIM_BUILD / "uninit_read_recv_harness"
MEMORY_RECV_HARNESS = SIM_BUILD / "memory_recv_harness"

CLK_PERIOD_NS = 10
RST_EDGES = 3
MAX_EDGES = 5000
PORT_NUM = GHDL_CASES.port_pair(3).first
# Fresh port pair, never used by another test function in this module (a
# separate pytest function is its own xdist-schedulable unit).
UNINIT_READ_PORT_NUM = GHDL_CASES.port_pair(4).first


def _build_memory_recv_harness(output: Path) -> None:
    SIM_BUILD.mkdir(parents=True, exist_ok=True)

    cflags = subprocess.run(
        ["pkg-config", "--cflags", "libzmq"], check=True, capture_output=True, text=True
    ).stdout.split()
    libs = subprocess.run(
        ["pkg-config", "--libs", "libzmq"], check=True, capture_output=True, text=True
    ).stdout.split()

    subprocess.run(
        [
            "gcc", "-Wall", "-g", "-pthread",
            "-DROGUE_SIM_LINK_NATIVE_TEST",
            f"-I{GHDL_DIR}", f"-I{SHARED_DIR}", *cflags,
            str(GHDL_DIR / "RogueTcpMemory.c"),
            str(SHARED_DIR / "RogueSimLinkInstance.c"),
            str(SHARED_DIR / "RogueSimLinkTransport.c"),
            str(SHARED_DIR / "RogueTcpMemoryCore.c"),
            str(HERE / "uninit_read_recv_harness.c"),
            "-o", str(output), *libs,
        ],
        check=True,
    )


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
        # calls RogueTcpMemoryStartTransport (binds ZMQ PULL/PUSH sockets).
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
    with managed_peer("memory", PORT_NUM, result_path) as peer:
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

        observed = peer.read_result()
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


def test_RogueTcpMemoryWrap():
    run_simlink_surf_test(
        test_file=__file__,
        toplevel="surf.roguetcpmemoryflatharness",
        sim_build=SIM_BUILD,
        parameters={"PORT_NUM_G": PORT_NUM},
        extra_vhdl_sources={
            "surf": ["simlink/test/common/RogueTcpMemoryFlatHarness.vhd"],
        },
    )


def test_RogueTcpMemory_malformed_requests_rejected():
    _build_memory_recv_harness(MEMORY_RECV_HARNESS)
    base_read = encode_mem_request(1, 0x0, 4, T_READ)
    base_verify = encode_mem_request(1, 0x0, 4, T_VERIFY)
    base_write = encode_mem_request(1, 0x0, 4, T_WRITE, b"\x01\x02\x03\x04")
    cases = (
        ("zero-length read", encode_mem_request(1, 0x0, 0, T_READ),
         "Transaction size invalid"),
        ("read with data", [*base_read, b"ignored"],
         "Read/verify transaction has unexpected data"),
        ("verify with data", [*base_verify, b"ignored"],
         "Read/verify transaction has unexpected data"),
        ("unknown type", encode_mem_request(1, 0x0, 4, 0x7FFFFFFF),
         "Unsupported transaction type"),
        ("write without data", base_write[:-1],
         "Write/post transaction data is missing"),
        ("post with wrong data size",
         encode_mem_request(1, 0x0, 4, T_POST, b"\x01\x02"),
         "Write/post transaction data size mismatch"),
    )

    for index, (description, request, diagnostic) in enumerate(cases):
        # One statically-reserved pair per case (registered in tests/simlink/ports.py
        # and disjointness-checked), so the harness never races a bind/close/rebind.
        port = GHDL_MEMORY_MALFORMED.port_pair(index).first
        proc = subprocess.Popen(
            [str(MEMORY_RECV_HARNESS), str(port)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        ctx = zmq.Context()
        push = ctx.socket(zmq.PUSH)
        push.connect(f"tcp://127.0.0.1:{port}")

        try:
            push.send_multipart(request)
            _, stderr = proc.communicate(timeout=10)
            assert proc.returncode != 0, f"{description} was accepted"
            assert diagnostic in stderr
        finally:
            push.close(linger=0)
            ctx.term()
            terminate_process(proc)


@pytest.mark.skipif(
    sys.platform != "linux" or shutil.which("valgrind") is None,
    reason="read-buffer valgrind check is Linux-only and needs valgrind on PATH",
)
def test_RogueTcpMemory_uninitialized_read():
    # A read request has no fifth write-data frame. Link the production receive
    # path into a narrow harness and have valgrind verify that the returned
    # buffer is initialized before AXI-Lite supplies the eventual read data.
    _build_memory_recv_harness(UNINIT_READ_HARNESS)

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
        # Four-frame T_READ request, intentionally without a write-data frame.
        push.send_multipart(encode_mem_request(1, 0x0, 4, T_READ))
        push.close()
        ctx.term()

        rc = proc.wait(timeout=30)
        assert rc == 0, f"valgrind detected an uninitialised-value use (rc={rc})"
    finally:
        terminate_process(proc)
