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
# - Precondition: `make MODULES=$PWD analysis` must have been run (surf library
#   analyzed into build/). The test skips with a clear message if absent.
# - Mechanism: Import and call build_index() from the builder script directly,
#   rather than running it as a subprocess, so the proof exercises the live code.
# - Assertions:
#   - SEL-02 (broad): base/general/rtl/StdRtlPkg.vhd must appear in the index
#     with > 10 dependent tests (package use edges honored).
#   - SEL-03 (narrow): dsp/generic/fixed/BoxcarFilter.vhd must appear with <= 2
#     dependent tests (leaf module, not a shared package). Note: BoxcarFilter
#     lives under dsp/generic/fixed/, NOT dsp/generic/rtl/ — "production RTL" is
#     defined by GHDL closure membership, not a /rtl/ path substring (surf keeps
#     production .vhd in /rtl/, /fixed/, /inferred/, /ip_integrator/, /dummy/).
# - Regression guard: asserts survive future GHDL upgrades / RTL refactors.
# - CI note: This proof is auto-discovered by a local `pytest` invocation, but
#   the existing CI command (surf_ci.yml) lists explicit directories
#   (tests/axi tests/base tests/dsp tests/protocols) and does NOT include
#   tests/proof. Phase 3 (CI workflow integration) must add tests/proof to the
#   CI invocation (or switch CI to tree-scan discovery) so this proof runs in CI.

from pathlib import Path
import sys

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]

STD_RTL_PKG = "base/general/rtl/StdRtlPkg.vhd"
BOXCAR_FILTER = "dsp/generic/fixed/BoxcarFilter.vhd"
BOXCAR_TEST = "tests/dsp/generic/test_BoxcarFilter.py"


@pytest.fixture(scope="module")
def index():
    cf_path = REPO_ROOT / "build" / "surf-obj08.cf"
    if not cf_path.exists():
        pytest.skip("build/surf-obj08.cf not found — run `make MODULES=$PWD analysis` first")
    sys.path.insert(0, str(REPO_ROOT / "scripts"))
    from build_test_dependency_index import build_index
    return build_index(repo_root=REPO_ROOT)


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
