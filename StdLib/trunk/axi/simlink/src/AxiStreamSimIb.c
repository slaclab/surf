//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include "VhpiGeneric.h"
#include <vhpi_user.h>
#include <stdlib.h>
#include <time.h>
#include "AxiStreamSimIb.h"
#include "AxiStreamSharedMem.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

// Init function
void AxiStreamSimIbInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT          *portData  = (portDataT *)          malloc(sizeof(portDataT));
   AxiStreamSimIbData *ibPtr     = (AxiStreamSimIbData *) malloc(sizeof(AxiStreamSimIbData));

   // Get port count
   portData->portCount = 8;

   // Set port directions
   portData->portDir[s_ibClk]        = vhpiIn;
   portData->portDir[s_ibReset]      = vhpiIn;
   portData->portDir[s_ibValid]      = vhpiIn;
   portData->portDir[s_ibDest]       = vhpiIn;
   portData->portDir[s_ibEof]        = vhpiIn;
   portData->portDir[s_ibEofe]       = vhpiIn;
   portData->portDir[s_ibData]       = vhpiIn;
   portData->portDir[s_streamId]     = vhpiIn;

   // Set port and widths
   portData->portWidth[s_ibClk]      = 1; 
   portData->portWidth[s_ibReset]    = 1; 
   portData->portWidth[s_ibValid]    = 1; 
   portData->portWidth[s_ibDest]     = 4; 
   portData->portWidth[s_ibEof]      = 1; 
   portData->portWidth[s_ibEofe]     = 1; 
   portData->portWidth[s_ibData]     = 32; 
   portData->portWidth[s_streamId]   = 8;

   // Create data structure to hold state
   portData->stateData = ibPtr;

   // State update function
   portData->stateUpdate = *AxiStreamSimIbUpdate;

   // Init data structure
   ibPtr->currClk      = 0;
   ibPtr->ibCount      = 0;
   ibPtr->ibDest       = 0;
   ibPtr->ibError      = 0;
   ibPtr->smem         = NULL;

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void AxiStreamSimIbUpdate ( void *userPtr ) {

   portDataT *portData = (portDataT*) userPtr;
   AxiStreamSimIbData *ibPtr = (AxiStreamSimIbData*)(portData->stateData);

   // Not yet open
   if ( ibPtr->smem == NULL ) {

      // Get ID
      uint id = getInt(s_streamId);
      ibPtr->smem = sim_open(id);

      if ( ibPtr->smem != NULL ) vhpi_printf("AxiStreamSimIb: Opened shared memory: %s\n", ibPtr->smem->path);
      else vhpi_printf("AxiStreamSimIb: Failed to open shared memory id: %i\n", id);
   }

   // Detect clock edge
   if ( ibPtr->currClk != getInt(s_ibClk) ) {
      ibPtr->currClk = getInt(s_ibClk);

      // Rising edge
      if ( ibPtr->currClk ) {

         // Reset is asserted, sample modes
         if ( getInt(s_ibReset) ) {
            ibPtr->ibCount           = 0;
            ibPtr->ibDest            = 0;
            ibPtr->ibError           = 0;
         }

         // Valid is asserted
         else if ( getInt(s_ibValid) == 1 ) {

            // First word
            if ( ibPtr->ibCount == 0 ) {
               ibPtr->ibError  = 0;
               ibPtr->ibDest   = getInt(s_ibDest);
               vhpi_printf("AxiStreamSimIb: Frame Start. Dest=%i, Time=%lld\n",ibPtr->ibDest,portData->simTime);
            }

            // VC mismatch
            if ( ibPtr->ibDest != getInt(s_ibDest) && ibPtr->ibError == 0 ) {
               vhpi_printf("AxiStreamSimIb: Dest mismatch error.\n");
               ibPtr->ibError = 1;
            }

            // Get data
            ibPtr->smem->usData[ibPtr->ibCount++] = getInt(s_ibData);

            // EOF is asserted
            if ( getInt(s_ibEof) ) {

               ibPtr->smem->usEofe = getInt(s_ibEofe);

               // Force EOFE for error
               if ( ibPtr->ibError ) ibPtr->smem->usEofe = 1;

               // Send data
               ibPtr->smem->usDest = ibPtr->ibDest;
               ibPtr->smem->usSize = ibPtr->ibCount;
               ibPtr->smem->usReqCount++;

               vhpi_printf("AxiStreamSimIb: Frame Done. Size=%i, Dest=%i, Time=%lld\n",
                  ibPtr->smem->usSize,ibPtr->smem->usDest,portData->simTime);

               // Wait for other end
               int toCount = 0;
               while ( ibPtr->smem->usReqCount != ibPtr->smem->usAckCount ) {
                  usleep(100);
                  if ( ++toCount > 10000 ) {
                     vhpi_printf("AxiStreamSimIb: Timeout waiting\n");
                     break;
                  }
               }

               ibPtr->ibCount = 0;
            }

            // Show updates for long frames
            else {
               if ( (ibPtr->ibCount % 100) == 0 ) {

                  vhpi_printf("AxiStreamSimIb: Frame In Progress. Size=%i, Dest=%i, Payload=%i, Time=%lld\n",
                     ibPtr->ibCount,ibPtr->ibDest,ibPtr->ibCount,portData->simTime);
               }
            }
         }
      }
   }
}

