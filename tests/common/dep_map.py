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
import os
import re
from pathlib import Path, PurePosixPath
import subprocess
import sys

from tests.common.regression_utils import (
    REPO_ROOT,
    TESTS_ROOT,
    cocotb_module_name_from_test_file,
)


# CI test universe (surf_ci.yml: `pytest ... tests/axi tests/base tests/dsp
# tests/protocols`); tests/ethernet is deliberately excluded.
DEFAULT_SCAN_DIRS = ("axi", "base", "dsp", "protocols")

# Sentinel line printed on stdout (and used as the CLI's fail-open signal)
# whenever the changed-files -> affected-tests resolution is indeterminate.
FORCE_FULL = "FORCE_FULL"

# GHDL binary used for `--gen-depends`. Overridable via the GHDL env var: the
# apt `ghdl-mcode` backend on the CI runner does not implement `--gen-depends`,
# so CI points this at an LLVM-backend GHDL for dependency resolution while the
# cocotb simulations still run on the default `ghdl`. Defaults to `ghdl`.
GHDL_CMD = os.environ.get("GHDL", "ghdl")

# Minimum fraction of the discovered universe (len(set(dep_map) | always_run))
# a source must appear in to be treated as a shared base-package hub. 0.09 is
# the tightest value that still catches all three widely-shared packages a
# selective run must never miss: StdRtlPkg.vhd (41.25%), AxiStreamPkg.vhd
# (11.67%), and AxiLitePkg.vhd (9.17%), measured against a clean
# `make MODULES=$PWD import` build of this tree on 2026-07-01. This is a
# tree-size-dependent value, not a permanent constant -- re-derive it if the
# scanned test universe grows substantially, since a larger denominator could
# push a currently-caught hub back below threshold.
FAN_OUT_THRESHOLD = 0.09


def discover_toplevels(
    repo_root: Path,
    scan_dirs: tuple[str, ...] = DEFAULT_SCAN_DIRS,
) -> tuple[dict[str, set[str]], set[str]]:
    """Walk `tests/<scan_dir>/**/test_*.py` and statically resolve each
    test's `toplevel` design unit(s) from its `toplevel=` call site(s)
    (`run_surf_vhdl_test(...)` and its thin per-family wrappers, e.g.
    `run_pgp_wrapper_test`/`run_line_code_*_test` — any call passing a
    `toplevel=` keyword is in scope, per D-07/D-08).

    Returns `(resolved, always_run)`:
    - `resolved`: {cocotb_module_name: {toplevel_unit, ...}} for tests whose
      `toplevel=` kwarg(s) are literal string constants, or a one-level
      dict-literal backtrack (`parameters["TOPLEVEL"]`) that resolves to one
      or more literal string values (D-08). A module can resolve to more
      than one toplevel when its `toplevel=` call site is itself
      parametrized over several literal design units (e.g. one wrapper test
      module sweeping several `surf.*wrapper` entities) — every one of them
      is included so the module's dependency set is the union of all of
      them, never a silent partial match.
    - `always_run`: cocotb module names whose `toplevel` could not be
      statically resolved to a literal string (fail-safe per D-08) —
      f-strings, cross-module passthrough params, or ambiguous backtracks.
    """
    resolved: dict[str, set[str]] = {}
    always_run: set[str] = set()

    test_files: list[Path] = []
    for scan_dir in scan_dirs:
        scan_path = TESTS_ROOT / scan_dir
        if not scan_path.is_dir():
            # Path.rglob on a nonexistent directory returns an empty
            # iterator rather than raising, which would otherwise silently
            # discover zero tests for a mistyped --scan-dir (or a future
            # DEFAULT_SCAN_DIRS typo) with no always_run/FORCE_FULL trigger
            # to catch it. Raise loudly instead (D-10 indeterminacy).
            raise FileNotFoundError(f"--scan-dir {scan_dir!r} does not exist under {TESTS_ROOT}")
        test_files.extend(sorted(scan_path.rglob("test_*.py")))

    for test_file in test_files:
        module_name = cocotb_module_name_from_test_file(test_file)
        toplevels = _literal_toplevels_from_file(test_file)
        if toplevels:
            resolved[module_name] = toplevels
        else:
            # Zero calls found, or an unresolvable kwarg (f-string,
            # cross-module passthrough, ambiguous dict backtrack) —
            # conservatively always-run rather than guess (D-08).
            always_run.add(module_name)

    return dict(sorted(resolved.items())), always_run


def _literal_toplevels_from_file(test_file: Path) -> set[str]:
    tree = ast.parse(test_file.read_text(encoding="utf-8"), filename=str(test_file))
    toplevels: set[str] = set()
    unresolved = False

    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if not _has_toplevel_kwarg(node):
            continue

        literals = _literal_toplevel_from_call(node, tree)
        if literals is None:
            unresolved = True
            continue
        toplevels.update(literals)

    if unresolved:
        return set()

    return toplevels


def _has_toplevel_kwarg(call: ast.Call) -> bool:
    return any(keyword.arg == "toplevel" for keyword in call.keywords)


def _literal_toplevel_from_call(call: ast.Call, module_tree: ast.Module) -> set[str] | None:
    for keyword in call.keywords:
        if keyword.arg != "toplevel":
            continue
        return _resolve_literal_value(keyword.value, module_tree)
    return None  # no toplevel= kwarg on this call


def _resolve_literal_value(value: ast.expr, module_tree: ast.Module) -> set[str] | None:
    """Resolve a `toplevel=` kwarg's AST value to a set of literal strings,
    or None if it cannot be statically resolved (D-08 always-run fallback).

    Handles the direct literal case and one level of dict-literal backtrack:
    `parameters["TOPLEVEL"]`, where `parameters` is ultimately sourced (via a
    `@pytest.mark.parametrize("parameters", SOME_SWEEP)` decorator and/or a
    plain pass-through helper argument, both common in this repo) from a
    module-level list of `pytest.param({"TOPLEVEL": "...", ...}, ...)`
    entries. Rather than trace the exact name-binding chain (decorator ->
    parameter -> helper argument), collect every dict literal anywhere in
    the module carrying a literal `"TOPLEVEL"` key — this file's dicts are
    the only possible source of a `"TOPLEVEL"` value, so it is equivalent
    in practice and avoids a fragile multi-hop resolver. Anything deeper
    (f-strings, cross-module passthrough, arbitrary expressions) is
    intentionally left unresolved."""
    if isinstance(value, ast.Constant) and isinstance(value.value, str):
        return {value.value}

    if (
        isinstance(value, ast.Subscript)
        and isinstance(value.value, ast.Name)
        and isinstance(value.slice, ast.Constant)
        and value.slice.value == "TOPLEVEL"
    ):
        return _module_toplevel_dict_literals(module_tree)

    return None  # non-literal kwarg (f-string, variable, ...)


def _module_toplevel_dict_literals(module_tree: ast.Module) -> set[str] | None:
    """Collect the literal string values under the `"TOPLEVEL"` key of
    every dict literal in the module (bare `{...}` or `pytest.param({...})`
    entries). Returns None if any such dict's `"TOPLEVEL"` value is not a
    literal string (ambiguous — always-run), or if none are found.

    NOTE: this backtrack is module-scoped, not call-site-scoped — it
    unions every `"TOPLEVEL"`-keyed dict literal found anywhere in the
    module, regardless of which `parameters=`/`toplevel=` call site
    actually consumes it. Safe by over-inclusion today (verified: every
    file with more than one such dict feeds the same call site), but a
    future file with two unrelated `toplevel=` call sites each fed by
    their own distinct `TOPLEVEL`-keyed list would have both dicts unioned
    into one over-broad set for that module — still safe (over-selection,
    not under-selection), just less precise than the docstring above might
    otherwise imply."""
    dict_literals: list[ast.Dict] = []
    for node in ast.walk(module_tree):
        if isinstance(node, ast.Dict) and _has_toplevel_key(node):
            dict_literals.append(node)

    if not dict_literals:
        return None  # no statically-visible "TOPLEVEL" dict literal in this module

    toplevels: set[str] = set()
    for dict_node in dict_literals:
        literal = _toplevel_key_literal(dict_node)
        if literal is None:
            return None  # a candidate dict has a non-literal "TOPLEVEL" value — ambiguous
        toplevels.add(literal)

    return toplevels


def _has_toplevel_key(dict_node: ast.Dict) -> bool:
    return any(isinstance(key, ast.Constant) and key.value == "TOPLEVEL" for key in dict_node.keys)


def _toplevel_key_literal(dict_node: ast.Dict) -> str | None:
    for key, val in zip(dict_node.keys, dict_node.values):
        if isinstance(key, ast.Constant) and key.value == "TOPLEVEL":
            if isinstance(val, ast.Constant) and isinstance(val.value, str):
                return val.value
            return None  # "TOPLEVEL" value isn't a literal string — ambiguous
    return None  # this dict has no "TOPLEVEL" key at all


def gen_depends_sources(toplevel: str, workdir: str, ghdl_flags: list[str]) -> set[str] | None:
    """Return the repo-relative RTL source paths `toplevel` transitively
    depends on, per GHDL's own elaboration-order analysis.

    Some discovered toplevels (e.g. `**/ip_integrator/*.vhd` wrappers) are
    only compiled as a test's `extra_vhdl_sources`, not by
    `make MODULES=$PWD import` — GHDL cannot resolve those from `build/`
    alone, and `ghdl --gen-depends` fails for them. That failure is
    indistinguishable here from any other genuine GHDL analysis error, so
    it is NOT folded into an empty (but valid) dependency set: `None` is
    returned instead, and callers must treat an unresolved toplevel as
    force-full-eligible on its own (D-10), never as "no dependencies"."""
    try:
        result = subprocess.run(
            [GHDL_CMD, "--gen-depends", *ghdl_flags, f"-P{workdir}", "--work=surf", toplevel.split(".")[-1]],
            capture_output=True,
            text=True,
            cwd=workdir,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        # A resolution failure is silent by default (the toplevel simply
        # becomes always-run). Set SURF_DEP_MAP_DEBUG to surface why each
        # toplevel could not be resolved -- the first line of GHDL's stderr
        # is usually enough to tell a genuine unresolvable wrapper apart from
        # an environment problem (missing library, wrong workdir, etc.).
        if os.environ.get("SURF_DEP_MAP_DEBUG"):
            stderr_lines = (exc.stderr or "").strip().splitlines()
            detail = stderr_lines[0] if stderr_lines else f"ghdl exit {exc.returncode}"
            print(f"gen-depends unresolved: {toplevel} -- {detail}", file=sys.stderr)
        return None  # genuine analysis failure -- distinguish from "no deps"

    sources: set[str] = set()
    in_targets_section = False
    for line in result.stdout.splitlines():
        if line.startswith("# Targets to analyze files"):
            in_targets_section = True
            continue
        if line.startswith("# Files dependences"):
            break
        if not in_targets_section or ":" not in line:
            continue

        _, _, path = line.partition(":")
        path = path.strip()
        if not path.endswith((".vhd", ".vhdl")):
            continue

        try:
            repo_relative = Path(path).resolve().relative_to(REPO_ROOT).as_posix()
        except ValueError:
            # Outside the repo (GHDL stdlib under /usr/local/lib/ghdl/...) —
            # never appears in `git diff` output, so it naturally falls out
            # of the changed-files intersection.
            continue
        sources.add(repo_relative)

    return sources


def is_wrapper_path(repo_relative_path: str) -> bool:
    """True when `repo_relative_path` has a `wrappers` path segment at any
    depth (e.g. "base/sync/wrappers/SyncTrigRateVectorFlatWrapper.vhd" or
    "protocols/pgp/pgp2b/wrappers/Foo.vhd"). Segment-exact, so
    "base/sync/wrappersXYZ/Foo.vhd" is correctly rejected."""
    return "wrappers" in PurePosixPath(repo_relative_path).parts


_CF_FILE_LINE = re.compile(r'^file\s+\S+\s+"([^"]+)"')
_CF_UNIT_LINE = re.compile(r'^\s\s(entity|architecture|package)\s+(?:body\s+)?(\S+)')


def parse_cf_units(cf_path: Path) -> dict[str, set[str]]:
    """{repo_relative_source_path: {design_unit_name, ...}} reversed from a
    GHDL `.cf` library index (`file "<path>" ...:` blocks followed by
    2-space-indented `entity`/`architecture ... of ...`/`package`/
    `package body` lines).

    `architecture <arch> of <entity>` lines contribute the entity name
    parsed from the `" of "` substring rather than being skipped: nothing
    in VHDL disallows an architecture being declared in a different file
    from its entity, so relying solely on the `entity`/`package`
    declaration line would miss that case. Every unit name is lowercased,
    matching GHDL's case-insensitive unit names and the lowercase
    `toplevel=` strings `discover_toplevels()` already produces.

    Paths outside REPO_ROOT (e.g. GHDL's own stdlib) are skipped via the
    same try/except relative_to idiom `gen_depends_sources` uses. A
    missing or malformed `.cf` file raises naturally (FileNotFoundError),
    consistent with `discover_toplevels()` raising loudly on a bad scan
    dir rather than silently returning empty."""
    file_to_units: dict[str, set[str]] = {}
    current_file: str | None = None

    for line in cf_path.read_text(encoding="utf-8").splitlines():
        file_match = _CF_FILE_LINE.match(line)
        if file_match:
            try:
                current_file = Path(file_match.group(1)).resolve().relative_to(REPO_ROOT).as_posix()
            except ValueError:
                current_file = None  # outside the repo -- never in a changed-file set
            continue

        if current_file is None:
            continue

        unit_match = _CF_UNIT_LINE.match(line)
        if not unit_match:
            continue

        kind, name = unit_match.groups()
        if kind == "architecture":
            _, _, name = line.partition(" of ")
            name = name.split()[0]
        file_to_units.setdefault(current_file, set()).add(name.lower())

    return dict(sorted(file_to_units.items()))


_WRAPPER_ENTITY_LINE = re.compile(r'^\s*entity\s+(\S+)\s+is\b', re.IGNORECASE)


def parse_wrapper_entity_units(repo_root: Path) -> dict[str, set[str]]:
    """{repo_relative_wrapper_path: {declared_entity_name}} from a direct
    regex scan of every `**/wrappers/*.vhd` file's own `entity <Name> is`
    declaration line.

    No `ruckus.tcl` in this repo ever loads a `wrappers/` directory into
    `make import` (verified: zero `wrappers/` entries in a clean
    `build/surf-obj08.cf`), so `parse_cf_units` alone can never see these
    files -- every wrapper is compiled per-test via `extra_vhdl_sources`
    instead. This is the primary source `build_wrapper_index` needs for
    wrapper unit names; `.cf` is joined only opportunistically for the
    (currently nonexistent, but not structurally impossible) case of a
    wrapper file that also happens to be pulled into a normal build."""
    wrapper_units: dict[str, set[str]] = {}
    for wrapper_file in sorted(repo_root.rglob("wrappers/*.vhd")):
        repo_relative = wrapper_file.resolve().relative_to(repo_root).as_posix()
        for line in wrapper_file.read_text(encoding="utf-8").splitlines():
            match = _WRAPPER_ENTITY_LINE.match(line)
            if match:
                wrapper_units.setdefault(repo_relative, set()).add(match.group(1).lower())
    return dict(sorted(wrapper_units.items()))


def build_wrapper_index(
    cf_units: dict[str, set[str]],
    toplevels: dict[str, set[str]],
) -> dict[str, set[str]]:
    """{wrapper_path: {owning_module_name, ...}} for every source path in
    `cf_units` that has a "wrappers" path segment, joined against
    `toplevels` (`discover_toplevels()`'s {module: {toplevel_unit}} shape)
    by lowercased bare unit name (the "surf." library prefix is stripped
    from each toplevel string before comparing).

    `cf_units` need not come from `.cf` alone -- callers should union
    `parse_cf_units`'s output with `parse_wrapper_entity_units`'s output
    before calling this, since `.cf` never contains wrapper files (see
    `parse_wrapper_entity_units`). This join itself is source-agnostic: it
    only cares that wrapper paths map to the unit name(s) they declare.

    A wrapper file whose unit no test's `toplevel=` names produces no
    entry here -- that is not an error, it is the expected shape for a
    wrapper this join cannot attribute to any owner; `select_tests`
    handles an unattributed wrapper edit as a FORCE_FULL trigger. This
    join never depends on `ghdl --gen-depends` succeeding for the
    wrapper's own toplevel, which is exactly the gap that otherwise leaves
    a wrapper edit unresolvable when its owning test's toplevel can't be
    GHDL-analyzed on its own (e.g. an ip_integrator-only toplevel)."""
    unit_to_modules: dict[str, set[str]] = {}
    for module_name, module_toplevels in toplevels.items():
        for toplevel in module_toplevels:
            bare = toplevel.split(".")[-1]
            unit_to_modules.setdefault(bare, set()).add(module_name)

    wrapper_index: dict[str, set[str]] = {}
    for source_path, units in cf_units.items():
        if not is_wrapper_path(source_path):
            continue
        owners: set[str] = set()
        for unit in units:
            owners |= unit_to_modules.get(unit, set())
        if owners:
            wrapper_index[source_path] = owners

    return dict(sorted(wrapper_index.items()))


def is_base_package_hub(source: str, dep_map: dict[str, set[str]], universe_size: int) -> bool:
    """True when `source` appears in at least `FAN_OUT_THRESHOLD` of the
    discovered universe's dependency sets -- i.e. it is widely-shared enough
    that a selective run must not be trusted to have found every affected
    test, so the caller should force a full run instead.

    `dependent_count` counts every `dep_map` value-set containing `source`,
    not a lookup of `source` as a key -- `dep_map` is keyed by test module
    name, not by source path. Returns False when `universe_size == 0` (no
    discovered universe to compute a fraction against) rather than raising a
    ZeroDivisionError."""
    dependent_count = sum(1 for sources in dep_map.values() if source in sources)
    return universe_size > 0 and (dependent_count / universe_size) >= FAN_OUT_THRESHOLD


# Wrapper (cocotb DUT-flattening) and Vivado IP-integrator shim sources live
# under **/wrappers/ and **/ip_integrator/ and are compiled per-test via
# `extra_vhdl_sources` -- no ruckus.tcl loads them into
# `make MODULES=$PWD import`, so they are absent from the surf work library the
# resolver queries. A test whose `toplevel=` names one of these entities
# therefore fails `ghdl --gen-depends` ("cannot find entity") and falls back to
# always-run (D-08/D-10). Because most surf cocotb tests wrap their DUT (cocotb
# cannot drive VHDL records), that fallback collapses selective mode into a
# near-full run. Importing these sources into the resolver's surf library makes
# their toplevels analyzable, so each such test gets a precise transitive
# dependency set instead.
_TEST_LOCAL_SOURCE_GLOBS = ("wrappers/*.vhd", "ip_integrator/*.vhd")


def discover_test_local_sources(repo_root: Path) -> list[Path]:
    """Absolute, de-duplicated, sorted paths of every wrapper / ip_integrator
    VHDL source in the tree (excluding the build/ output dir). These are exactly
    the design units `make import` omits but tests compile via
    `extra_vhdl_sources`."""
    build_root = (repo_root / "build").resolve()
    sources: set[Path] = set()
    for pattern in _TEST_LOCAL_SOURCE_GLOBS:
        for path in repo_root.rglob(pattern):
            resolved_path = path.resolve()
            if build_root in resolved_path.parents:
                continue  # skip copies under the GHDL output tree (build/SRC_VHDL)
            if resolved_path.is_file():
                sources.add(resolved_path)
    return sorted(sources)


def import_test_local_sources(repo_root: Path, workdir: str, ghdl_flags: list[str]) -> int:
    """`ghdl -i` the wrapper / ip_integrator sources into the surf work library
    at `workdir`, so `gen_depends_sources` can analyze wrapper/ip_integrator
    toplevels instead of failing them open (which makes selective mode near-full
    -- see `discover_test_local_sources`).

    Absolute source paths are passed deliberately: `ghdl -i` records the path as
    given, and only an absolute path yields the `file / "<abs>"` .cf form that
    `parse_cf_units` and the changed-file intersection resolve relative to
    REPO_ROOT. A workdir-relative import would instead write `.././...` entries
    that resolve against the wrong base and silently drop out.

    Returns the number of sources imported. A non-zero `ghdl -i` exit is
    non-fatal (logged under SURF_DEP_MAP_DEBUG): any toplevel that still cannot
    be found simply stays always-run, preserving the never-false-skip
    fail-safe."""
    sources = discover_test_local_sources(repo_root)
    if not sources:
        return 0
    result = subprocess.run(
        [GHDL_CMD, "-i", f"--workdir={workdir}", *ghdl_flags, "--work=surf", *(str(path) for path in sources)],
        capture_output=True,
        text=True,
        cwd=workdir,
        check=False,
    )
    if result.returncode != 0 and os.environ.get("SURF_DEP_MAP_DEBUG"):
        stderr_lines = (result.stderr or "").strip().splitlines()
        detail = stderr_lines[0] if stderr_lines else f"ghdl exit {result.returncode}"
        print(f"import-test-local-sources warning: {detail}", file=sys.stderr)
    return len(sources)


def build_dependency_map(
    toplevels: dict[str, set[str]],
    workdir: str,
    ghdl_flags: list[str],
) -> tuple[dict[str, set[str]], set[str]]:
    """(dep_map, unresolved_modules).

    `dep_map`: {cocotb_module_name: {repo_relative_source, ...}} for every
    module in `toplevels` whose GHDL analysis fully succeeded, sorted for
    reproducibility (DEP-02). A module resolved to multiple toplevels
    (parametrized `toplevel=` call site, D-08) gets the union of every
    toplevel's transitive dependency set — a changed file that only one of
    the parametrized toplevels depends on must still select the module
    (never-false-skip).

    `unresolved_modules`: module names for which `gen_depends_sources`
    could not analyze at least one of their toplevels (e.g. an
    `ip_integrator` wrapper only compiled via `extra_vhdl_sources`, or a
    genuine GHDL analysis failure). These modules are deliberately excluded
    from `dep_map` rather than given an empty-but-valid dependency set —
    an empty set would be indistinguishable from "no dependencies" and
    would let the module silently drop out of `select_tests` (D-10)."""
    dep_map: dict[str, set[str]] = {}
    unresolved_modules: set[str] = set()
    for module_name, module_toplevels in toplevels.items():
        sources: set[str] = set()
        unresolved = False
        for toplevel in module_toplevels:
            result = gen_depends_sources(toplevel, workdir, ghdl_flags)
            if result is None:
                unresolved = True
                continue
            sources |= result
        if unresolved:
            unresolved_modules.add(module_name)
            continue
        dep_map[module_name] = sources
    return dict(sorted(dep_map.items())), unresolved_modules


def merge_base_with_origin_main() -> str:
    """`git merge-base origin/main HEAD`. Raises subprocess.CalledProcessError
    if it cannot be computed (e.g. `origin/main` missing) — callers must
    treat that as a fail-open trigger (D-10), not a crash."""
    result = subprocess.run(
        ["git", "merge-base", "origin/main", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def changed_files(merge_base: str) -> dict[str, str]:
    """{repo_relative_path: status} where status in {A, M, D}. Renames
    resolve to the new path with status 'M' (content-preserving, D-14);
    true deletions get status 'D' (a force-full trigger upstream, D-10)."""
    result = subprocess.run(
        ["git", "diff", "--name-status", "-M", merge_base, "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    )

    changes: dict[str, str] = {}
    for line in result.stdout.splitlines():
        if not line:
            continue
        parts = line.split("\t")
        status, paths = parts[0], parts[1:]
        if status.startswith("R"):
            _, new_path = paths
            changes[new_path] = "M"
        elif status.startswith("D"):
            changes[paths[0]] = "D"
        else:
            changes[paths[0]] = status[0]
    return changes


_VHDL_SUFFIXES = (".vhd", ".vhdl")


def select_tests(
    dep_map: dict[str, set[str]],
    always_run: set[str],
    changed: dict[str, str],
    wrapper_index: dict[str, set[str]],
) -> tuple[set[str], bool]:
    """(selected_module_names, force_full).

    force_full becomes True (D-10 broad fail-open) when either:
    - a changed `.vhd`/`.vhdl` file is a true deletion (status 'D', not a
      rename — renames already resolve to the new path as 'M' upstream in
      `changed_files`); a deleted unit's former dependents can't be
      resolved from the post-change graph (D-14), or
    - a changed `wrappers/*.vhd` file has no entry in `wrapper_index` —
      the join could not attribute it to any owning test, so its effect
      is indeterminate, or
    - a changed `.vhd`/`.vhdl` file (any other status) intersects NO test's
      dependency set at all — an Added/renamed-away/unwired unit that the
      current graph can't attribute to any known test, which is exactly
      the kind of indeterminacy that requires failing open, or
    - a changed production `.vhd`/`.vhdl` file's fan-out fraction across the
      discovered universe is `>= FAN_OUT_THRESHOLD` — it is widely-shared
      enough (e.g. StdRtlPkg.vhd, AxiLitePkg.vhd, AxiStreamPkg.vhd) that a
      selective run can't be trusted to have found every affected test.

    A changed `wrappers/*.vhd` file with a `wrapper_index` entry selects
    exactly its attributed owner module(s) and is never subjected to the
    generic dependency-set check above — a wrapper edit for an
    always_run/unresolved owner must not trip a needless full run.

    Python test/helper changes are resolved by `map_python_changes` (D-11)
    and unioned into the selection; they participate in this function only
    via the `changed` file/status map's RTL entries."""
    changed_paths = set(changed.keys())
    all_known_sources: set[str] = set()
    for sources in dep_map.values():
        all_known_sources |= sources
    universe_size = len(set(dep_map) | always_run)

    force_full = False
    selected: set[str] = set()

    for module_name, sources in dep_map.items():
        if sources & changed_paths:
            selected.add(module_name)

    for path, status in changed.items():
        if not path.endswith(_VHDL_SUFFIXES):
            continue
        if status == "D":
            # True deletion: former dependents are unresolvable from the
            # post-change graph (D-14) — fail open rather than guess.
            force_full = True
            continue
        if is_wrapper_path(path):
            owners = wrapper_index.get(path)
            if owners:
                selected |= owners
            else:
                # Unattributable wrapper edit — indeterminate, fail open.
                force_full = True
            continue  # never fall through to the generic check below
        if path not in all_known_sources:
            # Added/renamed-away/unwired unit that no known test's
            # dependency set attributes to anything — indeterminate (D-10).
            force_full = True
        if is_base_package_hub(path, dep_map, universe_size):
            # Widely-shared base package: a selective run can't be trusted
            # to have found every affected test, so force a full run.
            force_full = True

    selected |= always_run
    return selected, force_full


def map_python_changes(
    changed: dict[str, str],
    resolved_map: dict[str, set[str]],
    always_run: set[str],
) -> tuple[set[str], bool]:
    """D-11 Python test/helper change mapping. Returns
    (selected_module_names, force_full) contributed by changed `tests/**`
    Python files only (RTL `.vhd`/`.vhdl` changes are handled by
    `select_tests`, not here):

    - a changed `tests/<sub>/.../test_X.py` selects the cocotb module for
      that exact file (if it's a known test module, resolved or
      always-run; otherwise it's a new/unknown test file and is ignored
      here — it has no prior dependency-map entry to select);
    - a changed `tests/<sub>/*_utils.py` (any non-`test_*.py` helper
      directly under a scanned subsystem subtree) selects every discovered
      test module under that same `tests/<sub>` subtree — a safe
      directory-prefix over-approximation (D-11), not import-graph
      resolution;
    - a change confined to `tests/common/` (including
      `regression_utils.py`) selects nothing and never forces full — the
      PROJECT.md accepted-risk carve-out.

    This function never sets force_full=True on its own; Python-side
    changes are an over-approximation by design and cannot be
    "unresolvable" the way an RTL file can."""
    all_modules = set(resolved_map.keys()) | always_run
    selected: set[str] = set()

    for path in changed.keys():
        if not path.startswith("tests/"):
            continue
        if path.startswith("tests/common/"):
            continue  # accepted-risk carve-out: never selects, never forces full

        parts = path.split("/")
        if len(parts) < 2:
            continue
        subsystem = parts[1]
        filename = parts[-1]

        if filename.startswith("test_") and filename.endswith(".py"):
            module_name = path[: -len(".py")].replace("/", ".")
            if module_name in all_modules:
                selected.add(module_name)
        elif filename.endswith(".py"):
            # Subsystem helper (e.g. tests/axi/utils.py, tests/base/sync/
            # sync_test_utils.py) — over-approximate to every discovered
            # module under this subsystem's subtree (D-11).
            prefix = f"tests.{subsystem}."
            selected |= {module for module in all_modules if module.startswith(prefix)}

    return selected, False
