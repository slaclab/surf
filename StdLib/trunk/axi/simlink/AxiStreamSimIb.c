
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

// Elab function
void AxiStreamSimIbElab(vhpiHandleT compInst) { 
   VhpiGenericElab(compInst);
}

// Init function
void AxiStreamSimIbInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT          *portData  = (portDataT *)          malloc(sizeof(portDataT));
   AxiStreamSimIbData *ibPtr     = (AxiStreamSimIbData *) malloc(sizeof(AxiStreamSimIbData));

   // Get port count
   portData->portCount = 7;

   // Set port directions
   portData->portDir[ibClk]        = vhpiIn;
   portData->portDir[ibReset]      = vhpiIn;
   portData->portDir[ibValid]      = vhpiIn;
   portData->portDir[ibDest]       = vhpiIn;
   portData->portDir[ibEof]        = vhpiIn;
   portData->portDir[ibEofe]       = vhpiIn;
   portData->portDir[ibData]       = vhpiIn;

   // Set port and widths
   portData->portWidth[ibClk]      = 1; 
   portData->portWidth[ibReset]    = 1; 
   portData->portWidth[ibValid]    = 1; 
   portData->portWidth[ibDest]     = 4; 
   portData->portWidth[ibEof]      = 1; 
   portData->portWidth[ibEofe]     = 1; 
   portData->portWidth[ibData]     = 32; 

   // Create data structure to hold state
   portData->stateData = ibPtr;

   // State update function
   portData->stateUpdate = *AxiStreamSimIbUpdate;

   // Init data structure
   ibPtr->currClk      = 0;
   ibPtr->ibCount      = 0;
   ibPtr->ibVc         = 0;
   ibPtr->ibError      = 0;

   // Create shared memory filename
   sprintf(ibPtr->smemFile,"simlink.%i.%s.%i", getuid(), SHM_NAME, SHM_ID);

   // Open shared memory
   ibPtr->smemFd = shm_open(ibPtr->smemFile, (O_CREAT | O_RDWR), (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
   ibPtr->smem = NULL;

   // Failed to open shred memory
   if ( ibPtr->smemFd > 0 ) {

      // Force permissions regardless of umask
      fchmod(ibPtr->smemFd, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));

      // Set the size of the shared memory segment
      ftruncate(ibPtr->smemFd, sizeof(AxiStreamSharedMem));

      // Map the shared memory
      if((ibPtr->smem = (AxiStreamSharedMem *)mmap(0, sizeof(AxiStreamSharedMem),
         (PROT_READ | PROT_WRITE), MAP_SHARED, ibPtr->smemFd, 0)) == MAP_FAILED) {
         ibPtr->smemFd = -1;
         ibPtr->smem   = NULL;
      }

      // Init records
      if ( ibPtr->smem != NULL ) {
         ibPtr->smem->usReqCount = 0;
         ibPtr->smem->usAckCount = 0;
      }
   }

   if ( ibPtr->smem != NULL ) vhpi_printf("AxiStreamSimIb: Opened shared memory file: %s\n", ibPtr->smemFile);
   else vhpi_printf("AxiStreamSimIb: Failed to open shared memory file: %s\n", ibPtr->smemFile);

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void AxiStreamSimIbUpdate ( void *userPtr ) {

   portDataT *portData = (portDataT*) userPtr;
   AxiStreamSimIbData *ibPtr = (AxiStreamSimIbData*)(portData->stateData);

   // Detect clock edge
   if ( ibPtr->currClk != getInt(ibClk) ) {
      ibPtr->currClk = getInt(ibClk);

      // Rising edge
      if ( ibPtr->currClk ) {

         // Reset is asserted, sample modes
         if ( getInt(ibReset) ) {
            ibPtr->smem->usBigEndian = 0;
            ibPtr->ibCount           = 0;
            ibPtr->ibVc              = 0;
            ibPtr->ibError           = 0;
         }

         // Valid is asserted
         else if ( getInt(ibValid) == 1 ) {

            // First word
            if ( ibPtr->ibCount == 0 ) {
               ibPtr->ibError  = 0;
               ibPtr->ibVc     = getInt(ibDest);
               vhpi_printf("AxiStreamSimIb: Frame Start. Dest=%i, Time=%lld\n",ibPtr->ibVc,portData->simTime);
            }

            // VC mismatch
            if ( ibPtr->ibVc != getInt(ibDest) && ibPtr->ibError == 0 ) {
               vhpi_printf("AxiStreamSimIb: Dest mismatch error.\n");
               ibPtr->ibError = 1;
            }

            // Get data
            ibPtr->smem->usData[ibPtr->ibCount++] = getInt(ibData);

            // EOF is asserted
            if ( getInt(ibEof) ) {

               ibPtr->smem->usEofe = getInt(ibEofe);

               // Force EOFE for error
               if ( ibPtr->ibError ) ibPtr->smem->usEofe = 1;

               // Send data
               ibPtr->smem->usVc   = ibPtr->ibVc;
               ibPtr->smem->usSize = ibPtr->ibCount;
               ibPtr->smem->usReqCount++;

               vhpi_printf("AxiStreamSimIb: Frame Done. Size=%i, Dest=%i, Time=%lld\n",
                  ibPtr->smem->usSize,ibPtr->smem->usVc,portData->simTime);

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
                     ibPtr->ibCount,ibPtr->ibVc,ibPtr->ibCount,portData->simTime);
               }
            }
         }
      }
   }
}

