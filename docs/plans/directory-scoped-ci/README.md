# Directory-Scoped CI Selection

## Goal

Replace PR #1449's runtime VHDL dependency graph with a conservative,
directory-owned test selector. Feature branches should get faster feedback for
localized protocol, DSP, and enabled Ethernet changes without making `.cf`
parsing, AST analysis, wrapper attribution, or a second GHDL installation part
of the CI policy.

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
- Enabled Ethernet routing accounts for the current source relationships:
  - `RoCEv2` changes select `tests/ethernet/RoCEv2/`.
  - `UdpEngine` and `IpV4Engine` changes select
    `tests/ethernet/UdpEngine/`.
  - `EthMacCore` changes select both enabled Ethernet suites because both use
    `EthMacPkg`.
  - Changes within either enabled Ethernet test directory select that directory
    only. Other Ethernet areas force a full run until they join the full CI
    universe.
- `tests/common/` always runs on selective CI executions.
- Any selector error fails open to the full suite.

## Implementation

- `.github/workflows/surf_ci.yml` owns trigger classification and pytest
  invocation. Its full regression target array is defined once and reused by
  integration runs and selective-mode fallbacks.
- `tests/common/path_selector.py` owns changed-file parsing and pure path-to-test
  routing.
- `python -m tests.common` prints pytest directory targets or `FORCE_FULL`.
- `tests/common/test_path_selector.py` covers routing, conservative fallbacks,
  merge-base behavior, and the CLI contract.

## Status

Implementation is complete on `ci-test-cherry-pick-using-GHDL-cf-file` and is
ready for review.

## Validation

- `./.venv/bin/python -m pytest -q tests/common`: `38 passed`.
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

The selector intentionally does not infer arbitrary dependencies between
different protocol areas. Ethernet cross-area routing is explicit only for the
currently enabled suites and their known `IpV4Engine`/`EthMacPkg` relationships.
A localized feature push can therefore omit another downstream area. The full
post-merge `pre-release` run and the full release PR run remain the authoritative
integration gates. This is the maintenance-for-minimality tradeoff selected for
this design.
