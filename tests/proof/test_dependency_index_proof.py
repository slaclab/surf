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
# - Precondition: test_dependency_index.json must exist (produced by
#   'make MODULES=$PWD analysis && python scripts/build_test_dependency_index.py').
#   In CI, the "Build dependency index" step stashes the file at
#   <repo_root>/test_dependency_index.json before `make import` wipes build/.
#   Locally it lives at build/test_dependency_index.json after running the indexer.
# - Mechanism: Load the pre-built index JSON directly rather than calling
#   build_index() from scratch.  build_index() requires ghdl gen-depends to
#   work against a fully *analyzed* library (ghdl -a).  After `make import`
#   replaces build/ with ghdl -i output the analyzed objects (.o files) are
#   gone, so gen-depends returns empty dependency sets and the proof would
#   silently produce a vacuously-empty index and fail.  Loading the stashed
#   JSON avoids this: it is the exact index that select_tests.py also reads,
#   so this proof validates both the index structure and the selector input.
# - Assertions:
#   - SEL-02 (broad): base/general/rtl/StdRtlPkg.vhd must appear in the index
#     with > 10 dependent tests (package use edges honored).
#   - SEL-03 (narrow): dsp/generic/fixed/BoxcarFilter.vhd must appear with <= 2
#     dependent tests (leaf module, not a shared package). Note: BoxcarFilter
#     lives under dsp/generic/fixed/, NOT dsp/generic/rtl/ — "production RTL" is
#     defined by GHDL closure membership, not a /rtl/ path substring (surf keeps
#     production .vhd in /rtl/, /fixed/, /inferred/, /ip_integrator/, /dummy/).
# - Regression guard: asserts survive future GHDL upgrades / RTL refactors.

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]

STD_RTL_PKG = "base/general/rtl/StdRtlPkg.vhd"
BOXCAR_FILTER = "dsp/generic/fixed/BoxcarFilter.vhd"
BOXCAR_TEST = "tests/dsp/generic/test_BoxcarFilter.py"


@pytest.fixture(scope="module")
def index():
    # CI stash (created before make import wipes build/); falls back to the
    # default build output for local development.
    stash = REPO_ROOT / "test_dependency_index.json"
    default_out = REPO_ROOT / "build" / "test_dependency_index.json"
    if stash.exists():
        json_path = stash
    elif default_out.exists():
        json_path = default_out
    else:
        pytest.skip(
            "test_dependency_index.json not found — run "
            "'make MODULES=$PWD analysis && python scripts/build_test_dependency_index.py' first"
        )
    return json.loads(json_path.read_text(encoding="utf-8"))


def test_stdrtlpkg_broad(index):
    dependents = index["production_rtl"].get(STD_RTL_PKG, [])
    assert len(dependents) > 10, (
        f"StdRtlPkg.vhd has only {len(dependents)} dependents — "
        "package use edges are not being honored (SEL-02)"
    )


def test_boxcarfilter_narrow(index):
    dependents = index["production_rtl"].get(BOXCAR_FILTER, [])
    assert BOXCAR_TEST in dependents, (
        "BoxcarFilter.vhd not found in its own test's dependency set (SEL-03)"
    )
    assert len(dependents) <= 2, (
        f"BoxcarFilter.vhd has {len(dependents)} dependents — expected narrow leaf <= 2 (SEL-03)"
    )


def test_always_run_nonempty(index):
    """At least some tests must be classified always-run (D-02/SEL-10 sanity check)."""
    assert len(index["always_run"]) > 0, (
        "always_run is empty — either every test resolved cleanly (unlikely) "
        "or the fail-safe fallback is broken (D-02)"
    )


def test_fallback_log_populated(index):
    """fallback_log must be non-empty and consistent with always_run.

    Every test in fallback_log must also appear in always_run (fail-safe contract).
    """
    assert len(index["fallback_log"]) > 0, (
        "fallback_log is empty — unresolvable tests are silently dropped (CR-01/D-02)"
    )
    always_run_set = set(index["always_run"])
    for entry in index["fallback_log"]:
        assert entry["test"] in always_run_set, (
            f"fallback_log entry {entry['test']!r} is not in always_run — "
            "fail-safe contract violated: every logged test must be always-run"
        )
