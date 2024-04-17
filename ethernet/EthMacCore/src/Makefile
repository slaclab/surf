##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
ARCH   := $(shell getconf LONG_BIT)
CC     := g++
CFLAGS := -Wall -m$(ARCH) -I$(PWD) -lpthread -lrt -lm

all:
	$(CC) $(CFLAGS) send_pause.cpp -o bin/send_pause

clean:
	rm -f send_pause
