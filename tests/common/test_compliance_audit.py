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

import json

from tests.common import compliance_audit


LICENSE_AND_METHODOLOGY = """\
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
##############################################################################

# Test methodology:
# - Sweep: Example.
# - Stimulus: Example.
# - Checks: Example.
# - Timing: Example.
"""


def _rules(findings):
    return [finding.rule for finding in findings]


def test_inventory_records_public_test_identifiers_and_controls():
    source = LICENSE_AND_METHODOLOGY + """
import cocotb
import pytest

RUN = "RUN_SAMPLE_KNOWN_ISSUE_TESTS"
SELECTOR = "COCOTB_TESTCASE"
FILTER = "COCOTB_TEST_FILTER"

@cocotb.test(timeout_time=2, timeout_unit="us")
async def transfer_test(dut):
    pass

@pytest.mark.skipif(True, reason="example")
@pytest.mark.parametrize("parameters", [pytest.param({}, id="default")])
def test_wrapper(parameters):
    pass
"""

    inventory = compliance_audit.inventory_source(source)

    assert inventory.cocotb_entrypoints == ("transfer_test",)
    assert inventory.pytest_functions == ("test_wrapper",)
    assert inventory.parameter_ids == ("default",)
    assert inventory.environment_controls == (
        "COCOTB_TESTCASE",
        "COCOTB_TEST_FILTER",
        "RUN_SAMPLE_KNOWN_ISSUE_TESTS",
    )
    assert inventory.skipped_functions == ("test_wrapper",)
    assert inventory.timeout_entrypoints == ("transfer_test",)


def test_inventory_recognizes_shared_filter_helper_as_selector_control():
    source = """
def test_wrapper(parameters):
    run(extra_env=cocotb_filtered_env(parameters, "default_test$"))
"""

    inventory = compliance_audit.inventory_source(source)

    assert inventory.environment_controls == ("COCOTB_TEST_FILTER",)


def test_audit_reports_high_and_low_confidence_screening_signals():
    source = """
import cocotb
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def routed_case(dut):
    if int(dut.mode.value) == 0:
        return
    cocotb.start_soon(run_monitor())
    while True:
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
"""

    findings = compliance_audit.audit_source(source)

    assert set(_rules(findings)) == {
        "early-bare-return",
        "missing-methodology",
        "unretained-start-soon",
        "open-ended-loop",
        "edge-then-timer",
    }
    assert len(findings) == 5
    assert {finding.symbol for finding in findings} == {"<module>", "routed_case"}


def test_audit_classifies_returns_by_prior_test_activity_not_line_distance():
    source = LICENSE_AND_METHODOLOGY + '''
import cocotb

@cocotb.test()
async def prestimulus_return(dut):
    """A long description can move a no-op return far below the decorator.

    The rule must still recognize that the function has performed no awaited
    simulator operation and made no assertion before taking this branch.
    """
    mode = 1
    if mode:
        return

@cocotb.test()
async def successful_terminal_path(dut):
    await exercise_named_behavior(dut)
    assert dut.done.value
    if dut.short_path.value:
        return
'''

    findings = compliance_audit.audit_source(source)
    returns = [finding for finding in findings if "bare-return" in finding.rule]

    assert {(finding.rule, finding.symbol) for finding in returns} == {
        ("early-bare-return", "prestimulus_return"),
        ("bare-return", "successful_terminal_path"),
    }


def test_audit_ignores_retained_tasks_and_clock_tasks():
    source = LICENSE_AND_METHODOLOGY + """
import cocotb
from cocotb.clock import Clock

@cocotb.test()
async def task_case(dut):
    monitor_task = cocotb.start_soon(run_monitor())
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await monitor_task
"""

    findings = compliance_audit.audit_source(source)

    assert "unretained-start-soon" not in _rules(findings)


def test_audit_distinguishes_documented_lifetime_agents_from_unbounded_operations():
    source = '''
async def monitor():
    """Lifetime agent: observe accepted transfers until the test ends."""
    while True:
        await sample_transfer()

async def receive_transaction():
    while True:
        await sample_transfer()
        if complete():
            break
'''

    findings = compliance_audit.audit_source(source)
    loops = [finding for finding in findings if finding.rule == "open-ended-loop"]

    assert [(finding.symbol, finding.line) for finding in loops] == [
        ("receive_transaction", 8),
    ]


def test_audit_reports_direct_runner_except_documented_simlink_helper():
    source = """
from cocotb_test.simulator import run

def test_wrapper():
    run(toplevel="surf.target")
"""

    ordinary = compliance_audit.audit_source(
        source,
        "tests/axi/test_target.py",
    )
    simlink = compliance_audit.audit_source(
        source,
        "tests/simlink/ghdl/simlink_test_utils.py",
    )

    assert _rules(ordinary) == ["direct-runner"]
    assert simlink == ()


def test_audit_detects_literal_source_already_in_import(tmp_path):
    source_path = tmp_path / "base" / "rtl" / "Target.vhd"
    source_path.parent.mkdir(parents=True)
    source_path.write_text("entity Target is end entity;\n", encoding="utf-8")

    source = """
def test_wrapper():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.target",
        extra_vhdl_sources={"surf": ["base/rtl/Target.vhd"]},
    )
"""

    findings = compliance_audit.audit_source(
        source,
        "tests/base/test_Target.py",
        repo_root=tmp_path,
        imported_sources=frozenset({source_path.resolve()}),
    )

    assert _rules(findings) == ["duplicate-imported-source"]
    assert "base/rtl/Target.vhd" in findings[0].detail


def test_discovery_excludes_legacy_build_and_cache_directories(tmp_path):
    included = tmp_path / "tests" / "base" / "test_included.py"
    included.parent.mkdir(parents=True)
    included.write_text("def test_included(): pass\n", encoding="utf-8")

    for directory in ("legacy", "sim_build", "__pycache__"):
        excluded = tmp_path / "tests" / directory / "test_excluded.py"
        excluded.parent.mkdir(parents=True)
        excluded.write_text("def test_excluded(): pass\n", encoding="utf-8")

    discovered = compliance_audit.discover_python_files(("tests",), tmp_path)

    assert discovered == (included.resolve(),)


def test_preservation_comparison_reports_removed_and_added_identifiers():
    before = {
        "schema_version": compliance_audit.SCHEMA_VERSION,
        "files": {
            "tests/test_target.py": {
                "cocotb_entrypoints": ["old_case"],
                "pytest_functions": ["test_target"],
            },
        },
    }
    after = {
        "schema_version": compliance_audit.SCHEMA_VERSION,
        "files": {
            "tests/test_target.py": {
                "cocotb_entrypoints": ["new_case"],
                "pytest_functions": ["test_target"],
            },
        },
    }

    delta = compliance_audit.compare_preservation_reports(before, after)

    assert delta.removed == {
        "tests/test_target.py": {"cocotb_entrypoints": ("old_case",)},
    }
    assert delta.added == {
        "tests/test_target.py": {"cocotb_entrypoints": ("new_case",)},
    }
    assert delta.has_removals is True


def test_compliance_baseline_allows_cleanup_but_rejects_new_findings():
    baseline = {
        "schema_version": compliance_audit.SCHEMA_VERSION,
        "rules": {
            "direct-runner": {"tests/old.py": 1},
            "duplicate-imported-source": {"tests/sources.py": 2},
            "early-bare-return": {"tests/ambiguous.py": 1},
            "missing-methodology": {},
            "open-ended-loop": {},
            "unretained-start-soon": {},
        },
    }
    findings = (
        compliance_audit.Finding(
            "duplicate-imported-source",
            "tests/sources.py",
            10,
            "<module>",
            "existing",
        ),
        compliance_audit.Finding(
            "missing-methodology",
            "tests/new.py",
            1,
            "<module>",
            "new",
        ),
        compliance_audit.Finding(
            "early-bare-return",
            "tests/ambiguous.py",
            20,
            "scenario",
            "not enforced yet",
        ),
    )

    delta = compliance_audit.compare_compliance_baseline(baseline, findings)

    assert delta.new == {"missing-methodology": {"tests/new.py": 1}}
    assert delta.reduced == {
        "direct-runner": {"tests/old.py": 1},
        "duplicate-imported-source": {"tests/sources.py": 1},
    }
    assert delta.has_new is True


def test_compliance_baseline_counts_findings_by_rule_and_path():
    findings = (
        compliance_audit.Finding(
            "duplicate-imported-source",
            "tests/source.py",
            10,
            "<module>",
            "one",
        ),
        compliance_audit.Finding(
            "duplicate-imported-source",
            "tests/source.py",
            11,
            "<module>",
            "two",
        ),
        compliance_audit.Finding(
            "edge-then-timer",
            "tests/timing.py",
            12,
            "scenario",
            "reported only",
        ),
    )

    baseline = compliance_audit.compliance_baseline(findings)

    assert baseline == {
        "schema_version": compliance_audit.SCHEMA_VERSION,
        "rules": {
            "direct-runner": {},
            "duplicate-imported-source": {"tests/source.py": 2},
            "early-bare-return": {},
            "missing-methodology": {},
            "open-ended-loop": {},
            "unretained-start-soon": {},
        },
    }


def test_repository_does_not_exceed_compliance_baseline():
    baseline = json.loads(
        compliance_audit.DEFAULT_BASELINE.read_text(encoding="utf-8")
    )
    findings = compliance_audit.audit_paths(("tests",))

    delta = compliance_audit.compare_compliance_baseline(baseline, findings)

    assert not delta.has_new, compliance_audit._baseline_delta_text(delta)


def test_inventory_cli_writes_reproducible_json(tmp_path):
    test_file = tmp_path / "tests" / "test_target.py"
    test_file.parent.mkdir()
    test_file.write_text(
        LICENSE_AND_METHODOLOGY
        + """
import cocotb

@cocotb.test()
async def target_case(dut):
    pass

def test_target():
    pass
""",
        encoding="utf-8",
    )
    output = tmp_path / "inventory.json"

    result = compliance_audit.main(
        ["inventory", "tests", "--output", str(output)],
        repo_root=tmp_path,
    )

    assert result == 0
    report = json.loads(output.read_text(encoding="utf-8"))
    assert report == {
        "schema_version": compliance_audit.SCHEMA_VERSION,
        "files": {
            "tests/test_target.py": {
                "cocotb_entrypoints": ["target_case"],
                "environment_controls": [],
                "parameter_ids": [],
                "pytest_functions": ["test_target"],
                "skipped_functions": [],
                "timeout_entrypoints": [],
            },
        },
    }


def test_compare_cli_fails_when_identifiers_are_removed(tmp_path):
    before = tmp_path / "before.json"
    after = tmp_path / "after.json"
    output = tmp_path / "delta.json"
    before.write_text(
        json.dumps(
            {
                "schema_version": compliance_audit.SCHEMA_VERSION,
                "files": {"tests/test.py": {"pytest_functions": ["test_one"]}},
            }
        ),
        encoding="utf-8",
    )
    after.write_text(
        json.dumps(
            {
                "schema_version": compliance_audit.SCHEMA_VERSION,
                "files": {"tests/test.py": {"pytest_functions": []}},
            }
        ),
        encoding="utf-8",
    )

    result = compliance_audit.main(
        ["compare", str(before), str(after), "--json", "--output", str(output)],
        repo_root=tmp_path,
    )

    assert result == 1
    delta = json.loads(output.read_text(encoding="utf-8"))
    assert delta["removed"] == {
        "tests/test.py": {"pytest_functions": ["test_one"]},
    }
