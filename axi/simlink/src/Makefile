##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
# Note: Need to define VCS_VERSION & VCS_HOME in your synopsys vncs setup script
#       SIMLINK_PWD gets defined in the ruckus/vivado_vcs.tcl script
##############################################################################

# Variables
CC     := gcc
DEF    := 
OUT    := $(SIMLINK_PWD)
OBJ    := $(SIMLINK_PWD)/.obj
CFLAGS := -Wall -fPIC -I$(VCS_HOME)/include -DVCS_VERSION=$(VCS_VERSION) `pkg-config --cflags libzmq`
LFLAGS := -lrt -pthread `pkg-config --libs libzmq`
LIB    := $(OUT)/libAxiSim.so

# Local Sources
LOC_DIR := $(SIMLINK_PWD)
LOC_SRC := $(wildcard $(LOC_DIR)/*.c)
LOC_HDR := $(wildcard $(LOC_DIR)/*.h)
LOC_OBJ := $(patsubst $(LOC_DIR)/%.c,$(OBJ)/%.o,$(LOC_SRC))

# Default
all: dir $(GEN_OBJ) $(LOC_OBJ) $(LIB)

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
clean:
	rm -rf $(OBJ)
	rm -f $(LIB)

# Compile Local Sources
$(OBJ)/%.o: $(LOC_DIR)/%.c $(LOC_DIR)/%.h
	$(CC) -c -O $(CFLAGS) $(DEF) -o $@ $<

# Compile Library
$(OUT)/%.so: $(LOC_OBJ)
	$(CC) -shared $(DEF) $(OBJ)/* -o $@ $(LFLAGS) 
