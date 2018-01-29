//-----------------------------------------------------------------------------
// Title      : JTAG Support
//-----------------------------------------------------------------------------
// File       : xvcSrv.cc
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

#include <xvcSrv.h>
#include <xvcConn.h>
#include <xvcDrvLoopBack.h>
#include <xvcDrvUdp.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <pthread.h>
#include <math.h>

// To be defined by Makefile
#ifndef XVC_SRV_VERSION
#define XVC_SRV_VERSION "unknown"
#endif

JtagDriver::JtagDriver(int argc, char *const argv[], unsigned debug)
: debug_ ( debug ),
  drop_  ( 0     ),
  drEn_  ( false )
{
}

void
JtagDriver::setDebug(unsigned debug)
{
	debug_ = debug;
}

void
JtagDriver::setTestMode(unsigned flags)
{
	drEn_ = !!(flags & 1);
}

unsigned
JtagDriver::getDebug()
{
	return debug_;
}

SysErr::SysErr(const char *prefix)
: std::runtime_error( std::string(prefix) + std::string(": ") + std::string(::strerror(errno)) )
{
}

ProtoErr::ProtoErr(const char *msg)
: std::runtime_error( std::string("Protocol error: ") + std::string(msg) )
{
}

TimeoutErr::TimeoutErr(const char *detail)
: std::runtime_error( std::string("Timeout error; too many retries failed") + std::string(detail) )
{
}

static unsigned hdBufMax()
{
	return 16;
}

JtagDriverAxisToJtag::JtagDriverAxisToJtag( int argc, char *const argv[], unsigned debug )
: JtagDriver( argc, argv, debug ),
  wordSize_ ( sizeof(Header)    ),
  memDepth_ ( 1                 ),
  retry_    ( 5                 ),
  periodNs_ ( UNKNOWN_PERIOD    )
{
	// start out with an initial header size; it might be increased
	// once we contacted the server...
	bufSz_ = 2048;
	txBuf_.reserve( bufSz_     );
	hdBuf_.reserve( hdBufMax() );
	hdBuf_.resize ( hdBufMax() ); // fill with zeros
}


JtagDriverAxisToJtag::Header
JtagDriverAxisToJtag::newXid()
{
	if ( XID_ANY == ++xid_ ) {
		++xid_;
	}
	return ((Header)(xid_)) << XID_SHIFT;
}

JtagDriverAxisToJtag::Xid
JtagDriverAxisToJtag::getXid(Header x)
{
	return (x>>20) & 0xff;
}

uint32_t
JtagDriverAxisToJtag::getCmd(Header x)
{
	return x & CMD_MASK;
}

unsigned
JtagDriverAxisToJtag::getErr(Header   x)
{
	if ( getCmd(x) != CMD_E ) {
		return 0;
	}
	return (x & ERR_MASK) >> ERR_SHIFT;
}

unsigned long
JtagDriverAxisToJtag::getLen(Header x)
{
	if ( getCmd(x) != CMD_S ) {
		throw ProtoErr("Cannot extract length from non-shift command header");
	}
	return ((x & LEN_MASK) >> LEN_SHIFT) + 1;
}

const char *
JtagDriverAxisToJtag::getMsg(unsigned e)
{
	switch ( e ) {
		case  0:               return "NO ERROR";
		case ERR_BAD_VERSION:  return "Unsupported Protocol Version";
		case ERR_BAD_COMMAND:  return "Unsupported Command";
		case ERR_TRUNCATED:    return "Unsupported Command";
		case ERR_NOT_PRESENT:  return "XVC Support not Instantiated in Firmware";
        default:    break;
	}
	return NULL;
}


JtagDriverAxisToJtag::Header
JtagDriverAxisToJtag::mkQuery()
{
	return PVERS | CMD_Q | XID_ANY;
}

JtagDriverAxisToJtag::Header
JtagDriverAxisToJtag::mkShift(unsigned len)
{
	len = len - 1;
	return PVERS | CMD_S | newXid() | (len<<LEN_SHIFT);
}

unsigned
JtagDriverAxisToJtag::wordSize(Header reply)
{
	return (reply & 0x0000000f) + 1;
}

unsigned
JtagDriverAxisToJtag::memDepth(Header reply)
{
	return (reply >> 4) & 0xffff;
}

uint32_t
JtagDriverAxisToJtag::cvtPerNs(Header reply)
{
unsigned rawVal = (reply >> XID_SHIFT) & 0xff;
double   tmp;

	if ( 0 == rawVal ) {
		return UNKNOWN_PERIOD;
	}

	tmp = ((double)rawVal)*4.0/256.0;

	return (uint32_t) round( pow( 10.0, tmp )*1.0E9/REF_FREQ_HZ() );
}

unsigned
JtagDriverAxisToJtag::getWordSize()
{
	return wordSize_;
}

unsigned
JtagDriverAxisToJtag::getMemDepth()
{
	return memDepth_;
}

JtagDriverAxisToJtag::Header
JtagDriverAxisToJtag::getHdr(uint8_t *buf)
{
	Header hdr;
	memcpy( &hdr, buf, sizeof(hdr) );
	if ( ! isLE() ) {
		hdr = ntohl( hdr );
	}
	return hdr;
}

void
JtagDriverAxisToJtag::setHdr(uint8_t *buf, Header   hdr)
{
unsigned empty =  getWordSize() - sizeof(hdr);

	if ( ! isLE() ) {
		hdr = ntohl( hdr ); // just use for byte-swap
	}
	memcpy( buf, &hdr, sizeof(hdr) );
	memset( buf + sizeof(hdr), 0, empty );
}

void
JtagDriverAxisToJtag::init()
{
	// obtain server parameters
	query();
}

int
JtagDriverAxisToJtag::xferRel( uint8_t *txb, unsigned txBytes, Header *phdr, uint8_t *rxb, unsigned sizeBytes )
{
Xid      xid = getXid( getHdr( txb ) );
unsigned attempt;
unsigned e;
int      got;

	for (attempt = 0; attempt <= retry_; attempt++ ) {
		Header   hdr;
		try {
			got = xfer( txb, txBytes, &hdBuf_[0], getWordSize(), rxb, sizeBytes );
			hdr = getHdr( &hdBuf_[0] );
			if ( (e = getErr( hdr )) ) {
				char        errb[256];
                const char *msg = getMsg( e );
                int         pos; 
				pos = snprintf(errb, sizeof(errb), "Got error response from server -- ");
				if ( msg ) {
					snprintf(errb + pos, sizeof(errb) - pos, "%s", msg);
				} else {
					snprintf(errb + pos, sizeof(errb) - pos, "error %d", e);
				}
                
				throw ProtoErr(errb);
			}
			if ( xid == XID_ANY || xid == getXid( hdr ) ) {
				if ( phdr ) {
					*phdr = hdr;
				}
				return got;
			}
		} catch (TimeoutErr) {
		}
	}

	throw TimeoutErr();
}

unsigned long
JtagDriverAxisToJtag::query()
{
Header   hdr;
unsigned siz;

	setHdr ( &txBuf_[0], mkQuery() );

	if ( debug_ > 1 ) {
		fprintf(stderr, "query\n");
	}

	xferRel( &txBuf_[0], getWordSize(), &hdr, 0, 0 );

	wordSize_ = wordSize( hdr );
	if ( wordSize_  < sizeof(hdr) ) {
		throw ProtoErr("Received invalid word size");
	}
	memDepth_ = memDepth( hdr );
	periodNs_ = cvtPerNs( hdr );

	if ( debug_ > 1 ) {
		fprintf(stderr, "query result: wordSize %d, memDepth %d, period %ldns\n", wordSize_, memDepth_, (unsigned long)periodNs_);
	}

	if ( 0 == memDepth_ )
		retry_ = 0;
	else
		retry_ = 5;

	if ( (siz = (2*memDepth_ + 1) * wordSize_) > bufSz_ ) {
		bufSz_ = siz;
		txBuf_.reserve( bufSz_ );
	}

	return memDepth_ * wordSize_;
}


uint32_t
JtagDriverAxisToJtag::getPeriodNs()
{
	return periodNs_;
}

uint32_t
JtagDriverAxisToJtag::setPeriodNs(uint32_t requestedPeriod)
{
uint32_t currentPeriod = getPeriodNs();

	if ( 0 == requestedPeriod )
		return currentPeriod;

	return UNKNOWN_PERIOD == currentPeriod ? requestedPeriod : currentPeriod;
}

void
JtagDriverAxisToJtag::sendVectors(unsigned long bits, uint8_t *tms, uint8_t *tdi, uint8_t *tdo)
{
unsigned      wsz = getWordSize();

unsigned long bytesCeil      = (bits  +   8 - 1 )/8;
unsigned      wholeWords     = bytesCeil / wsz;
unsigned      wholeWordBytes = wholeWords * wsz;
unsigned      wordCeilBytes  = ((bytesCeil + wsz - 1)/wsz) * wsz;
unsigned      idx;
unsigned      bytesLeft      = bytesCeil - wholeWordBytes;
unsigned      bytesTot       = wsz + 2*wordCeilBytes;

uint8_t       *wp;

	if ( debug_ > 1 ) {
		fprintf(stderr, "sendVec -- bits %ld, bytes %ld, bytesTot %d\n", bits, bytesCeil, bytesTot);
	}

	setHdr( &txBuf_[0], mkShift( bits ) );

	// reformat

	wp = &txBuf_[0] + wsz; // past header

	// store sequence of TMS/TDI pairs; word-by-word
	for ( idx=0; idx < wholeWordBytes; idx += wsz ) {
		memcpy( wp, & tms[idx], wsz );
		wp  += wsz;
		memcpy( wp, & tdi[idx], wsz );
		wp  += wsz;
	}
	if ( bytesLeft ) {
		memcpy( wp,       & tms[idx], bytesLeft );
		memcpy( wp + wsz, & tdi[idx], bytesLeft );
	}

	xferRel( &txBuf_[0], bytesTot, 0, tdo, bytesCeil );
}

void
JtagDriverAxisToJtag::dumpInfo(FILE *f)
{
	fprintf(f, "Word size:                  %d\n",  getWordSize());
	fprintf(f, "Target Memory Depth (bytes) %d\n",  getWordSize() * getMemDepth());
	fprintf(f, "Max. Vector Length  (bytes) %ld\n", getMaxVectorSize());
	fprintf(f, "TCK Period             (ns) %ld\n", (unsigned long)getPeriodNs());
}

void
JtagDriverAxisToJtag::usage()
{
}

SockSd::SockSd(bool stream)
{
	if ( (sd_ = ::socket( AF_INET, stream ? SOCK_STREAM : SOCK_DGRAM, 0 )) < 0 ) {
		throw SysErr("Unable to create Socket");
	}
}

SockSd::~SockSd()
{
	::close( sd_ );
}

int
SockSd::getSd()
{
	return sd_;
}

XvcServer::XvcServer(
	uint16_t    port,
	JtagDriver *drv,
	unsigned    debug,
	unsigned    maxMsgSize,
	bool        once
)
: sock_      ( true       ),
  drv_       ( drv        ),
  debug_     ( debug      ),
  maxMsgSize_( maxMsgSize ),
  once_      ( once       )
{
struct sockaddr_in a;
int               yes = 1;

	a.sin_family      = AF_INET;
	a.sin_addr.s_addr = INADDR_ANY;
	a.sin_port        = htons( port );

	if ( ::setsockopt( sock_.getSd(), SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes) ) ) {
		throw SysErr("setsockopt(SO_REUSEADDR) failed");
	}


	if ( ::bind( sock_.getSd(), (struct sockaddr*)&a, sizeof(a) ) ) {
		throw SysErr("Unable to bind Stream socket to local address");
	}

	if ( ::listen( sock_.getSd(), 1 ) ) {
		throw SysErr("Unable to listen on socket");
	}

}

void
XvcServer::run()
{
	do {
	XvcConn conn( sock_.getSd(), drv_, maxMsgSize_ );
		try {
			conn.run();
		} catch (SysErr &e) {
			fprintf(stderr,"Closing connection (%s)\n", e.what());
		}
	} while ( ! once_ );
}

static void
usage(const char *nm)
{
	fprintf(stderr,"Usage: %s [-v{v}] [-Vh] [-D <driver>] [-p <port>] -t <target> [ -- <driver_options>]\n", nm);
	fprintf(stderr,"  -t <target> : contact target (depends on driver; e.g., <ip[:port]>)\n");
	fprintf(stderr,"  -h          : this message\n");
	fprintf(stderr,"  -D <driver> : use transport driver 'driver'\n");
	fprintf(stderr,"                   built-in drivers:\n");
	fprintf(stderr,"                   'udp' (default)\n");
	fprintf(stderr,"                   'loopback'\n");
	fprintf(stderr,"                   'udpLoopback'\n");
	fprintf(stderr,"  -p <port>   : bind to TCP port <port> (default: 2542)\n");
	fprintf(stderr,"  -M          : max XVC vector size (default 32768)\n");
	fprintf(stderr,"  -v          : verbose (more 'v's increase verbosity)\n");
	fprintf(stderr,"  -V          : print version information\n");
	fprintf(stderr,"  -T <mode>   : set test mode/flags\n");
}

static void *
udpTestThread(void *arg)
{
UdpLoopBack *loop = (UdpLoopBack*) arg;

	loop->setTestMode( 1 );

	loop->run();

	return 0;
}

DriverRegistry::DriverRegistry()
: creator_(0)
{
}

void
DriverRegistry::registerFactory(Factory f, Usage h)
{
	printf("Registering Driver\n");
	creator_ = f;
    helper_  = h;
}

void
DriverRegistry::usage()
{
	if ( helper_ ) {
		helper_();
	}
}

DriverRegistry *
DriverRegistry::getP(bool creat)
{
static DriverRegistry *theR = 0;
	if ( ! theR && creat ) {
		theR = new DriverRegistry();
	}
	return theR;
}

DriverRegistry *
DriverRegistry::get()
{
	return getP( false );
}

DriverRegistry *
DriverRegistry::init()
{
	return getP( true );
}

JtagDriver *
DriverRegistry::create(int argc, char *const argv[], const char *arg)
{
JtagDriver *drv;
	if ( ! creator_ ) {
		throw std::runtime_error("Internal Error: No driver module registered");
	}
	drv = creator_( argc, argv, arg );
	return drv;
}

int
main(int argc, char **argv)
{
int opt;

unsigned        debug    = 0;
const char     *target   = 0;
const char     *drvnam   = "udp";
unsigned        port     = 2542;
unsigned       *i_p      = 0;
JtagDriver     *drv      = 0;
void           *hdl;
UdpLoopBack    *loop     = 0;
pthread_t       loopT;
unsigned        maxMsg   = 32768;
DriverRegistry *registry = DriverRegistry::init();
bool            setTest  = false;
unsigned        testMode = 0;
bool            once     = false;
bool            help     = false;

	while ( (opt = getopt(argc, argv, "hvVot:D:p:M:T:")) > 0 ) {
        i_p = 0;
		switch ( opt ) {
			default:
				fprintf(stderr,"Unknown option '-%c'\n", opt);
				return 1;
			case 'h':
				usage( argv[0] );
				help = true;
				break;

			case 'v':
				debug++;
				break;

			case 'V':
				printf("%s\n", XVC_SRV_VERSION);
				return 0;

			case 't':
				target = optarg;
				break;

			case 'D':
				drvnam = optarg;
				break;

			case 'M':
				i_p = &maxMsg;
				break;

			case 'p':
				i_p = &port;
				break;

			case 'T':
				i_p = &testMode;
				setTest = true;
				break;

			case 'o':
				once = true;
				break;
		}
		if ( i_p && 1 != sscanf(optarg, "%i", i_p) ) {
			fprintf(stderr,"Unable to scan arg for option '-%c': %s\n", opt, optarg);
			return 1;
		}
	}

    // Reset opterr so that drivers can parse options after '--'
	opterr = 0;

	if ( ! target && ! help ) {
		fprintf(stderr,"Need a -t <target> arg (e.g., -t <ip>[:port])\n\n\n");
		usage( argv[0] );
		return 1;
	}

	if ( 0 == strcmp( drvnam, "udp" ) ) {
		if ( help ) {
			fprintf(stderr,"\n");
			JtagDriverUdp::usage();
			return 0;
		}
		drv = new JtagDriverUdp( argc, argv, target );
	} else if ( 0 == strcmp( drvnam, "loopback" ) ) {
		if ( help ) {
			JtagDriverLoopBack::usage();
			return 0;
		}
		drv = new JtagDriverLoopBack( argc, argv, target );
	} else if ( 0 == strcmp( drvnam, "udpLoopback" ) ) {
		if ( help ) {
			JtagDriverUdp::usage();
			return 0;
		}
		drv  = new JtagDriverUdp( argc, argv, "localhost:2543" );
		loop = new UdpLoopBack( target, 2543 );
	} else {
		if ( ! (hdl = dlopen( drvnam, RTLD_NOW | RTLD_GLOBAL )) ) {
			throw std::runtime_error(std::string("Unable to load requested driver: ") + std::string(dlerror()));
		}
		if ( help ) {
			registry->usage();
			return 0;
		}
		drv = registry->create( argc, argv, target );
	}

	if ( ! drv ) {
		fprintf(stderr,"ERROR: No transport-driver found\n");
		return 1;
	}

	// must fire up the loopback UDP (FW emulation) first
	if ( loop ) {

		loop->setDebug( debug );
		loop->init();

		if ( pthread_create( &loopT, 0, udpTestThread, loop ) ) {
			throw SysErr("Unable to launch UDP loopback test thread");
		}
	}


	drv->setDebug( debug );
	// initialize fully constructed object
	drv->init();


	if ( setTest ) {
		drv->setTestMode( testMode );
	}

	if ( drv->getDebug() > 0 ) {
		drv->dumpInfo();
	}

XvcServer s(port, drv, debug, maxMsg, once);

	s.run();
}
