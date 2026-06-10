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
# - Precondition: None (selector pure functions need no filesystem or git).
# - Mechanism: Import classify_ref(), select_tests(), build_pytest_command()
#   from select_tests.py directly (sys.path insert into scripts/), inject
#   fake env values and a fake index dict — no subprocess, no git required.
# - Assertions: cover all five branches of classify_ref() (SEL-04/SEL-01),
#   empty-diff noop (SEL-07), non-empty intersection (SEL-01), always_run
#   gating (SEL-07/D-02), full-suite auto-discovery command (SEL-05), and
#   command flag preservation (SEL-09).
# - Regression guard: asserts survive future ref-classification changes.

from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[2]

sys.path.insert(0, str(REPO_ROOT / "scripts"))
from select_tests import classify_ref, select_tests, build_pytest_command  # noqa: E402

# Minimal fake index covering production_rtl, test_infra, always_run, fallback_log.
_FAKE_INDEX = {
    "production_rtl": {
        "dsp/generic/fixed/BoxcarFilter.vhd": ["tests/dsp/generic/test_BoxcarFilter.py"],
    },
    "test_infra": {},
    "always_run": ["tests/protocols/ssi/test_SsiPrbs.py"],
    "fallback_log": [],
}

BOXCAR_TEST  = "tests/dsp/generic/test_BoxcarFilter.py"
ALWAYS_TEST  = "tests/protocols/ssi/test_SsiPrbs.py"
BOXCAR_VHD   = "dsp/generic/fixed/BoxcarFilter.vhd"


# ---------------------------------------------------------------------------
# classify_ref — SEL-04
# ---------------------------------------------------------------------------

def test_classify_full_on_tag():
    assert classify_ref("push", "tag", "v2.71.0", "") == "full", (
        "Tag push must always classify as full suite (SEL-04)"
    )


def test_classify_full_on_main():
    assert classify_ref("push", "branch", "main", "") == "full", (
        "Push to main must classify as full suite (SEL-04)"
    )


def test_classify_full_on_prerelease():
    assert classify_ref("push", "branch", "pre-release", "") == "full", (
        "Push to pre-release must classify as full suite (SEL-04)"
    )


def test_classify_full_on_pr_to_main():
    assert classify_ref("pull_request", "branch", "42/merge", "main") == "full", (
        "PR whose base is main must classify as full suite (SEL-04)"
    )


def test_classify_full_on_pr_to_prerelease():
    assert classify_ref("pull_request", "branch", "42/merge", "pre-release") == "full", (
        "PR whose base is pre-release must classify as full suite (SEL-04)"
    )


# ---------------------------------------------------------------------------
# classify_ref — SEL-01
# ---------------------------------------------------------------------------

def test_classify_selective_on_dev_pr():
    assert classify_ref("pull_request", "branch", "42/merge", "feature-foo") == "selective", (
        "Dev-branch PR must classify as selective (SEL-01)"
    )


# ---------------------------------------------------------------------------
# select_tests — SEL-07 (empty-diff noop)
# ---------------------------------------------------------------------------

def test_empty_diff_is_noop():
    result = select_tests([], _FAKE_INDEX)
    assert result == set(), (
        "Zero .vhd files changed must produce empty selection — always_run must NOT fire (SEL-07)"
    )


# ---------------------------------------------------------------------------
# select_tests — SEL-01 (intersection picks correct tests)
# ---------------------------------------------------------------------------

def test_intersection_picks_correct_tests():
    result = select_tests([BOXCAR_VHD], _FAKE_INDEX)
    assert BOXCAR_TEST in result, (
        f"{BOXCAR_VHD} changed but {BOXCAR_TEST} not selected — "
        "production_rtl intersection is broken (SEL-01)"
    )


# ---------------------------------------------------------------------------
# select_tests — SEL-07 / D-02 (always_run unioned when a .vhd changed)
# ---------------------------------------------------------------------------

def test_always_run_unioned_on_vhd_change():
    result = select_tests([BOXCAR_VHD], _FAKE_INDEX)
    assert ALWAYS_TEST in result, (
        "always_run test not included when a .vhd changed — D-02 fail-safe violated (SEL-07/D-02)"
    )


def test_always_run_not_fired_on_empty_diff():
    result = select_tests([], _FAKE_INDEX)
    assert ALWAYS_TEST not in result, (
        "always_run must NOT be included when zero .vhd files changed (SEL-07)"
    )


# ---------------------------------------------------------------------------
# build_pytest_command — SEL-05 (full-suite auto-discovery)
# ---------------------------------------------------------------------------

def test_full_command_uses_autodiscovery():
    cmd = build_pytest_command(set(), "full")
    assert "tests/ --ignore=tests/legacy --ignore=tests/ethernet" in cmd, (
        "Full-suite command must use tests/ root auto-discovery with --ignore (SEL-05); "
        f"got: {cmd}"
    )


# ---------------------------------------------------------------------------
# build_pytest_command — SEL-09 (flag preservation)
# ---------------------------------------------------------------------------

def test_flags_preserved_full():
    cmd = build_pytest_command(set(), "full")
    assert "--cov -v -n auto --dist=worksteal" in cmd, (
        f"Full-suite command must preserve pytest flags (SEL-09); got: {cmd}"
    )


def test_flags_preserved_selective():
    cmd = build_pytest_command({BOXCAR_TEST}, "selective")
    assert "--cov -v -n auto --dist=worksteal" in cmd, (
        f"Selective command must preserve pytest flags (SEL-09); got: {cmd}"
    )


# ---------------------------------------------------------------------------
# build_pytest_command — SEL-07 (empty selective -> None)
# ---------------------------------------------------------------------------

def test_empty_selective_command_is_none():
    result = build_pytest_command(set(), "selective")
    assert result is None, (
        "Empty selective selection must return None — SEL-07 noop contract"
    )
