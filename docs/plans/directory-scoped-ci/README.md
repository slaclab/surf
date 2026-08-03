# Directory-Scoped CI Selection

## Goal

Replace PR #1449's runtime VHDL dependency graph with a conservative,
directory-owned test selector. Feature branches should get faster feedback for
localized protocol and DSP changes without making `.cf` parsing, AST analysis,
wrapper attribution, or a second GHDL installation part of the CI policy.

## Policy

- Feature-branch pushes compare their changes with `origin/pre-release`.
- Pushes to `pre-release` and `main`, tag pushes, and pull requests targeting
  `main` run the full regression suite.
- Changes under `base/`, `axi/`, their matching test trees, `tests/common/`,
  CI/build manifests, deletions, renames, and unknown paths force the full
  suite.
- `protocols/<area>/` and `tests/protocols/<area>/` changes select the matching
  `tests/protocols/<area>/` directory. Hyphenated source-area names map to the
  underscore form used by the test tree. If an area has no matching test
  directory, all of `tests/protocols/` runs.
- `dsp/` and `tests/dsp/` changes select `tests/dsp/`.
- `tests/common/` always runs on selective CI executions.
- Any selector error fails open to the full suite.

## Implementation

- `.github/workflows/surf_ci.yml` owns trigger classification and pytest
  invocation.
- `tests/common/path_selector.py` owns changed-file parsing and pure path-to-test
  routing.
- `python -m tests.common` prints pytest directory targets or `FORCE_FULL`.
- `tests/common/test_path_selector.py` covers routing, conservative fallbacks,
  merge-base behavior, and the CLI contract.

## Status

Implementation is complete on `ci-test-cherry-pick-using-GHDL-cf-file` and is
ready for review.

## Validation

- `./.venv/bin/python -m pytest -q tests/common`: `29 passed`.
- Focused flake8 for the three selector/CLI test files: passed.
- `python -m compileall -q -f tests/common`: passed.
- `git diff --check`: passed.
- Workflow YAML syntax load: passed.
- Manual CLI checks covered a single protocol area, hyphen-to-underscore area
  mapping, combined protocol/DSP selection, foundational force-full behavior,
  and the branch's real diff.

No HDL behavior changed, so a full simulator regression was not run locally.
The branch CI run is expected to take the force-full route because this change
edits both `.github/workflows/surf_ci.yml` and `tests/common/`.

## Accepted Tradeoff

The selector intentionally does not infer dependencies between different
protocol areas. A localized feature push can therefore omit a downstream area
that consumes the changed protocol. The full post-merge `pre-release` run and
the full release PR run remain the authoritative integration gates. This is the
maintenance-for-minimality tradeoff selected for this design.
