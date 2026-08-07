##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Exercise localized protocol/DSP/Ethernet paths and each full-run class.
# - Stimulus: Pass synthetic git change records to the pure path selector and CLI.
# - Checks: Verify exact pytest targets, deduplication, and FORCE_FULL behavior.
# - Timing: Pure-Python policy tests; no simulator timing behavior is involved.

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
import subprocess

import pytest

from tests.common import __main__ as selector_cli
from tests.common import path_selector


_PROTOCOL_AREA_CASES = (
    ("packetizer", "packetizer"),
    ("event-frame-sequencer", "event_frame_sequencer"),
    ("hamming-ecc", "hamming_ecc"),
    ("line-codes", "line_codes"),
)

_ETHERNET_SOURCE_CASES = (
    ("EthMacCore", ("EthMacCore", "IpV4Engine", "RoCEv2", "UdpEngine")),
    ("IpV4Engine", ("IpV4Engine", "UdpEngine")),
    ("RawEthFramer", ("RawEthFramer",)),
    ("RoCEv2", ("RoCEv2",)),
    ("UdpEngine", ("UdpEngine",)),
)


def _change(path: str, status: str = "M") -> path_selector.ChangedFile:
    return path_selector.ChangedFile(path=path, status=status)


def _ethernet_test_targets(areas: tuple[str, ...]) -> tuple[str, ...]:
    return tuple(f"tests/ethernet/{area}" for area in areas)


def _add_test_areas(repo_root: Path, tree: str, areas: tuple[str, ...]) -> None:
    for area in areas:
        (repo_root / "tests" / tree / area).mkdir(parents=True, exist_ok=True)


@pytest.mark.parametrize(
    ("source_area", "test_area"),
    _PROTOCOL_AREA_CASES,
)
@pytest.mark.parametrize("is_test_path", (False, True))
def test_protocol_change_selects_owned_test_area(tmp_path, source_area, test_area, is_test_path):
    _add_test_areas(tmp_path, "protocols", (test_area,))
    if is_test_path:
        path = f"tests/protocols/{test_area}/test_changed.py"
    else:
        path = f"protocols/{source_area}/rtl/Changed.vhd"

    selection = path_selector.select_targets([_change(path)], tmp_path)

    assert selection == path_selector.Selection((f"tests/protocols/{test_area}",))


@pytest.mark.parametrize(
    "path",
    ("dsp/generic/rtl/Changed.vhd", "tests/dsp/generic/test_changed.py"),
)
def test_dsp_change_selects_dsp_tests(tmp_path, path):
    selection = path_selector.select_targets([_change(path)], tmp_path)

    assert selection == path_selector.Selection(("tests/dsp",))


def test_protocol_without_owned_test_area_runs_all_protocol_tests(tmp_path):
    selection = path_selector.select_targets(
        [_change("protocols/unowned/rtl/Changed.vhd")],
        tmp_path,
    )

    assert selection.targets == ("tests/protocols",)
    assert selection.force_full is False


def test_multiple_areas_are_sorted_and_deduplicated(tmp_path):
    _add_test_areas(tmp_path, "protocols", ("packetizer",))
    selection = path_selector.select_targets(
        [
            _change("protocols/packetizer/rtl/Changed.vhd"),
            _change("dsp/generic/rtl/Changed.vhd"),
            _change("tests/protocols/packetizer/test_changed.py"),
        ],
        tmp_path,
    )

    assert selection.targets == ("tests/dsp", "tests/protocols/packetizer")


@pytest.mark.parametrize(
    ("area", "selected_areas"),
    _ETHERNET_SOURCE_CASES,
)
def test_ethernet_source_change_selects_area_and_dependents(tmp_path, area, selected_areas):
    _add_test_areas(tmp_path, "ethernet", selected_areas)
    selection = path_selector.select_targets(
        [_change(f"ethernet/{area}/rtl/Changed.vhd")],
        tmp_path,
    )

    assert selection.targets == _ethernet_test_targets(selected_areas)
    assert selection.force_full is False


@pytest.mark.parametrize("area", tuple(area for area, _ in _ETHERNET_SOURCE_CASES))
def test_ethernet_test_change_selects_only_its_area(tmp_path, area):
    _add_test_areas(tmp_path, "ethernet", (area,))
    selection = path_selector.select_targets(
        [_change(f"tests/ethernet/{area}/test_changed.py")],
        tmp_path,
    )

    assert selection == path_selector.Selection((f"tests/ethernet/{area}",))


def test_new_ethernet_area_with_owned_tests_selects_its_area(tmp_path):
    _add_test_areas(tmp_path, "ethernet", ("NewArea",))
    selection = path_selector.select_targets(
        [_change("ethernet/NewArea/rtl/Changed.vhd")],
        tmp_path,
    )

    assert selection == path_selector.Selection(("tests/ethernet/NewArea",))


def test_combines_ethernet_and_protocol_targets(tmp_path):
    _add_test_areas(tmp_path, "ethernet", ("RoCEv2",))
    _add_test_areas(tmp_path, "protocols", ("packetizer",))
    selection = path_selector.select_targets(
        [
            _change("ethernet/RoCEv2/rtl/Changed.vhd"),
            _change("protocols/packetizer/rtl/Changed.vhd"),
        ],
        tmp_path,
    )

    assert selection.targets == ("tests/ethernet/RoCEv2", "tests/protocols/packetizer")


@pytest.mark.parametrize("area", ("rssi", "srp", "ssi"))
def test_cross_area_protocol_source_change_forces_full(tmp_path, area):
    selection = path_selector.select_targets(
        [_change(f"protocols/{area}/rtl/Changed.vhd")],
        tmp_path,
    )

    assert selection.force_full is True
    assert selection.reason == f"foundational area changed: protocols/{area}/rtl/Changed.vhd"


@pytest.mark.parametrize("area", ("rssi", "srp", "ssi"))
def test_cross_area_protocol_test_change_selects_owned_suite(tmp_path, area):
    _add_test_areas(tmp_path, "protocols", (area,))
    selection = path_selector.select_targets(
        [_change(f"tests/protocols/{area}/test_changed.py")],
        tmp_path,
    )

    assert selection == path_selector.Selection((f"tests/protocols/{area}",))


@pytest.mark.parametrize(
    ("path", "reason"),
    (
        ("base/general/rtl/StdRtlPkg.vhd", "foundational area"),
        ("axi/axi-stream/rtl/AxiStreamPkg.vhd", "foundational area"),
        ("tests/base/fifo/test_Fifo.py", "foundational area"),
        ("tests/axi/axi_stream/test_AxiStreamPkg.py", "foundational area"),
        ("tests/common/path_selector.py", "foundational area"),
        (".github/workflows/surf_ci.yml", "CI configuration"),
        ("protocols/ssi/ruckus.tcl", "build control file"),
        ("ethernet/UnknownArea/rtl/Unknown.vhd", "no owned selective suite"),
        ("python/surf/__init__.py", "unmapped path"),
        ("README.md", "unmapped path"),
    ),
)
def test_force_full_paths(tmp_path, path, reason):
    selection = path_selector.select_targets([_change(path)], tmp_path)

    assert selection.force_full is True
    assert reason in selection.reason


@pytest.mark.parametrize("status", ("C", "D", "R", "T", "U"))
def test_non_add_or_modify_status_forces_full(tmp_path, status):
    selection = path_selector.select_targets(
        [_change("protocols/ssi/rtl/Changed.vhd", status)],
        tmp_path,
    )

    assert selection.force_full is True
    assert selection.reason.startswith(f"{status} change")


def test_no_changes_selects_no_area_targets(tmp_path):
    assert path_selector.select_targets([], tmp_path) == path_selector.Selection(())


def test_changed_files_parses_nul_delimited_git_output(monkeypatch, tmp_path):
    output = (
        b"M\0protocols/ssi/rtl/SsiFifo.vhd\0"
        b"A\0tests/protocols/ssi/test_SsiFifo.py\0"
        b"R097\0protocols/old.vhd\0protocols/new.vhd\0"
    )

    def fake_run(*args, **kwargs):
        return SimpleNamespace(stdout=output)

    monkeypatch.setattr(subprocess, "run", fake_run)

    assert path_selector.changed_files("base-sha", tmp_path) == (
        _change("protocols/ssi/rtl/SsiFifo.vhd"),
        _change("tests/protocols/ssi/test_SsiFifo.py", "A"),
        path_selector.ChangedFile("protocols/new.vhd", "R", "protocols/old.vhd"),
    )


@pytest.mark.parametrize("status", ("A", "C", "D", "M", "R", "T", "U", "X"))
def test_changed_files_override_accepts_one_letter_git_status(status):
    changes = selector_cli._parse_changed_files_override(f"protocols/ssi/rtl/Changed.vhd:{status}")

    assert changes == (_change("protocols/ssi/rtl/Changed.vhd", status),)


def test_merge_base_uses_pre_release_by_default(monkeypatch, tmp_path):
    calls = []

    def fake_run(command, **kwargs):
        calls.append((command, kwargs))
        return SimpleNamespace(stdout="abc123\n")

    monkeypatch.setattr(subprocess, "run", fake_run)

    assert path_selector.merge_base(repo_root=tmp_path) == "abc123"
    assert calls[0][0] == ["git", "merge-base", "origin/pre-release", "HEAD"]
    assert calls[0][1]["cwd"] == tmp_path


def test_cli_prints_directory_targets(capsys, tmp_path):
    _add_test_areas(tmp_path, "protocols", ("packetizer",))
    result = selector_cli.main(
        ["--changed-files-override", "protocols/packetizer/rtl/Changed.vhd,dsp/generic/rtl/Changed.vhd"],
        tmp_path,
    )

    captured = capsys.readouterr()
    assert result == 0
    assert captured.out.splitlines() == ["tests/dsp", "tests/protocols/packetizer"]
    assert "2 changed file(s)" in captured.err


def test_cli_force_full_is_a_successful_policy_result(capsys, tmp_path):
    result = selector_cli.main(
        ["--changed-files-override", "base/general/rtl/StdRtlPkg.vhd"],
        tmp_path,
    )

    captured = capsys.readouterr()
    assert result == 0
    assert captured.out.splitlines() == [path_selector.FORCE_FULL]
    assert "foundational area" in captured.err


def test_cli_git_error_fails_open(monkeypatch, capsys, tmp_path):
    def fail_merge_base(*args, **kwargs):
        raise subprocess.CalledProcessError(1, ["git", "merge-base"])

    monkeypatch.setattr(path_selector, "merge_base", fail_merge_base)

    result = selector_cli.main([], Path(tmp_path))

    captured = capsys.readouterr()
    assert result == 1
    assert captured.out.splitlines() == [path_selector.FORCE_FULL]
    assert "could not determine changed files" in captured.err
