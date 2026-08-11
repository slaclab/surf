##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# Build one xsim DPI-C library for all adapters with xsc's compile/link flow.
# A single `-sv_lib libRogueSimLinkDpi` binds the result; xelab appends `.so`
# to that exact name and does not add a `lib` prefix. xsc stages intermediate
# objects in its implicit xsim.dir/work/xsc/ tree.
##############################################################################

CC := xsc
ELAB := xelab
# The shared include path exposes the common core interfaces. The underlying
# GCC searches each source directory first, preserving the xsim-local Rogue*.h
# headers. xsc supplies Vivado's svdpi.h include path automatically.
CFLAGS := -pthread -I../shared $(shell pkg-config --cflags libzmq)
# Vivado <= 2024.1 bundles a gcc-9.3.0 whose link driver invokes its own
# binutils via -B and does not search the host multiarch lib dir, so the
# libRogueSimLinkDpi.so link fails with "cannot find crti.o / -lzmq / -lm". Point both
# the startfile search (-B, for crt*.o) and the library search (-L) at the
# active gcc's lib dir, derived portably from `gcc -print-file-name=crti.o`
# (resolves to /usr/lib/x86_64-linux-gnu on Debian/Ubuntu, /usr/lib64 on RHEL).
# Harmless on Vivado >= 2024.2, whose xsc already resolves these.
MULTIARCH_DIR := $(dir $(shell gcc -print-file-name=crti.o))
LFLAGS := -pthread $(shell pkg-config --libs libzmq) -B$(MULTIARCH_DIR) -L$(MULTIARCH_DIR)

LIB := libRogueSimLinkDpi.so
ADAPTER_SOURCES := RogueDpiInstance.c RogueTcpStream.c RogueTcpMemory.c \
                   RogueSideBand.c
ABI_SOURCES := RogueTcpStream.c RogueTcpMemory.c RogueSideBand.c
SOURCES := $(ADAPTER_SOURCES) \
           ../shared/RogueSimLinkInstance.c \
           ../shared/RogueSimLinkTransport.c \
           ../shared/RogueTcpStreamCore.c ../shared/RogueTcpMemoryCore.c \
           ../shared/RogueSideBandCore.c
HEADERS := RogueDpiInstance.h RogueTcpStream.h RogueTcpMemory.h RogueSideBand.h \
           ../shared/RogueSimLinkInstance.h \
           ../shared/RogueSimLinkTransport.h \
           ../shared/RogueTcpStreamCore.h ../shared/RogueTcpStreamModel.h \
           ../shared/RogueTcpMemoryCore.h \
           ../shared/RogueTcpMemoryModel.h ../shared/RogueSideBandCore.h \
           ../shared/RogueSideBandModel.h
SV_SOURCES := RogueTcpStreamDpi.sv RogueTcpMemoryDpi.sv RogueSideBandDpi.sv
ABI_HEADER := xsim.dir/RogueSimLinkDpi.generated.h

all: $(LIB)

$(LIB): $(SOURCES) $(HEADERS) Makefile
	@set -e; for source in $(SOURCES); do \
		$(CC) -c $$source -gcc_compile_options "$(CFLAGS)"; \
	done
	$(CC) --shared -o $(LIB) -gcc_link_options "$(LFLAGS)"

$(ABI_HEADER): $(SV_SOURCES)
	mkdir -p $(dir $@)
	$(ELAB) -dpiheader $@ $(foreach src,$(SV_SOURCES),-svlog $(src))

abi-check: $(ABI_HEADER) $(SOURCES) $(HEADERS)
	@set -e; for source in $(ABI_SOURCES); do \
		$(CC) -c $$source -gcc_compile_options "$(CFLAGS) -include $(abspath $(ABI_HEADER))"; \
	done

clean:
	rm -rf xsim.dir xsc.pb xsc.log xelab.pb xelab.log xelab.jou $(LIB)

.PHONY: all abi-check clean
