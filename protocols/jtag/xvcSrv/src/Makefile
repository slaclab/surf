#-----------------------------------------------------------------------------
# Title      : JTAG Support
#-----------------------------------------------------------------------------
# Company    : SLAC National Accelerator Laboratory
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# If you want to cross-compile this program define
# the path to the cross-tools either here or on the
# command line
#
# CROSS=/path/to/arm-linux-
#
# so that $(CROSS)$(CXX) points to a valid cross compiler

all: xvcSrv drvFifo.so

OBJS=xvcSrv.o xvcDrvLoopBack.o xvcConn.o xvcDrvUdp.o

VERSION_INFO:='"$(shell git describe --always)"'

CPPFLAGS+=-DXVC_SRV_VERSION=$(VERSION_INFO)

xvcSrv: $(OBJS)
	$(CROSS)$(CXX) -o $@ $^ -ldl -Wl,--export-dynamic -lm -lpthread

%.o: %.cc
	$(CROSS)$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ $^ -I. -O2 -c

drvFifo.so: xvcDrvAxisFifo.cc
	$(CROSS)$(CXX) $(CPPFLAGS) $(CXXFLAGS) -shared -fPIC -I. -O2 -o $@ $^

clean:
	$(RM) xvcSrv drvFifo.so $(OBJS)
