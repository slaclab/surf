#!/usr/bin/env python3
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

import argparse
from pathlib import Path
import subprocess
import sys

from tests.common import dep_map
from tests.common.regression_utils import BASE_GHDL_COMPILE_ARGS, REPO_ROOT


def _parse_changed_files_override(raw: str) -> dict[str, str]:
    # Unit tests / Phase 2 pass an explicit changed-file list rather than
    # having the CLI compute the diff itself (D-13). Entries default to
    # status 'M'; an optional ':A'/':D' suffix expresses Added/Deleted so
    # callers can exercise the D-14 deletion-forces-full path without a
    # real git history (e.g. `--changed-files-override foo.vhd:D`).
    changed: dict[str, str] = {}
    for entry in raw.split(","):
        entry = entry.strip()
        if not entry:
            continue
        path, _, status = entry.partition(":")
        changed[path] = status if status in ("A", "M", "D") else "M"
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Print the pytest targets affected by the current changed-file set, "
        "or a FORCE_FULL sentinel when that cannot be determined."
    )
    parser.add_argument(
        "--workdir",
        default=str(REPO_ROOT / "build"),
        help="GHDL working directory produced by `make MODULES=$PWD import` (default: build/).",
    )
    parser.add_argument(
        "--scan-dir",
        action="append",
        dest="scan_dirs",
        help="Restrict test discovery to one or more tests/<dir> subtrees. "
        "Defaults to the CI test universe (axi, base, dsp, protocols).",
    )
    parser.add_argument(
        "--changed-files-override",
        help="Comma-separated list of repo-relative changed files, used instead of "
        "computing the diff against origin/main (for unit tests / Phase 2).",
    )
    args = parser.parse_args()

    scan_dirs = tuple(args.scan_dirs) if args.scan_dirs else dep_map.DEFAULT_SCAN_DIRS

    if args.changed_files_override is not None:
        changed = _parse_changed_files_override(args.changed_files_override)
    else:
        try:
            merge_base = dep_map.merge_base_with_origin_main()
            changed = dep_map.changed_files(merge_base)
        except (subprocess.CalledProcessError, FileNotFoundError):
            print(dep_map.FORCE_FULL)
            print("rationale: could not compute merge-base with origin/main", file=sys.stderr)
            return 1

    resolved, always_run = dep_map.discover_toplevels(REPO_ROOT, scan_dirs)
    # Import the wrapper / ip_integrator sources `make import` omits so their
    # toplevels are analyzable by `ghdl --gen-depends`. Without this, the
    # majority of cocotb tests -- which wrap their DUT because cocotb cannot
    # drive VHDL records -- fail resolution and fall back to always-run,
    # degrading selective mode into a near-full run.
    dep_map.import_test_local_sources(REPO_ROOT, args.workdir, BASE_GHDL_COMPILE_ARGS)
    built_map, unresolved_modules = dep_map.build_dependency_map(resolved, args.workdir, BASE_GHDL_COMPILE_ARGS)
    # A module whose GHDL analysis failed (ip_integrator wrapper only
    # compiled via extra_vhdl_sources, or a genuine analysis error) gets
    # the same fail-safe treatment as a non-literal toplevel (D-08): it is
    # unconditionally selected rather than silently dropped (D-10).
    always_run = always_run | unresolved_modules

    try:
        cf_units = dep_map.parse_cf_units(Path(args.workdir) / "surf-obj08.cf")
    except FileNotFoundError:
        print(dep_map.FORCE_FULL)
        print("rationale: could not find the GHDL .cf library index needed for wrapper attribution", file=sys.stderr)
        return 1
    # wrappers/ files are never loaded into `.cf` by any ruckus.tcl (they
    # are compiled per-test via extra_vhdl_sources instead), so wrapper
    # unit names come from a direct scan of the wrapper files themselves;
    # `.cf` is unioned in only opportunistically.
    wrapper_units = dep_map.parse_wrapper_entity_units(REPO_ROOT)
    for path, units in wrapper_units.items():
        cf_units.setdefault(path, set()).update(units)
    wrapper_index = dep_map.build_wrapper_index(cf_units, resolved)

    selected, force_full = dep_map.select_tests(built_map, always_run, changed, wrapper_index)
    python_selected, _ = dep_map.map_python_changes(changed, resolved, always_run)
    selected |= python_selected

    if force_full:
        print(dep_map.FORCE_FULL)
        print(
            "rationale: full run because a changed RTL file could not be resolved "
            "(deleted, renamed-away, or unresolvable design unit)",
            file=sys.stderr,
        )
        return 1

    # An entry in `selected` that names neither a resolved nor an always-run
    # module is impossible by construction (select_tests only ever adds
    # dep_map keys, wrapper_index owners, always_run, or map_python_changes
    # output, all of which are subsets of resolved | always_run) -- its
    # presence would mean a resolver logic bug, not a genuine indeterminacy,
    # so it is dropped here rather than escalated to FORCE_FULL.
    selected &= set(resolved) | always_run

    for module_name in sorted(selected):
        print(module_name)

    print(
        f"rationale: {len(selected)} test(s) selected from {len(changed)} changed file(s); "
        f"{len(built_map)} toplevel(s) resolved, {len(unresolved_modules)} unresolved",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
