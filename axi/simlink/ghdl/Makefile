##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# GHDL-only build: re-targeted from axi/simlink/vcs/Makefile with the
# VCS-only flags dropped (-I$(VCS_HOME)/include, -DVCS_VERSION, -lrt
# -pthread); the gcc -shared -fPIC + pkg-config libzmq pattern is unchanged.
# Builds one .so per module into a dedicated build/ dir (never sim_build/,
# which is owned by the cocotb-test run) via the dynamic VHPIDIRECT foreign
# form only -- no VCS_HOME, no -Wl,/-W-prefixed linker tokens anywhere.
##############################################################################

CC     := gcc
# -I../shared resolves the shared RogueTcp*Core.h headers that both this GHDL
# backend and the VHPI (vcs) backend include; gcc searches the including
# file's own dir first, so the ghdl/ RogueTcp*.h still take precedence.
CFLAGS := -Wall -fPIC -I../shared $(shell pkg-config --cflags libzmq)
LFLAGS := $(shell pkg-config --libs libzmq)

BUILD_DIR := build

# Default target: builds both module .so outputs.
all: $(BUILD_DIR)/libRogueTcpStream.so $(BUILD_DIR)/libRogueTcpMemory.so $(BUILD_DIR)/libRogueSideBand.so

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/lib%.so: %.c | $(BUILD_DIR)
	$(CC) -shared -fPIC $(CFLAGS) $< -o $@ $(LFLAGS)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
