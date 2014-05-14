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
void AxiStreamDmaSim::write(unsigned char *data, uint size, uint dest) {
   uint addr;
   uint desc;

   if ( size > _maxSize ) {
      printf("AxiStreamDmaSim:write -> Bad write size: %i\n",size);
      return;
   }

   do {
      addr = _mastMem->read(_fifoOffset+_txFreeAddr);
   } while ( (addr & 0x80000000) == 0);
   addr = addr & 0x7FFFFFFF;
   memcpy(&(_slaveMem[addr]),data,size);

   _mastMem->write(_fifoOffset+_txPostAddrA,addr);
   _mastMem->write(_fifoOffset+_txPostAddrB,size);

   desc  = 0x100; // SOF
   desc |= (dest & 0xFF); // SOF
   _mastMem->write(_fifoOffset+_txPostAddrC,desc);
   printf("AxiStreamDmaSim:write -> Transmit frame size= %i\n",size);
}

// Read a block of data, return -1 on error, 0 if no data, size if data
int AxiStreamDmaSim::read(unsigned char *data, uint maxSize, uint *dest, uint *eofe) {
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

   memcpy(data,&(_slaveMem[addr]),size);

   do {
      desc = _mastMem->read(_fifoOffset+_rxPendAddr);
      usleep(100);
   } while ( (desc & 0x80000000) == 0 );

   *dest = desc & 0xFF;
   *eofe = (desc >> 16) & 0x1;

   _mastMem->write(_fifoOffset+_rxFreeAddr,addr);

   if ( desc & 0x02000000 ) {
      printf("AxiStreamDmaSim:write -> Rx overflow error.\n");
      return -1;
   }

   if ( desc & 0x01000000 ) {
      printf("AxiStreamDmaSim:write -> Rx write error.\n");
      return -1;
   }

   printf("AxiStreamDmaSim:read -> Receive frame size= %i\n",size);

   return(size);
}

