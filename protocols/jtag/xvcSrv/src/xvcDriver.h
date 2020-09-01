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

#ifndef XVC_TRANSPORT_DRIVER_H
#define XVC_TRANSPORT_DRIVER_H

#include <stdint.h>
#include <exception>
#include <stdexcept>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <vector>

using std::vector;

// Abstract JTAG driver -- in most cases you'd want to
// subclass JtagDriverAxisToJtag if you want to support
// a new transport.
class JtagDriver {
protected:
	unsigned debug_;
	// occasionally drop a packet for testing (when enabled)
	unsigned drop_;
	bool     drEn_;

public:
	JtagDriver(int argc, char *const argv[], unsigned debug);

	// set/get debug level
	void     setDebug(unsigned debug);
	unsigned getDebug();

	void     setTestMode(unsigned flags);

	virtual void init()
		= 0;

	// XVC query support; return the size of max. supported JTAG vector in bytes
	//                    if 0 then no the target does not have memory and if
	//                    there is reliable transport there is no limit to vector
	//                    length.
	virtual unsigned long
	query()
		= 0;

	// Max. vector size (in bytes) this driver supports - may be different
	// from what the target supports and the minimum will be used...
	// Note that this is a single vector (the message the driver
	// must handle typically contains two vectors and a header, so
	// the driver must consider this when computing the max. supported
	// vector size)
	virtual unsigned long
	getMaxVectorSize()
		= 0;

	// XVC -- setting to 0 merely retrieves
	virtual uint32_t
	setPeriodNs(uint32_t newPeriod)
		= 0;

	// send tms and tdi vectors of length numBits (each) and receive tdo
	// little-endian (first send/received at lowest offset)
    virtual void
	sendVectors(
		unsigned long numBits,
		uint8_t          *tms,
		uint8_t          *tdi,
		uint8_t          *tdo)
		= 0;

	virtual void
	dumpInfo(FILE *f = stdout) = 0;

	virtual ~JtagDriver() {}

    static void usage(); // to be implemented by subclass
};

// Simple driver registry (only a single loadable driver is remembered)
//
// Each driver must instantiate a registrar object:
//
//  static DriverRegistrar<MyDriver> r;
//

class DriverRegistry {
public:
	typedef JtagDriver * (*Factory)(int argc, char *const argv[], const char *);
	typedef void         (*Usage)();

private:
	Factory creator_;
    Usage   helper_;

	 DriverRegistry();
	~DriverRegistry();

	static DriverRegistry *getP(bool creat);

public:
	JtagDriver *create(int argc, char *const argv[], const char *arg);

	void registerFactory(Factory f, Usage h);

    void usage();

	static DriverRegistry *
	get();

	static DriverRegistry *
	init();
};

template <typename T> class DriverRegistrar {
private:
	static JtagDriver *createP(int argc, char * const argv[], const char *arg)
	{
		return new T(argc, argv, arg);
	}

public:

	DriverRegistrar()
	{
	// avoid registring statically linked drivers
	// (prior to init() being executed)
	DriverRegistry *r = DriverRegistry::get();
		if ( r ) {
			r->registerFactory( createP, T::usage );
		}
	}
};


// Exceptions

// library/syscall errors (yielding and 'errno' -- which is converted to a message)
class SysErr : public std::runtime_error {
public:
	SysErr(const char *prefix);
};

// Protocol error
class ProtoErr : public std::runtime_error {
public:
	ProtoErr(const char *msg);
};

// Timeout
class TimeoutErr : public std::runtime_error {
public:
	TimeoutErr(const char *detail = "");
};


// Driver for the AxisToJtag FW module; a transport-level
// driver must derive from this and implement
//
//   - 'xfer()'.
//   - 'getMaxVectorSize()'
//
// If the driver is to be run-time loaded (compiled separately)
// then it must register itself:
//
// static DriverRegistrar<MyDriverClass> r;
//
// 'getMaxVectorSize()' must return the max. size of a single
// JTAG vector (in bytes) the driver can support. Note that the
// max. *message* size is bigger - it comprises two vectors and
// a header word (depends on the word size the target FW was
// built for).
// E.g., A UDP transport might want to limit to less than the
// ethernet MTU. See xvcDrvUdp.cc for an example...
//
// 'xfer()' must transmit the (opaque) message in 'txb' of size
// 'txBytes' (which is guaranteed to be at most
//
//     2*maxVectorSize() + getWordSize()
//
// The method must then receive the reply from the target
// and:
//   - store the first 'hsize' bytes into 'hbuf'. If less than
//     'hsize' were received then 'xfer' must throw and exception.
//   - store the remainder of the message up to at most 'size'
//     bytes into 'rbuf'.
//   - return the number of actual bytes stored in 'rbuf'.
//
// If a timeout occurs then 'xfer' must throw a TimeoutErr().
//
class JtagDriverAxisToJtag : public JtagDriver {
protected:
	typedef uint32_t Header;
	typedef uint8_t  Xid;

	static const Xid XID_ANY = 0;

private:
	unsigned        wordSize_;
	unsigned        memDepth_;

	vector<uint8_t> txBuf_;
	vector<uint8_t> hdBuf_;

	unsigned        bufSz_;
	unsigned        retry_;

	Xid             xid_;

	uint32_t        periodNs_;

	Header newXid();

	Header   mkQuery();
	Header   mkShift(unsigned len);

	virtual void         setHdr(uint8_t *buf, Header   hdr);

protected:

	static       Header   getHdr(uint8_t *buf);


	static const Header   PVERS = 0x00000000;
	static const Header   CMD_Q = 0x00000000;
	static const Header   CMD_S = 0x10000000;
	static const Header   CMD_E = 0x20000000;

	static const Header   CMD_MASK  = 0x30000000;
	static const unsigned ERR_SHIFT =  0;
	static const Header   ERR_MASK  = 0x000000ff;

	static const unsigned XID_SHIFT = 20;
	static const unsigned LEN_SHIFT =  0;
	static const Header   LEN_MASK  = 0x000fffff;

    static const unsigned ERR_BAD_VERSION = 1;
    static const unsigned ERR_BAD_COMMAND = 2;
    static const unsigned ERR_TRUNCATED   = 3;
    static const unsigned ERR_NOT_PRESENT = 4;

	static Xid           getXid(Header x);
	static uint32_t      getCmd(Header x);
	static unsigned      getErr(Header x);
	static unsigned long getLen(Header x);

    // returns error message or NULL (unknown error)
    static const char   *getMsg(unsigned error);


	// extract from message header
	unsigned wordSize(Header  reply);
	unsigned memDepth(Header  reply);
    uint32_t cvtPerNs(Header  reply);

	static int isLE()
	{
	static const union { uint8_t c[2]; uint16_t s; } u = { s: 1 };
		return !!u.c[0];
	}

	static const uint32_t UNKNOWN_PERIOD = 0;

	static double         REF_FREQ_HZ()
	{
		return 200.0E6;
	}

	// obtain (current/cached) parameters; these may
	// depend on values provided by the transport-level driver
	virtual unsigned getWordSize();
	virtual unsigned getMemDepth();
	virtual uint32_t getPeriodNs();

public:

	JtagDriverAxisToJtag( int argc, char *const argv[], unsigned debug = 0 );

	// initialization after full construction
	virtual void
	init();

	// virtual method to be implemented by transport-level driver;
	// transmit txBytes from TX buffer (txb) and receive 'hsize' header
	// bytes into hdbuf and up to 'size' bytes into rxb.
	// RETURNS: number of payload bytes (w/o header).
	virtual int
	xfer( uint8_t *txb, unsigned txBytes, uint8_t *hdbuf, unsigned hsize, uint8_t *rxb, unsigned size ) = 0;

	// Transfer with retry/timeout.
	// 'txBytes' are transmitted from the TX buffer 'txb'.
	// The message header is received into '*phdr', payload (of up to 'sizeBytes') into 'rxb'.
	//
	virtual int
	xferRel( uint8_t *txb, unsigned txBytes, Header *phdr, uint8_t *rxb, unsigned sizeBytes );

	// XVC query ("getinfo")
	virtual unsigned long
	query();

	virtual uint32_t
	setPeriodNs(uint32_t newPeriod);

	// XVC send vectors ("shift")
	virtual void sendVectors(unsigned long bits, uint8_t *tms, uint8_t *tdi, uint8_t *tdo);

	virtual void dumpInfo(FILE *f);

	static void usage();
};

// RAII socket helper
class SockSd {
private:
	int      sd_;

	SockSd(const SockSd&);
	SockSd & operator=(const SockSd&);

public:
	// 'stream': SOCK_STREAM vs SOCK_DGRAM
	SockSd(bool stream);

	virtual int getSd();

	virtual ~SockSd();
};

#endif
