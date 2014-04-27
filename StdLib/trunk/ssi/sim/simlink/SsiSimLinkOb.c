
#include "VhpiGeneric.h"
#include <vhpi_user.h>
#include <stdlib.h>
#include <time.h>
#include "SsiSimLinkOb.h"
#include "SimLinkMemory.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>

// Init function
void SsiSimLinkObInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT        *portData  = (portDataT *)        malloc(sizeof(portDataT));
   SsiSimLinkObData *obData    = (SsiSimLinkObData *) malloc(sizeof(SsiSimLinkObData));

   // Get port count
   portData->portCount = 7;

   // Set port directions
   portData->portDir[obClk]      = vhpiIn; 
   portData->portDir[obReset]    = vhpiIn; 
   portData->portDir[obValid]    = vhpiOut;
   portData->portDir[obDest]     = vhpiOut;
   portData->portDir[obEof]      = vhpiOut;
   portData->portDir[obData]     = vhpiOut;
   portData->portDir[obReady]    = vhpiIn; 

   // Set port widths
   portData->portWidth[obClk]    = 1;
   portData->portWidth[obReset]  = 1;
   portData->portWidth[obValid]  = 1;
   portData->portWidth[obDest]   = 4;
   portData->portWidth[obEof]    = 1;
   portData->portWidth[obData]   = 32;
   portData->portWidth[obReady]  = 1;

   // Create data structure to hold state
   portData->stateData = obData;

   // State update function
   portData->stateUpdate = *SsiSimLinkObUpdate;

   // Init data structure
   obData->currClk   = 0;
   obData->obCount   = 0;
   obData->obSize    = 0;
   obData->obLast    = 0;
   obData->width     = 0;
   obData->obActive  = 0;

   // Create shared memory filename
   sprintf(obData->smemFile,"simlink.%i.%s.%i", getuid(), SHM_NAME, SHM_ID);

   // Open shared memory
   obData->smemFd = shm_open(obData->smemFile, (O_CREAT | O_RDWR), (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
   obData->smem = NULL;

   // Failed to open shred memory
   if ( obData->smemFd > 0 ) {

      // Force permissions regardless of umask
      fchmod(obData->smemFd, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));

      // Set the size of the shared memory segment
      ftruncate(obData->smemFd, sizeof(SimLinkMemory));

      // Map the shared memory
      if((obData->smem = (SimLinkMemory *)mmap(0, sizeof(SimLinkMemory),
                (PROT_READ | PROT_WRITE), MAP_SHARED, obData->smemFd, 0)) == MAP_FAILED) {
         obData->smemFd = -1;
         obData->smem   = NULL;
      }

      // Init records
      if ( obData->smem != NULL ) {
         obData->smem->dsReqCount = 0;
         obData->smem->dsAckCount = 0;
      }
   }

   if ( obData->smem != NULL ) vhpi_printf("SsiSimLinkOb: Opened shared memory file: %s\n", obData->smemFile);
   else vhpi_printf("SsiSimLinkOb: Failed to open shared memory file: %s\n", obData->smemFile);

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void SsiSimLinkObUpdate ( portDataT *portData ) {

   SsiSimLinkObData *obData = (SsiSimLinkObData*)(portData->stateData);

   // Detect clock edge
   if ( obData->currClk != getInt(obClk) ) {
      obData->currClk = getInt(obClk);

      // Rising edge
      if ( obData->currClk ) {

         // Reset is asserted
         if ( getInt(obReset) == 1 ) {
            obData->smem->dsBigEndian = 0;
            obData->obCount           = 0;
            setInt(obValid,0);
         } 

         // Not active
         else if ( obData->obCount == 0 ) {

            // Check for available data
            if ( obData->smem->dsReqCount != obData->smem->dsAckCount ) {
               vhpi_printf("SsiSimLinkOb: Frame Start. Size=%i, Dest=%i, Time=%lld\n",
                  obData->smem->dsSize,obData->smem->dsVc,portData->simTime);
               obData->obActive = 1;
               obData->obCount  = 0;

               // Setup frame
               setInt(obEof,0);
               setInt(obDest,obData->smem->dsVc);
               setInt(obValid,1);

               // Output first data
               setInt(obDataDataLow,obData->smem->dsData[obData->obCount++]);
               if ( obData->obCount == obData->smem->dsSize ) setInt(obDataEof,1);
            }
         }

         // Ready is asserted
         else if ( getInt(obReady) ) {

            // Frame is done
            if ( obData->obCount == obData->smem->dsSize ) {
               obData->obCount = 0;
               setInt(obValid,0);

               vhpi_printf("SsiSimLinkOb: Frame Done. Size=%i, Dest=%i, Time=%lld\n",
                  obData->smem->dsSize,obData->smem->dsVc,portData->simTime);
               obData->smem->dsAckCount = obData->smem->dsReqCount;
            }

            // Next word
            else {
               setInt(obDataDataLow,obData->smem->dsData[obData->obCount++]);
               if ( obData->obCount == obData->smem->dsSize ) setInt(obDataEof,1);
            }
         }
      }
   }
}

