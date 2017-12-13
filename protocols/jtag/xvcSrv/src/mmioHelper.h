//-----------------------------------------------------------------------------
// Title      : JTAG Support
//-----------------------------------------------------------------------------
// File       : mmioHelper.h
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


#ifndef MMIO_HELPER_H
#define MMIO_HELPER_H

#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>

template<typename T> class MemMap {
private:
	volatile T        *devMem_;
	unsigned long      mapSiz_;
public:
	MemMap(const char *devnam, unsigned long siz = 1);

	// default implementations; if the system requires
	// special ordering instructions and/or byte-swapping
	// etc. then they should override
    virtual T    rd(unsigned index)
	{
		return devMem_[index];
	}

    virtual void wr(unsigned index, T val)
	{
		devMem_[index] = val;
	}

	virtual ~MemMap();
};


template <typename T>
MemMap<T>::MemMap(const char *devnam, unsigned long siz)
{
int fd;
unsigned long pgsz;

	if ( (fd = open( devnam, O_RDWR )) < 0 ) {
		throw SysErr("Unable to open FIFO device file");
	}
	pgsz = sysconf( _SC_PAGE_SIZE );

	mapSiz_  = (siz + pgsz - 1) / pgsz;
	mapSiz_ *= pgsz;

	devMem_ = (volatile T*)
	         mmap(
	            NULL,
	            mapSiz_,
	            PROT_READ | PROT_WRITE,
	            MAP_SHARED,
	            fd,
	            0
	          );

	close( fd );

	if ( (void*)devMem_ == MAP_FAILED ) {
		throw SysErr("Unable to mmap device");
	}
}

template <typename T>
MemMap<T>::~MemMap()
{
	munmap( (void*)devMem_, mapSiz_ );
}

#endif
