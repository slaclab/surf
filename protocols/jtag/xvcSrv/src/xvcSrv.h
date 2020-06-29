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

#ifndef XVC_SRV_H
#define XVC_SRV_H

#include <xvcDriver.h>

// XVC Server (top) class
class XvcServer {
private:
	SockSd            sock_;
	JtagDriver       *drv_;
	unsigned          debug_;
	unsigned          maxMsgSize_;
	bool              once_;

public:
	XvcServer(
		uint16_t port,
		JtagDriver *drv,
		unsigned debug=0,
		unsigned maxMsgSize = 32768,
		bool once = false
	);

	virtual void run();

	virtual ~XvcServer()
	{
	};
};

#endif
