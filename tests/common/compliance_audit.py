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
from collections import Counter
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
import sys
from typing import Iterable, Iterator


REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_VERSION = 1
DEFAULT_BASELINE = Path(__file__).with_name("compliance_baseline.json")

ENFORCED_RULES = {
    "bare-return",
    "direct-runner",
    "duplicate-imported-source",
    "edge-then-timer",
    "early-bare-return",
    "missing-methodology",
    "open-ended-loop",
    "unretained-start-soon",
}

EXCLUDED_DIRECTORY_NAMES = {
    "__pycache__",
    "legacy",
    "sim_build",
}

METHODOLOGY_MARKER = "Test methodology:"
LIFETIME_AGENT_MARKER = "Lifetime agent:"
PROPAGATION_SAMPLING_MARKER = "Propagation sampling:"
REAL_TIME_TIMING_MARKER = "Real-time timing:"
TERMINAL_SCENARIO_MARKER = "# Terminal scenario:"
ENVIRONMENT_CONTROL_RE = re.compile(
    r"^(?:RUN_[A-Z0-9_]*_TESTS|COCOTB_TEST_FILTER|COCOTB_TESTCASE|[A-Z0-9_]*TESTCASE)$"
)

DOCUMENTED_DIRECT_RUNNERS = {
    "tests/common/regression_utils.py",
    "tests/simlink/ghdl/simlink_test_utils.py",
}


@dataclass(frozen=True, order=True)
class Finding:
    rule: str
    path: str
    line: int
    symbol: str
    detail: str

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


@dataclass(frozen=True)
class FileInventory:
    cocotb_entrypoints: tuple[str, ...]
    pytest_functions: tuple[str, ...]
    parameter_ids: tuple[str, ...]
    environment_controls: tuple[str, ...]
    skipped_functions: tuple[str, ...]
    timeout_entrypoints: tuple[str, ...]

    def to_dict(self) -> dict[str, object]:
        return {
            key: list(value)
            for key, value in asdict(self).items()
        }


@dataclass(frozen=True)
class PreservationDelta:
    removed: dict[str, dict[str, tuple[str, ...]]]
    added: dict[str, dict[str, tuple[str, ...]]]

    @property
    def has_removals(self) -> bool:
        return bool(self.removed)

    def to_dict(self) -> dict[str, object]:
        return {
            "removed": _nested_tuples_to_lists(self.removed),
            "added": _nested_tuples_to_lists(self.added),
        }


@dataclass(frozen=True)
class BaselineDelta:
    new: dict[str, dict[str, int]]
    reduced: dict[str, dict[str, int]]

    @property
    def has_new(self) -> bool:
        return bool(self.new)

    def to_dict(self) -> dict[str, object]:
        return {
            "new": self.new,
            "reduced": self.reduced,
        }


def _nested_tuples_to_lists(
    values: dict[str, dict[str, tuple[str, ...]]],
) -> dict[str, dict[str, list[str]]]:
    return {
        path: {
            category: list(items)
            for category, items in categories.items()
        }
        for path, categories in values.items()
    }


def _has_terminal_scenario_marker(source_lines: list[str], return_line: int) -> bool:
    for line in reversed(source_lines[max(0, return_line - 4) : return_line - 1]):
        stripped = line.strip()
        if not stripped.startswith("#"):
            break
        if stripped.startswith(TERMINAL_SCENARIO_MARKER):
            return True
    return False


def _qualified_name(node: ast.AST) -> str:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        prefix = _qualified_name(node.value)
        return f"{prefix}.{node.attr}" if prefix else node.attr
    if isinstance(node, ast.Call):
        return _qualified_name(node.func)
    return ""


def _is_cocotb_test(function: ast.FunctionDef | ast.AsyncFunctionDef) -> bool:
    for decorator in function.decorator_list:
        target = decorator.func if isinstance(decorator, ast.Call) else decorator
        if _qualified_name(target) == "cocotb.test":
            return True
    return False


def _has_timeout(function: ast.FunctionDef | ast.AsyncFunctionDef) -> bool:
    for decorator in function.decorator_list:
        if not isinstance(decorator, ast.Call):
            continue
        if _qualified_name(decorator.func) != "cocotb.test":
            continue
        if any(keyword.arg == "timeout_time" for keyword in decorator.keywords):
            return True
    return False


def _has_skip(function: ast.FunctionDef | ast.AsyncFunctionDef) -> bool:
    for decorator in function.decorator_list:
        name = _qualified_name(decorator)
        if any(part.startswith("skip") for part in name.split(".")):
            return True

    for node in _walk_function(function):
        if isinstance(node, ast.Call) and _qualified_name(node.func) == "pytest.skip":
            return True
    return False


def _is_lifetime_agent(function: ast.FunctionDef | ast.AsyncFunctionDef) -> bool:
    docstring = ast.get_docstring(function, clean=False)
    return docstring is not None and LIFETIME_AGENT_MARKER in docstring


class _FunctionWalker(ast.NodeVisitor):
    def __init__(self, root: ast.FunctionDef | ast.AsyncFunctionDef):
        self.root = root
        self.nodes: list[ast.AST] = []

    def generic_visit(self, node: ast.AST) -> None:
        self.nodes.append(node)
        super().generic_visit(node)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        if node is self.root:
            self.generic_visit(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        if node is self.root:
            self.generic_visit(node)

    def visit_Lambda(self, node: ast.Lambda) -> None:
        self.nodes.append(node)


def _walk_function(
    function: ast.FunctionDef | ast.AsyncFunctionDef,
) -> tuple[ast.AST, ...]:
    walker = _FunctionWalker(function)
    walker.visit(function)
    return tuple(walker.nodes)


def _top_level_functions(
    tree: ast.Module,
) -> tuple[ast.FunctionDef | ast.AsyncFunctionDef, ...]:
    return tuple(
        node
        for node in tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
    )


def _all_functions(
    tree: ast.Module,
) -> tuple[ast.FunctionDef | ast.AsyncFunctionDef, ...]:
    return tuple(
        sorted(
            (
                node
                for node in ast.walk(tree)
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
            ),
            key=lambda node: (node.lineno, node.name),
        )
    )


def _string_constants(node: ast.AST) -> Iterator[tuple[str, int]]:
    for child in ast.walk(node):
        if isinstance(child, ast.Constant) and isinstance(child.value, str):
            yield child.value, child.lineno


def _parameter_ids(tree: ast.Module) -> tuple[str, ...]:
    result = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue

        name = _qualified_name(node.func)
        if name == "pytest.param":
            for keyword in node.keywords:
                if keyword.arg == "id" and isinstance(keyword.value, ast.Constant):
                    if isinstance(keyword.value.value, str):
                        result.add(keyword.value.value)
        elif name.endswith("parameter_case") and node.args:
            first = node.args[0]
            if isinstance(first, ast.Constant) and isinstance(first.value, str):
                result.add(first.value)
    return tuple(sorted(result))


def _environment_controls(tree: ast.Module) -> tuple[str, ...]:
    controls = {
        value
        for value, _ in _string_constants(tree)
        if ENVIRONMENT_CONTROL_RE.fullmatch(value)
    }
    if any(
        isinstance(node, ast.Call) and _qualified_name(node.func).endswith("cocotb_filtered_env")
        for node in ast.walk(tree)
    ):
        controls.add("COCOTB_TEST_FILTER")
    return tuple(sorted(controls))


def inventory_source(source: str, path: str = "test.py") -> FileInventory:
    tree = ast.parse(source, filename=path)
    functions = _top_level_functions(tree)
    cocotb_functions = tuple(function for function in functions if _is_cocotb_test(function))

    return FileInventory(
        cocotb_entrypoints=tuple(sorted(function.name for function in cocotb_functions)),
        pytest_functions=tuple(
            sorted(
                function.name
                for function in functions
                if function.name.startswith("test_") and not _is_cocotb_test(function)
            )
        ),
        parameter_ids=_parameter_ids(tree),
        environment_controls=_environment_controls(tree),
        skipped_functions=tuple(
            sorted(function.name for function in functions if _has_skip(function))
        ),
        timeout_entrypoints=tuple(
            sorted(function.name for function in cocotb_functions if _has_timeout(function))
        ),
    )


def _repo_relative(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.resolve().as_posix()


def discover_python_files(
    paths: Iterable[str | Path],
    repo_root: Path = REPO_ROOT,
) -> tuple[Path, ...]:
    result = set()
    requested = tuple(paths) or ("tests",)

    for raw_path in requested:
        path = Path(raw_path)
        if not path.is_absolute():
            path = repo_root / path

        if path.is_file():
            if path.suffix == ".py":
                result.add(path.resolve())
            continue

        if not path.exists():
            raise FileNotFoundError(path)

        for candidate in path.rglob("*.py"):
            relative_parts = candidate.relative_to(path).parts
            if any(part in EXCLUDED_DIRECTORY_NAMES for part in relative_parts):
                continue
            result.add(candidate.resolve())

    return tuple(sorted(result))


def inventory_paths(
    paths: Iterable[str | Path],
    repo_root: Path = REPO_ROOT,
) -> dict[str, FileInventory]:
    report = {}
    for path in discover_python_files(paths, repo_root):
        source = path.read_text(encoding="utf-8")
        inventory = inventory_source(source, _repo_relative(path, repo_root))
        if any(asdict(inventory).values()):
            report[_repo_relative(path, repo_root)] = inventory
    return dict(sorted(report.items()))


def _parent_map(tree: ast.AST) -> dict[ast.AST, ast.AST]:
    return {
        child: parent
        for parent in ast.walk(tree)
        for child in ast.iter_child_nodes(parent)
    }


def _is_clock_start(call: ast.Call) -> bool:
    if not call.args:
        return False
    try:
        expression = ast.unparse(call.args[0])
    except AttributeError:
        return False
    return "Clock(" in expression or "start_lockstep_clocks" in expression


def _await_call_name(statement: ast.stmt) -> str:
    if not isinstance(statement, ast.Expr) or not isinstance(statement.value, ast.Await):
        return ""
    awaited = statement.value.value
    if not isinstance(awaited, ast.Call):
        return ""
    return _qualified_name(awaited.func)


def _statement_lists(node: ast.AST) -> Iterator[list[ast.stmt]]:
    for _, value in ast.iter_fields(node):
        if isinstance(value, list) and value and all(isinstance(item, ast.stmt) for item in value):
            yield value
            for statement in value:
                yield from _statement_lists(statement)
        elif isinstance(value, ast.AST):
            yield from _statement_lists(value)


def _direct_runner_aliases(tree: ast.Module) -> set[str]:
    aliases = set()
    for node in tree.body:
        if not isinstance(node, ast.ImportFrom) or node.module != "cocotb_test.simulator":
            continue
        for name in node.names:
            if name.name == "run":
                aliases.add(name.asname or name.name)
    return aliases


def _imported_source_paths(repo_root: Path) -> frozenset[Path]:
    paths = set()
    build_root = repo_root / "build" / "SRC_VHDL"
    if not build_root.exists():
        return frozenset()
    for library in build_root.iterdir():
        if not library.is_dir():
            continue
        for path in library.iterdir():
            if path.is_file():
                paths.add(path.resolve())
    return frozenset(paths)


def audit_source(
    source: str,
    path: str = "test.py",
    *,
    repo_root: Path = REPO_ROOT,
    imported_sources: frozenset[Path] | None = None,
) -> tuple[Finding, ...]:
    tree = ast.parse(source, filename=path)
    source_lines = source.splitlines()
    findings = []
    functions = _top_level_functions(tree)
    cocotb_functions = tuple(function for function in functions if _is_cocotb_test(function))

    if cocotb_functions:
        first_entrypoint_line = min(function.lineno for function in cocotb_functions)
        header = "\n".join(source.splitlines()[:first_entrypoint_line])
        if METHODOLOGY_MARKER not in header:
            findings.append(
                Finding(
                    "missing-methodology",
                    path,
                    1,
                    "<module>",
                    "cocotb test file has no Test methodology block before its first entrypoint",
                )
            )

    for function in cocotb_functions:
        function_nodes = _walk_function(function)
        for node in function_nodes:
            if isinstance(node, ast.Return) and node.value is None:
                has_prior_test_activity = any(
                    isinstance(prior, (ast.Assert, ast.Await))
                    and prior.lineno < node.lineno
                    for prior in function_nodes
                )
                rule = "bare-return" if has_prior_test_activity else "early-bare-return"
                if (
                    rule == "bare-return"
                    and _has_terminal_scenario_marker(source_lines, node.lineno)
                ):
                    continue
                findings.append(
                    Finding(
                        rule,
                        path,
                        node.lineno,
                        function.name,
                        "bare return in cocotb entrypoint; confirm that the scenario cannot pass without its named checks",
                    )
                )

    for function in _all_functions(tree):
        parents = _parent_map(function)
        lifetime_agent = _is_lifetime_agent(function)
        timing_docstring = ast.get_docstring(function) or ""
        classified_real_time = any(
            marker in timing_docstring
            for marker in (PROPAGATION_SAMPLING_MARKER, REAL_TIME_TIMING_MARKER)
        )
        for node in _walk_function(function):
            if isinstance(node, ast.While) and isinstance(node.test, ast.Constant):
                if node.test.value is True and not lifetime_agent:
                    findings.append(
                        Finding(
                            "open-ended-loop",
                            path,
                            node.lineno,
                            function.name,
                            "while True requires a bounded enclosing timeout or lifetime-agent classification",
                        )
                    )

            if not isinstance(node, ast.Call) or _qualified_name(node.func) != "cocotb.start_soon":
                continue
            if _is_clock_start(node):
                continue
            if isinstance(parents.get(node), ast.Expr):
                findings.append(
                    Finding(
                        "unretained-start-soon",
                        path,
                        node.lineno,
                        function.name,
                        "classify as finite work or a lifetime agent and make ownership explicit",
                    )
                )

        for statements in _statement_lists(function):
            for first, second in zip(statements, statements[1:]):
                if (
                    _await_call_name(first).endswith("RisingEdge")
                    and _await_call_name(second).endswith("Timer")
                    and not classified_real_time
                ):
                    findings.append(
                        Finding(
                            "edge-then-timer",
                            path,
                            second.lineno,
                            function.name,
                            "classify the delay as delta-cycle settling or a real modeled propagation delay",
                        )
                    )

    relative_path = path.replace("\\", "/")
    direct_aliases = _direct_runner_aliases(tree)
    if direct_aliases and relative_path not in DOCUMENTED_DIRECT_RUNNERS:
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                if node.func.id in direct_aliases:
                    findings.append(
                        Finding(
                            "direct-runner",
                            path,
                            node.lineno,
                            "<module>",
                            "use run_surf_vhdl_test() or document the capability the shared runner cannot express",
                        )
                    )

    if imported_sources is None:
        imported_sources = _imported_source_paths(repo_root)
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        for keyword in node.keywords:
            if keyword.arg != "extra_vhdl_sources":
                continue
            for literal, line in _string_constants(keyword.value):
                if not literal.lower().endswith((".vhd", ".vhdl")):
                    continue
                source_path = Path(literal)
                if not source_path.is_absolute():
                    source_path = repo_root / source_path
                if source_path.exists() and source_path.resolve() in imported_sources:
                    findings.append(
                        Finding(
                            "duplicate-imported-source",
                            path,
                            line,
                            "<module>",
                            f"{literal} is already supplied by build/SRC_VHDL",
                        )
                    )

    return tuple(sorted(set(findings)))


def audit_paths(
    paths: Iterable[str | Path],
    repo_root: Path = REPO_ROOT,
) -> tuple[Finding, ...]:
    imported_sources = _imported_source_paths(repo_root)
    findings = []
    for source_path in discover_python_files(paths, repo_root):
        relative_path = _repo_relative(source_path, repo_root)
        try:
            findings.extend(
                audit_source(
                    source_path.read_text(encoding="utf-8"),
                    relative_path,
                    repo_root=repo_root,
                    imported_sources=imported_sources,
                )
            )
        except SyntaxError as exc:
            findings.append(
                Finding(
                    "syntax-error",
                    relative_path,
                    exc.lineno or 1,
                    "<module>",
                    exc.msg,
                )
            )
    return tuple(sorted(findings))


def preservation_report(
    paths: Iterable[str | Path],
    repo_root: Path = REPO_ROOT,
) -> dict[str, object]:
    inventories = inventory_paths(paths, repo_root)
    return {
        "schema_version": SCHEMA_VERSION,
        "files": {
            path: inventory.to_dict()
            for path, inventory in inventories.items()
        },
    }


def compare_preservation_reports(
    before: dict[str, object],
    after: dict[str, object],
) -> PreservationDelta:
    if before.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("unsupported before-report schema")
    if after.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("unsupported after-report schema")

    before_files = before.get("files")
    after_files = after.get("files")
    if not isinstance(before_files, dict) or not isinstance(after_files, dict):
        raise ValueError("preservation reports must contain a files object")

    removed: dict[str, dict[str, tuple[str, ...]]] = {}
    added: dict[str, dict[str, tuple[str, ...]]] = {}
    all_paths = sorted(set(before_files) | set(after_files))
    for path in all_paths:
        before_inventory = before_files.get(path, {})
        after_inventory = after_files.get(path, {})
        if not isinstance(before_inventory, dict) or not isinstance(after_inventory, dict):
            raise ValueError(f"invalid inventory for {path}")

        categories = sorted(set(before_inventory) | set(after_inventory))
        for category in categories:
            before_values = set(before_inventory.get(category, []))
            after_values = set(after_inventory.get(category, []))
            removed_values = tuple(sorted(before_values - after_values))
            added_values = tuple(sorted(after_values - before_values))
            if removed_values:
                removed.setdefault(path, {})[category] = removed_values
            if added_values:
                added.setdefault(path, {})[category] = added_values

    return PreservationDelta(removed=removed, added=added)


def compliance_baseline(findings: Iterable[Finding]) -> dict[str, object]:
    counts: dict[str, Counter[str]] = {
        rule: Counter()
        for rule in sorted(ENFORCED_RULES)
    }
    for finding in findings:
        if finding.rule in ENFORCED_RULES:
            counts[finding.rule][finding.path] += 1

    return {
        "schema_version": SCHEMA_VERSION,
        "rules": {
            rule: dict(sorted(paths.items()))
            for rule, paths in counts.items()
        },
    }


def compare_compliance_baseline(
    baseline: dict[str, object],
    findings: Iterable[Finding],
) -> BaselineDelta:
    if baseline.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("unsupported compliance-baseline schema")
    baseline_rules = baseline.get("rules")
    if not isinstance(baseline_rules, dict):
        raise ValueError("compliance baseline must contain a rules object")

    current = compliance_baseline(findings)["rules"]
    new: dict[str, dict[str, int]] = {}
    reduced: dict[str, dict[str, int]] = {}
    for rule in sorted(ENFORCED_RULES):
        allowed_paths = baseline_rules.get(rule, {})
        current_paths = current.get(rule, {})
        if not isinstance(allowed_paths, dict) or not isinstance(current_paths, dict):
            raise ValueError(f"invalid baseline counts for {rule}")
        for path in sorted(set(allowed_paths) | set(current_paths)):
            allowed_count = allowed_paths.get(path, 0)
            current_count = current_paths.get(path, 0)
            if not isinstance(allowed_count, int) or not isinstance(current_count, int):
                raise ValueError(f"invalid baseline count for {rule}:{path}")
            if current_count > allowed_count:
                new.setdefault(rule, {})[path] = current_count - allowed_count
            elif current_count < allowed_count:
                reduced.setdefault(rule, {})[path] = allowed_count - current_count

    return BaselineDelta(new=new, reduced=reduced)


def _write_output(content: str, output: str | None) -> None:
    if output is None:
        print(content)
    else:
        Path(output).write_text(f"{content}\n", encoding="utf-8")


def _audit_text(findings: tuple[Finding, ...]) -> str:
    counts = Counter(finding.rule for finding in findings)
    lines = [
        f"{finding.path}:{finding.line}: {finding.rule}: {finding.symbol}: {finding.detail}"
        for finding in findings
    ]
    lines.append("")
    lines.append(f"{len(findings)} finding(s) across {len(counts)} rule(s)")
    for rule, count in sorted(counts.items()):
        lines.append(f"  {rule}: {count}")
    return "\n".join(lines)


def _delta_text(delta: PreservationDelta) -> str:
    lines = []
    for label, values in (("removed", delta.removed), ("added", delta.added)):
        for path, categories in values.items():
            for category, items in categories.items():
                for item in items:
                    lines.append(f"{label}: {path}: {category}: {item}")
    if not lines:
        return "No preservation-report differences."
    return "\n".join(lines)


def _baseline_delta_text(delta: BaselineDelta) -> str:
    lines = []
    for label, values in (("new", delta.new), ("reduced", delta.reduced)):
        for rule, paths in values.items():
            for path, count in paths.items():
                lines.append(f"{label}: {rule}: {path}: {count}")
    if not lines:
        return "No enforced compliance-baseline differences."
    return "\n".join(lines)


def _require_imported_source_tree(repo_root: Path) -> None:
    if not (repo_root / "build" / "SRC_VHDL").exists():
        raise FileNotFoundError(
            "missing build/SRC_VHDL; run `make MODULES=\"$PWD\" import` before baseline checks"
        )


def main(argv: list[str] | None = None, repo_root: Path = REPO_ROOT) -> int:
    parser = argparse.ArgumentParser(
        description="Audit SURF regression structure and compare test-preservation reports."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    audit_parser = subparsers.add_parser("audit", help="report compliance screening signals")
    audit_parser.add_argument("paths", nargs="*", default=["tests"])
    audit_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    audit_parser.add_argument("--output", help="write the report to this path")

    inventory_parser = subparsers.add_parser(
        "inventory",
        help="record pytest/cocotb names, parameters, gates, skips, and timeouts",
    )
    inventory_parser.add_argument("paths", nargs="*", default=["tests"])
    inventory_parser.add_argument("--output", help="write the JSON report to this path")

    baseline_parser = subparsers.add_parser(
        "baseline",
        help="record current counts for reliable, enforceable audit rules",
    )
    baseline_parser.add_argument("paths", nargs="*", default=["tests"])
    baseline_parser.add_argument("--output", required=True, help="write the JSON baseline here")

    check_parser = subparsers.add_parser(
        "check",
        help="fail when enforced findings exceed the checked-in legacy baseline",
    )
    check_parser.add_argument("paths", nargs="*", default=["tests"])
    check_parser.add_argument(
        "--baseline",
        default=str(DEFAULT_BASELINE),
        help="legacy baseline JSON path",
    )
    check_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    check_parser.add_argument("--output", help="write the comparison to this path")

    compare_parser = subparsers.add_parser(
        "compare",
        help="compare two preservation reports and fail when coverage identifiers disappear",
    )
    compare_parser.add_argument("before")
    compare_parser.add_argument("after")
    compare_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    compare_parser.add_argument("--output", help="write the comparison to this path")

    args = parser.parse_args(argv)
    try:
        if args.command == "audit":
            findings = audit_paths(args.paths, repo_root)
            if args.json:
                content = json.dumps(
                    {
                        "schema_version": SCHEMA_VERSION,
                        "findings": [finding.to_dict() for finding in findings],
                    },
                    indent=2,
                    sort_keys=True,
                )
            else:
                content = _audit_text(findings)
            _write_output(content, args.output)
            return 0

        if args.command == "inventory":
            content = json.dumps(
                preservation_report(args.paths, repo_root),
                indent=2,
                sort_keys=True,
            )
            _write_output(content, args.output)
            return 0

        if args.command == "baseline":
            _require_imported_source_tree(repo_root)
            content = json.dumps(
                compliance_baseline(audit_paths(args.paths, repo_root)),
                indent=2,
                sort_keys=True,
            )
            _write_output(content, args.output)
            return 0

        if args.command == "check":
            _require_imported_source_tree(repo_root)
            baseline = json.loads(Path(args.baseline).read_text(encoding="utf-8"))
            delta = compare_compliance_baseline(
                baseline,
                audit_paths(args.paths, repo_root),
            )
            content = (
                json.dumps(delta.to_dict(), indent=2, sort_keys=True)
                if args.json
                else _baseline_delta_text(delta)
            )
            _write_output(content, args.output)
            return 1 if delta.has_new else 0

        before = json.loads(Path(args.before).read_text(encoding="utf-8"))
        after = json.loads(Path(args.after).read_text(encoding="utf-8"))
        delta = compare_preservation_reports(before, after)
        content = (
            json.dumps(delta.to_dict(), indent=2, sort_keys=True)
            if args.json
            else _delta_text(delta)
        )
        _write_output(content, args.output)
        return 1 if delta.has_removals else 0
    except (FileNotFoundError, SyntaxError, ValueError, json.JSONDecodeError) as exc:
        parser.error(str(exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
