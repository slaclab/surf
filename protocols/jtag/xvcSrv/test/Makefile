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

all: test

testDataTdoOnly.txt: testData.txt
	$(RM) $@
	grep TDO $^ > $@

clean:
	$(RM) testDataTdoOnly.txt

test: ../src/xvcSrv test.py testDataTdoOnly.txt
	sh -c "(../src/xvcSrv -D udpLoopback -o -t testDataTdoOnly.txt & sleep 1 ; python3 test.py -k)"

../src/xvcSrv:
	@$(error "You need to build the xvcSrv executable in the ../src/ directory first!")
