# Xsim Multi-Instance Live Traffic — Implementation Plan

> **Historical implementation record:** Paths and commands under
> `axi/simlink` and `tests/axi/simlink` describe the pre-alignment branch and
> are not current usage instructions. Start with the current
> [SimLink documentation](../../../simlink/README.md).

> **Implementation reconciliation note (2026-07-17):** This is the historical
> execution plan. After pull request 1450 converged, the final implementation
> adopted its canonical `stream_instance_vectors`,
> `memory_instance_transactions`, and `sideband_instance_vectors` helpers and
> dedicated `*-instance` peer modes. Each Stream instance now exchanges one
> four-byte frame: peer-to-DUT `[0x10+i, 0x20+i, 0x30+i, 0x40+i]` and
> DUT-to-peer `[0x80+i, 0x90+i, 0xA0+i, 0xB0+i]`. The orchestrator also waits
> for a test-only `--ready-file` from each peer before starting xsim, then keeps
> a fixed settle delay for the asynchronous ZeroMQ handshake. See
> [design.md](design.md) and [progress.md](progress.md) for the current design
> and validation status. Embedded snippets and unchecked tasks below are
> preserved as execution history and are superseded where they differ.

**Goal:** Prove under real Vivado xsim that the eight-instance DPI topology (4 Stream, 2 Memory, 2 SideBand) exchanges isolated live ZeroMQ traffic through the actual DPI-C boundary, with each instance talking only to its own peer.

**Architecture:** A self-contained VHDL testbench (`RogueXsimTrafficTb.vhd`) drives the eight model instances; eight independent `rogue_tcp_peer.py` subprocesses provide connected-and-draining peers using the canonical per-instance modes. pytest orchestrates the `make → xvlog → xvhdl → xelab → xsim -R` pipeline and makes final assertions. Isolation is proven positively (each peer sees only its own instance vectors) and by exact result comparison.

**Tech Stack:** Vivado xsim 2024.1 (DPI-C via `-sv_lib`), VHDL-2008, Python 3.10 + pyzmq, pytest. libzmq via pkg-config. System libstdc++ preloaded at xsim run time (`xsim_run_env()`).

**Design spec:** [design.md](design.md)

**Environment note (every Vivado-dependent step):** the shell running pytest must have Vivado on PATH. Source it once per shell:
```bash
source /sdf/group/faders/tools/xilinx/2024.1/Vivado/2024.1/settings64.sh
```
Steps that do NOT need Vivado (pure-Python unit tests in Tasks 1–2) run without it. Steps that DO need it are marked **[VIVADO]**; without Vivado on PATH they skip (by design) rather than fail.

**Tag scheme (single source of truth, mirrors the native traffic test):**

| Model | i | Port pair (`port`,`port+1`) | Peer→DUT payload | DUT→Peer payload (HDL drives) |
|---|---|---|---|---|
| Stream | 0..3 | `19740+2i` | `[0x10+i, 0x20+i, 0x30+i, 0x40+i]` | `[0x80+i, 0x90+i, 0xA0+i, 0xB0+i]` |
| Memory | 0..1 | `19748+2i` | write then read @ `0x100+0x10*i`, data `[0x40+i,0x50+i,0x60+i,0x70+i]` | AXI-Lite slave responses |
| SideBand | 0..1 | `19752+2i` | opcode `0x20+i` (opCodeEn), then remData `0x40+i` (remDataChanged) | tx opcode `0x60+i`, remData `0x70+i` |

The final implementation exchanges one four-byte frame per Stream instance, one write/read pair per Memory instance, and one opcode plus one remData event per SideBand instance.

---

## File Structure

- `tests/axi/simlink/rogue_tcp_peer.py` — **modify**: reuse the canonical per-instance vector helpers and `*-instance` modes; add a backward-compatible, test-only `--ready-file` argument.
- `tests/axi/simlink/test_rogue_tcp_peer_tags.py` — **create**: pure-Python unit tests for the instance vectors, mode dispatch, and ready-file barrier (no Vivado).
- `tests/axi/simlink/xsim_test_utils.py` — **create**: shared xsim helpers (`xsim_run_env`, tool list + skip predicate, `build_dpi_library` fixture factory, compile/elaborate/run helper) factored out of `test_RogueXsimMulti.py`.
- `tests/axi/simlink/test_RogueXsimMulti.py` — **modify**: import shared helpers from `xsim_test_utils.py`; behavior unchanged.
- `tests/axi/simlink/RogueXsimTrafficTb.vhd` — **create**: the 8-instance active-traffic top.
- `tests/axi/simlink/test_RogueXsimTraffic.py` — **create**: orchestration + assertions.
- `docs/plans/xsim-multi-instance-live-traffic/progress.md` — **create** (Task 8): handoff/progress notes per AGENTS.md.

---

## Task 1: Per-tag vector helpers in the peer (pure functions, no Vivado)

**Files:**
- Modify: `tests/axi/simlink/rogue_tcp_peer.py`
- Test: `tests/axi/simlink/test_rogue_tcp_peer_tags.py`

- [ ] **Step 1: Write the failing test**

Create `tests/axi/simlink/test_rogue_tcp_peer_tags.py`:

```python
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
# - Sweep: Each instance index used by the xsim traffic top (Stream 0-3,
#   Memory 0-1, SideBand 0-1) fed to the peer's per-tag vector helpers.
# - Stimulus: Call the pure helper functions directly; no simulator, no ZMQ.
# - Checks: Each helper returns the exact byte/address/opcode values the tag
#   scheme in the plan mandates, and distinct tags never collide.
# - Timing: None -- pure functions.

from tests.axi.simlink.rogue_tcp_peer import (
    stream_peer_to_dut_payload,
    stream_dut_to_peer_payload,
    memory_txn_for_tag,
    sideband_peer_to_dut,
    sideband_expect_for_tag,
)


def test_stream_payloads_match_scheme():
    for i in range(4):
        assert stream_peer_to_dut_payload(i) == bytes([0x10 + i] * 4)
        assert stream_dut_to_peer_payload(i) == bytes([0x80 + i] * 4)


def test_memory_txn_matches_scheme():
    for i in range(2):
        txn = memory_txn_for_tag(i)
        assert txn["addr"] == 0x100 + (0x10 * i)
        assert txn["size"] == 4
        assert txn["write_data"] == bytes([0x40 + i, 0x50 + i, 0x60 + i, 0x70 + i])


def test_sideband_vectors_match_scheme():
    for i in range(2):
        frames = sideband_peer_to_dut(i)
        assert frames[0] == {"opCodeEn": 1, "opCode": 0x20 + i, "remDataChanged": 0, "remData": 0x00}
        assert frames[1] == {"opCodeEn": 0, "opCode": 0x00, "remDataChanged": 1, "remData": 0x40 + i}
        assert sideband_expect_for_tag(i) == {"opCode": 0x60 + i, "remData": 0x70 + i}


def test_distinct_tags_do_not_collide():
    assert stream_dut_to_peer_payload(0) != stream_dut_to_peer_payload(1)
    assert memory_txn_for_tag(0)["addr"] != memory_txn_for_tag(1)["addr"]
    assert sideband_expect_for_tag(0) != sideband_expect_for_tag(1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/axi/simlink/test_rogue_tcp_peer_tags.py -q`
Expected: FAIL with `ImportError: cannot import name 'stream_peer_to_dut_payload'`.

- [ ] **Step 3: Add the helper functions**

In `tests/axi/simlink/rogue_tcp_peer.py`, add near the top (after `RCVTIMEO_MS`, before the Stream section) a new block:

```python
# ---------------------------------------------------------------------------
# Per-instance tag scheme (used by the xsim multi-instance live-traffic top,
# RogueXsimTrafficTb.vhd). Each instance index i derives a distinct traffic
# family so a peer receiving another instance's traffic is a detectable
# isolation failure. Values mirror test_RogueDpiInstance.py's native traffic
# test. These are pure functions -- no ZMQ, no simulator -- so they are unit
# tested directly in test_rogue_tcp_peer_tags.py.
# ---------------------------------------------------------------------------

STREAM_TAG_FRAME_COUNT = 3  # single-beat frames each Stream instance exchanges


def stream_peer_to_dut_payload(tag):
    """Payload the peer pushes into Stream instance `tag` (DUT surfaces on ob)."""
    return bytes([(0x10 + tag) & 0xFF] * 4)


def stream_dut_to_peer_payload(tag):
    """Payload the HDL drives on Stream instance `tag`'s ib (peer receives)."""
    return bytes([(0x80 + tag) & 0xFF] * 4)


def memory_txn_for_tag(tag):
    """Write-then-read transaction Memory instance `tag` exchanges."""
    return {
        "addr": 0x100 + (0x10 * tag),
        "size": 4,
        "write_data": bytes([0x40 + tag, 0x50 + tag, 0x60 + tag, 0x70 + tag]),
    }


def sideband_peer_to_dut(tag):
    """The two frames the peer pushes into SideBand instance `tag`."""
    return [
        {"opCodeEn": 1, "opCode": 0x20 + tag, "remDataChanged": 0, "remData": 0x00},
        {"opCodeEn": 0, "opCode": 0x00, "remDataChanged": 1, "remData": 0x40 + tag},
    ]


def sideband_expect_for_tag(tag):
    """The tx opcode/remData SideBand instance `tag` should transmit back."""
    return {"opCode": 0x60 + tag, "remData": 0x70 + tag}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/axi/simlink/test_rogue_tcp_peer_tags.py -q`
Expected: PASS (4 passed).

- [ ] **Step 5: Commit**

```bash
git add tests/axi/simlink/rogue_tcp_peer.py tests/axi/simlink/test_rogue_tcp_peer_tags.py
git commit -m "test(simlink): add per-tag vector helpers for xsim traffic peers"
```

---

## Task 2: Thread `--tag` through the peer modes (backward compatible)

**Files:**
- Modify: `tests/axi/simlink/rogue_tcp_peer.py`
- Test: `tests/axi/simlink/test_rogue_tcp_peer_tags.py`

The peer runs as a subprocess, so its tag behavior is validated end-to-end under Vivado in later tasks. Here we only unit-test that `--tag` parses and that a tagged peer's *foreign-tag detection* logic is correct, by exercising the small pure predicate it uses.

- [ ] **Step 1: Write the failing test (append to `test_rogue_tcp_peer_tags.py`)**

```python
from tests.axi.simlink.rogue_tcp_peer import stream_frame_is_foreign, main


def test_stream_frame_is_foreign_detects_cross_talk():
    own = stream_dut_to_peer_payload(2).hex()
    # A frame carrying our own tag is not foreign.
    assert stream_frame_is_foreign({"data_hex": own}, tag=2) is False
    # A frame carrying another instance's tag is foreign.
    other = stream_dut_to_peer_payload(3).hex()
    assert stream_frame_is_foreign({"data_hex": other}, tag=2) is True


def test_argparse_accepts_optional_tag():
    # --tag is optional; parsing a tagged invocation must not raise. Use a
    # nonexistent port so any accidental socket work would fail fast, but we
    # only assert argument acceptance by catching the SystemExit-free parse via
    # a dry flag path is not available -- instead assert the parser directly.
    import argparse
    from tests.axi.simlink import rogue_tcp_peer

    parser = rogue_tcp_peer.build_arg_parser()
    args = parser.parse_args(["--mode", "stream", "--tag", "2", "19740", "/tmp/x.json"])
    assert args.tag == 2
    args2 = parser.parse_args(["--mode", "stream", "19604", "/tmp/y.json"])
    assert args2.tag is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/axi/simlink/test_rogue_tcp_peer_tags.py -q`
Expected: FAIL with `ImportError` on `stream_frame_is_foreign` / `build_arg_parser`.

- [ ] **Step 3: Add the foreign-tag predicate and refactor argparse**

In `rogue_tcp_peer.py`, add the predicate next to the other tag helpers:

```python
def stream_frame_is_foreign(decoded, tag):
    """True if a decoded stream frame carries a Stream tag other than `tag`.

    Foreign traffic reaching this peer means socket isolation between DPI
    instances leaked. Only the four Stream tag families (0x80..0x83) are
    considered; anything else is left to the normal payload check.
    """
    own = stream_dut_to_peer_payload(tag).hex()
    if decoded.get("data_hex") == own:
        return False
    for other in range(4):
        if other != tag and decoded.get("data_hex") == stream_dut_to_peer_payload(other).hex():
            return True
    return False
```

Replace the `main()` function's inline `argparse` construction with a factored builder so tests can parse without executing. Change the existing:

```python
def main(argv=None):
    parser = argparse.ArgumentParser(description="Rogue-TCP protocol peer")
    parser.add_argument("--mode", choices=["stream", "stream-recv", "memory", "sideband"], required=True)
    parser.add_argument("port", type=int)
    parser.add_argument("result_path")
    args = parser.parse_args(argv)
```

to:

```python
def build_arg_parser():
    parser = argparse.ArgumentParser(description="Rogue-TCP protocol peer")
    parser.add_argument("--mode", choices=["stream", "stream-recv", "memory", "sideband"], required=True)
    parser.add_argument("--tag", type=int, default=None,
                        help="per-instance tag family for the xsim multi-instance traffic top; "
                             "when omitted, the fixed single-instance vectors are used")
    parser.add_argument("port", type=int)
    parser.add_argument("result_path")
    return parser


def main(argv=None):
    args = build_arg_parser().parse_args(argv)
```

- [ ] **Step 4: Thread `tag` into the run_*_peer dispatch**

Update the dispatch tail of `main()` to pass `args.tag`:

```python
    if args.mode == "stream":
        return run_stream_peer(args.port, args.result_path, tag=args.tag)

    if args.mode == "stream-recv":
        return run_stream_recv_peer(args.port, args.result_path)

    if args.mode == "memory":
        return run_memory_peer(args.port, args.result_path, tag=args.tag)

    return run_sideband_peer(args.port, args.result_path, tag=args.tag)
```

Add a `tag=None` parameter to `run_stream_peer`, `run_memory_peer`, and `run_sideband_peer`. In each, when `tag is not None`, derive vectors from the tag helpers and enable foreign-tag rejection; when `tag is None`, keep the existing fixed-vector code path untouched. Concretely:

`run_stream_peer(port, result_path, tag=None)` — when tagged, send `STREAM_TAG_FRAME_COUNT` frames of `stream_peer_to_dut_payload(tag)`, then receive `STREAM_TAG_FRAME_COUNT` frames and for each assert `not stream_frame_is_foreign(decoded, tag)` (record `reason = "peer: FOREIGN tag ..."` + `result = 1` on failure) and `decoded["data_hex"] == stream_dut_to_peer_payload(tag).hex()`.

`run_memory_peer(port, result_path, tag=None)` — when tagged, use the single transaction from `memory_txn_for_tag(tag)` in place of the `MEM_TRANSACTIONS` loop; the existing read-back compare already rejects foreign data because a wrong instance's data will not equal this tag's `write_data`.

`run_sideband_peer(port, result_path, tag=None)` — when tagged, push `sideband_peer_to_dut(tag)` and expect `sideband_expect_for_tag(tag)` (opcode `0x60+tag`, remData `0x70+tag`) in place of the fixed `SIDEBAND_*` constants.

- [ ] **Step 5: Run tests to verify they pass**

Run: `.venv/bin/python -m pytest tests/axi/simlink/test_rogue_tcp_peer_tags.py -q`
Expected: PASS (6 passed).

- [ ] **Step 6: Regression — untagged peer path unchanged [VIVADO-optional]**

The GHDL Wrap tests call the peer with no `--tag`. Confirm they still pass (needs GHDL, which is present):
Run: `.venv/bin/python -m pytest tests/axi/simlink/test_RogueTcpStreamWrap.py tests/axi/simlink/test_RogueSideBandWrap.py -q`
Expected: PASS (SideBandWrap may be cold-start flaky; rerun once if it times out).

- [ ] **Step 7: Commit**

```bash
git add tests/axi/simlink/rogue_tcp_peer.py tests/axi/simlink/test_rogue_tcp_peer_tags.py
git commit -m "feat(simlink): thread optional --tag through Rogue-TCP peer modes"
```

---

## Task 3: Factor shared xsim helpers into `xsim_test_utils.py`

**Files:**
- Create: `tests/axi/simlink/xsim_test_utils.py`
- Modify: `tests/axi/simlink/test_RogueXsimMulti.py`

- [ ] **Step 1: Create `xsim_test_utils.py`**

```python
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Shared helpers for the Vivado xsim DPI regressions (test_RogueXsimMulti.py
# and test_RogueXsimTraffic.py): tool discovery/skip, the system-libstdc++
# LD_PRELOAD workaround, the RogueTcpDpi.so build fixture, and the
# xvlog/xvhdl/xelab/xsim compile-and-run helper.

import fcntl
import os
from pathlib import Path
import shutil
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[3]
XSIM_DIR = REPO_ROOT / "axi" / "simlink" / "xsim"

SV_SOURCES = [
    XSIM_DIR / "RogueTcpStreamDpi.sv",
    XSIM_DIR / "RogueTcpMemoryDpi.sv",
    XSIM_DIR / "RogueSideBandDpi.sv",
]
MODEL_VHDL_SOURCES = [
    XSIM_DIR / "RogueTcpStream.vhd",
    XSIM_DIR / "RogueTcpMemory.vhd",
    XSIM_DIR / "RogueSideBand.vhd",
]
REQUIRED_TOOLS = ("make", "xsc", "xvlog", "xvhdl", "xelab", "xsim")
BUILD_TIMEOUT_SECONDS = 300
RUN_TIMEOUT_SECONDS = 120

SKIP_REASON = "Vivado xsim regression needs make/xsc/xvlog/xvhdl/xelab/xsim"


def tools_available():
    return all(shutil.which(tool) is not None for tool in REQUIRED_TOOLS)


def xsim_run_env():
    """Environment for running xsim's DPI-linked snapshot.

    Every Vivado release bundles its own (older) libstdc++ and puts it ahead of
    the system libraries at run time. When the host libzmq was built against a
    newer libstdc++ than Vivado's, xsimk fails to start with a "GLIBCXX_...
    not found (required by libzmq.so.5)" loader error. Preloading the system
    libstdc++ (located portably via gcc, matching the xsim Makefile's crti.o
    lookup) resolves the newer symbols without affecting the build steps.
    Harmless when Vivado's bundled libstdc++ is already new enough.
    """
    env = os.environ.copy()
    try:
        libstdcxx = subprocess.run(
            ["gcc", "-print-file-name=libstdc++.so.6"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return env
    if not libstdcxx or not os.path.isfile(libstdcxx):
        return env
    preload = [libstdcxx]
    if env.get("LD_PRELOAD"):
        preload.append(env["LD_PRELOAD"])
    env["LD_PRELOAD"] = os.pathsep.join(preload)
    return env


def build_dpi_library():
    """Build RogueTcpDpi.so and run the DPI-header ABI check, under a file lock
    so parallel pytest workers do not race on the shared xsim.dir output."""
    build_dir = XSIM_DIR / "xsim.dir"
    build_dir.mkdir(parents=True, exist_ok=True)
    with open(build_dir / ".pytest-build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(
            ["make", "-C", str(XSIM_DIR), "all", "abi-check"],
            check=True, timeout=BUILD_TIMEOUT_SECONDS,
        )


def run_top(top, vhdl_sources, sim_build_dir):
    """Compile the SV leaves + given VHDL sources, elaborate `top`, run it under
    xsim -R with the libstdc++ preload, and return the CompletedProcess."""
    build_dir = sim_build_dir / top
    build_dir.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        ["xvlog", "-sv", *(str(s) for s in SV_SOURCES)],
        cwd=build_dir, check=True, timeout=BUILD_TIMEOUT_SECONDS,
    )
    subprocess.run(
        ["xvhdl", "-2008", *(str(s) for s in vhdl_sources)],
        cwd=build_dir, check=True, timeout=BUILD_TIMEOUT_SECONDS,
    )
    subprocess.run(
        ["xelab", "-debug", "typical", "-s", top,
         "-sv_root", str(XSIM_DIR), "-sv_lib", "RogueTcpDpi", f"work.{top}"],
        cwd=build_dir, check=True, timeout=BUILD_TIMEOUT_SECONDS,
    )
    return subprocess.run(
        ["xsim", top, "-R"],
        cwd=build_dir, capture_output=True, text=True,
        timeout=RUN_TIMEOUT_SECONDS, env=xsim_run_env(),
    )
```

- [ ] **Step 2: Rewrite `test_RogueXsimMulti.py` to use the shared helpers**

Replace the body (keep the license header + `Test methodology` block) with:

```python
import pytest

from tests.axi.simlink import xsim_test_utils as xu

HERE = xu.REPO_ROOT / "tests" / "axi" / "simlink"
TB_SOURCE = HERE / "RogueXsimMultiTb.vhd"
SIM_BUILD = HERE / "sim_build_RogueXsimMulti"
VHDL_SOURCES = [*xu.MODEL_VHDL_SOURCES, TB_SOURCE]

pytestmark = pytest.mark.skipif(not xu.tools_available(), reason=xu.SKIP_REASON)


@pytest.fixture(scope="module", autouse=True)
def build_dpi_library():
    xu.build_dpi_library()


def _run_top(top):
    return xu.run_top(top, VHDL_SOURCES, SIM_BUILD)


def test_xsim_multi_instance_smoke():
    result = _run_top("RogueXsimMultiTb")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Rogue xsim multi-instance smoke test passed" in result.stdout


def test_xsim_rejects_duplicate_port_pair():
    result = _run_top("RogueXsimDuplicatePortTb")
    output = result.stdout + result.stderr
    # xsim's $fatal exits 0 even in batch (-R) mode, so the return code cannot
    # distinguish rejection from success. The port-pair guard must fire (the
    # $fatal message is present) and the testbench's "not rejected" failure
    # branch must never be reached.
    assert "overlaps live RogueTcpStream port pair" in output, output
    assert "Duplicate xsim port pair was not rejected" not in output, output
```

- [ ] **Step 3: Regression — existing xsim tests still pass [VIVADO]**

Run:
```bash
.venv/bin/python -m pytest tests/axi/simlink/test_RogueXsimMulti.py -q
```
Expected (Vivado on PATH): `2 passed`. Without Vivado: `2 skipped`.

- [ ] **Step 4: Commit**

```bash
git add tests/axi/simlink/xsim_test_utils.py tests/axi/simlink/test_RogueXsimMulti.py
git commit -m "refactor(simlink): extract shared xsim test helpers into xsim_test_utils"
```

---

## Task 4: Traffic top + orchestration — Stream instances only [VIVADO]

Build the traffic TB and test incrementally, one model type at a time, validating under xsim at each step (the xsim run is the test). Start with the four Stream instances.

**Files:**
- Create: `tests/axi/simlink/RogueXsimTrafficTb.vhd`
- Create: `tests/axi/simlink/test_RogueXsimTraffic.py`

- [ ] **Step 1: Create `RogueXsimTrafficTb.vhd` with the four Stream instances**

```vhdl
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Multi-instance Vivado xsim DPI-C live-traffic test harness
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Test methodology:
-- - Instantiate four Stream, two Memory, and two SideBand xsim/DPI models,
--   each on its own endpoint pair, and exchange a per-instance tagged traffic
--   family with a dedicated external peer.
-- - Hold off all outbound traffic for a fixed settle delay after reset so the
--   eight peers are connected and draining first (the accepted transport
--   contract; no readiness handshake).
-- - Each Stream instance drives inbound beats tagged 0x80+i and checks the
--   outbound byte equals its peer's 0x10+i; Memory completes a tagged
--   write/read; SideBand strobes tx opcode/remData tagged for i and checks
--   the peer-driven rx opcode/remData.
-- - Report the success banner only after all instances pass; $fatal on any
--   wrong/missing tag. $fatal exits 0 under xsim -R, so pytest judges success
--   by the banner plus per-peer exit codes/JSON, not the xsim return code.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity RogueXsimTrafficTb is
end entity RogueXsimTrafficTb;

architecture test of RogueXsimTrafficTb is

   constant CLK_HALF_C     : time    := 5 ns;
   -- Settle delay before any outbound HDL traffic. Sized with wide margin for
   -- eight freshly-spawned Python peers to import, connect, and drain. Tuned
   -- in Task 7; start generous.
   constant SETTLE_EDGES_C : natural := 2000;
   constant WAIT_EDGES_C   : natural := 20000;  -- bounded per-item inbound wait

   signal clock : std_logic := '0';
   signal reset : std_logic := '1';

   -- Per-Stream-instance handshake/data
   type slv32_array is array (natural range <>) of std_logic_vector(31 downto 0);
   type slv8_array  is array (natural range <>) of std_logic_vector(7 downto 0);

   signal sObValid : std_logic_vector(3 downto 0);
   signal sObData  : slv32_array(3 downto 0);
   signal sObKeep  : slv8_array(3 downto 0);
   signal sIbValid : std_logic_vector(3 downto 0) := (others => '0');
   signal sIbReady : std_logic_vector(3 downto 0);
   signal sIbData  : slv32_array(3 downto 0)      := (others => (others => '0'));
   signal sIbKeep  : slv8_array(3 downto 0)       := (others => (others => '0'));
   signal sIbLast  : std_logic_vector(3 downto 0) := (others => '0');

   signal streamDone : std_logic_vector(3 downto 0) := (others => '0');

begin

   clock <= not clock after CLK_HALF_C;

   GEN_STREAM : for i in 0 to 3 generate
      U_STREAM : entity work.RogueTcpStream
         port map (
            clock      => clock,
            reset      => reset,
            portNum    => std_logic_vector(to_unsigned(19740 + (2*i), 16)),
            ssi        => '0',
            obValid    => sObValid(i),
            obReady    => '1',
            obDataLow  => sObData(i),
            obDataHigh => open,
            obUserLow  => open,
            obUserHigh => open,
            obKeep     => sObKeep(i),
            obLast     => open,
            ibValid    => sIbValid(i),
            ibReady    => sIbReady(i),
            ibDataLow  => sIbData(i),
            ibDataHigh => (others => '0'),
            ibUserLow  => (others => '0'),
            ibUserHigh => (others => '0'),
            ibKeep     => sIbKeep(i),
            ibLast     => sIbLast(i));
   end generate GEN_STREAM;

   -- One driver/checker process per Stream instance.
   GEN_STREAM_DRV : for i in 0 to 3 generate
      drv : process is
         variable expByte  : std_logic_vector(7 downto 0);
         variable rxCount  : natural := 0;
         variable waited   : natural;
      begin
         -- Wait out reset + settle so the peer is draining first.
         for e in 0 to SETTLE_EDGES_C loop
            wait until rising_edge(clock);
         end loop;

         -- Drive 3 inbound single-beat frames tagged 0x80+i (4 bytes, keep 0x0F).
         for f in 0 to 2 loop
            sIbData(i)  <= std_logic_vector(to_unsigned((16#80# + i), 8)) &
                           std_logic_vector(to_unsigned((16#80# + i), 8)) &
                           std_logic_vector(to_unsigned((16#80# + i), 8)) &
                           std_logic_vector(to_unsigned((16#80# + i), 8));
            sIbKeep(i)  <= x"0F";
            sIbLast(i)  <= '1';
            sIbValid(i) <= '1';
            wait until rising_edge(clock);
            sIbValid(i) <= '0';
            sIbLast(i)  <= '0';
            -- small gap between frames
            for g in 0 to 3 loop
               wait until rising_edge(clock);
            end loop;
         end loop;

         -- Expect 3 outbound frames carrying the peer's 0x10+i, obReady tied '1'.
         expByte := std_logic_vector(to_unsigned((16#10# + i), 8));
         waited  := 0;
         while rxCount < 3 loop
            wait until rising_edge(clock);
            waited := waited + 1;
            if sObValid(i) = '1' then
               assert sObData(i)(7 downto 0) = expByte
                  report "Stream " & integer'image(i) &
                         ": wrong outbound tag" severity failure;
               rxCount := rxCount + 1;
            end if;
            assert waited < WAIT_EDGES_C
               report "Stream " & integer'image(i) &
                      ": timed out waiting for outbound frame" severity failure;
         end loop;

         streamDone(i) <= '1';
         wait;
      end process drv;
   end generate GEN_STREAM_DRV;

   -- Banner process: assert reset sequencing then wait for all Stream done.
   banner : process is
   begin
      for e in 0 to 2 loop
         wait until rising_edge(clock);
      end loop;
      reset <= '0';
      wait until streamDone = "1111";
      report "Rogue xsim traffic test passed" severity note;
      stop;
      wait;
   end process banner;

end architecture test;
```

Note: obData low byte carries the payload tag (the C model packs the 4 kept bytes into obDataLow with keep 0x0F). If Task 4 validation shows the byte lands elsewhere, adjust the checked slice — this is the kind of detail the under-xsim run confirms.

- [ ] **Step 2: Create `test_RogueXsimTraffic.py` (Stream-only first)**

```python
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
# - Sweep: One eight-instance top (4 Stream, 2 Memory, 2 SideBand) run under
#   the real Vivado xsim mixed-language/DPI flow with eight live peers.
# - Stimulus: Launch one rogue_tcp_peer.py per instance (each --tag i) before
#   xsim starts; the top holds off outbound traffic for a fixed settle delay
#   so peers are connected and draining, then exchanges a tagged family per
#   instance.
# - Checks: xsim prints the success banner, every peer exits 0, and each
#   peer's JSON shows only its own tag family with zero foreign tags.
# - Timing: The top uses bounded clock loops; each peer bounds recv with
#   RCVTIMEO; xsim is wall-clock bounded. Skips when Vivado tools are absent.

import json
from pathlib import Path
import subprocess
import sys

import pytest

from tests.axi.simlink import xsim_test_utils as xu

HERE = xu.REPO_ROOT / "tests" / "axi" / "simlink"
TB_SOURCE = HERE / "RogueXsimTrafficTb.vhd"
SIM_BUILD = HERE / "sim_build_RogueXsimTraffic"
PEER = HERE / "rogue_tcp_peer.py"
VHDL_SOURCES = [*xu.MODEL_VHDL_SOURCES, TB_SOURCE]

pytestmark = pytest.mark.skipif(not xu.tools_available(), reason=xu.SKIP_REASON)

PEER_WAIT_SECONDS = 30

# (mode, tag, port) for each instance. Ports match RogueXsimTrafficTb.vhd.
STREAM_PEERS = [("stream", i, 19740 + 2 * i) for i in range(4)]


@pytest.fixture(scope="module", autouse=True)
def build_dpi_library():
    xu.build_dpi_library()


def _spawn_peers(specs, result_dir):
    result_dir.mkdir(parents=True, exist_ok=True)
    procs = []
    for mode, tag, port in specs:
        result_path = result_dir / f"{mode}_{tag}_{port}.json"
        procs.append((
            mode, tag, port, result_path,
            subprocess.Popen(
                [sys.executable, str(PEER), "--mode", mode, "--tag", str(tag),
                 str(port), str(result_path)],
                env=xu.xsim_run_env(),
            ),
        ))
    return procs


def _reap(procs):
    for _, _, _, _, proc in procs:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()


def test_xsim_stream_instances_exchange_isolated_traffic():
    result_dir = SIM_BUILD / "peers"
    procs = _spawn_peers(STREAM_PEERS, result_dir)
    try:
        result = xu.run_top("RogueXsimTrafficTb", VHDL_SOURCES, SIM_BUILD)
        output = result.stdout + result.stderr
        assert "Rogue xsim traffic test passed" in output, output

        for mode, tag, port, result_path, proc in procs:
            rc = proc.wait(timeout=PEER_WAIT_SECONDS)
            assert rc == 0, f"{mode} peer tag {tag} exited {rc}"
            observed = json.loads(result_path.read_text())
            # Every received stream frame must carry this tag's 0x80+tag family.
            own = bytes([(0x80 + tag) & 0xFF] * 4).hex()
            for frame in observed["received"]:
                assert frame["data_hex"] == own, (tag, frame)
    finally:
        _reap(procs)
```

- [ ] **Step 3: Run under xsim and iterate**

```bash
source /sdf/group/faders/tools/xilinx/2024.1/Vivado/2024.1/settings64.sh
.venv/bin/python -m pytest tests/axi/simlink/test_RogueXsimTraffic.py -q -s
```
Expected: PASS. If it fails, use the printed xsim output + peer JSON to fix: (a) the obData byte slice in the TB, (b) the settle-delay ordering, (c) frame counts. Re-run until green. Keep changes to the TB stimulus and the checked slice; do not change any model source.

- [ ] **Step 4: Commit**

```bash
git add tests/axi/simlink/RogueXsimTrafficTb.vhd tests/axi/simlink/test_RogueXsimTraffic.py
git commit -m "test(simlink): xsim live-traffic top + orchestration for Stream instances"
```

---

## Task 5: Add Memory instances [VIVADO]

**Files:**
- Modify: `tests/axi/simlink/RogueXsimTrafficTb.vhd`
- Modify: `tests/axi/simlink/test_RogueXsimTraffic.py`

- [ ] **Step 1: Add two Memory instances to the TB**

Add to the architecture: two `RogueTcpMemory` instances on ports `19748 + 2*i` (i=0..1), a `memDone : std_logic_vector(1 downto 0) := "00"` signal, and one driver process per instance that, after the settle delay, provides AXI-Lite slave responses so the model completes the peer's write then read:

- Write: when `awvalid='1' and wvalid='1'`, pulse `awready='1'`, `wready='1'` for one cycle, then `bvalid='1'` with `bresp="00"` until `bready='1'`. Assert `awaddr = 0x100 + 0x10*i` (the tag's address) — `$fatal` on mismatch.
- Read: when `arvalid='1'`, pulse `arready='1'`, then drive `rdata` = the tag's little-endian write_data (`0x70+i,0x60+i,0x50+i,0x40+i` packed) with `rvalid='1'`, `rresp="00"` until `rready='1'`. Assert `araddr = 0x100 + 0x10*i`.
- Set `memDone(i) <= '1'` after the read completes.

Update the banner wait to `wait until streamDone = "1111" and memDone = "11";`.

(Provide the concrete AXI-Lite response process by mirroring `_memory_cycle` in `test_RogueDpiInstance.py`: the same signals, driven from VHDL. Validate the exact handshake timing under xsim in Step 3.)

- [ ] **Step 2: Add Memory peers to the test**

In `test_RogueXsimTraffic.py`, add:
```python
MEMORY_PEERS = [("memory", i, 19748 + 2 * i) for i in range(2)]
```
Extend the test (or add `test_xsim_memory_instances_...`) to spawn `STREAM_PEERS + MEMORY_PEERS` and, for memory peers, assert each peer's JSON `transactions` show the tag's address and a read-back `data_hex` equal to the tag's write_data, all `resp == 0`.

- [ ] **Step 3: Run under xsim and iterate**

```bash
source /sdf/group/faders/tools/xilinx/2024.1/Vivado/2024.1/settings64.sh
.venv/bin/python -m pytest tests/axi/simlink/test_RogueXsimTraffic.py -q -s
```
Expected: PASS. Iterate on AXI-Lite handshake timing using xsim output + peer JSON.

- [ ] **Step 4: Commit**

```bash
git add tests/axi/simlink/RogueXsimTrafficTb.vhd tests/axi/simlink/test_RogueXsimTraffic.py
git commit -m "test(simlink): add Memory instances to xsim live-traffic top"
```

---

## Task 6: Add SideBand instances [VIVADO]

**Files:**
- Modify: `tests/axi/simlink/RogueXsimTrafficTb.vhd`
- Modify: `tests/axi/simlink/test_RogueXsimTraffic.py`

- [ ] **Step 1: Add two SideBand instances to the TB**

Add two `RogueSideBand` instances on ports `19752 + 2*i` (i=0..1), a `sbDone : std_logic_vector(1 downto 0)` signal, and one driver process per instance that, after settle:
- Pulse `txOpCodeEn='1'` with `txOpCode = 0x60+i` for one cycle, then a gap, then set `txRemData = 0x70+i`.
- Wait (bounded) until `rxOpCodeEn` pulses and check `rxOpCode = 0x20+i`; wait until `rxRemData = 0x40+i`. `$fatal` on mismatch/timeout.
- Set `sbDone(i) <= '1'`.

Update the banner wait to `wait until streamDone = "1111" and memDone = "11" and sbDone = "11";`.

- [ ] **Step 2: Add SideBand peers to the test**

```python
SIDEBAND_PEERS = [("sideband", i, 19752 + 2 * i) for i in range(2)]
```
Spawn all eight (`STREAM_PEERS + MEMORY_PEERS + SIDEBAND_PEERS`). For sideband peers assert the JSON shows the DUT's tx opcode `0x60+i` and remData `0x70+i` were received.

- [ ] **Step 3: Run under xsim and iterate**

```bash
source /sdf/group/faders/tools/xilinx/2024.1/Vivado/2024.1/settings64.sh
.venv/bin/python -m pytest tests/axi/simlink/test_RogueXsimTraffic.py -q -s
```
Expected: PASS with all eight peers exiting 0.

- [ ] **Step 4: Commit**

```bash
git add tests/axi/simlink/RogueXsimTrafficTb.vhd tests/axi/simlink/test_RogueXsimTraffic.py
git commit -m "test(simlink): add SideBand instances to xsim live-traffic top"
```

---

## Task 7: Tune settle delay + finalize foreign-tag rejection [VIVADO]

**Files:**
- Modify: `tests/axi/simlink/RogueXsimTrafficTb.vhd`
- Modify: `tests/axi/simlink/test_RogueXsimTraffic.py`

- [ ] **Step 1: Confirm foreign-tag rejection is active for all peers**

Stream peers already reject foreign tags via `stream_frame_is_foreign` (Task 2). Confirm Memory (wrong data → read-back mismatch) and SideBand (wrong opcode/remData → mismatch) peers each fail if they receive another instance's family. Add an explicit assertion in the test that each peer's JSON contains **only** its own tag family (no cross-talk records).

- [ ] **Step 2: Right-size `SETTLE_EDGES_C`**

Run the full traffic test 5 times back-to-back:
```bash
source /sdf/group/faders/tools/xilinx/2024.1/Vivado/2024.1/settings64.sh
for n in 1 2 3 4 5; do .venv/bin/python -m pytest tests/axi/simlink/test_RogueXsimTraffic.py -q; done
```
Expected: 5/5 PASS. If any run shows a peer timeout (peers not draining before outbound traffic), increase `SETTLE_EDGES_C` and document the chosen value + observed peer-startup margin in a TB comment. The known tradeoff (fixed timing, Option B) is documented in the design spec.

- [ ] **Step 3: Commit**

```bash
git add tests/axi/simlink/RogueXsimTrafficTb.vhd tests/axi/simlink/test_RogueXsimTraffic.py
git commit -m "test(simlink): tune xsim traffic settle delay and finalize isolation checks"
```

---

## Task 8: Full regression, progress notes, and wrap-up [VIVADO]

**Files:**
- Create: `docs/plans/xsim-multi-instance-live-traffic/progress.md`

- [ ] **Step 1: Full simlink suite, serial and parallel**

```bash
source /sdf/group/faders/tools/xilinx/2024.1/Vivado/2024.1/settings64.sh
.venv/bin/python -m pytest -q -n 0 tests/axi/simlink
.venv/bin/python -m pytest -q -n auto --dist=worksteal tests/axi/simlink
```
Expected: all pass except the valgrind test (`1 skipped` if valgrind absent). The new traffic test and the refactored `test_RogueXsimMulti.py` both green. Record exact pass/skip counts.

- [ ] **Step 2: Lint the new/edited sources**

```bash
.venv/bin/python -m flake8 tests/axi/simlink/rogue_tcp_peer.py tests/axi/simlink/test_rogue_tcp_peer_tags.py tests/axi/simlink/xsim_test_utils.py tests/axi/simlink/test_RogueXsimTraffic.py tests/axi/simlink/test_RogueXsimMulti.py
.venv/bin/python -m vsg -f tests/axi/simlink/RogueXsimTrafficTb.vhd
git diff --check
```
Expected: flake8 clean; VSG reports (fix or record any style deviations consistent with the existing `RogueXsimMultiTb.vhd`); `git diff --check` clean.

- [ ] **Step 3: Write progress/handoff notes**

Create `docs/plans/xsim-multi-instance-live-traffic/progress.md` capturing: goal, final status, files added/changed, the Vivado version used (2024.1), the chosen `SETTLE_EDGES_C` value and its margin, exact regression counts, the Option B fixed-timing tradeoff, and any open risks (e.g. cold-start flakiness). Keep simulator artifacts out; summarize and link.

- [ ] **Step 4: Verify no artifacts staged; clean build dirs**

```bash
make -C axi/simlink/xsim clean
rm -rf tests/axi/simlink/sim_build_RogueXsimTraffic
git status --short
```
Expected: only the intended source/doc files show; no `xsim.dir`, `*.pb`, `*.jou`, or `sim_build_*` staged.

- [ ] **Step 5: Commit**

```bash
git add docs/plans/xsim-multi-instance-live-traffic/progress.md
git commit -m "docs(simlink): record xsim live-traffic validation progress notes"
```

---

## Self-Review Notes

- **Spec coverage:** goal (isolated live traffic through xsim) → Tasks 4–7; per-instance tagging → Tasks 1–2; shared-helper refactor → Task 3; Option B settle delay → TB `SETTLE_EDGES_C` + Task 7; positive + foreign-tag rejection → Task 2 (`stream_frame_is_foreign`) + Task 7; skip-without-Vivado → `pytestmark`; regression of existing tests → Task 3 Step 3, Task 8; docs under `docs/plans/<task-name>/` → Task 8. No changes to model C/SV/entity source (spec scope) — TB and tests only. Sparse-tKeep/uninit-read not ported (out of scope) — confirmed absent from tasks.
- **Placeholder scan:** VHDL for Memory (Task 5) and SideBand (Task 6) driver processes is described precisely (signals, handshake, tag values) rather than shown line-for-line, because the exact AXI-Lite/sideband handshake timing must be confirmed against the live model under xsim (the run is the test); this is an explicit run-and-iterate loop, not a deferred decision. All Python is shown in full.
- **Type/name consistency:** `xsim_test_utils` exports `tools_available`, `SKIP_REASON`, `xsim_run_env`, `build_dpi_library`, `run_top`, `REPO_ROOT`, `MODEL_VHDL_SOURCES`, `SV_SOURCES` — used consistently in both test modules. Peer helpers `stream_peer_to_dut_payload` / `stream_dut_to_peer_payload` / `memory_txn_for_tag` / `sideband_peer_to_dut` / `sideband_expect_for_tag` / `stream_frame_is_foreign` / `build_arg_parser` — names match across Tasks 1, 2, 4. TB signals `streamDone`/`memDone`/`sbDone` consistent across Tasks 4–6.
