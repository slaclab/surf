
#ifndef __AXI_STREAM_SIM_IB_H__
#define __AXI_STREAM_SIM_IB_H__

#include <vhpi_user.h>
#include "AxiStreamSharedMem.h"

// Signals
#define ibClk        0
#define ibReset      1
#define ibValid      2
#define ibDest       3
#define ibEof        4
#define ibEofe       5
#define ibData       6

// Structure to track state
typedef struct {

   // Shared memory
   uint                smemFd;
   AxiStreamSharedMem *smem;
   char                smemFile[1000];

   // Current state
   uint currClk;
   uint ibCount;
   uint ibVc;
   uint ibError;

} AxiStreamSimIbData;

// Init function
void AxiStreamSimIbInit(vhpiHandleT compInst);

// Callback function for updating
void AxiStreamSimIbUpdate ( void *userPtr );

#endif

