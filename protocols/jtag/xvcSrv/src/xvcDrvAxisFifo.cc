//-----------------------------------------------------------------------------
// Title      : JTAG Support
//-----------------------------------------------------------------------------
// File       : xvcDrvAxisFifo.cc
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

#include <xvcDrvAxisFifo.h>

JtagDriverZynqFifo::JtagDriverZynqFifo(const char *devnam)
: JtagDriverAxisToJtag(),
  map_( devnam )
{
uint32_t sizVal;
unsigned long maxBytes;
unsigned long maxWords;

	reset();

	sizVal = i32( TX_SIZ_IDX );

	wrdSiz_ = (sizVal >> 24);

	// this fifo must have one empty slot always.
	maxWords = (sizVal & 0x00ffffff) - 1;

	// one header word; two vectors must fit
	maxBytes = (maxWords - 1) * wrdSiz_;

    maxVec_ = maxBytes/2;
}

JtagDriverZynqFifo::~JtagDriverZynqFifo()
{
}

void
JtagDriverZynqFifo::o32(unsigned idx, uint32_t v)
{
	if ( debug_ > 2 ) {
		fprintf(stderr, "r[%d]:=0x%08x\n", idx, v);
	}
	map_.wr(idx, v);
}

uint32_t
JtagDriverZynqFifo::i32(unsigned idx)
{
	uint32_t v = map_.rd(idx);
	if ( debug_ > 2 ) {
		fprintf(stderr, "r[%d]=>0x%08x\n", idx, v);
	}
	return v;
}

void
JtagDriverZynqFifo::reset()
{
	o32( RX_RST_IDX, RST_MAGIC );
	o32( TX_RST_IDX, RST_MAGIC );
	while ( ! (i32(RX_RST_IDX) & (1<<RX_RST_SHF)) )
		/* busy wait */;
	o32( RX_STA_IDX, (1<<RX_RST_SHF) );
	while ( ! (i32(TX_RST_IDX) & (1<<TX_RST_SHF)) )
		/* busy wait */;
	o32( TX_STA_IDX, (1<<TX_RST_SHF) );
}

void
JtagDriverZynqFifo::init()
{
	reset();
	JtagDriverAxisToJtag::init();
	// have now the target word size -- verify:
	if ( getWordSize() != wrdSiz_ ) {
		throw std::runtime_error("ERROR: firmware misconfigured -- FIFO word size /= JTAG stream word size");
	}
}

unsigned long
JtagDriverZynqFifo::getMaxVectorSize()
{
	return maxVec_;
}

int
JtagDriverZynqFifo::xfer( uint8_t *txb, unsigned txBytes, uint8_t *hdbuf, unsigned hsize, uint8_t *rxb, unsigned size )
{
unsigned txWords   = (txBytes + 3)/4;
uint32_t lastBytes = txBytes - 4*(txWords - 1);
unsigned i;
unsigned got, min, minw, rem;
uint32_t w;

	if ( hsize % 4 != 0 ) {
		throw std::runtime_error("zynq FIFO only supports word-lengths that are a multiple of 4");
	}

	for ( i=0; i<txWords; i++ ) {
		memcpy( &w, &txb[4*i], 4 );
		o32( TX_DAT_IDX, w );
	}
	o32( TX_END_IDX, lastBytes );

	while ( ! (i32( RX_STA_IDX ) & (1<<RX_RDY_SHF)) ) {
		/* busy wait */
	}
	/* clear status */
	o32( RX_STA_IDX, (1<<RX_RDY_SHF) );

	got = i32( RX_CNT_IDX );

	if ( 0 == got ) {
		throw ProtoErr("Didn't receive enough data for header");
	}

	for ( i=0; i<hsize; i+= 4 ) {
		w = i32( RX_DAT_IDX );
		if ( got < 4 ) {
			throw ProtoErr("Didn't receive enough data for header");
		}
		memcpy( hdbuf + i, &w, 4 );
		got   -= 4;
	}
	min  = got;

	if ( size < min ) {
		min = size;
	}

	minw = min/4;

	for ( i=0; i<4*minw; i+=4 ) {
		w = i32( RX_DAT_IDX );
		memcpy( &rxb[i], &w, 4 );
	}

	if ( (rem = (min - i)) ) {
		w = i32( RX_DAT_IDX );
		memcpy( &rxb[i], &w, rem );
		i += 4;
	}

	/* Discard excess */
	while ( i < got ) {
		i32( RX_DAT_IDX );
		i += 4;
	}

	if ( drEn_ && 0 == ((++drop_) & 0xff) ) {
		fprintf(stderr, "Drop\n");
		fflush(stderr);
		throw TimeoutErr();
	}

	return min;
}

void
JtagDriverZynqFifo::usage()
{
	printf("  Driver options: [-i]\n");
	printf("  -i          : disable interrupts (use polled mode)\n");
}

static DriverRegistrar<JtagDriverZynqFifo> r;
