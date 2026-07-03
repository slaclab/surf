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
import shlex
import subprocess
import sys

from tests.common.regression_utils import REPO_ROOT


# Scanned cocotb-test universe (surf_ci.yml simulates `tests/axi tests/base
# tests/dsp tests/protocols`); tests/ethernet is deliberately excluded.
# tests/common (the resolver's own unit tests) is also run by CI but is not a
# scan dir -- it holds no cocotb toplevels for this map to resolve.
DEFAULT_SCAN_DIRS = ("axi", "base", "dsp", "protocols")

# Sentinel line printed on stdout (and used as the CLI's fail-open signal)
# whenever the changed-files -> affected-tests resolution is indeterminate.
FORCE_FULL = "FORCE_FULL"

# GHDL binary used for `--gen-depends`. Overridable via the GHDL_CMD env var --
# the repo-wide convention (Makefile exports `GHDL_CMD`, regression_utils.py
# reads it), so `make import` and the resolver never disagree on which `ghdl`
# to use. The apt `ghdl-mcode` backend on the CI runner does not implement
# `--gen-depends`, so CI points GHDL_CMD at an LLVM-backend GHDL for dependency
# resolution while the cocotb simulations still run on the default `ghdl`.
# shlex.split (matching regression_utils.py) tolerates a command with args.
# Defaults to `ghdl`.
GHDL_CMD = shlex.split(os.environ.get("GHDL_CMD", "ghdl"))

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
    `toplevel=` keyword is in scope).

    Returns `(resolved, always_run)`:
    - `resolved`: {cocotb_module_name: {toplevel_unit, ...}} for tests whose
      `toplevel=` kwarg(s) are literal string constants, or a one-level
      dict-literal backtrack (`parameters["TOPLEVEL"]`) that resolves to one
      or more literal string values. A module can resolve to more
      than one toplevel when its `toplevel=` call site is itself
      parametrized over several literal design units (e.g. one wrapper test
      module sweeping several `surf.*wrapper` entities) — every one of them
      is included so the module's dependency set is the union of all of
      them, never a silent partial match.
    - `always_run`: cocotb module names whose `toplevel` could not be
      statically resolved to a literal string (fail-safe) —
      f-strings, cross-module passthrough params, or ambiguous backtracks.
    """
    resolved: dict[str, set[str]] = {}
    always_run: set[str] = set()

    tests_root = repo_root / "tests"
    test_files: list[Path] = []
    for scan_dir in scan_dirs:
        scan_path = tests_root / scan_dir
        if not scan_path.is_dir():
            # Path.rglob on a nonexistent directory returns an empty
            # iterator rather than raising, which would otherwise silently
            # discover zero tests for a mistyped --scan-dir (or a future
            # DEFAULT_SCAN_DIRS typo) with no always_run/FORCE_FULL trigger
            # to catch it. Raise loudly instead (indeterminacy).
            raise FileNotFoundError(f"--scan-dir {scan_dir!r} does not exist under {tests_root}")
        test_files.extend(sorted(scan_path.rglob("test_*.py")))

    for test_file in test_files:
        # Derive the cocotb module import path relative to the passed-in
        # `repo_root`, not the module-global REPO_ROOT: this keeps discovery
        # fully scoped by the function's parameters (matching sibling helpers
        # like `parse_wrapper_entity_units`/`discover_test_local_sources`) so a
        # caller passing a different tree (e.g. a temp checkout in a unit test)
        # resolves cleanly instead of raising in `relative_to`. In production
        # `repo_root is REPO_ROOT`, so this is identical to
        # `cocotb_module_name_from_test_file()`.
        module_name = ".".join(test_file.resolve().relative_to(repo_root).with_suffix("").parts)
        toplevels = _literal_toplevels_from_file(test_file)
        if toplevels:
            resolved[module_name] = toplevels
        else:
            # Zero calls found, or an unresolvable kwarg (f-string,
            # cross-module passthrough, ambiguous dict backtrack) —
            # conservatively always-run rather than guess.
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
    or None if it cannot be statically resolved (always-run fallback).

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
    force-full-eligible on its own, never as "no dependencies".

    A misconfigured GHDL_CMD (or `ghdl` missing from PATH) makes
    subprocess.run raise FileNotFoundError; that is caught and folded into the
    same `None` fail-open path rather than crashing the resolver."""
    try:
        result = subprocess.run(
            [*GHDL_CMD, "--gen-depends", *ghdl_flags, f"-P{workdir}", "--work=surf", toplevel.split(".")[-1]],
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
    except FileNotFoundError:
        # GHDL_CMD is misconfigured or `ghdl` is not on PATH. Fail open the
        # same way as an analysis failure -- the toplevel stays unresolved
        # (always-run), never silently "no deps" -- instead of letting the
        # missing-binary error escape and crash the resolver.
        if os.environ.get("SURF_DEP_MAP_DEBUG"):
            print(f"gen-depends unresolved: {toplevel} -- {GHDL_CMD[0]!r} not found", file=sys.stderr)
        return None

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


# A GHDL `.cf` file line is `file <dir> "<path>" "<sha1>" "<ts>":`. The
# <dir> field is mandatory in every GHDL library-file version (`v N`): it is
# `/` for an absolute-path import and `.` for a cwd-relative one -- GHDL never
# omits it. Matching it with `\S+` (rather than making it optional) is
# deliberate: if a future GHDL ever changed the format, the line stops
# matching, `current_file` stays None, no units are attributed, and wrapper
# resolution falls back to a full run -- the module's fail-safe direction. A
# tolerant regex could instead partial-match a malformed line and mis-attribute
# units, silently under-selecting tests.
_CF_FILE_LINE = re.compile(r'^file\s+\S+\s+"([^"]+)"')
_CF_UNIT_LINE = re.compile(r'^\s\s(entity|architecture|package)\s+(?:body\s+)?(\S+)')


def parse_cf_units(cf_path: Path) -> dict[str, set[str]]:
    """{repo_relative_source_path: {design_unit_name, ...}} reversed from a
    GHDL `.cf` library index (`file <dir> "<path>" "<sha1>" "<ts>":` blocks
    followed by 2-space-indented `entity`/`architecture ... of ...`/`package`/
    `package body` lines). The `<dir>` field (`/` for absolute imports, `.`
    for relative) is a mandatory part of the format, so it is matched, not
    treated as optional -- see the `_CF_FILE_LINE` comment above.

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


def parse_wrapper_entity_units(
    repo_root: Path,
    scan_dirs: tuple[str, ...] = DEFAULT_SCAN_DIRS,
) -> dict[str, set[str]]:
    """{repo_relative_wrapper_path: {declared_entity_name}} from a direct
    regex scan of every `<scan_dir>/**/wrappers/*.vhd` file's own
    `entity <Name> is` declaration line.

    No `ruckus.tcl` in this repo ever loads a `wrappers/` directory into
    `make import` (verified: zero `wrappers/` entries in a clean
    `build/surf-obj08.cf`), so a `.cf` from `make import` alone would not
    carry these files -- every wrapper is compiled per-test via
    `extra_vhdl_sources` instead. This direct scan is therefore the primary
    source `build_wrapper_index` needs for wrapper unit names. The resolver
    does inject wrapper sources into the `.cf` itself (the CLI runs
    `import_test_local_sources` -> `ghdl -i` on these same files before
    reading the `.cf`), so `parse_cf_units` can in fact surface wrappers;
    they are unioned in on top of this scan, which is harmless -- both
    describe the same file -> unit mapping.

    The scan is scoped to `scan_dirs` (mirroring
    `discover_test_local_sources`): a wrapper outside the scanned universe
    (e.g. under `ethernet/**/wrappers/`) can never join to a discovered
    module owner in `build_wrapper_index` -- `discover_toplevels()` is
    itself scoped to `scan_dirs` -- so scanning it is pure IO overhead."""
    wrapper_units: dict[str, set[str]] = {}
    for scan_dir in scan_dirs:
        for wrapper_file in sorted((repo_root / scan_dir).rglob("wrappers/*.vhd")):
            repo_relative = wrapper_file.resolve().relative_to(repo_root).as_posix()
            with wrapper_file.open(encoding="utf-8") as handle:
                for line in handle:
                    match = _WRAPPER_ENTITY_LINE.match(line)
                    if match:
                        wrapper_units.setdefault(repo_relative, set()).add(match.group(1).lower())
                        # A wrapper file declares exactly one entity (the DUT it
                        # wraps for cocotb), so stop at the first declaration.
                        # Iterating the handle reads lazily, so the break also
                        # avoids reading the rest of the file (unlike
                        # read_text(), which loads it all up front).
                        break
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
    before calling this. A `.cf` produced by `make import` alone carries no
    wrapper files, so the direct wrapper scan is the reliable source; note
    the resolver can still add wrapper/ip_integrator sources to the `.cf` by
    running `ghdl -i` in the same workdir (see `parse_wrapper_entity_units`),
    so `.cf` is not guaranteed wrapper-free. This join itself is
    source-agnostic: it only cares that wrapper paths map to the unit
    name(s) they declare.

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
# always-run. Because most surf cocotb tests wrap their DUT (cocotb
# cannot drive VHDL records), that fallback collapses selective mode into a
# near-full run. Importing these sources into the resolver's surf library makes
# their toplevels analyzable, so each such test gets a precise transitive
# dependency set instead.
_TEST_LOCAL_SOURCE_GLOBS = ("wrappers/*.vhd", "ip_integrator/*.vhd")


def discover_test_local_sources(
    repo_root: Path,
    scan_dirs: tuple[str, ...] = DEFAULT_SCAN_DIRS,
) -> list[Path]:
    """Absolute, de-duplicated, sorted paths of every wrapper / ip_integrator
    VHDL source under the active scan-dir subtrees (excluding the build/ output
    dir). These are exactly the design units `make import` omits but tests
    compile via `extra_vhdl_sources`.

    The search is scoped to `scan_dirs` -- the top-level RTL source dirs share
    their names with the cocotb scan dirs (`axi`, `base`, `dsp`, `protocols`),
    so restricting to them keeps a selective run from importing wrapper sources
    for subsystems outside the scanned universe (e.g. the ~40 sources under
    `ethernet/**/wrappers/`, which `DEFAULT_SCAN_DIRS` excludes) -- pure
    resolver overhead, since no scanned test resolves to those toplevels. A
    scan dir with no source subtree of that name simply contributes nothing."""
    build_root = (repo_root / "build").resolve()
    sources: set[Path] = set()
    for scan_dir in scan_dirs:
        scan_root = repo_root / scan_dir
        for pattern in _TEST_LOCAL_SOURCE_GLOBS:
            for path in scan_root.rglob(pattern):
                resolved_path = path.resolve()
                if build_root in resolved_path.parents:
                    continue  # skip copies under the GHDL output tree (build/SRC_VHDL)
                if resolved_path.is_file():
                    sources.add(resolved_path)
    return sorted(sources)


def import_test_local_sources(
    repo_root: Path,
    workdir: str,
    ghdl_flags: list[str],
    scan_dirs: tuple[str, ...] = DEFAULT_SCAN_DIRS,
) -> int:
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
    fail-safe. A misconfigured GHDL_CMD (or `ghdl` missing from PATH) raises
    FileNotFoundError from subprocess.run; that is caught and treated as the
    same non-fatal warning, returning 0 imported sources -- every wrapper
    toplevel then simply stays always-run rather than crashing the CLI."""
    sources = discover_test_local_sources(repo_root, scan_dirs)
    if not sources:
        return 0
    try:
        result = subprocess.run(
            [*GHDL_CMD, "-i", f"--workdir={workdir}", *ghdl_flags, "--work=surf", *(str(path) for path in sources)],
            capture_output=True,
            text=True,
            cwd=workdir,
            check=False,
        )
    except FileNotFoundError:
        # GHDL_CMD is misconfigured or `ghdl` is not on PATH. Nothing is
        # imported, so every wrapper/ip_integrator toplevel stays unresolved
        # (always-run) downstream -- the fail-safe direction -- instead of the
        # missing-binary error escaping and crashing the CLI.
        if os.environ.get("SURF_DEP_MAP_DEBUG"):
            print(f"import-test-local-sources warning: {GHDL_CMD[0]!r} not found", file=sys.stderr)
        return 0
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
    reproducibility. A module resolved to multiple toplevels
    (parametrized `toplevel=` call site) gets the union of every
    toplevel's transitive dependency set — a changed file that only one of
    the parametrized toplevels depends on must still select the module
    (never-false-skip).

    `unresolved_modules`: module names for which `gen_depends_sources`
    could not analyze at least one of their toplevels (e.g. an
    `ip_integrator` wrapper only compiled via `extra_vhdl_sources`, or a
    genuine GHDL analysis failure). These modules are deliberately excluded
    from `dep_map` rather than given an empty-but-valid dependency set —
    an empty set would be indistinguishable from "no dependencies" and
    would let the module silently drop out of `select_tests`."""
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
    treat that as a fail-open trigger, not a crash."""
    result = subprocess.run(
        ["git", "merge-base", "origin/main", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def changed_files(merge_base: str) -> dict[str, str]:
    """{repo_relative_path: status} where status in {A, M, D}. Renames
    resolve to the new path with status 'M' (content-preserving);
    true deletions get status 'D' (a force-full trigger upstream)."""
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
            # Normalize any other status code (e.g. 'T' typechange) to 'M' so
            # the documented {A, M, D} contract holds. Downstream select_tests
            # only special-cases 'D'; every other status is treated like a
            # modification anyway, so this is contract-tightening, not a
            # behavior change.
            code = status[0]
            changes[paths[0]] = code if code in ("A", "M") else "M"
    return changes


_VHDL_SUFFIXES = (".vhd", ".vhdl")


def select_tests(
    dep_map: dict[str, set[str]],
    always_run: set[str],
    changed: dict[str, str],
    wrapper_index: dict[str, set[str]],
) -> tuple[set[str], bool]:
    """(selected_module_names, force_full).

    force_full becomes True (broad fail-open) when either:
    - a changed `.vhd`/`.vhdl` file is a true deletion (status 'D', not a
      rename — renames already resolve to the new path as 'M' upstream in
      `changed_files`); a deleted unit's former dependents can't be
      resolved from the post-change graph, or
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
    generic dependency-set check above. `wrapper_index` is built from the
    `resolved` toplevels (CLI: `build_wrapper_index(cf_units, resolved)`),
    which still carry the literal `toplevel=` names of modules whose
    `ghdl --gen-depends` later failed (`unresolved_modules`, folded into
    `always_run`). So a wrapper edit for such an *unresolved* owner is
    attributed precisely by the wrapper scan and does not trip a full run,
    even though that owner's toplevel can't be GHDL-analyzed on its own. A
    wrapper whose only owner is a *non-literal-toplevel* always_run test
    (absent from `resolved`, so unattributable) has no `wrapper_index` entry
    and does fall to the unattributable-wrapper FORCE_FULL branch above — the
    precise handling here covers resolved and gen-depends-unresolved owners,
    not non-literal always_run owners.

    Python test/helper changes are resolved by `map_python_changes`
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
            # post-change graph — fail open rather than guess.
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
            # dependency set attributes to anything — indeterminate.
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
    """Python test/helper change mapping. Returns
    (selected_module_names, force_full) contributed by changed `tests/**`
    Python files only (RTL `.vhd`/`.vhdl` changes are handled by
    `select_tests`, not here):

    - a changed `tests/<sub>/.../test_X.py` selects the cocotb module for
      that exact file. `resolved_map`/`always_run` are discovered from the
      current checkout, so a test file added on this branch is already in
      the universe and selects itself; a test file is ignored here only
      when it falls outside the discovered universe (e.g. under a
      non-scanned subtree such as `tests/ethernet/...`), since it has no
      dependency-map entry to select;
    - a changed non-`test_*.py` `.py` helper anywhere under
      `tests/<sub>/...` (at any depth, e.g. `tests/axi/utils.py` or
      `tests/base/sync/sync_test_utils.py`) selects every discovered test
      module under that same top-level `tests/<sub>` subtree — a safe
      directory-prefix over-approximation keyed on `<sub>` alone,
      not import-graph resolution;
    - a change confined to `tests/common/` (including
      `regression_utils.py`) selects nothing and never forces full — the
      accepted-risk carve-out.

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
            # module under this subsystem's subtree.
            prefix = f"tests.{subsystem}."
            selected |= {module for module in all_modules if module.startswith(prefix)}

    return selected, False
