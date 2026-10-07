##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# Vivado-free ruckus project for the self-driving SimLink SV tops in this
# directory, driven by tests/simlink/iverilog and tests/simlink/verilator.
# RUCKUS_SIM_BACKEND (iverilog or verilator) selects both system_<backend>.mk
# and the surf SimLink backend, SIM_TOP selects the top, and the tests supply
# OUT_DIR, IVERILOG_FLAGS or VERILATOR_FLAGS and SIM_PLUSARGS.
#
#   make build RUCKUS_SIM_BACKEND=verilator SIM_TOP=RogueSvMultiInstanceTb
##############################################################################

export RUCKUS_SIM_BACKEND ?= iverilog
ifeq ($(filter iverilog verilator,$(RUCKUS_SIM_BACKEND)),)
$(error RUCKUS_SIM_BACKEND must be iverilog or verilator, got '$(RUCKUS_SIM_BACKEND)')
endif

export PROJECT = SimLinkSvTest
export PROJ_DIR = $(CURDIR)
export TOP_DIR = $(abspath $(PROJ_DIR)/../../..)
export SIM_TOP ?= RogueSvTrafficTb

ifndef MODULES
export MODULES = $(abspath $(TOP_DIR)/..)
endif

ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif

include $(RUCKUS_DIR)/system_$(RUCKUS_SIM_BACKEND).mk

# The flow sets IMAGES_DIR unconditionally to $(PROJ_DIR)/images; override it
# to live under OUT_DIR so `make dir` does not leave an untracked images/
# directory in the surf source tree.
export IMAGES_DIR = $(OUT_DIR)/images
