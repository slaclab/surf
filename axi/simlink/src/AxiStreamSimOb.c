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
#include "AxiStreamSimOb.h"
#include "AxiStreamSharedMem.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>

// Init function
void AxiStreamSimObInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT          *portData  = (portDataT *)          malloc(sizeof(portDataT));
   AxiStreamSimObData *obPtr     = (AxiStreamSimObData *) malloc(sizeof(AxiStreamSimObData));

   // Get port count
   portData->portCount = 8;

   // Set port directions
   portData->portDir[s_obClk]      = vhpiIn; 
   portData->portDir[s_obReset]    = vhpiIn; 
   portData->portDir[s_obValid]    = vhpiOut;
   portData->portDir[s_obDest]     = vhpiOut;
   portData->portDir[s_obEof]      = vhpiOut;
   portData->portDir[s_obData]     = vhpiOut;
   portData->portDir[s_obReady]    = vhpiIn; 
   portData->portDir[s_streamId]   = vhpiIn; 

   // Set port widths
   portData->portWidth[s_obClk]    = 1;
   portData->portWidth[s_obReset]  = 1;
   portData->portWidth[s_obValid]  = 1;
   portData->portWidth[s_obDest]   = 4;
   portData->portWidth[s_obEof]    = 1;
   portData->portWidth[s_obData]   = 32;
   portData->portWidth[s_obReady]  = 1;
   portData->portWidth[s_streamId] = 8;

   // Create data structure to hold state
   portData->stateData = obPtr;

   // State update function
   portData->stateUpdate = *AxiStreamSimObUpdate;

   // Init data structure
   obPtr->currClk   = 0;
   obPtr->obCount   = 0;
   obPtr->smem      = NULL;

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void AxiStreamSimObUpdate ( void *userPtr ) {

   portDataT *portData = (portDataT*) userPtr;
   AxiStreamSimObData *obPtr = (AxiStreamSimObData*)(portData->stateData);

   // Not yet open
   if ( obPtr->smem == NULL ) {

      // Get ID
      uint id = getInt(s_streamId);
      obPtr->smem = sim_open(id);

      if ( obPtr->smem != NULL ) vhpi_printf("AxiStreamSimOb: Opened shared memory: %s\n", obPtr->smem->path);
      else vhpi_printf("AxiStreamSimOb: Failed to open shared memory id: %i\n", id);
   }

   // Detect clock edge
   if ( obPtr->currClk != getInt(s_obClk) ) {
      obPtr->currClk = getInt(s_obClk);

      // Rising edge
      if ( obPtr->currClk ) {

         // Reset is asserted
         if ( getInt(s_obReset) == 1 ) {
            obPtr->obCount           = 0;
            setInt(s_obValid,0);
         } 

         // Not active
         else if ( obPtr->obCount == 0 ) {

            // Check for available data
            if ( obPtr->smem->dsReqCount != obPtr->smem->dsAckCount ) {
               vhpi_printf("AxiStreamSimOb: Frame Start. Size=%i, Dest=%i, Time=%lld\n",
                  obPtr->smem->dsSize,obPtr->smem->dsDest,portData->simTime);
               obPtr->obCount  = 0;

               // Setup frame
               setInt(s_obEof,0);
               setInt(s_obDest,obPtr->smem->dsDest);
               setInt(s_obValid,1);

               // Output first data
               setInt(s_obData,obPtr->smem->dsData[obPtr->obCount++]);
               if ( obPtr->obCount == obPtr->smem->dsSize ) setInt(s_obEof,1);
            }
         }

         // Ready is asserted
         else if ( getInt(s_obReady) ) {

            // Frame is done
            if ( obPtr->obCount == obPtr->smem->dsSize ) {
               obPtr->obCount = 0;
               setInt(s_obValid,0);

               vhpi_printf("AxiStreamSimOb: Frame Done. Size=%i, Dest=%i, Time=%lld\n",
                  obPtr->smem->dsSize,obPtr->smem->dsDest,portData->simTime);
               obPtr->smem->dsAckCount = obPtr->smem->dsReqCount;
            }

            // Next word
            else {
               setInt(s_obData,obPtr->smem->dsData[obPtr->obCount++]);
               if ( obPtr->obCount == obPtr->smem->dsSize ) setInt(s_obEof,1);
            }
         }
      }
   }
}

