
#ifndef __SSI_SIM_LINK_IB_H__
#define __SSI_SIM_LINK_IB_H__

#include <vhpi_user.h>
#include "SimLinkMemory.h"

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
   uint          smemFd;
   SimLinkMemory *smem;
   char          smemFile[1000];

   // Current state
   int currClk;
   int ibCount;
   int ibVc;
   int ibError;

} AxiStreamSimLinkIbData;

// Init function
void AxiStreamSimLinkIbInit(vhpiHandleT compInst);

// Callback function for updating
void AxiStreamSimLinkIbUpdate ( portDataT *portData );

#endif

