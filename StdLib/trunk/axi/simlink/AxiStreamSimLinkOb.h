
#ifndef __SSI_SIM_LINK_OB_H__
#define __SSI_SIM_LINK_OB_H__

#include <vhpi_user.h>
#include "SimLinkMemory.h"

// Signals
#define obClk            0
#define obReset          1
#define obValid          2
#define obDest           3
#define obEof            4
#define obData           5
#define obReady          6

// Structure to track state
typedef struct {

   // Shared memory
   uint          smemFd;
   SimLinkMemory *smem;
   char          smemFile[1000];

   // Current state of clock
   int currClk;
   int obCount;
  
} AxiStreamSimLinkObData;


// Init function
void AxiStreamSimLinkObInit(vhpiHandleT compInst);


// Callback function for updating
void AxiStreamSimLinkObUpdate ( portDataT *portData );

#endif

