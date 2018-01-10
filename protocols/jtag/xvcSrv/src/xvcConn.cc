//-----------------------------------------------------------------------------
// Title      : JTAG Support
//-----------------------------------------------------------------------------
// File       : xvcConn.cc
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

#include <xvcConn.h>

#include <netinet/tcp.h>
#include <arpa/inet.h>

XvcConn::XvcConn( int sd, JtagDriver *drv, unsigned long maxVecLen )
: drv_       ( drv         ),
  maxVecLen_ ( maxVecLen   ),
  supVecLen_ ( 0           )
{
socklen_t sz = sizeof(peer_);

	// RAII for the sd_
	if ( (sd_ = ::accept(sd, (struct sockaddr*)&peer_, &sz) ) < 0 ) {
		throw SysErr("Unable to accept connection");
	}
}

XvcConn::~XvcConn()
{
	::close( sd_ );
}

// fill rx buffer to 'n' octets
void
XvcConn::fill(unsigned long n)
{
uint8_t      *p = rp_ + rl_;
int           got;
unsigned long k = n;

	if ( n <= rl_ )
		return;

	k -= rl_;
	while ( k > 0 ) {
		got = read( sd_, p, k );
		if ( got <= 0 ) {
			throw SysErr("Unable to read from socket");
		}
		k -= got;
		p += got;
	}
	rl_ = n;
}

// mark 'n' octets as 'consumed'
void
XvcConn::bump(unsigned long n)
{
	rp_ += n;
	rl_ -= n;
	if ( rl_ == 0 ) {
		rp_ = &rxb_[0];
	}
}

void
XvcConn::allocBufs()
{
unsigned long      tgtVecLen;
unsigned long      overhead = 128; //headers and such;

	// Determine the vector size supported by the target
    tgtVecLen = drv_->query();

	if ( 0 == tgtVecLen ) {
		// target can stream
		tgtVecLen = maxVecLen_;
	}

	// What can the driver support?
    supVecLen_ = drv_->getMaxVectorSize();

	if ( supVecLen_ == 0 ) {
		// supports any size
		supVecLen_ = tgtVecLen;
	} else if ( tgtVecLen < supVecLen_ ) {
		supVecLen_ = tgtVecLen;
	}

	chunk_  = (2*maxVecLen_ + overhead);

	rxb_.resize( 2*chunk_              );
	txb_.resize( maxVecLen_ + overhead );

	rp_     = &rxb_[0];
	rl_     = 0;
	tl_     = 0;
}

void
XvcConn::flush()
{
int      put;
uint8_t *p = &txb_[0];

	while ( tl_ > 0 ) {
		put = write( sd_, p, tl_ );
		if ( put <= 0 ) {
			throw SysErr("Unable to send from socket");
		}
		p   += put;
		tl_ -= put;
	}
}

void
XvcConn::run()
{

int        got;
uint32_t   bits, bitsLeft, bitsSent;
unsigned long bytes;
unsigned long vecLen;
unsigned long off;


	allocBufs();

	// XVC protocol is synchronous / not pipelined :-(
	// use TCP_NODELAY to make sure our messages (many of which
	// are small) are sent ASAP
	got = 1;
	if ( setsockopt( sd_, IPPROTO_TCP, TCP_NODELAY, &got, sizeof(got) ) ) {
		throw SysErr("Unable to set TCP_NODELAY");
	}

	while ( 1 ) {

	// read stuff;

	got = read( sd_, rp_, chunk_ );
	if ( got <= 0 ) {
		throw SysErr("Unable to read from socket");
	}

	rl_ = got;

	do {

		fill( 2 );

		if ( 0 == ::memcmp( rp_, "ge", 2 ) ) {
			fill( 8 );

			drv_->query(); // informs the driver that there is a new connection

			tl_ = sprintf( (char*)&txb_[0], "xvcServer_v1.0:%ld\n", maxVecLen_ );

			bump( 8 );
		} else
		if ( 0 == ::memcmp( rp_, "se", 2 ) ) {
			uint32_t requestedPeriod;
			uint32_t newPeriod;

			fill( 11 );

			requestedPeriod = (rp_[10] << 24) | (rp_[9] << 16) | (rp_[8] << 8) | rp_[7];

			newPeriod = drv_->setPeriodNs( requestedPeriod );

			for ( unsigned u = 0; u < sizeof(newPeriod); u++ ) {
				txb_[u]   = (uint8_t)newPeriod;
				newPeriod = newPeriod >> 8;
			}

			tl_ = 4;

			bump( 11 );
		} else
		if ( 0 == ::memcmp( rp_, "sh", 2 ) ) {
			fill( 10 );

			bits = 0;
			for ( got = 9; got >=6; got-- ) {
				bits = (bits<<8) | rp_[got];
			}
			bytes = (bits + 7)/8;
			if ( bytes > maxVecLen_ ) {
				throw ProtoErr("Requested bit vector length too big");
			}
			bump( 10 );
			fill( 2*bytes );

			vecLen = bytes > supVecLen_ ? supVecLen_ : bytes;

			// break into chunks the driver can handle; due to the xvc layout we can't efficiently
			// start working on a chunk while still waiting for more data to come in (well - we could
			// but had to have the full TDI vector plus a chunk of the TMS vector in. Thus, we don't
			// bother...).
			for ( off = 0, bitsLeft = bits; bitsLeft > 0; bitsLeft -= bitsSent, off += vecLen ) {

				bitsSent = 8*vecLen;
				if ( bitsLeft < bitsSent ) {
					bitsSent = bitsLeft;
				}

				drv_->sendVectors( bitsSent, rp_ + off, rp_ + bytes + off, &txb_[0] + off );
			}
			tl_ = bytes;

			bump( 2*bytes );
		} else {
			throw ProtoErr("unsupported message received");
		}

		flush();

		/* Repeat until all the characters from the first chunk are exhausted
		 * (most likely the chunk just contained a vector shift message) and
		 * it is exhausted during the first iteration. If for some reason it is
		 * not then we use the spill-over area for a second iteration which
		 * should then terminate this while loop.
		 */
	} while ( rl_ > 0 );

	}

}
