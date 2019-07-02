//-----------------------------------------------------------------------------
// Title      : JTAG Support
//-----------------------------------------------------------------------------
// File       : xvcDrvUdp.cc
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

#include <xvcDrvUdp.h>
#include <netdb.h>
#include <string.h>
#include <netinet/ip.h>

static const char *DFLT_PORT="2542";

static const unsigned MAXL  = 256;

JtagDriverUdp::JtagDriverUdp(int argc, char *const argv[], const char *target)
: JtagDriverAxisToJtag( argc, argv ),
  sock_      ( false ),
  timeoutMs_ ( 500   ),
  mtu_       ( 1450  ) // ethernet mtu minus MAC/IP/UDP addresses
{
struct addrinfo hint, *res;
const char            *col, *prtnam;
char                   buf[MAXL];
unsigned               l;
int                    stat, opt;
unsigned               mtu;
unsigned              *i_p;
socklen_t              slen;
bool                   userMtu = false;
bool                   frag    = false;

	while ( (opt = getopt(argc, argv, "m:f")) > 0 ) {

		i_p = 0;

		switch ( opt ) {
			case 'm':
				i_p     = &mtu_;
				userMtu = true;
			break;

			case 'f':
				frag    = true;
			break;

			default:
				fprintf(stderr,"Unknown driver option -%c\n", opt);
				throw std::runtime_error("Unknown driver option");
		}

		if ( i_p ) {
			if ( 1 != sscanf(optarg,"%i", i_p) ) {
				fprintf(stderr,"Unable to scan argument to option -%c\n", opt);
				throw std::runtime_error("Unable to scan option argument");
			}
		}
	}

	if ( (col = strchr(target, ':')) ) {

		l = col - target;

		if ( l+1 > sizeof(buf) ) {
			snprintf(buf, sizeof(buf), "Internal error - not supporting target string lengths > %d", MAXL);
			throw std::runtime_error( buf );
		}

		strncpy(buf, target, l);
		buf[l] = 0;

		target = buf;
		prtnam = col + 1;

	} else {
		prtnam = DFLT_PORT;
	}

	hint.ai_family   = AF_INET;
	hint.ai_socktype = SOCK_DGRAM;
	hint.ai_protocol = IPPROTO_UDP;
	hint.ai_flags    = AI_NUMERICSERV;

	if ( ( stat = getaddrinfo( target, prtnam, &hint, &res ) ) ) {
		// doesn't use errno
		snprintf(buf, sizeof(buf), "getaddrinfo for '%s' failed: %s", target, gai_strerror( stat ) );
		throw std::runtime_error( buf );
	} else {
		stat = connect( sock_.getSd(), res->ai_addr, res->ai_addrlen );
		freeaddrinfo( res );

		if ( stat ) {
			throw SysErr("Unable to connect UDP socket");
		}
	}

	// find current MTU
    slen = sizeof(mtu);
	stat = getsockopt( sock_.getSd(), IPPROTO_IP, IP_MTU, &mtu, &slen );
	if ( stat ) {
		fprintf(stderr,"Warning: Unable to estimate MTU (getsockopt(IP_MTU) failed: %s) -- using %d\n", strerror(errno), mtu_);
	} else {
		if ( mtu < mtu_ ) {
			fprintf(stderr,"Warning: requested MTU limit (%d) > IP_MTU; clipping to %d octets\n", mtu_, mtu);
			mtu_ = mtu;
		} else if ( ! userMtu ) {
			// allow MTU to be increased only if not defined by the user
            mtu_ = mtu;
		}
	}

	if ( ! frag ) {
		opt  = IP_PMTUDISC_DO; // this forces the DF (dont-fragment) flag
		stat = setsockopt( sock_.getSd(), IPPROTO_IP, IP_MTU_DISCOVER, &opt, sizeof(opt) );
		if ( stat ) {
			throw SysErr("Unable to set IP_MTU_DISCOVER to IP_PMTUDISC_DO (enforce DF)");
		}
	}

	poll_[0].fd     = sock_.getSd();
	poll_[0].events = POLLIN;
}

JtagDriverUdp::~JtagDriverUdp()
{
}


void
JtagDriverUdp::init()
{
	JtagDriverAxisToJtag::init();
	if ( getMemDepth() == 0 ) {
		fprintf(stderr,"WARNING: target does not appear to have memory support.\n");
		fprintf(stderr,"         Reliable communication impossible!\n");
	}
}

unsigned long
JtagDriverUdp::getMaxVectorSize()
{
// MTU lim; 2*vector size + header must fit!
unsigned long mtuLim    = (mtu_ - getWordSize()) / 2;

		return mtuLim;
}

int
JtagDriverUdp::xfer( uint8_t *txb, unsigned txBytes, uint8_t *hdbuf, unsigned hsize, uint8_t *rxb, unsigned size )
{
int got;

	if ( write( poll_[0].fd, txb, txBytes ) < 0 ) {
		if ( EMSGSIZE == errno ) {
			fprintf(stderr, "UDP message size too large; would require fragmentation!\n");
			fprintf(stderr, "Try to reduce using the driver option -- -m <mtu_size>.\n");
		}
		throw SysErr("JtagDriverUdp: unable to send");
	}

	poll_[0].revents = 0;

	got = poll( poll_, sizeof(poll_)/sizeof(poll_[0]), timeoutMs_ /* ms */ );

	if ( got < 0 ) {
		throw SysErr("JtagDriverUdp: poll failed");
	}

	if ( got == 0 ) {
		throw TimeoutErr();
	}

	if ( poll_[0].revents & (POLLERR | POLLNVAL) ) {
		throw std::runtime_error("JtagDriverUdp -- internal error; poll has POLLERR or POLLNVAL set");
	}

	if ( ! (poll_[0].revents & POLLIN) ) {
		throw std::runtime_error("JtagDriverUdp -- poll with no data?");
	}


	iovs_[0].iov_base = hdbuf;
	iovs_[0].iov_len  = hsize;
	iovs_[1].iov_base = rxb;
	iovs_[1].iov_len  = size;

	got = read( poll_[0].fd, iovs_, sizeof(iovs_)/sizeof(iovs_[0]) );

	if ( debug_ > 1 ) {
		fprintf(stderr, "HSIZE %d, SIZE %d, got %d\n", hsize ,size, got );
	}

	if ( got < 0 ) {
		throw SysErr("JtagDriverUdp -- recvmsg failed");
	}

	got -= hsize;

	if ( got < 0 ) {
		throw ProtoErr("JtagDriverUdp -- not enough header data received");
	}

	return got;
}

void
JtagDriverUdp::usage()
{
	printf("  UDP Driver options: [-m <mtu>]\n");
	printf("  -m <mtu>    : Set MTU limit for UDP datagrams (must not be fragmented!)\n");
	printf("  -f          : Enable IP fragmentation - note that FW does probably not support this!\n");
}

static DriverRegistrar<JtagDriverUdp> r;
