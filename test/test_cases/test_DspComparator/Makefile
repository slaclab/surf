##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Top-level (Non-default) VHDL Generic values
SIM_ARGS += -gWIDTH_G=8

##############################################################################

# Load source code
VHDL_SOURCES_SURF := $(abspath ../../../build/SRC_VHDL/surf/*)

# CocoTb + GHDL Configuration
SIM := ghdl
TOPLEVEL_LANG := vhdl

# MODULE is the basename of the Python test file
MODULE = $(notdir $(PWD))

# Define the top-level module and top-level library
TOPLEVEL    := $(shell echo $(subst test_,, $(MODULE)) | tr '[:upper:]' '[:lower:]')
RTL_LIBRARY := surf

# Dump waveform to file ($ gtkwave DspComparator.vcd)
ifdef DEBUG_WAVE
SIM_ARGS +=--vcd=$(TOPLEVEL).vcd
endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

##############################################################################
