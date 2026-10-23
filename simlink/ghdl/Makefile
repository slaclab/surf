##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# Build all three GHDL/VHPIDIRECT adapters and their shared cores into one
# process-wide dynamic library. Outputs stay under build/, separate from the
# cocotb-owned sim_build/ tree, and require no VCS environment or headers.
##############################################################################

CC       := gcc
# -MMD -MP records local and shared header dependencies per object. Including
# those files below ensures a header-only edit cannot leave a stale library.
CPPFLAGS := -I../shared $(shell pkg-config --cflags libzmq)
CFLAGS   := -Wall -fPIC -MMD -MP -pthread
LDLIBS   := -pthread $(shell pkg-config --libs libzmq)

# A Mach-O shared library records an install name in addition to its filename.
# Use the basename so the staged library resolves beside the GHDL executable.
ifeq ($(shell uname -s),Darwin)
SO_ID_FLAG = -Wl,-install_name,$(@F)
endif

BUILD_DIR := build
LIB := $(BUILD_DIR)/libRogueSimLinkVhpiDirect.so
ADAPTERS := RogueTcpStream RogueTcpMemory RogueSideBand
SHARED := RogueSimLinkInstance RogueSimLinkTransport \
          RogueTcpStreamCore RogueTcpMemoryCore RogueSideBandCore
OBJECTS := $(addprefix $(BUILD_DIR)/,$(addsuffix Adapter.o,$(ADAPTERS))) \
           $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(SHARED)))

all: $(LIB)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%Adapter.o: %.c Makefile | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: ../shared/%.c Makefile | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(LIB): $(OBJECTS) Makefile | $(BUILD_DIR)
	$(CC) -shared -fPIC $(OBJECTS) -o $@ $(SO_ID_FLAG) $(LDLIBS)

# Dependency files do not exist on the first build, so include them optionally.
-include $(wildcard $(BUILD_DIR)/*.d)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
