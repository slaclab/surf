##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# xsc-based build (Vivado xsim DPI-C), re-targeted from ghdl/Makefile's
# gcc -shared -fPIC + pkg-config libzmq pattern to the xsc two-step compile/
# link flow. Builds the combined RogueTcpDpi.so from every module's DPI-C
# adapter (RogueTcpStream.c, RogueTcpMemory.c, RogueSideBand.c); a single
# "-sv_lib RogueTcpDpi" binds all of them. Each adapter keeps its own
# file-scope static data and name-prefixed
# functions, so linking them into one .so has no symbol collisions. The
# file is named RogueTcpDpi.so (no "lib" prefix): xelab's "-sv_lib
# RogueTcpDpi" resolves the DPI library as <name>.so, not lib<name>.so
# (per UG900). xsc stages its compiled object under its own implicit
# ./xsim.dir/work/xsc/ directory (no BUILD_DIR indirection like GHDL/VCS use).
##############################################################################

CC     := xsc
# -I../shared resolves the shared RogueTcp*Core.h headers that every backend
# includes; xsc's underlying gcc searches the including file's own dir
# first, so the xsim/ RogueTcp*.h still take precedence. svdpi.h is
# auto-found by xsc (adds $XILINX_VIVADO/data/xsim/include automatically).
CFLAGS := -I../shared $(shell pkg-config --cflags libzmq)
# Vivado <= 2024.1 bundles a gcc-9.3.0 whose link driver invokes its own
# binutils via -B and does not search the host multiarch lib dir, so the
# RogueTcpDpi.so link fails with "cannot find crti.o / -lzmq / -lm". Point both
# the startfile search (-B, for crt*.o) and the library search (-L) at the
# active gcc's lib dir, derived portably from `gcc -print-file-name=crti.o`
# (resolves to /usr/lib/x86_64-linux-gnu on Debian/Ubuntu, /usr/lib64 on RHEL).
# Harmless on Vivado >= 2024.2, whose xsc already resolves these.
MULTIARCH_DIR := $(dir $(shell gcc -print-file-name=crti.o))
LFLAGS := $(shell pkg-config --libs libzmq) -B$(MULTIARCH_DIR) -L$(MULTIARCH_DIR)

LIB := RogueTcpDpi.so

all: $(LIB)

$(LIB): RogueTcpStream.c RogueTcpMemory.c RogueSideBand.c
	$(CC) -c RogueTcpStream.c -gcc_compile_options "$(CFLAGS)"
	$(CC) -c RogueTcpMemory.c -gcc_compile_options "$(CFLAGS)"
	$(CC) -c RogueSideBand.c -gcc_compile_options "$(CFLAGS)"
	$(CC) --shared -o $(LIB) -gcc_link_options "$(LFLAGS)"

clean:
	rm -rf xsim.dir xsc.pb xsc.log $(LIB)

.PHONY: all clean
