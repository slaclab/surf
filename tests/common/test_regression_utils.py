##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import re

import pytest

from tests.common.regression_utils import (
    cocotb_filtered_env,
    cocotb_test_filter,
    cocotb_test_filter_excluding,
)


def test_cocotb_test_filter_matches_only_named_entrypoints():
    pattern = cocotb_test_filter("server_opens_test", "server_closes_test")

    assert re.search(pattern, "tests.protocol.server_opens_test")
    assert re.search(pattern, "tests.protocol.server_closes_test")
    assert not re.search(pattern, "tests.protocol.client_opens_test")
    assert not re.search(pattern, "tests.protocol.server_opens_test_extra")


def test_cocotb_test_filter_excluding_rejects_only_named_entrypoints():
    pattern = cocotb_test_filter_excluding("routed_only_test", "extended_test")

    assert re.search(pattern, "tests.protocol.default_test")
    assert not re.search(pattern, "tests.protocol.routed_only_test")
    assert not re.search(pattern, "tests.protocol.extended_test")
    assert re.search(pattern, "tests.protocol.extended_test_extra")


@pytest.mark.parametrize("builder", (cocotb_test_filter, cocotb_test_filter_excluding))
def test_cocotb_filter_builders_require_a_test_name(builder):
    with pytest.raises(ValueError, match="At least one"):
        builder()


def test_cocotb_filtered_env_adds_filter_without_mutating_input(monkeypatch):
    monkeypatch.delenv("COCOTB_TESTCASE", raising=False)
    monkeypatch.delenv("COCOTB_TEST_FILTER", raising=False)
    original = {"MODE_G": "ROUTED"}

    result = cocotb_filtered_env(original, "routed_.*_test$")

    assert result == {
        "MODE_G": "ROUTED",
        "COCOTB_TEST_FILTER": "routed_.*_test$",
    }
    assert original == {"MODE_G": "ROUTED"}


@pytest.mark.parametrize("selector", ("COCOTB_TESTCASE", "COCOTB_TEST_FILTER"))
def test_cocotb_filtered_env_preserves_external_selection(monkeypatch, selector):
    monkeypatch.setenv(selector, "focused_test")

    assert cocotb_filtered_env({"MODE_G": "ROUTED"}, "default_.*") == {
        "MODE_G": "ROUTED",
        selector: "focused_test",
    }


def test_cocotb_filtered_env_rejects_conflicting_external_selectors(monkeypatch):
    monkeypatch.setenv("COCOTB_TESTCASE", "one_test")
    monkeypatch.setenv("COCOTB_TEST_FILTER", "other_test")

    with pytest.raises(ValueError, match="Specify only one"):
        cocotb_filtered_env({}, "default_.*")
