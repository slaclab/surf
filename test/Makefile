#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
# Do not fail on DeprecationWarning caused by virtualenv, which might come from
# the site module.
# Do not fail on DeprecationWarning caused by attrs dropping 3.6 support
#-----------------------------------------------------------------------------
# export PYTHONWARNINGS = error,ignore::DeprecationWarning:site,always::FutureWarning:cocotb.scheduler,ignore::DeprecationWarning:attr

ifndef MODULES
export MODULES = $(abspath $(PWD)/../../)
endif

# GHDL/ruckus source loading
export RUCKUS_DIR = $(MODULES)/ruckus
export PROJ_DIR   = $(abspath $(PWD)/../)
export OUT_DIR    = $(PROJ_DIR)/build

# Path to GHDL proc.tcl
export RUCKUS_PROC_TCL_COMBO = $(RUCKUS_DIR)/ghdl/proc.tcl

# Bypassing Xilinx Specific code
export VIVADO_VERSION = -1.0

# Override the submodule check because ruckus external of this repo
export OVERRIDE_SUBMODULE_LOCKS = 1

# Get list of all test cases
REGRESSIONS :=  $(shell ls test_cases/)

.PHONY: $(REGRESSIONS)

all: $(REGRESSIONS)

$(REGRESSIONS): src
	cd test_cases/$@ && $(MAKE)

# Test of the variables
test:
	@echo PWD: $(PWD)
	@echo MODULES: $(MODULES)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo RUCKUS_PROC_TCL_COMBO: $(RUCKUS_PROC_TCL_COMBO)
	@echo VIVADO_VERSION: $(VIVADO_VERSION)

# Find all the source code and load it into GHDL
src:
	@rm -rf $(OUT_DIR)
	@mkdir  $(OUT_DIR)
	@$(RUCKUS_DIR)/ghdl/import.tcl > /dev/null 2>&1

clean:
	$(foreach TEST, $(REGRESSIONS), $(MAKE) -C test_cases/$(TEST) clean;)

regression:
	$(foreach TEST, $(REGRESSIONS), $(MAKE) -C test_cases/$(TEST) regression;)
