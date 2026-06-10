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

# Select the pytest subset to run for a given CI invocation context.
#
# Ordering assumption (SEL-09): this selector must be called AFTER
#   make analysis -> python scripts/build_test_dependency_index.py -> make import
# The selector reads build/test_dependency_index.json (requires make analysis +
# build_test_dependency_index.py to have completed) but does NOT depend on
# build/SRC_VHDL/surf/ — pytest/cocotb needs that, not the selector.
#
# fetch-depth caveat: git diff --name-only origin/<base>...HEAD requires the base
# ref to be reachable in the local clone.  Phase 3 must set fetch-depth: 0 (or
# git fetch origin <base>) before calling this script in CI (Pitfall 1).

import argparse
import json
import logging
import os
import subprocess
import sys
from pathlib import Path

logger = logging.getLogger(__name__)

# Pytest flags preserved verbatim from surf_ci.yml (SEL-09 — do NOT alter order).
PYTEST_FLAGS = "--cov -v -n auto --dist=worksteal"

# Integration refs: pushes/PRs targeting these branches always run the full suite.
INTEGRATION_REFS = ("main", "pre-release")


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def classify_ref(event: str, ref_type: str, ref_name: str, base_ref: str) -> str:
    """Return 'full' or 'selective' for the given GitHub Actions context.

    Branch order is load-bearing (SEL-04):
      1. Tag push always means full suite — checked FIRST to avoid tag-name
         misclassification (Pitfall 6: on a tag GITHUB_REF_NAME is the tag
         name, not a branch, so the branch checks below must not fire).
      2. Push to an integration branch (main / pre-release) -> full.
      3. pull_request whose BASE is an integration branch -> full.
      4. Any other pull_request (dev-branch PR) -> selective.
      5. Conservative default: anything else (push to non-integration branch,
         unknown event) -> full.  Phase 3 decides whether direct dev pushes
         ever use selective mode (FUT-03).

    All arguments are strings; pass an empty string for unset env vars.
    """
    # 1. Tag push -> full suite regardless of tag name.
    if ref_type == "tag":
        return "full"

    # 2. Push to an integration branch -> full suite.
    if event == "push" and ref_name in INTEGRATION_REFS:
        return "full"

    # 3. PR whose base is an integration branch -> full suite.
    if event == "pull_request" and base_ref in INTEGRATION_REFS:
        return "full"

    # 4. Dev-branch PR -> selective.
    if event == "pull_request":
        return "selective"

    # 5. Conservative default.
    return "full"


def build_pytest_command(selected: set[str], mode: str) -> str | None:
    """Return a ready-to-eval pytest command string, or None for empty selection.

    Flag string is preserved verbatim from surf_ci.yml (SEL-09).

    Full mode (SEL-05): uses tests/ root auto-discovery so a new test directory
    is picked up automatically with no YAML or pytest.ini edit.  Do NOT
    enumerate subdirs explicitly.

    Selective mode: emits file-level node IDs (sorted for determinism).  Returns
    None when selected is empty (SEL-07 noop — caller logs to stderr and exits 0).
    """
    if mode == "full":
        return (
            f"python -m pytest {PYTEST_FLAGS} tests/"
            " --ignore=tests/legacy --ignore=tests/ethernet"
        )

    # mode == "selective"
    if not selected:
        return None
    node_list = " ".join(sorted(selected))
    return f"python -m pytest {PYTEST_FLAGS} {node_list}"


def select_tests(changed_vhd: list[str], index: dict) -> set[str]:
    """Return the set of test file paths to run for the given changed .vhd list.

    Pure function — no subprocess, no filesystem access.

    SEL-01: intersects changed paths against index['production_rtl'] (all surf
    production .vhd paths, not just /rtl/) and index['test_infra'] (wrappers,
    tb/sim files, and test files themselves).

    SEL-07 / Pitfall 3: if changed_vhd is empty (no .vhd files changed), return
    set() immediately — always_run must NOT fire on a zero-.vhd diff.

    D-02 fail-safe: when at least one .vhd changed, always_run tests are union-
    added unconditionally.  These tests have unresolvable toplevels and cannot be
    narrowed; they must run whenever any RTL might be affected.
    """
    if not changed_vhd:
        # SEL-07: no .vhd changed -> zero selection.
        return set()

    production_rtl = index["production_rtl"]
    test_infra     = index["test_infra"]
    always_run     = index["always_run"]

    selected: set[str] = set()
    for path in changed_vhd:
        if path in production_rtl:
            selected.update(production_rtl[path])
        if path in test_infra:
            selected.update(test_infra[path])

    # D-02: always_run fires whenever any .vhd was touched.
    selected.update(always_run)
    return selected


def changed_vhd_files(base_ref: str, repo_root: Path) -> list[str]:
    """Return repo-relative POSIX paths of .vhd files changed vs origin/<base_ref>.

    Uses a three-dot range (origin/<base>...HEAD) to diff from the merge-base,
    excluding changes already on the base branch before this PR branched.

    Security (T-02-01): base_ref is passed as a discrete argv element — never
    interpolated into a shell string.  The subprocess call uses an argv list only.

    Raises RuntimeError (wrapping CalledProcessError) if git fails — typically
    because the base ref is unreachable in a shallow clone (Pitfall 1 / T-02-05).
    Phase 3 must set fetch-depth: 0 before calling this script in CI.
    """
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", f"origin/{base_ref}...HEAD"],
            capture_output=True,
            text=True,
            cwd=str(repo_root),
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(
            f"git diff failed for base ref '{base_ref}' — this is usually caused by a "
            "shallow clone (fetch-depth: 1).  Ensure fetch-depth: 0 or a targeted "
            f"'git fetch origin {base_ref}' runs before this script in CI (Pitfall 1).\n"
            f"git stderr: {exc.stderr.strip()}"
        ) from exc

    paths: list[str] = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if line.endswith(".vhd"):
            # Normalize: forward slashes, strip any leading ./ (Pitfall 2).
            paths.append(Path(line).as_posix())
    return paths


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Classify CI context and emit the pytest command to run. "
            "Prints the command to stdout (or nothing on empty selection). "
            "Phase 3 wires this into surf_ci.yml; this script does not touch the workflow."
        )
    )
    parser.add_argument(
        "--base-ref",
        default=None,
        help=(
            "Git base ref for the diff (overrides GITHUB_BASE_REF). "
            "Required in selective mode when GITHUB_BASE_REF is not set."
        ),
    )
    parser.add_argument(
        "--index-path",
        default=None,
        help=(
            "Path to test_dependency_index.json "
            "(default: <repo_root>/build/test_dependency_index.json)."
        ),
    )
    parser.add_argument(
        "--mode",
        choices=["full", "selective"],
        default=None,
        help=(
            "Force a mode, skipping env-var classification. "
            "Useful for local testing without GitHub Actions env vars."
        ),
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    repo_root = _repo_root()

    # Resolve mode: CLI override takes precedence; else classify from env vars.
    if args.mode is not None:
        mode = args.mode
    else:
        mode = classify_ref(
            os.environ.get("GITHUB_EVENT_NAME", ""),
            os.environ.get("GITHUB_REF_TYPE", ""),
            os.environ.get("GITHUB_REF_NAME", ""),
            os.environ.get("GITHUB_BASE_REF", ""),
        )

    if mode == "full":
        # Full mode: no git diff, no index read needed.
        print(build_pytest_command(set(), "full"))
        sys.exit(0)

    # Selective mode.

    # Resolve and validate the index path (T-02-03: repo-escape guard).
    if args.index_path is not None:
        index_path = Path(args.index_path).resolve()
        try:
            index_path.relative_to(repo_root.resolve())
        except ValueError:
            raise ValueError(
                f"--index-path {index_path} escapes repo root {repo_root}; "
                "only paths inside the repository are allowed."
            )
    else:
        index_path = repo_root / "build" / "test_dependency_index.json"

    if not index_path.exists():
        raise FileNotFoundError(
            f"{index_path} not found — run 'python scripts/build_test_dependency_index.py' first "
            "(requires make analysis to have completed)."
        )

    with index_path.open() as f:
        index = json.load(f)

    # Determine base ref for git diff.
    base_ref = args.base_ref or os.environ.get("GITHUB_BASE_REF", "")
    if not base_ref:
        logger.error(
            "No base ref available: set GITHUB_BASE_REF or pass --base-ref."
        )
        sys.exit(1)

    changed = changed_vhd_files(base_ref, repo_root)
    selected = select_tests(changed, index)
    cmd = build_pytest_command(selected, "selective")

    if cmd is None:
        # SEL-07: empty selection -> log to stderr, print nothing, exit 0.
        print(
            "select_tests.py: zero tests selected — no surf production .vhd changed in this diff",
            file=sys.stderr,
        )
        sys.exit(0)

    print(cmd)
    sys.exit(0)


if __name__ == "__main__":
    main()
