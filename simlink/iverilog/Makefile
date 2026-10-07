##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# Build the Icarus VPI adapters and their shared cores into a single
# RogueSimLink.vpi, loaded with one `vvp -M<dir> -mRogueSimLink`. Outputs
# stay under build/, separate from the pytest-owned sim_build/ tree.
##############################################################################

CC       := gcc
CPPFLAGS := -I../shared $(shell pkg-config --cflags libzmq)
CFLAGS   := $(shell iverilog-vpi --cflags) -pthread -MMD -MP
LDFLAGS  := $(shell iverilog-vpi --ldflags)
LDLIBS   := $(shell iverilog-vpi --ldlibs) -pthread $(shell pkg-config --libs libzmq)

BUILD_DIR := build
VPI := RogueSimLink.vpi
ADAPTERS := RogueVpiInstance RogueTcpStream RogueTcpMemory RogueSideBand
SHARED := RogueSimLinkInstance RogueSimLinkTransport RogueTcpStreamCore \
          RogueTcpMemoryCore RogueSideBandCore
OBJECTS := $(addprefix $(BUILD_DIR)/,$(addsuffix Adapter.o,$(ADAPTERS))) \
           $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(SHARED)))

all: $(VPI)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%Adapter.o: %.c Makefile | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: ../shared/%.c Makefile | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(VPI): $(OBJECTS) Makefile | $(BUILD_DIR)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@ $(LDLIBS)

# Dependency files do not exist on the first build, so include them optionally.
-include $(wildcard $(BUILD_DIR)/*.d)

clean:
	rm -rf $(BUILD_DIR) $(VPI)

.PHONY: all clean
