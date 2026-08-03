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

from tests.common import path_selector
from tests.common.regression_utils import REPO_ROOT


def _parse_changed_files_override(raw: str) -> tuple[path_selector.ChangedFile, ...]:
    changes: list[path_selector.ChangedFile] = []
    for entry in raw.split(","):
        entry = entry.strip()
        if not entry:
            continue
        path, separator, status = entry.rpartition(":")
        if not separator or len(status) != 1 or not status.isascii() or not status.isupper():
            path = entry
            status = "M"
        changes.append(path_selector.ChangedFile(path=path, status=status))
    return tuple(changes)


def main(argv: list[str] | None = None, repo_root: Path = REPO_ROOT) -> int:
    parser = argparse.ArgumentParser(
        description="Print directory-owned pytest targets for the current change set, "
        "or FORCE_FULL when a safe coarse selection cannot be made."
    )
    parser.add_argument(
        "--base-ref",
        default=path_selector.BASE_REF,
        help=f"Integration ref used for the feature-branch merge base (default: {path_selector.BASE_REF}).",
    )
    parser.add_argument(
        "--changed-files-override",
        help="Comma-separated repo-relative paths used instead of git diff. "
        "Append a one-letter Git status such as :A, :D, :R, :T, or :U when needed.",
    )
    args = parser.parse_args(argv)

    if args.changed_files_override is not None:
        changes = _parse_changed_files_override(args.changed_files_override)
    else:
        try:
            base = path_selector.merge_base(args.base_ref, repo_root)
            changes = path_selector.changed_files(base, repo_root)
        except (FileNotFoundError, ValueError, subprocess.CalledProcessError) as exc:
            print(path_selector.FORCE_FULL)
            print(f"rationale: could not determine changed files ({exc})", file=sys.stderr)
            return 1

    selection = path_selector.select_targets(changes, repo_root)
    if selection.force_full:
        print(path_selector.FORCE_FULL)
        print(f"rationale: {selection.reason}", file=sys.stderr)
        return 0

    for target in selection.targets:
        print(target)

    target_summary = ", ".join(selection.targets) if selection.targets else "tests/common only"
    print(
        f"rationale: {len(changes)} changed file(s) selected {target_summary}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
