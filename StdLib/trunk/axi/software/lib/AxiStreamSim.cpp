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
bool AxiStreamSim::open (const char *system, uint id) {
   char smemFile[100];

   // Create shared memory filename
   sprintf(smemFile,"simlink.%i.%s.%i", getuid(), system, id);

   // Open shared memory
   _smemFd = shm_open(smemFile, (O_CREAT | O_RDWR), (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
   _smem = NULL;

   // Failed to open shred memory
   if ( _smemFd > 0 ) {

      // Force permissions regardless of umask
      fchmod(_smemFd, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));

      // Set the size of the shared memory segment
      ftruncate(_smemFd, sizeof(AxiStreamSharedMem));

      // Map the shared memory
      if((_smem = (AxiStreamSharedMem *)mmap(0, sizeof(AxiStreamSharedMem),
         (PROT_READ | PROT_WRITE), MAP_SHARED, _smemFd, 0)) == MAP_FAILED) {
         _smemFd = -1;
         _smem   = NULL;
      }

      // Init records
      if ( _smem != NULL ) {
         _smem->usReqCount = 0;
         _smem->usAckCount = 0;
         _smem->dsReqCount = 0;
         _smem->dsAckCount = 0;
      }
   }

   if ( _smem != NULL ) {
      printf("AxiStreamSim: Opened shared memory file: %s\n", smemFile);
      return(true);
   }
   else {
      printf("AxiStreamSimIb: Failed to open shared memory file: %s\n", smemFile);
      return(false);
   }
}

// Close the port
void AxiStreamSim::close () {
   ::close(_smemFd);
   _smemFd = -1;
   _smem   = NULL;
}

void AxiStreamSim::setVerbose(bool v) {
   _verbose = v;
}

// Write a block of data
void AxiStreamSim::write(uint *data, uint size, uint dest) {

   _smem->dsSize = size;
   _smem->dsVc   = dest;
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
         *dest = _smem->usVc;
         ret = _smem->usSize;
         _smem->usAckCount = _smem->usReqCount;
         if ( _verbose ) printf("AxiStreamSim::read -> Read %i dual words\n",ret);
      }
   }
   return(ret);
}

