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
    if len(values) < 2:
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
# CLI scaffolding (Plan 02 wires build_index and JSON output)
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

    repo_root = _repo_root()
    tests_root = Path(args.tests_root) if args.tests_root else repo_root / "tests"
    output_path = Path(args.output) if args.output else repo_root / "build" / "test_dependency_index.json"

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    tests = discover_tests(tests_root, repo_root)
    logger.info("Discovered %d test files (excluding legacy/ethernet)", len(tests))

    cf_path = repo_root / "build" / "surf-obj08.cf"
    if not cf_path.exists():
        raise FileNotFoundError(
            f"{cf_path} not found. Run `make MODULES=\"$PWD\" analysis` first."
        )

    # Plan 02 implements build_index() and JSON serialization.
    # This stub call preserves the CLI entry-point contract.
    logger.info(
        "Index build requires build_index() from Plan 02 — "
        "run with a complete installation once Plan 02 is merged."
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps({"production_rtl": {}, "test_infra": {}, "always_run": [], "fallback_log": []},
                   indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
