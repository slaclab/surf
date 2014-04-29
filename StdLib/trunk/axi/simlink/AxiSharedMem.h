#ifndef __AXI_SHARED_MEM_H__
#define __AXI_SHARED_MEM_H__

#include <sys/types.h>

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

   // Tracking objects
   char _smemPath[200];
   int  _smemId;

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
} AxiSharedMem;

// Map and create shared memory object
AxiSharedMem * sim_open ( char *system, uint id, int uid );

// close shared memory object
void sim_close ( AxiSharedMem *smem );

// Init variables
void init(AxiSharedMem *ptr);

// Increment clock count
void incrClkCnt(AxiSharedMem *ptr);

// Read clock count
uint getClkCnt(AxiSharedMem *ptr);

// Set write addr
void setWriteAddr (AxiSharedMem *ptr, AxiWriteAddr *writeAddr );

// Get write addr
uint getWriteAddr (AxiSharedMem *ptr, AxiWriteAddr *writeAddr );

// Get write addr Ready
uint readyWriteAddr (AxiSharedMem *ptr);

// Set write data
void setWriteData (AxiSharedMem *ptr, AxiWriteData *writeData );

// Get write data
uint getWriteData (AxiSharedMem *ptr, AxiWriteData *writeData );

// Get write data Ready
uint readyWriteData (AxiSharedMem *ptr);

// Set write comp
void setWriteComp (AxiSharedMem *ptr, AxiWriteComp *writeComp );

// Get write comp
uint getWriteComp (AxiSharedMem *ptr, AxiWriteComp *writeComp );

// Get write comp Ready
uint readyWriteComp (AxiSharedMem *ptr);

// Set read addr
void setReadAddr (AxiSharedMem *ptr, AxiReadAddr *readAddr );

// Get read addr
uint getReadAddr (AxiSharedMem *ptr, AxiReadAddr *readAddr );

// Get read addr Ready
uint readyReadAddr (AxiSharedMem *ptr);

// Set read data
void setReadData (AxiSharedMem *ptr, AxiReadData *readData );

// Get read data
uint getReadData (AxiSharedMem *ptr, AxiReadData *readData );

// Get read data Ready
uint readyReadData (AxiSharedMem *ptr);

#endif
