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

#include "AxiStreamSim.h"
using namespace std;
 
AxiStreamSim::AxiStreamSim () {
   _smem        = NULL;
   _verbose     = false;
}

AxiStreamSim::~AxiStreamSim () {
   this->close();
}

// Open the port
bool AxiStreamSim::open (uint id) {
   _smem = sim_open(id);

   if ( _smem != NULL ) {
      printf("AxiStreamSim: Opened shared memory : %s\n", _smem->path);
      return(true);
   }
   else {
      printf("AxiStreamSimIb: Failed to open shared memory id: %i\n", id);
      return(false);
   }
}

// Close the port
void AxiStreamSim::close () {
   sim_close(_smem);
   _smem = NULL;
}

void AxiStreamSim::setVerbose(bool v) {
   _verbose = v;
}

// Write a block of data
void AxiStreamSim::write(uint *data, uint size, uint dest) {

   _smem->dsSize = size;
   _smem->dsDest = dest;
   memcpy(_smem->dsData,data,(_smem->dsSize)*4);
   _smem->dsReqCount++;
   while (_smem->dsReqCount != _smem->dsAckCount) usleep(100);

   if ( _verbose ) printf("AxiStreamSim::write -> Write %i dual words\n",size);
}

// Read a block of data, return -1 on error, 0 if no data, size if data
int AxiStreamSim::read(uint *data, uint maxSize, uint *dest, uint *eofe) {
   int ret = 0;

   // Data is available
   if ( _smem->usReqCount != _smem->usAckCount ) {

      // Too large
      if ( _smem->usSize > maxSize ) {
         printf("AxiStreamSim::read -> Received data is too large!\n");
         _smem->usAckCount = _smem->usReqCount;
         ret = -1;
      }
      else {
         memcpy(data,_smem->usData,(_smem->usSize)*4);
         *eofe = _smem->usEofe;
         *dest = _smem->usDest;
         ret = _smem->usSize;
         _smem->usAckCount = _smem->usReqCount;
         if ( _verbose ) printf("AxiStreamSim::read -> Read %i dual words\n",ret);
      }
   }
   return(ret);
}

// Read a block of data, return -1 on error, 0 if no data, size if data
int AxiStreamSim::read(uint *data, uint maxSize) {
   int ret = 0;

   // Data is available
   if ( _smem->usReqCount != _smem->usAckCount ) {

      // Too large
      if ( _smem->usSize > maxSize ) {
         printf("AxiStreamSim::read -> Received data is too large!\n");
         _smem->usAckCount = _smem->usReqCount;
         ret = -1;
      }
      else {
         memcpy(data,_smem->usData,(_smem->usSize)*4);
         ret = _smem->usSize;
         _smem->usAckCount = _smem->usReqCount;
         if ( _verbose ) printf("AxiStreamSim::read -> Read %i dual words\n",ret);
      }
   }
   return(ret);
}

