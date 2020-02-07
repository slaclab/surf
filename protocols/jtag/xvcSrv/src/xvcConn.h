//-----------------------------------------------------------------------------
// Title      : JTAG Support
//-----------------------------------------------------------------------------
// Company    : SLAC National Accelerator Laboratory
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

#ifndef XVC_CONNECTION_H
#define XVC_CONNECTION_H

#include <xvcSrv.h>

#include <sys/socket.h>
#include <netinet/in.h>

// Class managing a XVC tcp connection

class XvcConn {
	JtagDriver        *drv_;
	int                sd_;
	struct sockaddr_in peer_;
	// just use vectors to back raw memory; DONT use 'size/resize'
	// (unfortunately 'resize' fills elements beyond the current 'size'
	// with zeroes)
	vector<uint8_t>    rxb_;
	uint8_t           *rp_;
    unsigned long      rl_;
	unsigned long      tl_;

	vector<uint8_t>    txb_;
	unsigned long      maxVecLen_;
	unsigned long      supVecLen_;
	unsigned long      chunk_;

public:
XvcConn( int sd, JtagDriver *drv, unsigned long maxVecLen_ = 32768 );

	// fill rx buffer to 'n' octets (from TCP connection)
	virtual void fill(unsigned long n);

	// send tx buffer to TCP connection
	virtual void flush();

	// discard 'n' octets from rx buffer (mark as consumed)
	virtual void bump(unsigned long n);

	// (re)allocated buffers
	virtual void allocBufs();

	virtual void run();

	virtual ~XvcConn();
};

#endif
