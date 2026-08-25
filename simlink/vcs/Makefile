##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
# VCS_HOME and VCS_VERSION come from the VCS environment. The ruckus VCS flow
# defines SIMLINK_PWD; direct builds default it to this directory.
##############################################################################

CC := gcc
SIMLINK_PWD ?= $(CURDIR)
SHARED_DIR := $(SIMLINK_PWD)/../shared
OBJ := $(SIMLINK_PWD)/.obj
LIB := $(SIMLINK_PWD)/libRogueSimLinkVhpi.so

# The shared include path exposes the common core interfaces. GCC searches the
# source file's directory first, so each adapter's local Rogue*.h keeps
# precedence over similarly named shared headers. Generated .d files track the
# exact local and shared headers used by each object.
CPPFLAGS := -I$(SHARED_DIR) -I$(VCS_HOME)/include \
            -DVCS_VERSION=$(VCS_VERSION) $(shell pkg-config --cflags libzmq)
CFLAGS := -Wall -O -fPIC -MMD -MP -pthread
LDLIBS := -lrt -pthread $(shell pkg-config --libs libzmq)

LOCAL := RogueSideBand RogueTcpMemory RogueTcpStream VhpiGeneric
SHARED := RogueSimLinkInstance RogueSimLinkTransport \
          RogueTcpStreamCore RogueTcpMemoryCore RogueSideBandCore
OBJECTS := $(addprefix $(OBJ)/,$(addsuffix .o,$(LOCAL) $(SHARED)))

all: $(LIB)

$(OBJ):
	mkdir -p $@

$(OBJ)/%.o: $(SIMLINK_PWD)/%.c $(SIMLINK_PWD)/Makefile | $(OBJ)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(OBJ)/%.o: $(SHARED_DIR)/%.c $(SIMLINK_PWD)/Makefile | $(OBJ)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(LIB): $(OBJECTS)
	$(CC) -shared $(OBJECTS) -o $@ $(LDLIBS)

# Dependency files do not exist on the first build, so include them optionally.
-include $(wildcard $(OBJ)/*.d)

clean:
	rm -rf $(OBJ)
	rm -f $(LIB)

.PHONY: all clean
