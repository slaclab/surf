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

_FOUNDATIONAL_TREES = (
    "axi",
    "base",
    "protocols/rssi",
    "protocols/srp",
    "protocols/ssi",
    "tests/axi",
    "tests/base",
    "tests/common",
)

_ETHERNET_SOURCE_DEPENDENTS = {
    "EthMacCore": ("IpV4Engine", "RoCEv2", "UdpEngine"),
    "IpV4Engine": ("UdpEngine",),
}

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


def _in_tree(path: str, tree: str) -> bool:
    return path == tree or path.startswith(f"{tree}/")


def _area_from_path(path: PurePosixPath, tree: str) -> tuple[str | None, bool]:
    parts = path.parts
    is_test_path = len(parts) >= 2 and parts[:2] == ("tests", tree)
    area_index = 2 if is_test_path else 1

    if not parts or (parts[0] != tree and not is_test_path) or len(parts) <= area_index:
        return None, is_test_path

    area = parts[area_index]
    if not area.replace("_", "").replace("-", "").isalnum():
        return None, is_test_path
    return area, is_test_path


def _owned_test_target(tree: str, area: str, repo_root: Path) -> str | None:
    target = f"tests/{tree}/{area}"
    return target if (repo_root / target).is_dir() else None


def _protocol_target(path: PurePosixPath, repo_root: Path) -> str:
    area, _ = _area_from_path(path, "protocols")

    if area is None:
        return "tests/protocols"

    target = _owned_test_target("protocols", area.replace("-", "_"), repo_root)
    return target or "tests/protocols"


def _ethernet_targets(path: PurePosixPath, repo_root: Path) -> tuple[str, ...] | None:
    area, is_test_path = _area_from_path(path, "ethernet")
    if area is None:
        return None

    selected_areas = (area,)
    if not is_test_path:
        selected_areas += _ETHERNET_SOURCE_DEPENDENTS.get(area, ())

    targets: list[str] = []
    for selected_area in sorted(selected_areas):
        target = _owned_test_target("ethernet", selected_area, repo_root)
        if target is None:
            return None
        targets.append(target)
    return tuple(targets)


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

        if any(_in_tree(path, tree) for tree in _FOUNDATIONAL_TREES):
            return Selection((), True, f"foundational area changed: {path}")

        if _in_tree(path, "dsp") or _in_tree(path, "tests/dsp"):
            targets.add("tests/dsp")
            continue

        if _in_tree(path, "protocols") or _in_tree(path, "tests/protocols"):
            targets.add(_protocol_target(pure_path, repo_root))
            continue

        if _in_tree(path, "ethernet") or _in_tree(path, "tests/ethernet"):
            ethernet_targets = _ethernet_targets(pure_path, repo_root)
            if ethernet_targets is None:
                return Selection((), True, f"Ethernet area has no owned selective suite: {path}")
            targets.update(ethernet_targets)
            continue

        return Selection((), True, f"unmapped path changed: {path}")

    return Selection(tuple(sorted(targets)))
