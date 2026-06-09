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
import ast
import json
import logging
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path


# Match Makefile GHDL_BASE_FLAGS exactly — gen-depends must use the same flags
# that were used during `make analysis` to avoid library flag mismatch.
# NOTE: do NOT use the Python test-runner flag; the Makefile uses --ieee=synopsys.
GHDL_BASE_FLAGS = [
    "--std=08",
    "--ieee=synopsys",
    "-frelaxed-rules",
    "-fexplicit",
]

logger = logging.getLogger(__name__)


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


# ---------------------------------------------------------------------------
# GHDL closure primitives
# ---------------------------------------------------------------------------

def gen_depends_closure(
    entity_spec: str,
    workdir: Path,
    work_lib: str,
    extra_lib_paths: list[Path],
    repo_root: Path,
) -> set[str] | None:
    """Return set of repo-relative .vhd paths in the transitive production-RTL
    closure (*/rtl/* files only), or None when ghdl exits non-zero.

    Args:
        entity_spec:     e.g. "surf.boxcarfilter" or "work.ssiprbswrapper"
        workdir:         GHDL work directory (e.g. repo_root / "build")
        work_lib:        library name, "surf" or "work"
        extra_lib_paths: additional -P library search paths (empty for direct surf)
        repo_root:       repository root; used as cwd for the subprocess
    """
    cmd = [
        "ghdl", "gen-depends",
        *GHDL_BASE_FLAGS,
        f"--workdir={workdir}",
        f"--work={work_lib}",
        *[f"-P{p}" for p in extra_lib_paths],
        entity_spec,
    ]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=str(repo_root),
    )
    if result.returncode != 0:
        return None

    source_files: set[str] = set()
    in_targets_section = False

    for line in result.stdout.splitlines():
        if line.startswith("# Targets to analyze files"):
            in_targets_section = True
            continue
        if line.startswith("# Files dependences"):
            break
        if not in_targets_section:
            continue
        if not line or line.startswith("#"):
            continue
        # Skip absolute paths (system libraries under /usr/local/lib/ghdl/)
        if line.startswith("/"):
            continue
        # Format: <workdir_relative_path>.o: <source_path>
        parts = line.split(": ", 1)
        if len(parts) == 2:
            source_path = parts[1].strip()
            if source_path.endswith(".vhd") and "/rtl/" in source_path:
                source_files.add(Path(source_path).as_posix())

    return source_files


def closure_via_on_the_fly_wrapper(
    wrapper_vhd: Path,
    entity_name: str,
    surf_workdir: Path,
    repo_root: Path,
) -> set[str] | None:
    """Analyze a sim_only wrapper on-the-fly and return its production-RTL closure.

    The wrapper is analyzed into a scratch tmpdir referencing the already-analyzed
    surf library.  Returns None if analyze or gen-depends fails.

    Security: wrapper_vhd must resolve to a path inside repo_root to block path
    traversal.  ValueError from relative_to() is allowed to propagate — callers
    should treat it as "skip + always-run fallback".

    Args:
        wrapper_vhd:   path to the wrapper .vhd source (must be inside repo_root)
        entity_name:   lowercased entity name, e.g. "ssiprbswrapper"
        surf_workdir:  repo_root / "build" (analyzed surf library)
        repo_root:     repository root
    """
    # Path-traversal guard: raises ValueError if wrapper is outside repo_root
    wrapper_vhd.resolve().relative_to(repo_root)

    with tempfile.TemporaryDirectory() as scratch_str:
        scratch = Path(scratch_str)

        analyze_result = subprocess.run(
            [
                "ghdl", "analyze",
                *GHDL_BASE_FLAGS,
                f"--workdir={scratch}",
                "--work=work",
                f"-P{surf_workdir}",
                str(wrapper_vhd),
            ],
            capture_output=True,
            cwd=str(repo_root),
        )
        if analyze_result.returncode != 0:
            return None

        return gen_depends_closure(
            entity_spec=f"work.{entity_name}",
            workdir=scratch,
            work_lib="work",
            extra_lib_paths=[surf_workdir],
            repo_root=repo_root,
        )


# ---------------------------------------------------------------------------
# Test discovery
# ---------------------------------------------------------------------------

def discover_tests(tests_root: Path, repo_root: Path) -> list[Path]:
    """Return sorted absolute paths of every test_*.py under tests_root,
    excluding any path containing a 'legacy' or 'ethernet' component.

    Mirrors pytest.ini norecursedirs and the FUT-01 ethernet exclusion.
    """
    results: list[Path] = []
    for p in tests_root.rglob("test_*.py"):
        parts = p.parts
        if "legacy" in parts or "ethernet" in parts:
            continue
        results.append(p)
    return sorted(results)


# ---------------------------------------------------------------------------
# AST signal extraction
# ---------------------------------------------------------------------------

_HELPER_NAMES = {
    "run_surf_vhdl_test",
    "run_pgp_wrapper_test",
    "run_line_code_package_test",
    "run_line_code_integration_test",
    "run_line_code_entity_test",
}


@dataclass
class TestSignals:
    """Extracted static signals for one test_*.py file."""
    test_file: str            # repo-relative posix path
    toplevel_entity: str | None   # lowercased entity name, surf. prefix stripped
    declared_sources: list[str] = field(default_factory=list)  # repo-relative posix .vhd paths
    wrapper_source: str | None = None   # repo-relative posix or None
    unresolved_toplevel: bool = False   # True when f-string toplevel cannot be resolved


def _callee_name(node: ast.Call) -> str | None:
    """Return the base function name for a Call node, or None."""
    func = node.func
    if isinstance(func, ast.Name):
        return func.id
    if isinstance(func, ast.Attribute):
        return func.attr
    return None


def _keyword_value(call: ast.Call, name: str) -> ast.expr | None:
    """Return the AST value node for a keyword argument, or None."""
    for kw in call.keywords:
        if kw.arg == name:
            return kw.value
    return None


def _try_literal(node: ast.expr) -> object:
    """Attempt ast.literal_eval on a literal sub-node; return sentinel on failure."""
    try:
        return ast.literal_eval(node)
    except (ValueError, TypeError):
        return _UNRESOLVABLE


_UNRESOLVABLE = object()


def _resolve_fstring_toplevel(
    fstr_node: ast.JoinedStr,
    assignments: dict[str, ast.expr],
) -> tuple[str | None, bool]:
    """Try to resolve an f-string toplevel to a literal string.

    Returns (resolved_entity_name, unresolved_flag).
    unresolved_flag is True when the f-string is present but cannot be resolved.
    """
    # Only handle simple cases: f"surf.{var.lower()}" or f"surf.{var}"
    # The f-string values list contains ast.Constant nodes (literal parts)
    # and ast.FormattedValue nodes (expressions).
    values = fstr_node.values
    if len(values) != 2:
        return None, True

    # Check that the first part is "surf."
    if not (isinstance(values[0], ast.Constant) and str(values[0].value).lower() == "surf."):
        return None, True

    # The second value should be a FormattedValue whose value is either a
    # Name or a method call like Name.lower()
    fv = values[1]
    if not isinstance(fv, ast.FormattedValue):
        return None, True

    expr = fv.value
    # Case 1: f"surf.{var_name.lower()}" — Attribute call
    var_name: str | None = None
    if isinstance(expr, ast.Call):
        inner = expr.func
        if isinstance(inner, ast.Attribute) and inner.attr == "lower":
            if isinstance(inner.value, ast.Name):
                var_name = inner.value.id
    # Case 2: f"surf.{var_name}" — direct Name
    elif isinstance(expr, ast.Name):
        var_name = expr.id

    if var_name is None:
        return None, True

    # Look up var_name in the assignments dict
    if var_name not in assignments:
        return None, True

    bound = assignments[var_name]
    val = _try_literal(bound)
    if val is _UNRESOLVABLE or not isinstance(val, str):
        return None, True

    # Success — strip surf. prefix and lowercase
    entity = val.lower().removeprefix("surf.")
    return entity, False


def _collect_module_assignments(tree: ast.Module) -> dict[str, ast.expr]:
    """Collect module-level and function-level Name = Constant assignments."""
    assignments: dict[str, ast.expr] = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign):
            if len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                assignments[node.targets[0].id] = node.value
    return assignments


def _extract_toplevel(
    call: ast.Call,
    assignments: dict[str, ast.expr],
) -> tuple[str | None, bool]:
    """Extract toplevel entity name from a helper call.

    Returns (entity_name_lowercase_no_surf_prefix, unresolved_flag).
    """
    tl_node = _keyword_value(call, "toplevel")
    if tl_node is None:
        return None, False

    if isinstance(tl_node, ast.Constant):
        raw = str(tl_node.value).lower()
        entity = raw.removeprefix("surf.")
        return entity, False

    if isinstance(tl_node, ast.JoinedStr):
        return _resolve_fstring_toplevel(tl_node, assignments)

    return None, True


def _normalize_source_path(path_str: str, repo_root: Path) -> str:
    """Return a repo-relative posix path string.

    Absolute paths are made relative to repo_root when possible.
    """
    p = Path(path_str)
    if p.is_absolute():
        try:
            return p.relative_to(repo_root).as_posix()
        except ValueError:
            return p.as_posix()
    return p.as_posix()


def _extract_sources_from_extra_vhdl_sources(
    node: ast.expr,
    repo_root: Path,
) -> list[str]:
    """Extract .vhd paths from extra_vhdl_sources={"surf": [...]} dict literal."""
    val = _try_literal(node)
    if val is _UNRESOLVABLE or not isinstance(val, dict):
        return []
    results: list[str] = []
    for lib_paths in val.values():
        if isinstance(lib_paths, list):
            for p in lib_paths:
                if isinstance(p, str):
                    results.append(_normalize_source_path(p, repo_root))
    return results


def _extract_sources_from_list(node: ast.expr, repo_root: Path) -> list[str]:
    """Extract .vhd paths from a literal list node."""
    val = _try_literal(node)
    if val is _UNRESOLVABLE or not isinstance(val, list):
        return []
    results: list[str] = []
    for p in val:
        if isinstance(p, str):
            results.append(_normalize_source_path(p, repo_root))
    return results


def _extract_single_source(node: ast.expr, repo_root: Path) -> str | None:
    """Extract a single .vhd path from a literal string node."""
    val = _try_literal(node)
    if val is _UNRESOLVABLE or not isinstance(val, str):
        return None
    return _normalize_source_path(val, repo_root)


def extract_test_signals(test_file: Path, repo_root: Path) -> TestSignals:
    """Parse test_file with AST (never exec/import) and extract static signals.

    Recognizes:
      - run_surf_vhdl_test(toplevel=..., extra_vhdl_sources=...)
      - run_pgp_wrapper_test(toplevel=..., wrapper_source=..., extra_sources=...)
      - run_line_code_package_test(toplevel=..., wrapper_source=...)
      - run_line_code_integration_test(toplevel=..., tb_source=...)
      - Module-level *_VHDL_SOURCES = [...] assignments (D-05)
    """
    try:
        rel_path = test_file.relative_to(repo_root).as_posix()
    except ValueError:
        rel_path = test_file.as_posix()

    signals = TestSignals(test_file=rel_path, toplevel_entity=None)

    try:
        source = test_file.read_text(encoding="utf-8")
        tree = ast.parse(source, filename=str(test_file))
    except (OSError, SyntaxError) as exc:
        logger.warning("Could not parse %s: %s", test_file, exc)
        signals.unresolved_toplevel = True
        return signals

    # Collect all assignments for f-string resolution
    assignments = _collect_module_assignments(tree)

    # Scan module-level *_VHDL_SOURCES assignments (D-05)
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign):
            if len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                name = node.targets[0].id
                if name.endswith("_VHDL_SOURCES"):
                    paths = _extract_sources_from_list(node.value, repo_root)
                    signals.declared_sources.extend(paths)

    # Walk all Call nodes for helper functions
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        name = _callee_name(node)
        if name not in _HELPER_NAMES:
            continue

        # Extract toplevel (first match wins)
        if signals.toplevel_entity is None and not signals.unresolved_toplevel:
            entity, unresolved = _extract_toplevel(node, assignments)
            if unresolved:
                signals.unresolved_toplevel = True
            elif entity is not None:
                signals.toplevel_entity = entity

        # run_surf_vhdl_test: extra_vhdl_sources={"surf": [...]}
        if name == "run_surf_vhdl_test":
            evs_node = _keyword_value(node, "extra_vhdl_sources")
            if evs_node is not None:
                paths = _extract_sources_from_extra_vhdl_sources(evs_node, repo_root)
                signals.declared_sources.extend(paths)

        # run_pgp_wrapper_test: wrapper_source=str, extra_sources=[...]
        elif name == "run_pgp_wrapper_test":
            ws_node = _keyword_value(node, "wrapper_source")
            if ws_node is not None:
                ws = _extract_single_source(ws_node, repo_root)
                if ws is not None and signals.wrapper_source is None:
                    signals.wrapper_source = ws
                    signals.declared_sources.append(ws)
            es_node = _keyword_value(node, "extra_sources")
            if es_node is not None:
                paths = _extract_sources_from_list(es_node, repo_root)
                signals.declared_sources.extend(paths)

        # run_line_code_package_test: wrapper_source=str
        elif name == "run_line_code_package_test":
            ws_node = _keyword_value(node, "wrapper_source")
            if ws_node is not None:
                ws = _extract_single_source(ws_node, repo_root)
                if ws is not None and signals.wrapper_source is None:
                    signals.wrapper_source = ws
                    signals.declared_sources.append(ws)

        # run_line_code_integration_test: tb_source=str
        elif name == "run_line_code_integration_test":
            tb_node = _keyword_value(node, "tb_source")
            if tb_node is not None:
                tb = _extract_single_source(tb_node, repo_root)
                if tb is not None and signals.wrapper_source is None:
                    signals.wrapper_source = tb
                    signals.declared_sources.append(tb)

    # Deduplicate declared sources while preserving order
    seen: set[str] = set()
    unique: list[str] = []
    for p in signals.declared_sources:
        if p not in seen:
            seen.add(p)
            unique.append(p)
    signals.declared_sources = unique

    return signals


# ---------------------------------------------------------------------------
# Per-test production-RTL closure with fallback hierarchy (D-01/D-02/D-04)
# ---------------------------------------------------------------------------

def _find_wrapper_source(signals: "TestSignals", repo_root: Path) -> Path | None:
    """Locate a wrapper .vhd for on-the-fly analysis.

    Prefers signals.wrapper_source; falls back to any declared source path that
    contains '/wrappers/' or ends with 'Wrapper.vhd' (case-insensitive).
    Returns an absolute Path or None if nothing resolvable is found.
    """
    candidate: str | None = signals.wrapper_source
    if candidate is None:
        for src in signals.declared_sources:
            if "/wrappers/" in src or src.lower().endswith("wrapper.vhd"):
                candidate = src
                break

    if candidate is None:
        return None

    p = Path(candidate)
    if p.is_absolute():
        # Security: resolve symlinks then reject paths outside repo_root
        # (ValueError propagates to caller); consistent with the downstream
        # closure_via_on_the_fly_wrapper guard.
        p.resolve().relative_to(repo_root)
        return p
    return repo_root / p


def _production_set_for_test(
    signals: "TestSignals",
    surf_workdir: Path,
    repo_root: Path,
) -> tuple[set[str], list[dict]]:
    """Compute the production-RTL closure for one test and any fallback-log records.

    Fallback hierarchy (D-01/D-02):
      1. gen-depends surf.<entity>  -> success  -> closure
      2. exit 1  -> on-the-fly wrapper via closure_via_on_the_fly_wrapper
      3. wrapper analysis fails / missing  -> always-run fallback

    Returns:
        (production_set, fallback_records)
        production_set is empty when the test should be classified always-run.
    """
    test_rel = signals.test_file  # already repo-relative posix

    # Step 0: dynamic/unresolvable toplevel — cannot proceed
    if signals.unresolved_toplevel:
        detail = f"toplevel contains an unresolvable f-string or dynamic expression in {test_rel}"
        logger.warning("always-run fallback [dynamic-toplevel]: %s", test_rel)
        return set(), [{"test": test_rel, "reason": "dynamic-toplevel", "detail": detail}]

    # Step 1: attempt direct gen-depends against the surf library
    entity = signals.toplevel_entity
    production_set: set[str] = set()
    fallback_records: list[dict] = []

    if entity is not None:
        closure = gen_depends_closure(
            entity_spec=f"surf.{entity}",
            workdir=surf_workdir,
            work_lib="surf",
            extra_lib_paths=[],
            repo_root=repo_root,
        )
        if closure is not None:
            production_set = closure
        else:
            # Step 2: entity not in surf lib — try on-the-fly wrapper analysis (D-01)
            try:
                wrapper_path = _find_wrapper_source(signals, repo_root)
            except ValueError:
                wrapper_path = None

            if wrapper_path is None:
                detail = (
                    f"gen-depends surf.{entity} failed and no wrapper source found "
                    f"in declared_sources for {test_rel}"
                )
                logger.warning("always-run fallback [wrapper-source-missing]: %s", test_rel)
                fallback_records.append({
                    "test": test_rel,
                    "reason": "wrapper-source-missing",
                    "detail": detail,
                })
            else:
                otf_closure = closure_via_on_the_fly_wrapper(
                    wrapper_vhd=wrapper_path,
                    entity_name=entity,
                    surf_workdir=surf_workdir,
                    repo_root=repo_root,
                )
                if otf_closure is not None:
                    production_set = otf_closure
                else:
                    detail = (
                        f"on-the-fly wrapper analysis failed for {wrapper_path.name} "
                        f"(entity surf.{entity}) in {test_rel}"
                    )
                    logger.warning("always-run fallback [wrapper-analyze-failed]: %s", test_rel)
                    fallback_records.append({
                        "test": test_rel,
                        "reason": "wrapper-analyze-failed",
                        "detail": detail,
                    })

    # D-04 union: fold in declared production-RTL sources (*/rtl/*.vhd) directly.
    # Re-relativize any absolute declared-source path to repo_root first.
    for src in signals.declared_sources:
        p = Path(src)
        if p.is_absolute():
            try:
                rel = p.relative_to(repo_root).as_posix()
            except ValueError:
                continue
        else:
            rel = p.as_posix()
        # Only include paths that are production-RTL (contain /rtl/)
        if "/rtl/" in rel:
            production_set.add(rel)

    # Production-RTL filter: drop anything that is NOT a /rtl/ path, drop
    # system library paths and test-infrastructure paths.
    _INFRA_TOKENS = ("/wrappers/", "/tb/", "/sim/", "/tests/", "/usr/local/lib/ghdl/")
    final_set: set[str] = set()
    for path_str in production_set:
        if "/rtl/" not in path_str:
            continue
        if any(tok in path_str for tok in _INFRA_TOKENS):
            continue
        final_set.add(path_str)

    # D-02 fail-safe: if no production set was built and we never found a
    # recognized helper (entity is None, unresolved_toplevel is False), the
    # test uses an unrecognized call pattern (e.g. direct simulator.run()).
    # Classify always-run and log — never silently drop.
    if not final_set and entity is None and not signals.unresolved_toplevel:
        detail = f"no recognized helper call found in {test_rel}"
        logger.warning("always-run fallback [no-recognized-helper]: %s", test_rel)
        fallback_records.append({
            "test": test_rel,
            "reason": "no-recognized-helper",
            "detail": detail,
        })

    return final_set, fallback_records


# ---------------------------------------------------------------------------
# Forward index accumulation and inversion (D-03/D-04/D-07)
# ---------------------------------------------------------------------------

def build_forward_index(
    repo_root: Path,
) -> tuple[dict[str, set[str]], list[str], list[dict], dict[str, set[str]]]:
    """Scan all tests and build the forward mapping (test -> production_set).

    Returns:
        forward_map:   test_file_rel -> set of production-RTL paths
        always_run:    sorted list of test files whose production set is empty (fallback)
        fallback_log:  structured fallback records
        infra_map:     infra_path -> set of owning test file paths (D-03/SEL-08)
    """
    surf_workdir = repo_root / "build"
    tests_root = repo_root / "tests"

    test_files = discover_tests(tests_root, repo_root)
    logger.info("Discovered %d test files (excluding legacy/ethernet)", len(test_files))

    forward_map: dict[str, set[str]] = {}
    always_run_set: set[str] = set()
    fallback_log: list[dict] = []
    # infra_map: keyed by infra file path -> set of test file paths owning it (D-03)
    infra_map: dict[str, set[str]] = {}

    for test_file in test_files:
        signals = extract_test_signals(test_file, repo_root)
        test_rel = signals.test_file  # repo-relative posix

        # Record test file itself as infra owned by itself (D-03/SEL-08)
        infra_map.setdefault(test_rel, set()).add(test_rel)

        # Record wrapper_source and declared non-RTL sources as infra (D-03)
        _INFRA_TOKENS = ("/wrappers/", "/tb/", "/sim/", "/tests/")
        for src in signals.declared_sources:
            p = Path(src)
            if p.is_absolute():
                try:
                    rel = p.relative_to(repo_root).as_posix()
                except ValueError:
                    continue
            else:
                rel = p.as_posix()
            # If the path is NOT a production-RTL path, it is infra
            if "/rtl/" not in rel or any(tok in rel for tok in _INFRA_TOKENS):
                infra_map.setdefault(rel, set()).add(test_rel)

        if signals.wrapper_source is not None:
            ws = signals.wrapper_source
            p = Path(ws)
            if p.is_absolute():
                try:
                    ws = p.relative_to(repo_root).as_posix()
                except ValueError:
                    ws = p.as_posix()
            infra_map.setdefault(ws, set()).add(test_rel)

        # Compute production-RTL closure for this test
        prod_set, records = _production_set_for_test(signals, surf_workdir, repo_root)
        fallback_log.extend(records)

        if not prod_set:
            # Empty production set -> always-run (D-02)
            always_run_set.add(test_rel)
        else:
            forward_map[test_rel] = prod_set

    return forward_map, sorted(always_run_set), fallback_log, infra_map


# ---------------------------------------------------------------------------
# Index assembly and JSON serialization (D-06/D-07)
# ---------------------------------------------------------------------------

def build_index(repo_root: Path) -> dict:
    """Build the four-section test-dependency index.

    Precondition: repo_root/build/surf-obj08.cf must exist (run `make analysis` first).

    Returns a dict with keys: production_rtl, test_infra, always_run, fallback_log.
    Also writes a fresh JSON to repo_root/build/test_dependency_index.json (D-06).
    """
    cf_path = repo_root / "build" / "surf-obj08.cf"
    if not cf_path.exists():
        raise FileNotFoundError(
            f"{cf_path} not found. Run `make MODULES=\"$PWD\" analysis` first."
        )

    forward_map, always_run, fallback_log, infra_map = build_forward_index(repo_root)

    # Invert forward_map to production_rtl[src] = sorted(tests) (D-07)
    production_rtl: dict[str, list[str]] = {}
    for test_rel, prod_set in forward_map.items():
        for src in prod_set:
            src_key = Path(src).as_posix()
            production_rtl.setdefault(src_key, set()).add(test_rel)  # type: ignore[arg-type]

    # Sort the value sets into lists for deterministic JSON output
    production_rtl_final: dict[str, list[str]] = {
        k: sorted(v) for k, v in production_rtl.items()  # type: ignore[arg-type]
    }

    # Invert infra_map to test_infra[infra_path] = sorted(tests) (D-03/SEL-08)
    test_infra: dict[str, list[str]] = {
        k: sorted(v) for k, v in infra_map.items()
    }

    index = {
        "production_rtl": production_rtl_final,
        "test_infra": test_infra,
        "always_run": always_run,
        "fallback_log": fallback_log,
    }

    # Write fresh JSON (D-06 — gitignored, never committed)
    output_path = repo_root / "build" / "test_dependency_index.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(index, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    logger.info(
        "Index written to %s: %d production_rtl keys, %d test_infra keys, "
        "%d always_run, %d fallback_log entries",
        output_path,
        len(production_rtl_final),
        len(test_infra),
        len(always_run),
        len(fallback_log),
    )

    return index


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build a test-dependency index mapping production-RTL files to test files."
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Path for output JSON (default: <repo_root>/build/test_dependency_index.json).",
    )
    parser.add_argument(
        "--tests-root",
        default=None,
        help="Root directory to scan for test_*.py files (default: <repo_root>/tests).",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    repo_root = _repo_root()

    # Resolve output path and enforce repo-root containment (T-01-04)
    if args.output is not None:
        output_path = Path(args.output).resolve()
        try:
            output_path.relative_to(repo_root.resolve())
        except ValueError:
            raise ValueError(
                f"--output path {output_path} escapes repo root {repo_root}; "
                "only paths inside the repository are allowed."
            )
    else:
        output_path = repo_root / "build" / "test_dependency_index.json"

    if args.tests_root is not None:
        # tests_root override: patch discover_tests via a local wrapper
        custom_tests_root = Path(args.tests_root)
        test_files = discover_tests(custom_tests_root, repo_root)
        logger.info(
            "Discovered %d test files (excluding legacy/ethernet) from %s",
            len(test_files), custom_tests_root,
        )

    index = build_index(repo_root)

    # Write to the user-specified output path if it differs from the default
    default_out = repo_root / "build" / "test_dependency_index.json"
    if output_path.resolve() != default_out.resolve():
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(index, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        logger.info("Index also written to %s", output_path)


if __name__ == "__main__":
    main()
