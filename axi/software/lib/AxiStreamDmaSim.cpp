//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <iostream>
#include <iomanip>
#include <queue>
#include <sys/stat.h>

#include "AxiStreamDmaSim.h"
using namespace std;

AxiStreamDmaSim::AxiStreamDmaSim (AxiMasterSim *mast, uint regOffset, uint fifoOffset, 
                                  unsigned char *mem, uint memSize, uint maxSize ) {
   uint x;
   uint addr;

   _mastMem    = mast;
   _regOffset  = regOffset;
   _fifoOffset = fifoOffset;
   _slaveMem   = mem;
   _slaveSize  = memSize;
   _maxSize    = maxSize;

   // Set max frame size
   _mastMem->write(_regOffset+_maxRxSizeAddr,maxSize);

   // Clear FIFOs
   _mastMem->write(_regOffset+_fifoClearAddr,1);
   _mastMem->write(_regOffset+_fifoClearAddr,0);

   // Enable rx and tx
   _mastMem->write(_regOffset+_rxEnableAddr,1);
   _mastMem->write(_regOffset+_txEnableAddr,1);
   _mastMem->write(_regOffset+_intEnableAddr,1);

   // Create tx and rx descriptors, 4 each
   addr = 0;
   for (x=0; x < _txBuffCount; x++) {
      if ( addr > memSize ) {
         printf("AxiStreamDmaSim:AxiStreamDmaSim -> Address space overflow. Addr %X\n",addr);
         return;
      }

      _mastMem->write(_fifoOffset+_txPassAddr,addr);
      addr += maxSize + 16;
      printf("AxiStreamDmaSim:AxiStreamDmaSim -> Created tx buffer addr %X\n",addr);
   }
   for (x=0; x < _rxBuffCount; x++) {
      if ( addr > memSize ) {
         printf("AxiStreamDmaSim:AxiStreamDmaSim -> Address space overflow. Addr %X\n",addr);
         return;
      }

      _mastMem->write(_fifoOffset+_rxFreeAddr,addr);
      addr += maxSize + 16;
      printf("AxiStreamDmaSim:AxiStreamDmaSim -> Created rx buffer addr %X\n",addr);
   }
}

AxiStreamDmaSim::~AxiStreamDmaSim () {
   _mastMem->write(_regOffset+_fifoClearAddr,1);
   _mastMem->write(_regOffset+_rxEnableAddr,0);
   _mastMem->write(_regOffset+_txEnableAddr,0);
   _mastMem->write(_regOffset+_intEnableAddr,0);
}

// Write a block of data
int AxiStreamDmaSim::write(unsigned char *data, uint size) {
   uint addr;
   uint desc;

   if ( size > _maxSize ) {
      printf("AxiStreamDmaSim:write -> Bad write size: %i\n",size);
      return -1;
   }

   addr = _mastMem->read(_fifoOffset+_txFreeAddr);
   if ( (addr&0x80000000) == 0 ) return(0);

   addr = addr & 0x7FFFFFFF;
   desc = *((uint *)data);
   data += 4;

   memcpy(&(_slaveMem[addr]),data,size-4);

   _mastMem->write(_fifoOffset+_txPostAddrA,addr);
   _mastMem->write(_fifoOffset+_txPostAddrB,size-4);
   _mastMem->write(_fifoOffset+_txPostAddrC,desc);
   printf("AxiStreamDmaSim:write -> Transmit frame size= %i\n",size-4);
   return(size);
}

// Read a block of data, return -1 on error, 0 if no data, size if data
int AxiStreamDmaSim::read(unsigned char *data, uint maxSize) {
   uint desc;
   uint addr;
   uint size;

   desc = _mastMem->read(_fifoOffset+_rxPendAddr);
   if ( (desc & 0x80000000) == 0 ) return(0);

   addr = desc & 0x7FFFFFFF;

   do {
      desc = _mastMem->read(_fifoOffset+_rxPendAddr);
      usleep(100);
   } while ( (desc & 0x80000000) == 0 );

   size = desc & 0xFFFFFF;

   do {
      desc = _mastMem->read(_fifoOffset+_rxPendAddr);
      usleep(100);
   } while ( (desc & 0x80000000) == 0 );

   *((uint *)data) = desc & 0x3FFFFFF;
   data += 4;

   memcpy(data,&(_slaveMem[addr]),size);
   size += 4;

   _mastMem->write(_fifoOffset+_rxFreeAddr,addr);

   printf("AxiStreamDmaSim:read -> Receive frame size= %i\n",size-4);

   return(size);
}

