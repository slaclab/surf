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
from tests.common.regression_utils import REPO_ROOT


def _change(path: str, status: str = "M") -> path_selector.ChangedFile:
    return path_selector.ChangedFile(path=path, status=status)


@pytest.mark.parametrize(
    ("path", "target"),
    (
        ("protocols/packetizer/rtl/AxiStreamPacketizer.vhd", "tests/protocols/packetizer"),
        ("tests/protocols/packetizer/test_AxiStreamPacketizer.py", "tests/protocols/packetizer"),
        ("protocols/event-frame-sequencer/rtl/EventFrameSequencer.vhd", "tests/protocols/event_frame_sequencer"),
        ("protocols/hamming-ecc/rtl/HammingEccPkg.vhd", "tests/protocols/hamming_ecc"),
        ("protocols/line-codes/rtl/Code8b10bPkg.vhd", "tests/protocols/line_codes"),
        ("dsp/generic/rtl/FirFilter.vhd", "tests/dsp"),
        ("tests/dsp/generic/test_FirFilter.py", "tests/dsp"),
    ),
)
def test_selects_owned_test_area(path, target):
    selection = path_selector.select_targets([_change(path)], REPO_ROOT)

    assert selection == path_selector.Selection((target,))


def test_protocol_without_owned_test_area_runs_all_protocol_tests():
    selection = path_selector.select_targets(
        [_change("protocols/pmbus/rtl/PMBusCore.vhd")],
        REPO_ROOT,
    )

    assert selection.targets == ("tests/protocols",)
    assert selection.force_full is False


def test_multiple_areas_are_sorted_and_deduplicated():
    selection = path_selector.select_targets(
        [
            _change("protocols/ssi/rtl/SsiFifo.vhd"),
            _change("dsp/generic/rtl/FirFilter.vhd"),
            _change("tests/protocols/ssi/test_SsiFifo.py"),
        ],
        REPO_ROOT,
    )

    assert selection.targets == ("tests/dsp", "tests/protocols/ssi")


@pytest.mark.parametrize(
    ("path", "targets"),
    (
        ("ethernet/RoCEv2/rtl/RoCEv2Engine.vhd", ("tests/ethernet/RoCEv2",)),
        ("tests/ethernet/RoCEv2/test_RoCEv2Dcqcn.py", ("tests/ethernet/RoCEv2",)),
        ("ethernet/UdpEngine/rtl/UdpEngine.vhd", ("tests/ethernet/UdpEngine",)),
        ("tests/ethernet/UdpEngine/test_UdpEngine.py", ("tests/ethernet/UdpEngine",)),
        ("ethernet/IpV4Engine/rtl/IpV4Engine.vhd", ("tests/ethernet/UdpEngine",)),
        (
            "ethernet/EthMacCore/rtl/EthMacPkg.vhd",
            ("tests/ethernet/RoCEv2", "tests/ethernet/UdpEngine"),
        ),
    ),
)
def test_selects_enabled_ethernet_suites(path, targets):
    selection = path_selector.select_targets([_change(path)], REPO_ROOT)

    assert selection.targets == targets
    assert selection.force_full is False


def test_combines_ethernet_and_protocol_targets():
    selection = path_selector.select_targets(
        [
            _change("ethernet/RoCEv2/rtl/RoCEv2Engine.vhd"),
            _change("protocols/ssi/rtl/SsiFifo.vhd"),
        ],
        REPO_ROOT,
    )

    assert selection.targets == ("tests/ethernet/RoCEv2", "tests/protocols/ssi")


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
        ("ethernet/RawEthFramer/rtl/RawEthFramer.vhd", "not enabled for selective CI"),
        ("tests/ethernet/EthMacCore/test_EthMacTop.py", "not enabled for selective CI"),
        ("python/surf/__init__.py", "unmapped path"),
        ("README.md", "unmapped path"),
    ),
)
def test_force_full_paths(path, reason):
    selection = path_selector.select_targets([_change(path)], REPO_ROOT)

    assert selection.force_full is True
    assert reason in selection.reason


@pytest.mark.parametrize("status", ("C", "D", "R", "T", "U"))
def test_non_add_or_modify_status_forces_full(status):
    selection = path_selector.select_targets(
        [_change("protocols/ssi/rtl/SsiFifo.vhd", status)],
        REPO_ROOT,
    )

    assert selection.force_full is True
    assert selection.reason.startswith(f"{status} change")


def test_no_changes_selects_no_area_targets():
    assert path_selector.select_targets([], REPO_ROOT) == path_selector.Selection(())


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


def test_merge_base_uses_pre_release_by_default(monkeypatch, tmp_path):
    calls = []

    def fake_run(command, **kwargs):
        calls.append((command, kwargs))
        return SimpleNamespace(stdout="abc123\n")

    monkeypatch.setattr(subprocess, "run", fake_run)

    assert path_selector.merge_base(repo_root=tmp_path) == "abc123"
    assert calls[0][0] == ["git", "merge-base", "origin/pre-release", "HEAD"]
    assert calls[0][1]["cwd"] == tmp_path


def test_cli_prints_directory_targets(capsys):
    result = selector_cli.main(
        ["--changed-files-override", "protocols/ssi/rtl/SsiFifo.vhd,dsp/generic/rtl/FirFilter.vhd"],
        REPO_ROOT,
    )

    captured = capsys.readouterr()
    assert result == 0
    assert captured.out.splitlines() == ["tests/dsp", "tests/protocols/ssi"]
    assert "2 changed file(s)" in captured.err


def test_cli_force_full_is_a_successful_policy_result(capsys):
    result = selector_cli.main(
        ["--changed-files-override", "base/general/rtl/StdRtlPkg.vhd"],
        REPO_ROOT,
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
