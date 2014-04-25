
#ifndef __VC64_SIM_LINK_IB_H__
#define __VC64_SIM_LINK_IB_H__

#include <vhpi_user.h>
#include "SimLinkMemory.h"

// Signals
#define ibClk            0
#define ibReset          1
#define ibDataValid      2
#define ibDataSize       3
#define ibDataVc         4
#define ibDataSof        5
#define ibDataEof        6
#define ibDataEofe       7
#define ibDataDataHigh   8
#define ibDataDataLow    9
#define littleEndian     10
#define vcWidth          11

// Structure to track state
typedef struct {

   // Shared memory
   uint          smemFd;
   SimLinkMemory *smem;
   char          smemFile[1000];

   // Current state
   int currClk;
   int ibActive;
   int ibCount;
   int ibSize;
   int ibVc;
   int ibError;
   int littleEnd;
   int width;

} Vc64SimLinkIbData;

// Init function
void Vc64SimLinkIbInit(vhpiHandleT compInst);

// Callback function for updating
void Vc64SimLinkIbUpdate ( portDataT *portData );

#endif
