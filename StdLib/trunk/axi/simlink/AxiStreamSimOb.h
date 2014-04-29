
#ifndef __AXI_STREAM_SIM_OB_H__
#define __AXI_STREAM_SIM_OB_H__

#include <vhpi_user.h>
#include "AxiStreamSharedMem.h"

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
   uint                smemFd;
   AxiStreamSharedMem *smem;
   char                smemFile[1000];

   // Current state of clock
   uint currClk;
   uint obCount;
  
} AxiStreamSimObData;

// Init function
void AxiStreamSimObInit(vhpiHandleT compInst);


// Callback function for updating
void AxiStreamSimObUpdate ( void *userPtr );

#endif

