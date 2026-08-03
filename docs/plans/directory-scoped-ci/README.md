# Directory-Scoped CI Selection

## Goal

Replace PR #1449's runtime VHDL dependency graph with a conservative,
directory-owned test selector. Feature branches should get faster feedback for
localized protocol, DSP, and Ethernet changes without making `.cf`
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
- Ethernet routing accounts for the current source relationships:
  - An area with a matching `tests/ethernet/<area>/` directory selects its own
    suite automatically.
  - `IpV4Engine` changes select its own suite and `tests/ethernet/UdpEngine/`.
  - `EthMacCore` changes select its own suite plus the `IpV4Engine`, `RoCEv2`,
    and `UdpEngine` suites because those areas build on the MAC interfaces and
    package definitions.
  - Changes within an Ethernet test directory select that directory only.
    Ethernet areas without an owned suite force a full run.
- The full regression uses `tests/` as its single target so every current and
  future pytest suite is included without maintaining an allowlist in the
  workflow.
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
  merge-base behavior, and the CLI contract using synthetic paths and temporary
  test-directory layouts.
- A manually dispatched workflow may provide a comma-separated
  `changed_files_override` to exercise the selective execution path on a real
  GitHub runner. The override is ignored for push and pull-request events, and
  the workflow writes its selection to the Actions job summary.

## Status

Implementation is complete on `ci-test-cherry-pick-using-GHDL-cf-file` and is
ready for review.

## Validation

- `./.venv/bin/python -m pytest -q tests/common`: `53 passed`.
- `./.venv/bin/python -m pytest -q -n 0 tests/ethernet/EthMacCore`:
  `42 passed`.
- `./.venv/bin/python -m pytest -q -n 0 tests/ethernet/IpV4Engine`: `7 passed`.
- `./.venv/bin/python -m pytest -q -n 0 tests/ethernet/RawEthFramer`: `4 passed`.
- Parallel combined run of those three suites with `-n auto --dist=worksteal`:
  `53 passed`.
- Focused flake8 for the three selector/CLI test files: passed.
- `python -m compileall -q -f tests/common`: passed.
- `git diff --check`: passed.
- Workflow YAML syntax load: passed.
- Collection comparison confirmed that the single `tests/` target and the old
  top-level target list select the same 914 tests.
- Manual CLI checks covered a single protocol area, hyphen-to-underscore area
  mapping, Ethernet ownership and dependency exceptions, combined
  protocol/DSP selection, foundational force-full behavior, one-letter Git
  statuses, and the branch's real diff.

No HDL behavior changed, and the three newly enabled suites required no fixes.
The next branch CI run is expected to take the force-full route because this
change edits both `.github/workflows/surf_ci.yml` and `tests/common/`.

A prior manually dispatched narrow validation using
`protocols/ssi/rtl/SsiFifo.vhd` selected
`tests/common tests/protocols/ssi` and passed all 223 tests. The ordinary push
run remained a full regression as intended.

## Accepted Tradeoff

The selector intentionally does not infer arbitrary dependencies between
different protocol areas. Ethernet cross-area routing is explicit only for the
known `IpV4Engine` and `EthMacCore` dependency exceptions.
A localized feature push can therefore omit another downstream area. The full
post-merge `pre-release` run and the full release PR run remain the authoritative
integration gates. This is the maintenance-for-minimality tradeoff selected for
this design.
