//-----------------------------------------------------------------------------
// Title      : JTAG Support
//-----------------------------------------------------------------------------
// File       : xvcDrvUdp.h
// Author     : Till Straumann <strauman@slac.stanford.edu>
// Company    : SLAC National Accelerator Laboratory
// Created    : 2017-12-05
// Last update: 2017-12-05
// Platform   : 
// Standard   : VHDL'93/02
//-----------------------------------------------------------------------------
// Description: 
//-----------------------------------------------------------------------------
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//-----------------------------------------------------------------------------

#ifndef JTAG_DRIVER_UDP_H
#define JTAG_DRIVER_UDP_H

#include <xvcDriver.h>
#include <sys/socket.h>
#include <poll.h>

class JtagDriverUdp : public JtagDriverAxisToJtag {
private:
	SockSd            sock_;

	struct pollfd     poll_[1];

	int               timeoutMs_;

	struct msghdr     msgh_;
	struct iovec      iovs_[2];

public:

	static const unsigned MTU_ = 1450; // etherner MTU - IP/UDP headers

	JtagDriverUdp(const char *target);

	virtual void
	init();

	virtual unsigned long
	getMaxVectorSize();

	virtual int
	xfer( uint8_t *txb, unsigned txBytes, uint8_t *hdbuf, unsigned hsize, uint8_t *rxb, unsigned size );

	virtual ~JtagDriverUdp();
};

#endif
