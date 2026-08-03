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

from dataclasses import dataclass
from pathlib import Path, PurePosixPath
import subprocess

from tests.common.regression_utils import REPO_ROOT


BASE_REF = "origin/pre-release"
FORCE_FULL = "FORCE_FULL"

_FOUNDATIONAL_PREFIXES = (
    "axi/",
    "base/",
    "tests/axi/",
    "tests/base/",
    "tests/common/",
)

_BUILD_CONTROL_NAMES = {
    "Makefile",
    "pip_requirements.txt",
    "ruckus.tcl",
    "setup.py",
}


@dataclass(frozen=True)
class ChangedFile:
    path: str
    status: str = "M"
    old_path: str | None = None


@dataclass(frozen=True)
class Selection:
    targets: tuple[str, ...]
    force_full: bool = False
    reason: str = ""


def merge_base(base_ref: str = BASE_REF, repo_root: Path = REPO_ROOT) -> str:
    """Return the merge base between the integration ref and HEAD."""

    result = subprocess.run(
        ["git", "merge-base", base_ref, "HEAD"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def changed_files(base: str, repo_root: Path = REPO_ROOT) -> tuple[ChangedFile, ...]:
    """Return added, modified, deleted, copied, and renamed paths since base."""

    result = subprocess.run(
        ["git", "diff", "--name-status", "-z", "-M", "-C", base, "HEAD"],
        cwd=repo_root,
        check=True,
        capture_output=True,
    )
    fields = result.stdout.split(b"\0")
    if fields and not fields[-1]:
        fields.pop()

    changes: list[ChangedFile] = []
    index = 0
    while index < len(fields):
        status_token = fields[index].decode("ascii")
        index += 1
        status = status_token[:1]
        if not status:
            raise ValueError("git diff returned an empty status")

        if status in {"C", "R"}:
            if index + 1 >= len(fields):
                raise ValueError(f"git diff returned an incomplete {status} record")
            old_path = fields[index].decode("utf-8", errors="surrogateescape")
            path = fields[index + 1].decode("utf-8", errors="surrogateescape")
            index += 2
            changes.append(ChangedFile(path=path, status=status, old_path=old_path))
        else:
            if index >= len(fields):
                raise ValueError(f"git diff returned an incomplete {status} record")
            path = fields[index].decode("utf-8", errors="surrogateescape")
            index += 1
            changes.append(ChangedFile(path=path, status=status))

    return tuple(changes)


def _protocol_target(path: PurePosixPath, repo_root: Path) -> str:
    parts = path.parts
    source_tree = parts[0] == "protocols"
    area_index = 1 if source_tree else 2

    if len(parts) <= area_index or not parts[area_index].replace("_", "").replace("-", "").isalnum():
        return "tests/protocols"

    area = parts[area_index].replace("-", "_")
    target = f"tests/protocols/{area}"
    if (repo_root / target).is_dir():
        return target
    return "tests/protocols"


def select_targets(
    changes: tuple[ChangedFile, ...] | list[ChangedFile],
    repo_root: Path = REPO_ROOT,
) -> Selection:
    """Map changed paths to conservative pytest directory targets."""

    targets: set[str] = set()
    for change in changes:
        path = change.path.removeprefix("./")
        pure_path = PurePosixPath(path)

        if change.status not in {"A", "M"}:
            return Selection((), True, f"{change.status} change requires a full run: {path}")

        if path.startswith(".github/"):
            return Selection((), True, f"CI configuration changed: {path}")

        if pure_path.name in _BUILD_CONTROL_NAMES or pure_path.suffix in {".tcl", ".mk"}:
            return Selection((), True, f"build control file changed: {path}")

        if any(path == prefix[:-1] or path.startswith(prefix) for prefix in _FOUNDATIONAL_PREFIXES):
            return Selection((), True, f"foundational area changed: {path}")

        if path == "dsp" or path.startswith("dsp/") or path == "tests/dsp" or path.startswith("tests/dsp/"):
            targets.add("tests/dsp")
            continue

        if path == "protocols" or path.startswith("protocols/"):
            targets.add(_protocol_target(pure_path, repo_root))
            continue

        if path == "tests/protocols" or path.startswith("tests/protocols/"):
            targets.add(_protocol_target(pure_path, repo_root))
            continue

        return Selection((), True, f"unmapped path changed: {path}")

    return Selection(tuple(sorted(targets)))
