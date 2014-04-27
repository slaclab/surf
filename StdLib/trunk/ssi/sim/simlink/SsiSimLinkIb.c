
#include "VhpiGeneric.h"
#include <vhpi_user.h>
#include <stdlib.h>
#include <time.h>
#include "SsiSimLinkIb.h"
#include "SimLinkMemory.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

// Init function
void SsiSimLinkIbInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT        *portData  = (portDataT *)        malloc(sizeof(portDataT));
   SsiSimLinkIbData *ibData    = (SsiSimLinkIbData *) malloc(sizeof(SsiSimLinkIbData));

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
   portData->stateData = ibData;

   // State update function
   portData->stateUpdate = *SsiSimLinkIbUpdate;

   // Init data structure
   ibData->currClk      = 0;
   ibData->ibCount      = 0;
   ibData->ibDest       = 0;
   ibData->ibError      = 0;

   // Create shared memory filename
   sprintf(ibData->smemFile,"simlink.%i.%s.%i", getuid(), SHM_NAME, SHM_ID);

   // Open shared memory
   ibData->smemFd = shm_open(ibData->smemFile, (O_CREAT | O_RDWR), (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
   ibData->smem = NULL;

   // Failed to open shred memory
   if ( ibData->smemFd > 0 ) {

      // Force permissions regardless of umask
      fchmod(ibData->smemFd, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));

      // Set the size of the shared memory segment
      ftruncate(ibData->smemFd, sizeof(SimLinkMemory));

      // Map the shared memory
      if((ibData->smem = (SimLinkMemory *)mmap(0, sizeof(SimLinkMemory),
                (PROT_READ | PROT_WRITE), MAP_SHARED, ibData->smemFd, 0)) == MAP_FAILED) {
         ibData->smemFd = -1;
         ibData->smem   = NULL;
      }

      // Init records
      if ( ibData->smem != NULL ) {
         ibData->smem->usReqCount = 0;
         ibData->smem->usAckCount = 0;
      }
   }

   if ( ibData->smem != NULL ) vhpi_printf("SsiSimLinkIb: Opened shared memory file: %s\n", ibData->smemFile);
   else vhpi_printf("SsiSimLinkIb: Failed to open shared memory file: %s\n", ibData->smemFile);

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void SsiSimLinkIbUpdate ( portDataT *portData ) {

   SsiSimLinkIbData *ibData = (SsiSimLinkIbData*)(portData->stateData);

   // Detect clock edge
   if ( ibData->currClk != getInt(ibClk) ) {
      ibData->currClk = getInt(ibClk);

      // Rising edge
      if ( ibData->currClk ) {

         // Reset is asserted, sample modes
         if ( getInt(ibReset) ) {
            ibData->smem->usBigEndian = 0;
            ibData->ibCount           = 0;
            ibData->ibDest            = 0;
            ibData->ibError           = 0;
         }

         // Valid is asserted
         else if ( getInt(ibValid) == 1 ) {

            // First word
            if ( ibData->ibCount == 0 ) {
               ibData->ibError  = 0;
               ibData->ibDest   = getInt(ibDest);
               vhpi_printf("SsiSimLinkIb: Frame Start. Dest=%i, Time=%lld\n",ibData->ibDest,portData->simTime);
            }

            // VC mismatch
            if ( ibData->ibDest != getInt(ibDest) && ibData->ibError == 0 ) {
               vhpi_printf("SsiSimLinkIb: Dest mismatch error.\n");
               ibData->ibError = 1;
            }

            // Get data
            ibData->smem->usData[ibData->ibCount++] = getInt(ibData);

            // EOF is asserted
            if ( getInt(ibDataEof) ) {

               ibData->smem->usEofe = getInt(ibDataEofe);

               // Force EOFE for error
               if ( ibData->ibError ) ibData->smem->usEofe = 1;

               // Send data
               ibData->smem->usVc   = ibData->ibDest;
               ibData->smem->usSize = ibData->ibCount;
               ibData->smem->usReqCount++;

               vhpi_printf("SsiSimLinkIb: Frame Done. Size=%i, Dest=%i, Time=%lld\n",
                  ibData->smem->usSize,ibData->smem->usVc,portData->simTime);

               // Wait for other end
               int toCount = 0;
               while ( ibData->smem->usReqCount != ibData->smem->usAckCount ) {
                  usleep(100);
                  if ( ++toCount > 10000 ) {
                     vhpi_printf("SsiSimLinkIb: Timeout waiting\n");
                     break;
                  }
               }

               ibData->ibCount = 0;
            }

            // Show updates for long frames
            else {
               if ( (ibData->ibCount % 100) == 0 ) {

                  vhpi_printf("SsiSimLinkIb: Frame In Progress. Size=%i, Dest=%i, Payload=%i, Time=%lld\n",
                     ibData->ibSize,ibData->ibDest,ibData->ibCount,portData->simTime);
               }
            }
         }
      }
   }
}

