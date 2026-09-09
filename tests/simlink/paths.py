##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from pathlib import Path

SIMLINK_TEST_ROOT = Path(__file__).resolve().parent
REPO_ROOT = SIMLINK_TEST_ROOT.parents[1]

SIMLINK_SOURCE_ROOT = REPO_ROOT / "simlink"
SHARED_SOURCE_DIR = SIMLINK_SOURCE_ROOT / "shared"
GHDL_SOURCE_DIR = SIMLINK_SOURCE_ROOT / "ghdl"
VCS_SOURCE_DIR = SIMLINK_SOURCE_ROOT / "vcs"
XSIM_SOURCE_DIR = SIMLINK_SOURCE_ROOT / "xsim"
SIMULATION_SOURCE_DIR = SIMLINK_SOURCE_ROOT / "sim"
HDL_TEST_SOURCE_DIR = SIMLINK_SOURCE_ROOT / "test"
COMMON_HDL_TEST_SOURCE_DIR = HDL_TEST_SOURCE_DIR / "common"
VCS_HDL_TEST_SOURCE_DIR = HDL_TEST_SOURCE_DIR / "vcs"
XSIM_HDL_TEST_SOURCE_DIR = HDL_TEST_SOURCE_DIR / "xsim"

SIM_BUILD_ROOT = REPO_ROOT / "tests" / "sim_build" / "simlink"


def sim_build_dir(category, name):
    return SIM_BUILD_ROOT / category / name
