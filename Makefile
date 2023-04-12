#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

ifndef MODULES
export MODULES = $(abspath $(PWD)/../)
endif

# GHDL/ruckus source loading
export RUCKUS_DIR = $(MODULES)/ruckus
export TOP_DIR    = $(abspath $(PWD))
export PROJ_DIR   = $(abspath $(PWD))
export OUT_DIR    = $(PROJ_DIR)/build

# Path to GHDL proc.tcl
export RUCKUS_PROC_TCL_COMBO = $(RUCKUS_DIR)/ghdl/proc.tcl

# Bypassing Xilinx Specific code
export VIVADO_VERSION = -1.0

# Override the submodule check because ruckus external of this repo
export OVERRIDE_SUBMODULE_LOCKS = 1

# GHDL build flags
GHDLFLAGS = --workdir=$(OUT_DIR) --ieee=synopsys -fexplicit -frelaxed-rules  --warn-no-library

# Include the shared ruckus Makefile header
include $(RUCKUS_DIR)/system_shared.mk

all: syntax

# Test of the variables
.PHONY : test
test:
	@echo PWD: $(PWD)
	@echo MODULES: $(MODULES)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo RUCKUS_PROC_TCL_COMBO: $(RUCKUS_PROC_TCL_COMBO)
	@echo VIVADO_VERSION: $(VIVADO_VERSION)

# Find all the source code and load it into GHDL
.PHONY : src
src:
	@$(RUCKUS_DIR)/ghdl/import.tcl > /dev/null 2>&1

# Find all the source code and load it into GHDL
.PHONY : syntax
syntax: src
	@echo "============================================================================="
	@echo VHDL Syntax Checking:
	@echo "============================================================================="
	@ghdl -i $(GHDLFLAGS) --work=surf   $(PROJ_DIR)/build/SRC_VHDL/surf/*
	@ghdl -i $(GHDLFLAGS) --work=ruckus $(PROJ_DIR)/build/SRC_VHDL/ruckus/*
