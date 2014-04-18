
#ifndef __SIM_LINK_RX_H__
#define __SIM_LINK_RX_H__

#include <vhpi_user.h>
#include "SimLinkMemory.h"

// Signals
#define obClk            0
#define obReset          1
#define obDataValid      2
#define obDataSize       3
#define obDataVc         4
#define obDataSof        5
#define obDataEof        6
#define obDataEofe       7
#define obDataDataHigh   8
#define obDataDataLow    9
#define obReady          10
#define littleEndian     11
#define vcWidth          12

// Structure to track state
typedef struct {

   // Shared memory
   uint          smemFd;
   SimLinkMemory *smem;
   char          smemFile[1000];

   // Current state of clock
   int currClk;
   int obCount;
   int obSize;
   int obLast;
   int littleEndian;
   int vcWidth;
  
} Vc64SimlLinkObData;


// Init function
void Vc64SimlLinkObInit(vhpiHandleT compInst);


// Callback function for updating
void Vc64SimlLinkObUpdate ( portDataT *portData );

#endif
