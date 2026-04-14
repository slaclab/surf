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

ifndef GHDL_CMD
export GHDL_CMD = ghdl
endif

export GHDL_BASE_FLAGS = \
	--workdir=$(OUT_DIR) \
	--std=08 \
	--ieee=synopsys \
	-frelaxed-rules \
	-fexplicit

export GHDL_OPTIONAL_WARNINGS = elaboration hide specs shared
export GHDL_SUPPORTED_WARNING_NAMES := $(shell $(GHDL_CMD) --help-warnings 2>/dev/null | awk '/^[[:space:]]*-W/ {name=$$1; sub(/^-W/, "", name); sub(/\*$$/, "", name); if (name != "all") print name}')
export GHDL_WARNING_FLAGS := $(strip $(foreach warn,$(GHDL_OPTIONAL_WARNINGS),$(if $(filter $(warn),$(GHDL_SUPPORTED_WARNING_NAMES)),-Wno-$(warn))))
export GHDLFLAGS = $(GHDL_BASE_FLAGS) $(GHDL_WARNING_FLAGS)

# Load the common makefile library
include $(MODULES)/ruckus/system_ghdl.mk
