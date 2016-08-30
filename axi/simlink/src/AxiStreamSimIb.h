//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __AXI_STREAM_SIM_IB_H__
#define __AXI_STREAM_SIM_IB_H__

#include <vhpi_user.h>
#include "AxiStreamSharedMem.h"

// Signals
#define s_ibClk        0
#define s_ibReset      1
#define s_ibValid      2
#define s_ibDest       3
#define s_ibEof        4
#define s_ibEofe       5
#define s_ibData       6
#define s_streamId     7

// Structure to track state
typedef struct {

   // Shared memory
   uint                smemFd;
   AxiStreamSharedMem *smem;
   char                smemFile[1000];

   // Current state
   uint currClk;
   uint ibCount;
   uint ibDest;
   uint ibError;

} AxiStreamSimIbData;

// Init function
void AxiStreamSimIbInit(vhpiHandleT compInst);

// Callback function for updating
void AxiStreamSimIbUpdate ( void *userPtr );

#endif

