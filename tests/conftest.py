#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import os

import find_libpython
import pytest
from cocotb_tools import config


@pytest.fixture(scope="session", autouse=True)
def cocotb_startup_environment():
    """Supply cocotb 2.1 startup for both shared and custom simulator runners."""
    # cocotb-test 0.2.6 supplies LIBPYTHON_LOC but not the new GPI_USERS.
    # Match cocotb's own runner: load libpython, then the PyGPI entry point.
    # Older cocotb releases lack this API and keep their existing startup.
    entry_point = getattr(config, "pygpi_entry_point", None)
    with pytest.MonkeyPatch.context() as patch:
        if entry_point is not None and "GPI_USERS" not in os.environ:
            libpython = os.environ.get("LIBPYTHON_LOC") or find_libpython.find_libpython()
            if libpython is None:
                raise RuntimeError("Unable to find libpython for cocotb startup")
            patch.setenv("GPI_USERS", f"{libpython};{entry_point()}")
        yield
