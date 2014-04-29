#include <sys/types.h>
#include <string.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>   
#include <unistd.h>
#include "AxiSharedMem.h"

// Map and create shared memory object
AxiSharedMem * AxiSharedMem::open ( std::string system, uint id, int uid ) {
   AxiSharedMem * ptr;
   int            smemFd;
   char           shmName[200];
   int            lid;

   // ID to use?
   if ( uid == -1 ) lid = getuid();
   else lid = uid;

   // Generate shared memory
   sprintf(shmName,"axi_shared.%i.%s.%i",lid,system.c_str(),id);

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

   return(ptr);
}

// close shared memory object
void AxiSharedMem::close ( AxiSharedMem *smem ) {
   char shmName[200];

   // Get shared name
   strcpy(shmName,smem->_smemPath);

   // Unlink
   shm_unlink(shmName);
}

// Constructor
AxiSharedMem::AxiSharedMem () {
   init();
}

// Destructor
AxiSharedMem::~AxiSharedMem () { }

// Init variables
void AxiSharedMem::init() {
   _clkCnt       = 0;
   _writeAddrReq = 0;
   _writeAddrAck = 0;
   _writeDataReq = 0;
   _writeDataAck = 0;
   _writeCompReq = 0;
   _writeCompAck = 0;
   _readAddrReq  = 0;
   _readAddrAck  = 0;
   _readDataReq  = 0;
   _readDataAck  = 0;
}

// Increment clock count
void AxiSharedMem::incrClkCnt() {
   _clkCnt++;
}

// Read clock count
uint AxiSharedMem::getClkCnt() {
   return(_clkCnt);
}

// Set write addr
void AxiSharedMem::setWriteAddr ( AxiWriteAddr *writeAddr ) {
   memcpy(&_writeAddr,writeAddr,sizeof(AxiWriteAddr));
   _writeAddrReq++;
}

// Get write addr
bool AxiSharedMem::getWriteAddr ( AxiWriteAddr *writeAddr ) {
   if ( _writeAddrReq == _writeAddrAck ) return(false);
   
   memcpy(writeAddr,&_writeAddr,sizeof(AxiWriteAddr));
   _writeAddrAck = _writeAddrReq;

   return(true);
}

// Get write addr Busy
bool AxiSharedMem::readyWriteAddr () {
   return ( _writeAddrReq == _writeAddrAck );
}

// Set write data
void AxiSharedMem::setWriteData ( AxiWriteData *writeData ) {
   memcpy(&_writeData,writeData,sizeof(AxiWriteData));
   _writeDataReq++;
}

// Get write data
bool AxiSharedMem::getWriteData ( AxiWriteData *writeData ) {
   if ( _writeDataReq == _writeDataAck ) return(false);
   
   memcpy(writeData,&_writeData,sizeof(AxiWriteData));
   _writeDataAck = _writeDataReq;

   return(true);
}

// Get write data Busy
bool AxiSharedMem::readyWriteData () {
   return ( _writeDataReq == _writeDataAck );
}

// Set write comp
void AxiSharedMem::setWriteComp ( AxiWriteComp *writeComp ) {
   memcpy(&_writeComp,writeComp,sizeof(AxiWriteComp));
   _writeCompReq++;
}

// Get write comp
bool AxiSharedMem::getWriteComp ( AxiWriteComp *writeComp ) {
   if ( _writeCompReq == _writeCompAck ) return(false);
   
   memcpy(writeComp,&_writeComp,sizeof(AxiWriteComp));
   _writeCompAck = _writeCompReq;

   return(true);
}

// Get write comp Busy
bool AxiSharedMem::readyWriteComp () {
   return ( _writeCompReq == _writeCompAck );
}

// Set read addr
void AxiSharedMem::setReadAddr ( AxiReadAddr *readAddr ) {
   memcpy(&_readAddr,readAddr,sizeof(AxiReadAddr));
   _readAddrReq++;
}

// Get read addr
bool AxiSharedMem::getReadAddr ( AxiReadAddr *readAddr ) {
   if ( _readAddrReq == _readAddrAck ) return(false);
   
   memcpy(readAddr,&_readAddr,sizeof(AxiReadAddr));
   _readAddrAck = _readAddrReq;

   return(true);
}

// Get read addr Busy
bool AxiSharedMem::readyReadAddr () {
   return ( _readAddrReq == _readAddrAck );
}

// Set read data
void AxiSharedMem::setReadData ( AxiReadData *readData ) {
   memcpy(&_readData,readData,sizeof(AxiReadData));
   _readDataReq++;
}

// Get read data
bool AxiSharedMem::getReadData ( AxiReadData *readData ) {
   if ( _readDataReq == _readDataAck ) return(false);
   
   memcpy(readData,&_readData,sizeof(AxiReadData));
   _readDataAck = _readDataReq;

   return(true);
}

// Get read data Busy
bool AxiSharedMem::readyReadData () {
   return ( _readDataReq == _readDataAck );
}

