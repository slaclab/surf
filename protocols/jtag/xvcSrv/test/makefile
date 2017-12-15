#-----------------------------------------------------------------------------
# Title      : JTAG Support
#-----------------------------------------------------------------------------
# File       : makefile
# Author     : Till Straumann <strauman@slac.stanford.edu>
# Company    : SLAC National Accelerator Laboratory
# Created    : 2017-12-05
# Last update: 2017-12-05
# Platform   :
# Standard   : VHDL'93/02
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
	sh -c "(./xvcSrv -D udpLoopback -o -t testDataTdoOnly.txt & sleep 1 ; python3 test.py -k)"
