##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from __future__ import annotations

import ast
import random
import subprocess

import pytest

from tests.common import dep_map
from tests.common.regression_utils import REPO_ROOT, TESTS_ROOT


def test_select_tests_happy_path():
    # Hand-built dep_map + changed-file set standing in for a real
    # `ghdl --gen-depends` result and a real `git diff` — this is the
    # failing-first end-to-end assertion for the whole resolver path.
    # The dep_map is padded with unrelated modules so the changed source's
    # fan-out fraction stays below FAN_OUT_THRESHOLD -- this test asserts
    # selection precision, not the fan-out force-full route (covered
    # separately below).
    built_map = {
        "tests.axi.axi_lite.test_AxiLiteAsync": {"axi/axi-lite/rtl/AxiLiteAsync.vhd", "base/general/rtl/StdRtlPkg.vhd"},
        "tests.base.fifo.test_FifoAsync": {"base/fifo/rtl/FifoAsync.vhd"},
        **{f"tests.padding.test_{i}": {f"padding/rtl/Padding{i}.vhd"} for i in range(20)},
    }
    always_run = {"tests.dsp.generic.test_FirFilterTap"}
    changed = {"axi/axi-lite/rtl/AxiLiteAsync.vhd": "M"}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert selected == {
        "tests.axi.axi_lite.test_AxiLiteAsync",
        "tests.dsp.generic.test_FirFilterTap",
    }
    assert force_full is False


def test_select_tests_no_matching_dependency():
    # A changed .vhd that matches no test's dependency set is exactly the
    # D-10 fail-open trigger (superseding Plan 01's placeholder
    # "force_full is always False" note) — see
    # test_select_tests_force_full_on_unresolved_changed_rtl_file below for
    # the dedicated D-10 assertion.
    built_map = {"tests.base.fifo.test_FifoAsync": {"base/fifo/rtl/FifoAsync.vhd"}}
    always_run: set[str] = set()
    changed = {"axi/axi-lite/rtl/AxiLiteAsync.vhd": "M"}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert selected == set()
    assert force_full is True


def test_discover_toplevels_literal():
    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT, scan_dirs=("axi",))

    assert resolved["tests.axi.axi_lite.test_AxiLiteAsync"] == {"surf.axiliteasyncipintegrator"}
    assert "tests.axi.axi_lite.test_AxiLiteAsync" not in always_run


def test_discover_toplevels_always_run_for_dynamic_toplevel():
    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT, scan_dirs=("dsp",))

    # test_FirFilterTap.py builds its toplevel from an f-string
    # (`f"surf.{wrapper_name.lower()}"`) — not a literal, so it must be
    # conservatively always-run per D-08, never silently resolved/skipped.
    assert "tests.dsp.generic.test_FirFilterTap" in always_run
    assert "tests.dsp.generic.test_FirFilterTap" not in resolved


def test_discover_toplevels_raises_on_nonexistent_scan_dir():
    # A mistyped --scan-dir (or a future DEFAULT_SCAN_DIRS typo) must raise
    # rather than silently discover zero tests for that subtree -- Path.rglob
    # on a nonexistent directory returns an empty iterator, not an error, so
    # this must be checked explicitly.
    with pytest.raises(FileNotFoundError):
        dep_map.discover_toplevels(REPO_ROOT, scan_dirs=("no_such_subtree",))


def _run_git(args: list[str], cwd) -> None:
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True)


def test_changed_files_classification(tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()

    _run_git(["init", "-q"], cwd=repo)
    _run_git(["config", "user.email", "test@example.com"], cwd=repo)
    _run_git(["config", "user.name", "Test"], cwd=repo)

    keep_file = repo / "keep.vhd"
    keep_file.write_text("-- unchanged\n", encoding="utf-8")
    old_name = repo / "old_name.vhd"
    old_name.write_text("-- will be renamed\n", encoding="utf-8")
    delete_me = repo / "delete_me.vhd"
    delete_me.write_text("-- will be deleted\n", encoding="utf-8")

    _run_git(["add", "."], cwd=repo)
    _run_git(["commit", "-q", "-m", "base"], cwd=repo)
    base_sha = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=repo, check=True, capture_output=True, text=True
    ).stdout.strip()

    # Modify one file, rename another, delete a third, add a fourth.
    keep_file.write_text("-- modified\n", encoding="utf-8")
    new_name = repo / "new_name.vhd"
    old_name.rename(new_name)
    delete_me.unlink()
    added_file = repo / "added.vhd"
    added_file.write_text("-- new\n", encoding="utf-8")

    _run_git(["add", "-A"], cwd=repo)
    _run_git(["commit", "-q", "-m", "changes"], cwd=repo)

    original_run = subprocess.run

    def run_in_repo(args, **kwargs):
        kwargs.setdefault("cwd", repo)
        return original_run(args, **kwargs)

    import tests.common.dep_map as dep_map_module

    old_subprocess_run = dep_map_module.subprocess.run
    dep_map_module.subprocess.run = run_in_repo
    try:
        changes = dep_map_module.changed_files(base_sha)
    finally:
        dep_map_module.subprocess.run = old_subprocess_run

    assert changes["keep.vhd"] == "M"
    assert changes["new_name.vhd"] == "M"
    assert changes["added.vhd"] == "A"
    assert changes["delete_me.vhd"] == "D"
    assert "old_name.vhd" not in changes


# --- D-10: broad fail-open --------------------------------------------------


def test_select_tests_force_full_on_unresolved_changed_rtl_file():
    # A changed .vhd that intersects NO test's dependency set (a new,
    # renamed-away, or unwired unit the current graph can't attribute) must
    # fail open to a full run, not silently select nothing (D-10).
    built_map = {"tests.base.fifo.test_FifoAsync": {"base/fifo/rtl/FifoAsync.vhd"}}
    always_run: set[str] = set()
    changed = {"axi/axi-lite/rtl/NewNeverSeenEntity.vhd": "A"}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert force_full is True


def test_select_tests_no_force_full_when_all_changed_rtl_resolves():
    # The mirror-image happy path: every changed .vhd is a known dependency
    # of some test, so force_full must stay False (no false full-run either).
    # The dep_map is padded with unrelated modules so the changed source's
    # fan-out fraction stays below FAN_OUT_THRESHOLD -- this test asserts
    # selection precision, not the fan-out force-full route (covered separately
    # below).
    built_map = {
        "tests.base.fifo.test_FifoAsync": {"base/fifo/rtl/FifoAsync.vhd"},
        **{f"tests.padding.test_{i}": {f"padding/rtl/Padding{i}.vhd"} for i in range(20)},
    }
    always_run: set[str] = set()
    changed = {"base/fifo/rtl/FifoAsync.vhd": "M"}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert force_full is False
    assert selected == {"tests.base.fifo.test_FifoAsync"}


def test_select_tests_force_full_on_deletion():
    # D-14: a true deletion (status 'D', not a rename) forces a full run —
    # the former dependents can't be resolved from the post-change graph.
    built_map = {"tests.base.fifo.test_FifoAsync": {"base/fifo/rtl/FifoAsync.vhd"}}
    always_run: set[str] = set()
    changed = {"base/fifo/rtl/FifoAsync.vhd": "D"}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert force_full is True


def test_select_tests_rename_stays_precise():
    # D-14: a rename resolves via the new path (changed_files() already
    # emits status 'M' at the new path for renames) and stays precise — it
    # must NOT force a full run merely because the path is "new" to us.
    # The dep_map is padded with unrelated modules so the changed source's
    # fan-out fraction stays below FAN_OUT_THRESHOLD -- this test asserts
    # rename precision, not the fan-out force-full route (covered separately
    # below).
    built_map = {
        "tests.base.fifo.test_FifoAsync": {"base/fifo/rtl/FifoAsyncRenamed.vhd"},
        **{f"tests.padding.test_{i}": {f"padding/rtl/Padding{i}.vhd"} for i in range(20)},
    }
    always_run: set[str] = set()
    changed = {"base/fifo/rtl/FifoAsyncRenamed.vhd": "M"}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert force_full is False
    assert selected == {"tests.base.fifo.test_FifoAsync"}


def test_select_tests_wrapper_change_selects_owner_only():
    # A changed wrappers/ path with a wrapper_index entry selects exactly
    # its attributed owner(s) and does not force a full run.
    built_map: dict[str, set[str]] = {}
    always_run: set[str] = set()
    changed = {"base/sync/wrappers/W.vhd": "M"}
    wrapper_index = {"base/sync/wrappers/W.vhd": {"tests.base.sync.test_X"}}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, wrapper_index)

    assert selected == {"tests.base.sync.test_X"}
    assert force_full is False


def test_select_tests_wrapper_change_unattributable_forces_full():
    # A changed wrappers/ path absent from wrapper_index is indeterminate —
    # fail open, and must not fall through to the generic
    # not-in-all_known_sources check.
    built_map: dict[str, set[str]] = {}
    always_run: set[str] = set()
    changed = {"base/sync/wrappers/W.vhd": "M"}
    wrapper_index: dict[str, set[str]] = {}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, wrapper_index)

    assert force_full is True


def test_merge_base_failure_is_a_fail_open_trigger(monkeypatch):
    # merge_base_with_origin_main() raises subprocess.CalledProcessError on
    # failure (e.g. origin/main absent) rather than returning a sentinel —
    # callers (the CLI) must catch this and fail open, never crash (D-10).
    def raise_called_process_error(*args, **kwargs):
        raise subprocess.CalledProcessError(returncode=128, cmd=args[0] if args else [])

    monkeypatch.setattr(dep_map.subprocess, "run", raise_called_process_error)

    with pytest.raises(subprocess.CalledProcessError):
        dep_map.merge_base_with_origin_main()


# --- gen_depends_sources / build_dependency_map -----------------------------


def test_gen_depends_sources_returns_none_on_ghdl_failure(monkeypatch):
    # A `ghdl --gen-depends` failure (CalledProcessError) must be signaled
    # distinctly from "no dependencies" -- None, not set() -- so callers can
    # tell "unresolved" apart from "genuinely empty" (D-10).
    def raise_called_process_error(*args, **kwargs):
        raise subprocess.CalledProcessError(returncode=1, cmd=args[0] if args else [])

    monkeypatch.setattr(dep_map.subprocess, "run", raise_called_process_error)

    result = dep_map.gen_depends_sources("surf.somewrapper", "/nonexistent/workdir", [])

    assert result is None


def test_build_dependency_map_reports_unresolved_toplevel(monkeypatch):
    # A toplevel whose gen_depends_sources() call fails must make its module
    # unresolved (excluded from dep_map, listed in unresolved_modules) rather
    # than silently getting an empty-but-valid dependency set.
    def fake_gen_depends_sources(toplevel, workdir, ghdl_flags):
        if toplevel == "surf.brokenwrapper":
            return None
        return {"base/general/rtl/StdRtlPkg.vhd"}

    monkeypatch.setattr(dep_map, "gen_depends_sources", fake_gen_depends_sources)

    toplevels = {
        "tests.axi.test_A": {"surf.brokenwrapper"},
        "tests.base.test_B": {"surf.healthywrapper"},
    }

    built_map, unresolved_modules = dep_map.build_dependency_map(toplevels, "/workdir", [])

    assert unresolved_modules == {"tests.axi.test_A"}
    assert "tests.axi.test_A" not in built_map
    assert built_map == {"tests.base.test_B": {"base/general/rtl/StdRtlPkg.vhd"}}


def test_unresolved_toplevel_is_not_silently_dropped_from_selection(monkeypatch):
    # CR-01 repro: toplevel A's GHDL analysis fails (unresolved) while
    # healthy toplevel B shares a changed file (StdRtlPkg.vhd) with it. Prior
    # to the fix, gen_depends_sources() folded A's failure into set(), so
    # dep_map["tests.axi.test_A"] == set() -- A could never be selected via
    # the changed-file intersection, and it was not in `always_run` either
    # (it's a "resolved" toplevel, not a non-literal one) -- so it silently
    # dropped out of `selected` entirely. Worse, `force_full` also stayed
    # False, because StdRtlPkg.vhd was still a "known source" via B's healthy
    # entry -- a hard false-skip on the one path D-10 must not allow.
    #
    # This test asserts the fix: A's failure is threaded through as an
    # `unresolved_modules` entry and unioned into `always_run` (the same
    # fail-safe treatment D-08 already gives non-literal toplevels), so A's
    # test is unconditionally selected -- never silently dropped.
    def fake_gen_depends_sources(toplevel, workdir, ghdl_flags):
        if toplevel == "surf.brokenwrapper":
            return None  # GHDL analysis failed for toplevel A
        return {"base/general/rtl/StdRtlPkg.vhd"}  # healthy toplevel B

    monkeypatch.setattr(dep_map, "gen_depends_sources", fake_gen_depends_sources)

    toplevels = {
        "tests.axi.test_A": {"surf.brokenwrapper"},
        "tests.base.test_B": {"surf.healthywrapper"},
    }
    always_run: set[str] = set()
    changed = {"base/general/rtl/StdRtlPkg.vhd": "M"}

    built_map, unresolved_modules = dep_map.build_dependency_map(toplevels, "/workdir", [])
    always_run = always_run | unresolved_modules
    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert "tests.axi.test_A" in selected  # must NOT be silently dropped
    assert "tests.base.test_B" in selected  # healthy toplevel still selected normally


# --- D-11: Python test/helper change mapping --------------------------------


def test_map_python_changes_test_file_selects_itself():
    resolved_map = {"tests.axi.axi_lite.test_AxiLiteAsync": {"axi/axi-lite/rtl/AxiLiteAsync.vhd"}}
    always_run: set[str] = set()
    changed = {"tests/axi/axi_lite/test_AxiLiteAsync.py": "M"}

    selected, force_full = dep_map.map_python_changes(changed, resolved_map, always_run)

    assert selected == {"tests.axi.axi_lite.test_AxiLiteAsync"}
    assert force_full is False


def test_map_python_changes_subsystem_helper_selects_whole_subtree():
    resolved_map = {
        "tests.axi.axi_lite.test_AxiLiteAsync": {"axi/axi-lite/rtl/AxiLiteAsync.vhd"},
        "tests.axi.axi4.test_AxiRam": {"axi/axi4/rtl/AxiRam.vhd"},
        "tests.base.fifo.test_FifoAsync": {"base/fifo/rtl/FifoAsync.vhd"},
    }
    always_run: set[str] = set()
    changed = {"tests/axi/utils.py": "M"}

    selected, force_full = dep_map.map_python_changes(changed, resolved_map, always_run)

    assert selected == {"tests.axi.axi_lite.test_AxiLiteAsync", "tests.axi.axi4.test_AxiRam"}
    assert force_full is False


def test_map_python_changes_common_carve_out_selects_nothing():
    # PROJECT.md accepted-risk carve-out: a change confined to tests/common/
    # (including regression_utils.py) must neither force full nor select
    # anything by itself.
    resolved_map = {"tests.axi.axi_lite.test_AxiLiteAsync": {"axi/axi-lite/rtl/AxiLiteAsync.vhd"}}
    always_run = {"tests.dsp.generic.test_FirFilterTap"}
    changed = {"tests/common/regression_utils.py": "M", "tests/common/dep_map.py": "M"}

    selected, force_full = dep_map.map_python_changes(changed, resolved_map, always_run)

    assert selected == set()
    assert force_full is False


# --- D-08: dict-literal AST backtrack ---------------------------------------


def test_discover_toplevels_dict_literal_backtrack_resolves_pgp2b_wrappers():
    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT, scan_dirs=("protocols",))

    module_name = "tests.protocols.pgp.pgp2b.test_Pgp2bCoreWrappers"
    assert module_name not in always_run
    assert resolved[module_name] == {
        "surf.pgp2btxwrapper",
        "surf.pgp2brxwrapper",
        "surf.pgp2btxcellwrapper",
        "surf.pgp2brxcellwrapper",
        "surf.pgp2btxphywrapper",
        "surf.pgp2brxphywrapper",
        "surf.pgp2btxschedwrapper",
    }


def test_discover_toplevels_dict_literal_backtrack_resolves_srpv3axilite():
    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT, scan_dirs=("protocols",))

    module_name = "tests.protocols.srp.test_SrpV3AxiLite"
    assert module_name not in always_run
    assert resolved[module_name] == {"surf.srpv3axilitewrapper", "surf.srpv3axilitefullwrapper"}


def test_discover_toplevels_fstring_toplevel_stays_always_run():
    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT, scan_dirs=("dsp",))

    # Genuinely dynamic f-string toplevels (test_FirFilterTap.py,
    # test_FirFilterMultiChannel.py) are not resolvable by any static
    # backtrack and must remain always-run (D-08).
    assert "tests.dsp.generic.test_FirFilterTap" in always_run
    assert "tests.dsp.generic.test_FirFilterMultiChannel" in always_run
    assert "tests.dsp.generic.test_FirFilterTap" not in resolved
    assert "tests.dsp.generic.test_FirFilterMultiChannel" not in resolved


# --- Pitfall 4: every toplevel= call site is resolved-or-always-run, never a
# silent third state -----------------------------------------------------


def _toplevel_call_sites(test_file):
    tree = ast.parse(test_file.read_text(encoding="utf-8"), filename=str(test_file))
    sites = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and dep_map._has_toplevel_kwarg(node):
            sites.append(node)
    return sites


def test_every_toplevel_call_site_is_resolved_or_always_run():
    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT)

    unaccounted = []
    for scan_dir in dep_map.DEFAULT_SCAN_DIRS:
        for test_file in sorted((TESTS_ROOT / scan_dir).rglob("test_*.py")):
            module_name = dep_map.cocotb_module_name_from_test_file(test_file)
            has_call_site = bool(_toplevel_call_sites(test_file))
            if not has_call_site:
                continue  # no toplevel= call site in this file at all
            if module_name not in resolved and module_name not in always_run:
                unaccounted.append(module_name)

    assert unaccounted == [], (
        f"toplevel= call site(s) not classified as resolved-or-always-run: {unaccounted}"
    )


# --- parse_cf_units / is_wrapper_path / build_wrapper_index ----------------


def test_parse_cf_units_extracts_entity_and_package_units(tmp_path):
    cf_file = tmp_path / "surf-obj08.cf"
    cf_file.write_text(
        "v 4\n"
        f'file / "{REPO_ROOT}/base/general/rtl/StdRtlPkg.vhd" "sha1" "ts":\n'
        "  package stdrtlpkg at 17( 979) + 0 on 4;\n"
        "  package body stdrtlpkg at 105( 4525) + 0 on 4;\n",
        encoding="utf-8",
    )

    result = dep_map.parse_cf_units(cf_file)

    assert result == {"base/general/rtl/StdRtlPkg.vhd": {"stdrtlpkg"}}


def test_parse_cf_units_architecture_line_names_entity(tmp_path):
    cf_file = tmp_path / "surf-obj08.cf"
    cf_file.write_text(
        "v 4\n"
        f'file / "{REPO_ROOT}/axi/bridge/rtl/AxiLiteToDrp.vhd" "sha1" "ts":\n'
        "  entity axilitetodrp at 15( 869) + 0 on 4;\n"
        "  architecture rtl of axilitetodrp at 57( 2455) + 0 on 4;\n",
        encoding="utf-8",
    )

    result = dep_map.parse_cf_units(cf_file)

    # "architecture rtl of axilitetodrp" contributes "axilitetodrp" (the
    # entity name after "of"), not "rtl" (the architecture's own name).
    assert result == {"axi/bridge/rtl/AxiLiteToDrp.vhd": {"axilitetodrp"}}


def test_is_wrapper_path_matches_segment_rejects_near_miss():
    assert dep_map.is_wrapper_path("base/sync/wrappers/SyncTrigRateVectorFlatWrapper.vhd") is True
    assert dep_map.is_wrapper_path("protocols/pgp/pgp2b/wrappers/Foo.vhd") is True
    assert dep_map.is_wrapper_path("base/sync/rtl/Synchronizer.vhd") is False
    assert dep_map.is_wrapper_path("base/sync/wrappersXYZ/Foo.vhd") is False


def test_build_wrapper_index_joins_by_unit_name():
    cf_units = {"base/sync/wrappers/W.vhd": {"synctrigratevectorflatwrapper"}}
    toplevels = {"tests.base.sync.test_X": {"surf.synctrigratevectorflatwrapper"}}

    result = dep_map.build_wrapper_index(cf_units, toplevels)

    assert result == {"base/sync/wrappers/W.vhd": {"tests.base.sync.test_X"}}


def test_build_wrapper_index_unattributable_wrapper_absent():
    cf_units = {"base/sync/wrappers/W.vhd": {"somewrapper"}}
    toplevels = {"tests.base.sync.test_X": {"surf.unrelatedwrapper"}}

    result = dep_map.build_wrapper_index(cf_units, toplevels)

    assert result == {}


def test_parse_wrapper_entity_units_finds_real_sync_trig_wrapper():
    # Direct-scan fallback (Pitfall 1): .cf never contains wrapper files, so
    # this is the actual source of a wrapper file's declared entity name.
    wrapper_units = dep_map.parse_wrapper_entity_units(REPO_ROOT)

    assert wrapper_units["base/sync/wrappers/SyncTrigRateVectorFlatWrapper.vhd"] == {
        "synctrigratevectorflatwrapper"
    }


def test_wrapper_change_selects_owner_live_repo():
    # The full live-repo join: parse_wrapper_entity_units gives the
    # wrapper's own declared entity name (never available from .cf), joined
    # against the real discover_toplevels() map, then routed through
    # select_tests -- proving the real SyncTrigRateVectorFlatWrapper.vhd ->
    # test_SyncTrigRateVector pairing end to end without requiring a built
    # .cf in the unit-test environment.
    resolved, _ = dep_map.discover_toplevels(REPO_ROOT, scan_dirs=("base",))
    wrapper_units = dep_map.parse_wrapper_entity_units(REPO_ROOT)
    wrapper_index = dep_map.build_wrapper_index(wrapper_units, resolved)

    changed = {"base/sync/wrappers/SyncTrigRateVectorFlatWrapper.vhd": "M"}
    selected, force_full = dep_map.select_tests({}, set(), changed, wrapper_index)

    assert selected == {"tests.base.sync.test_SyncTrigRateVector"}
    assert force_full is False


def test_wrapper_never_in_production_dependency_set():
    # Invariant: no dependency set in a built dep_map should ever
    # contain a path with a "wrappers" path segment -- GHDL closures are
    # kept intact, never stripped, but a wrapper genuinely showing up
    # as another test's *production* dependency would be a silent fan-out
    # bug this invariant catches. Synthetic fixture, no GHDL build needed.
    built_map = {
        "tests.base.fifo.test_FifoAsync": {"base/fifo/rtl/FifoAsync.vhd", "base/general/rtl/StdRtlPkg.vhd"},
        "tests.base.sync.test_SyncTrigRateVector": {"base/sync/rtl/Synchronizer.vhd"},
    }

    for sources in built_map.values():
        for source in sources:
            assert not dep_map.is_wrapper_path(source)


# --- FAN_OUT_THRESHOLD / is_base_package_hub / fan-out force-full ----------


def test_is_base_package_hub_threshold_boundary():
    # 12-module universe: a source in 1 of 12 (~8.33%) stays just below the
    # 9% threshold; a source in 2 of 12 (~16.67%) sits comfortably above it.
    # Build the dep_map fixtures directly so the boundary is explicit rather
    # than relied on for a single reused fixture.
    below_map = {f"tests.mod{i}": {"shared.vhd"} if i == 0 else {"other.vhd"} for i in range(12)}
    at_or_above_map = {f"tests.mod{i}": {"shared.vhd"} if i < 2 else {"other.vhd"} for i in range(12)}

    assert dep_map.is_base_package_hub("shared.vhd", below_map, universe_size=12) is False
    assert dep_map.is_base_package_hub("shared.vhd", at_or_above_map, universe_size=12) is True


def test_is_base_package_hub_zero_universe_size_is_false():
    # universe_size == 0 must return False, not raise ZeroDivisionError.
    assert dep_map.is_base_package_hub("shared.vhd", {}, universe_size=0) is False


def test_select_tests_force_full_on_base_package_fanout():
    # A source present in 2 of ~12 discovered modules exceeds the 9%
    # fan-out threshold and must force a full run even though its own
    # directly-intersecting test is also selected.
    built_map = {
        "tests.base.general.test_StdRtlPkg": {"base/general/rtl/StdRtlPkg.vhd"},
        "tests.base.general.test_Other": {"base/general/rtl/StdRtlPkg.vhd", "base/other/rtl/Other.vhd"},
    }
    always_run = {f"tests.always_run.test_{i}" for i in range(10)}
    changed = {"base/general/rtl/StdRtlPkg.vhd": "M"}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert force_full is True
    assert {"tests.base.general.test_StdRtlPkg", "tests.base.general.test_Other"} <= selected


def test_select_tests_no_force_full_below_fanout_threshold():
    # A source present in only 1 of a large universe stays below the 9%
    # fan-out threshold: force_full stays False and the directly-
    # intersecting test is still selected precisely.
    built_map = {
        "tests.base.crc.test_CrcPkg": {"base/crc/rtl/CrcPkg.vhd"},
    }
    always_run = {f"tests.always_run.test_{i}" for i in range(20)}
    changed = {"base/crc/rtl/CrcPkg.vhd": "M"}

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

    assert force_full is False
    assert "tests.base.crc.test_CrcPkg" in selected


def test_select_tests_selection_stays_within_universe_live_repo():
    # Live-universe fan-out assertion: using the real discovered universe
    # (no GHDL invocation -- discover_toplevels() is pure static AST
    # parsing), a synthetic dep_map places each of StdRtlPkg.vhd,
    # AxiLitePkg.vhd, and AxiStreamPkg.vhd into >=9% of the real universe's
    # modules. Each, changed alone, must force a full run.
    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT)
    universe = sorted(set(resolved) | always_run)
    # >= 9% of the universe -- pick enough modules to comfortably clear the
    # threshold regardless of exact universe size.
    hub_share = max(1, (len(universe) * 9 + 99) // 100)  # ceil(9% of universe)
    hub_modules = universe[:hub_share]

    for package in (
        "base/general/rtl/StdRtlPkg.vhd",
        "axi/axi-lite/rtl/AxiLitePkg.vhd",
        "axi/axi-stream/rtl/AxiStreamPkg.vhd",
    ):
        built_map = {module_name: {package} for module_name in hub_modules}
        changed = {package: "M"}

        selected, force_full = dep_map.select_tests(built_map, always_run, changed, {})

        assert force_full is True, f"{package} did not force full against the real universe"


# --- Never-false-skip subset invariant --------------------------------------


def test_never_false_skip_subset_invariant():
    # For N seeded, randomized changed-file-set shapes: selected must always
    # be a subset of the full discovered test universe, and always_run must
    # always be a subset of selected — the phase's north star, asserted
    # directly. Each seed mixes production RTL paths (drawn from the
    # synthetic dep_map), a synthetic wrappers/ path (routed through a
    # synthetic wrapper_index), and an out-of-universe path, so the
    # invariant is exercised across every select_tests routing branch, not
    # just the plain production-RTL case. stdlib random only -- no
    # hypothesis (not a project dependency).
    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT)
    discovered_universe = set(resolved.keys()) | always_run

    built_map = {
        module_name: {f"fake/source/for/{module_name}.vhd"} for module_name in resolved
    }
    all_sources = sorted({source for sources in built_map.values() for source in sources})

    wrapper_path = "some/path/wrappers/Rand.vhd"
    wrapper_owner = next(iter(resolved), None)
    wrapper_index = {wrapper_path: {wrapper_owner}} if wrapper_owner is not None else {}
    out_of_universe_path = "totally/unknown/Path.vhd"

    for seed in range(30):
        rng = random.Random(seed)
        changed: dict[str, str] = {}

        sample_size = rng.randint(0, min(3, len(all_sources)))
        for source in rng.sample(all_sources, sample_size):
            changed[source] = rng.choice(["A", "M"])

        if rng.random() < 0.5:
            changed[wrapper_path] = "M"
        if rng.random() < 0.5:
            changed[out_of_universe_path] = "M"

        selected, force_full = dep_map.select_tests(built_map, always_run, changed, wrapper_index)

        assert selected <= discovered_universe, f"seed {seed}: selected escaped the discovered universe"
        assert always_run <= selected, f"seed {seed}: always_run was not a subset of selected"


# --- discover_test_local_sources / import_test_local_sources ----------------


def test_discover_test_local_sources_collects_wrappers_and_ip_integrator(tmp_path):
    # Wrapper and ip_integrator .vhd sources are collected as absolute paths;
    # normal rtl/, non-.vhd files, and copies under build/ are excluded.
    (tmp_path / "protocols/srp/wrappers").mkdir(parents=True)
    (tmp_path / "axi/axi-lite/ip_integrator").mkdir(parents=True)
    (tmp_path / "base/general/rtl").mkdir(parents=True)
    (tmp_path / "build/x/wrappers").mkdir(parents=True)

    wrapper = tmp_path / "protocols/srp/wrappers/SrpV3AxiWrapper.vhd"
    wrapper.write_text("-- wrapper\n", encoding="utf-8")
    ip_integrator = tmp_path / "axi/axi-lite/ip_integrator/AxiDualPortRamIpIntegrator.vhd"
    ip_integrator.write_text("-- ipi\n", encoding="utf-8")
    # Excluded: ordinary rtl, a non-.vhd file, and a wrappers/ copy under build/.
    (tmp_path / "base/general/rtl/StdRtlPkg.vhd").write_text("-- rtl\n", encoding="utf-8")
    (tmp_path / "protocols/srp/wrappers/notes.txt").write_text("x\n", encoding="utf-8")
    (tmp_path / "build/x/wrappers/Copied.vhd").write_text("-- copy\n", encoding="utf-8")

    result = dep_map.discover_test_local_sources(tmp_path)

    assert result == sorted([wrapper.resolve(), ip_integrator.resolve()])


def test_discover_test_local_sources_finds_real_wrapper_and_ip_integrator():
    # Live-repo smoke check (pure filesystem scan, no GHDL): the real
    # wrapper/ip_integrator sources are discovered, all absolute and none under
    # the build/ output tree.
    sources = dep_map.discover_test_local_sources(REPO_ROOT)
    names = {path.name for path in sources}

    assert "SrpV3AxiWrapper.vhd" in names
    assert "AxiDualPortRamIpIntegrator.vhd" in names

    build_root = (REPO_ROOT / "build").resolve()
    for path in sources:
        assert path.is_absolute()
        assert build_root not in path.parents


def test_import_test_local_sources_invokes_ghdl_i_with_absolute_paths(monkeypatch, tmp_path):
    # `ghdl -i` is invoked with --workdir, the resolver flags, --work=surf, and
    # the absolute source paths last -- absolute paths are what yield the
    # REPO_ROOT-resolvable `file / "<abs>"` .cf form (workdir-relative would
    # write `.././...` entries that resolve against the wrong base).
    src_a = tmp_path / "a/wrappers/A.vhd"
    src_b = tmp_path / "b/ip_integrator/B.vhd"
    monkeypatch.setattr(dep_map, "discover_test_local_sources", lambda repo_root: [src_a, src_b])

    captured = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["cwd"] = kwargs.get("cwd")
        return subprocess.CompletedProcess(args=cmd, returncode=0, stderr="")

    monkeypatch.setattr(dep_map.subprocess, "run", fake_run)

    count = dep_map.import_test_local_sources(tmp_path, "/wd", ["--std=08", "-fsynopsys"])

    assert count == 2
    assert captured["cmd"][: len(dep_map.GHDL_CMD) + 1] == [*dep_map.GHDL_CMD, "-i"]
    assert "--workdir=/wd" in captured["cmd"]
    assert "--work=surf" in captured["cmd"]
    assert "--std=08" in captured["cmd"] and "-fsynopsys" in captured["cmd"]
    assert captured["cmd"][-2:] == [str(src_a), str(src_b)]
    assert captured["cwd"] == "/wd"


def test_import_test_local_sources_no_sources_is_noop(monkeypatch, tmp_path):
    # With no wrapper/ip_integrator sources, ghdl is never invoked and the
    # count is zero.
    monkeypatch.setattr(dep_map, "discover_test_local_sources", lambda repo_root: [])

    def fail_run(*args, **kwargs):
        raise AssertionError("ghdl must not run when there are no sources")

    monkeypatch.setattr(dep_map.subprocess, "run", fail_run)

    assert dep_map.import_test_local_sources(tmp_path, "/wd", []) == 0


def test_import_test_local_sources_ghdl_failure_is_nonfatal(monkeypatch, tmp_path):
    # A non-zero `ghdl -i` exit must not raise (check=False): any toplevel that
    # still cannot be found simply stays always-run (fail-safe preserved).
    monkeypatch.setattr(
        dep_map, "discover_test_local_sources", lambda repo_root: [tmp_path / "w/wrappers/W.vhd"]
    )

    def fake_run(cmd, **kwargs):
        return subprocess.CompletedProcess(args=cmd, returncode=1, stderr="ghdl: boom")

    monkeypatch.setattr(dep_map.subprocess, "run", fake_run)

    assert dep_map.import_test_local_sources(tmp_path, "/wd", []) == 1
