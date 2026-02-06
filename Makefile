#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Define default target
target: analysis

ifndef MODULES
export MODULES = $(abspath $(PWD)/../)
endif

export RUCKUS_DIR = $(MODULES)/ruckus
export TOP_DIR    = $(abspath $(PWD))
export PROJ_DIR   = $(abspath $(PWD))
export OUT_DIR    = $(PROJ_DIR)/build

# Override the submodule check because ruckus external of this repo
export OVERRIDE_SUBMODULE_LOCKS = 1

# Load the common makefile library
include $(MODULES)/ruckus/system_ghdl.mk
