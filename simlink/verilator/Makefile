##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# Build one combined DPI-C library for all three Verilator leaves. The four
# xsim adapters (RogueDpiInstance, RogueTcpStream, RogueTcpMemory,
# RogueSideBand) are compiled in place from ../xsim/ against Verilator's own
# svdpi.h, so no C source is copied or duplicated. abi-check regenerates each
# leaf's DPI header straight from the .sv import declaration with
# --dpi-hdr-only and syntax-checks the matching xsim adapter against it, so a
# prototype drift between the SV import and the C definition fails the build
# instead of surfacing as a runtime ABI mismatch.
##############################################################################

VERILATOR      ?= verilator
VERILATOR_ROOT ?= $(shell $(VERILATOR) --getenv VERILATOR_ROOT)

CC       := gcc
CPPFLAGS := -I../shared -I$(VERILATOR_ROOT)/include/vltstd $(shell pkg-config --cflags libzmq)
CFLAGS   := -Wall -fPIC -pthread
# -MMD -MP apply only to the object-file build rules below; abi-check's
# -fsyntax-only invocations produce no object file, so they omit these to
# avoid stray dependency files landing outside build/.
DEPFLAGS := -MMD -MP
LDLIBS   := -pthread $(shell pkg-config --libs libzmq)

BUILD_DIR := build
LIB := libRogueSimLinkDpi.so
ADAPTERS := RogueDpiInstance RogueTcpStream RogueTcpMemory RogueSideBand
SHARED := RogueSimLinkInstance RogueSimLinkTransport \
          RogueTcpStreamCore RogueTcpMemoryCore RogueSideBandCore
OBJECTS := $(addprefix $(BUILD_DIR)/,$(addsuffix Adapter.o,$(ADAPTERS))) \
           $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(SHARED)))

LEAVES := RogueTcpStream RogueTcpMemory RogueSideBand
ABI_HEADERS := $(foreach leaf,$(LEAVES),$(BUILD_DIR)/abi/$(leaf)/V$(leaf)__Dpi.h)

all: $(LIB)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%Adapter.o: ../xsim/%.c Makefile | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: ../shared/%.c Makefile | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(LIB): $(OBJECTS) Makefile | $(BUILD_DIR)
	$(CC) -shared -fPIC $(OBJECTS) -o $@ $(LDLIBS)

# Dependency files do not exist on the first build, so include them optionally.
-include $(wildcard $(BUILD_DIR)/*.d)

# A pattern rule target may contain only one '%', so each leaf's ABI header
# rule is generated explicitly instead of matching both the directory and the
# V<leaf>__Dpi.h filename with a single stem.
define ABI_HEADER_RULE
$(BUILD_DIR)/abi/$(1)/V$(1)__Dpi.h: $(1).sv Makefile
	mkdir -p $$(dir $$@)
	$(VERILATOR) --dpi-hdr-only --Mdir $$(dir $$@) --top-module $(1) $$<
endef
$(foreach leaf,$(LEAVES),$(eval $(call ABI_HEADER_RULE,$(leaf))))

abi-check: $(ABI_HEADERS)
	@set -e; for leaf in $(LEAVES); do \
		echo $(CC) $(CPPFLAGS) $(CFLAGS) -include $(BUILD_DIR)/abi/$${leaf}/V$${leaf}__Dpi.h -fsyntax-only ../xsim/$${leaf}.c; \
		$(CC) $(CPPFLAGS) $(CFLAGS) -include $(BUILD_DIR)/abi/$${leaf}/V$${leaf}__Dpi.h -fsyntax-only ../xsim/$${leaf}.c; \
	done

clean:
	rm -rf $(BUILD_DIR) $(LIB)

.PHONY: all abi-check clean
