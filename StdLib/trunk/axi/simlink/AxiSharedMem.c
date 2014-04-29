#include <sys/types.h>
#include <string.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>   
#include <unistd.h>
#include "AxiSharedMem.h"

// Map and create shared memory object
AxiSharedMem * sim_open ( char *system, uint id, int uid ) {
   AxiSharedMem * ptr;
   int            smemFd;
   char           shmName[200];
   int            lid;

   // ID to use?
   if ( uid == -1 ) lid = getuid();
   else lid = uid;

   // Generate shared memory
   sprintf(shmName,"axi_shared.%i.%s.%i",lid,system,id);

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

   // Store variables
   strcpy(ptr->_smemPath,shmName);
   ptr->_smemId = smemFd;

   init(ptr);

   return(ptr);
}

// close shared memory object
void sim_close ( AxiSharedMem *smem ) {
   char shmName[200];

   // Get shared name
   strcpy(shmName,smem->_smemPath);

   // Unlink
   shm_unlink(shmName);
}

// Init variables
void init(AxiSharedMem *ptr) {
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

// Increment clock count
void incrClkCnt(AxiSharedMem *ptr) {
   ptr->_clkCnt++;
}

// Read clock count
uint getClkCnt(AxiSharedMem *ptr) {
   return(ptr->_clkCnt);
}

// Set write addr
void setWriteAddr ( AxiSharedMem *ptr, AxiWriteAddr *writeAddr ) {
   memcpy(&(ptr->_writeAddr),writeAddr,sizeof(AxiWriteAddr));
   ptr->_writeAddrReq++;
}

// Get write addr
uint getWriteAddr ( AxiSharedMem *ptr, AxiWriteAddr *writeAddr ) {
   if ( ptr->_writeAddrReq == ptr->_writeAddrAck ) return(0);
   
   memcpy(writeAddr,&(ptr->_writeAddr),sizeof(AxiWriteAddr));
   ptr->_writeAddrAck = ptr->_writeAddrReq;

   return(1);
}

// Get write addr Busy
uint readyWriteAddr (AxiSharedMem *ptr) {
   return ( ptr->_writeAddrReq == ptr->_writeAddrAck );
}

// Set write data
void setWriteData (AxiSharedMem *ptr,  AxiWriteData *writeData ) {
   memcpy(&(ptr->_writeData),writeData,sizeof(AxiWriteData));
   ptr->_writeDataReq++;
}

// Get write data
uint getWriteData (AxiSharedMem *ptr,  AxiWriteData *writeData ) {
   if ( ptr->_writeDataReq == ptr->_writeDataAck ) return(0);
   
   memcpy(writeData,&(ptr->_writeData),sizeof(AxiWriteData));
   ptr->_writeDataAck = ptr->_writeDataReq;

   return(1);
}

// Get write data Busy
uint readyWriteData (AxiSharedMem *ptr) {
   return ( ptr->_writeDataReq == ptr->_writeDataAck );
}

// Set write comp
void setWriteComp (AxiSharedMem *ptr,  AxiWriteComp *writeComp ) {
   memcpy(&(ptr->_writeComp),writeComp,sizeof(AxiWriteComp));
   ptr->_writeCompReq++;
}

// Get write comp
uint getWriteComp (AxiSharedMem *ptr,  AxiWriteComp *writeComp ) {
   if ( ptr->_writeCompReq == ptr->_writeCompAck ) return(0);
   
   memcpy(writeComp,&(ptr->_writeComp),sizeof(AxiWriteComp));
   ptr->_writeCompAck = ptr->_writeCompReq;

   return(1);
}

// Get write comp Busy
uint readyWriteComp (AxiSharedMem *ptr) {
   return ( ptr->_writeCompReq == ptr->_writeCompAck );
}

// Set read addr
void setReadAddr (AxiSharedMem *ptr,  AxiReadAddr *readAddr ) {
   memcpy(&(ptr->_readAddr),readAddr,sizeof(AxiReadAddr));
   ptr->_readAddrReq++;
}

// Get read addr
uint getReadAddr (AxiSharedMem *ptr,  AxiReadAddr *readAddr ) {
   if ( ptr->_readAddrReq == ptr->_readAddrAck ) return(0);
   
   memcpy(readAddr,&(ptr->_readAddr),sizeof(AxiReadAddr));
   ptr->_readAddrAck = ptr->_readAddrReq;

   return(1);
}

// Get read addr Busy
uint readyReadAddr (AxiSharedMem *ptr) {
   return ( ptr->_readAddrReq == ptr->_readAddrAck );
}

// Set read data
void setReadData (AxiSharedMem *ptr,  AxiReadData *readData ) {
   memcpy(&(ptr->_readData),readData,sizeof(AxiReadData));
   ptr->_readDataReq++;
}

// Get read data
uint getReadData (AxiSharedMem *ptr,  AxiReadData *readData ) {
   if ( ptr->_readDataReq == ptr->_readDataAck ) return(0);
   
   memcpy(readData,&(ptr->_readData),sizeof(AxiReadData));
   ptr->_readDataAck = ptr->_readDataReq;

   return(1);
}

// Get read data Busy
uint readyReadData (AxiSharedMem *ptr) {
   return ( ptr->_readDataReq == ptr->_readDataAck );
}

