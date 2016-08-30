//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef __AXI_SHARED_MEM_H__
#define __AXI_SHARED_MEM_H__

#include <sys/types.h>
#include <sys/types.h>
#include <string.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>   
#include <unistd.h>

#define SHM_AXI_BASE "axi_shared"

// Write address record
typedef struct {
   uint awaddr;
   uint awid;
   uint awlen;
   uint awsize;
   uint awburst;
   uint awlock;
   uint awcache;
   uint awprot;
} AxiWriteAddr;

// Write data record
typedef struct {
   uint wdataH;
   uint wdataL;
   uint wlast;
   uint wid;
   uint wstrb;
} AxiWriteData;

// Write completion record
typedef struct {
   uint bresp;
   uint bid;
} AxiWriteComp;

// Read address record
typedef struct {
   uint araddr;
   uint arid;
   uint arlen;
   uint arsize;
   uint arburst;
   uint arlock;
   uint arprot;
   uint arcache;
} AxiReadAddr;

// Read data record
typedef struct {
   uint rdataH;
   uint rdataL;
   uint rlast;
   uint rid;
   uint rresp;
} AxiReadData;

typedef struct {

   // Clock counter
   uint _clkCnt;

   // Write records
   AxiWriteAddr _writeAddr;
   uint         _writeAddrReq;
   uint         _writeAddrAck;
   AxiWriteData _writeData;
   uint         _writeDataReq;
   uint         _writeDataAck;
   AxiWriteComp _writeComp;
   uint         _writeCompReq;
   uint         _writeCompAck;

   // Read records
   AxiReadAddr  _readAddr;
   uint         _readAddrReq;
   uint         _readAddrAck;
   AxiReadData  _readData;
   uint         _readDataReq;
   uint         _readDataAck;

   // Shard path
   char _path[200];

} AxiSharedMem;

// Init variables
static inline void init(AxiSharedMem *ptr) {
   ptr->_clkCnt       = 0;
   ptr->_writeAddrReq = 0;
   ptr->_writeAddrAck = 0;
   ptr->_writeDataReq = 0;
   ptr->_writeDataAck = 0;
   ptr->_writeCompReq = 0;
   ptr->_writeCompAck = 0;
   ptr->_readAddrReq  = 0;
   ptr->_readAddrAck  = 0;
   ptr->_readDataReq  = 0;
   ptr->_readDataAck  = 0;
}

// Map and create shared memory object
static inline AxiSharedMem * sim_open ( const char *type, uint id ) {
   AxiSharedMem * ptr;
   int            smemFd;
   char           shmName[200];

   // Generate shared memory
   sprintf(shmName,"%s.%i.%s.%i",SHM_AXI_BASE,getuid(),type,id);

   // Attempt to open existing shared memory
   if ( (smemFd = shm_open(shmName, O_RDWR, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)) ) < 0 ) {

      // Otherwise open and create shared memory
      if ( (smemFd = shm_open(shmName, (O_CREAT | O_RDWR), (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)) ) < 0 ) return(NULL);

      // Force permissions regardless of umask
      fchmod(smemFd, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
    
      // Set the size of the shared memory segment
      ftruncate(smemFd, sizeof(AxiSharedMem));
   }

   // Map the shared memory
   if((ptr = (AxiSharedMem *)mmap(0, sizeof(AxiSharedMem),
             (PROT_READ | PROT_WRITE), MAP_SHARED, smemFd, 0)) == MAP_FAILED) return(NULL);

   // Store path
   strcpy(ptr->_path,shmName);

   init(ptr);

   return(ptr);
}

// close shared memory object
static inline void sim_close ( AxiSharedMem *smem ) {
   char shmName[200];

   // Get shared name
   strcpy(shmName,smem->_path);

   // Unlink
   shm_unlink(shmName);
}

// Increment clock count
static inline void incrClkCnt(AxiSharedMem *ptr) {
   ptr->_clkCnt++;
}

// Read clock count
static inline uint getClkCnt(AxiSharedMem *ptr) {
   return(ptr->_clkCnt);
}

// Set write addr
static inline void setWriteAddr ( AxiSharedMem *ptr, AxiWriteAddr *writeAddr ) {
   memcpy(&(ptr->_writeAddr),writeAddr,sizeof(AxiWriteAddr));
   ptr->_writeAddrReq++;
}

// Get write addr
static inline uint getWriteAddr ( AxiSharedMem *ptr, AxiWriteAddr *writeAddr ) {
   if ( ptr->_writeAddrReq == ptr->_writeAddrAck ) return(0);
   
   memcpy(writeAddr,&(ptr->_writeAddr),sizeof(AxiWriteAddr));
   ptr->_writeAddrAck = ptr->_writeAddrReq;

   return(1);
}

// Get write addr Busy
static inline uint readyWriteAddr (AxiSharedMem *ptr) {
   return ( ptr->_writeAddrReq == ptr->_writeAddrAck );
}

// Set write data
static inline void setWriteData (AxiSharedMem *ptr,  AxiWriteData *writeData ) {
   memcpy(&(ptr->_writeData),writeData,sizeof(AxiWriteData));
   ptr->_writeDataReq++;
}

// Get write data
static inline uint getWriteData (AxiSharedMem *ptr,  AxiWriteData *writeData ) {
   if ( ptr->_writeDataReq == ptr->_writeDataAck ) return(0);
   
   memcpy(writeData,&(ptr->_writeData),sizeof(AxiWriteData));
   ptr->_writeDataAck = ptr->_writeDataReq;

   return(1);
}

// Get write data Busy
static inline uint readyWriteData (AxiSharedMem *ptr) {
   return ( ptr->_writeDataReq == ptr->_writeDataAck );
}

// Set write comp
static inline void setWriteComp (AxiSharedMem *ptr,  AxiWriteComp *writeComp ) {
   memcpy(&(ptr->_writeComp),writeComp,sizeof(AxiWriteComp));
   ptr->_writeCompReq++;
}

// Get write comp
static inline uint getWriteComp (AxiSharedMem *ptr,  AxiWriteComp *writeComp ) {
   if ( ptr->_writeCompReq == ptr->_writeCompAck ) return(0);
   
   memcpy(writeComp,&(ptr->_writeComp),sizeof(AxiWriteComp));
   ptr->_writeCompAck = ptr->_writeCompReq;

   return(1);
}

// Get write comp Busy
static inline uint readyWriteComp (AxiSharedMem *ptr) {
   return ( ptr->_writeCompReq == ptr->_writeCompAck );
}

// Set read addr
static inline void setReadAddr (AxiSharedMem *ptr,  AxiReadAddr *readAddr ) {
   memcpy(&(ptr->_readAddr),readAddr,sizeof(AxiReadAddr));
   ptr->_readAddrReq++;
}

// Get read addr
static inline uint getReadAddr (AxiSharedMem *ptr,  AxiReadAddr *readAddr ) {
   if ( ptr->_readAddrReq == ptr->_readAddrAck ) return(0);
   
   memcpy(readAddr,&(ptr->_readAddr),sizeof(AxiReadAddr));
   ptr->_readAddrAck = ptr->_readAddrReq;

   return(1);
}

// Get read addr Busy
static inline uint readyReadAddr (AxiSharedMem *ptr) {
   return ( ptr->_readAddrReq == ptr->_readAddrAck );
}

// Set read data
static inline void setReadData (AxiSharedMem *ptr,  AxiReadData *readData ) {
   memcpy(&(ptr->_readData),readData,sizeof(AxiReadData));
   ptr->_readDataReq++;
}

// Get read data
static inline uint getReadData (AxiSharedMem *ptr,  AxiReadData *readData ) {
   if ( ptr->_readDataReq == ptr->_readDataAck ) return(0);
   
   memcpy(readData,&(ptr->_readData),sizeof(AxiReadData));
   ptr->_readDataAck = ptr->_readDataReq;

   return(1);
}

// Get read data Busy
static inline uint readyReadData (AxiSharedMem *ptr) {
   return ( ptr->_readDataReq == ptr->_readDataAck );
}

#endif

