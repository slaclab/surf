//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef __AXI_STREAM_SHARED_MEM_H__
#define __AXI_STREAM_SHARED_MEM_H__

#include <sys/types.h>
#include <sys/types.h>
#include <string.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>   
#include <unistd.h>

// Shared memory structure, matches structure in general DAQ
// in generic/SimLink.h (redefined here for simplicity)

#define SIM_LINK_BUFF_SIZE 1000000

#define SHM_BASE "axi_stream"

typedef struct {

   // Upstream or Inbound
   uint        usReqCount;
   uint        usAckCount;
   uint        usData[SIM_LINK_BUFF_SIZE];
   uint        usSize;
   uint        usDest;
   uint        usEofe;
   
   // Downstream or outbound
   uint        dsReqCount;
   uint        dsAckCount;
   uint        dsData[SIM_LINK_BUFF_SIZE];
   uint        dsSize;
   uint        dsDest;

   // Shard path
   char path[200];

} AxiStreamSharedMem;

// Init structure
static void inline init (AxiStreamSharedMem *mem) {
   mem->usReqCount = 0;
   mem->usAckCount = 0;
   mem->dsReqCount = 0;
   mem->dsAckCount = 0;
}

// Map and create shared memory object
static inline AxiStreamSharedMem * sim_open ( uint id ) {
   AxiStreamSharedMem * ptr;
   int                  smemFd;
   char                 shmName[200];

   // Generate shared memory
   sprintf(shmName,"%s.%i.%i",SHM_BASE,getuid(),id);

   // Attempt to open existing shared memory
   if ( (smemFd = shm_open(shmName, O_RDWR, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)) ) < 0 ) {

      // Otherwise open and create shared memory
      if ( (smemFd = shm_open(shmName, (O_CREAT | O_RDWR), (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)) ) < 0 ) return(NULL);

      // Force permissions regardless of umask
      fchmod(smemFd, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
    
      // Set the size of the shared memory segment
      ftruncate(smemFd, sizeof(AxiStreamSharedMem));
   }

   // Map the shared memory
   if((ptr = (AxiStreamSharedMem *)mmap(0, sizeof(AxiStreamSharedMem),
             (PROT_READ | PROT_WRITE), MAP_SHARED, smemFd, 0)) == MAP_FAILED) return(NULL);

   // Store path
   strcpy(ptr->path,shmName);

   init(ptr);

   return(ptr);
}

// close shared memory object
static inline void sim_close ( AxiStreamSharedMem *smem ) {
   char shmName[200];

   // Get shared name
   strcpy(shmName,smem->path);

   // Unlink
   shm_unlink(shmName);
}





#endif
