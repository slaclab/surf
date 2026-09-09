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

import os

import find_libpython
from cocotb_tools import config


def _export_gpi_users() -> None:
    """Export GPI_USERS on behalf of cocotb-test.

    cocotb 2.1 moved responsibility for building GPI_USERS onto the test
    runner: the VPI/VHPI shims now refuse to start the embedded interpreter
    without it, aborting elaboration with "No GPI_USERS specified, exiting..."
    and leaving a zero-length results.xml that surfaces as an unrelated
    xml.etree ParseError. cocotb's own runner sets it in
    cocotb_tools.runner._set_env_common(); cocotb-test never learned to, so
    the repo has to supply it.

    Doing this in os.environ rather than through cocotb-test's `extra_env=`
    is deliberate on two counts. cocotb_test.simulator.set_env() copies the
    whole os.environ over extra_env after applying it, so os.environ is the
    layer that actually reaches the simulator (the same asymmetry documented
    for LD_LIBRARY_PATH in tests/simlink/ghdl/simlink_test_utils.py). And
    run_surf_vhdl_test() folds every extra_env key into the sim_build
    directory name, so routing a path-valued variable through there would
    rename every parameterized build directory in the tree.
    """
    # An explicit GPI_USERS wins, matching cocotb's own runner precedence and
    # keeping the tests/simlink/env.local.sh override hook usable.
    if "GPI_USERS" in os.environ:
        return

    # cocotb 2.0.x ships cocotb_tools.config without this helper, so probe for
    # it instead of letting a stale environment raise a bare AttributeError.
    pygpi_entry_point = getattr(config, "pygpi_entry_point", None)
    if pygpi_entry_point is None:
        raise RuntimeError(
            "cocotb >= 2.1 is required: cocotb_tools.config.pygpi_entry_point "
            "is missing, so GPI_USERS cannot be assembled. Reinstall with "
            "'python -m pip install -r pip_requirements.txt'."
        )

    libpython = os.environ.get("LIBPYTHON_LOC") or find_libpython.find_libpython()
    if libpython is None:
        raise RuntimeError(
            "find_libpython could not locate libpython, which cocotb needs to "
            "start the embedded interpreter. Install the Python development "
            "package, or set LIBPYTHON_LOC to the absolute libpython path."
        )

    # GPI_USERS is semicolon-delimited, not os.pathsep-delimited: a ':' here
    # makes the loader treat the whole value as one unloadable path and fails
    # exactly as an unset GPI_USERS does. libpython has to precede the entry
    # point so the interpreter symbols are resolved before PyGPI loads.
    os.environ["GPI_USERS"] = f"{libpython};{pygpi_entry_point()}"


_export_gpi_users()
