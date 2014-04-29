
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

// Elab function
void AxiStreamSimObElab(vhpiHandleT compInst) { 
   VhpiGenericElab(compInst);
}

// Init function
void AxiStreamSimObInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT          *portData  = (portDataT *)          malloc(sizeof(portDataT));
   AxiStreamSimObData *obPtr     = (AxiStreamSimObData *) malloc(sizeof(AxiStreamSimObData));

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
   portData->stateData = obPtr;

   // State update function
   portData->stateUpdate = *AxiStreamSimObUpdate;

   // Init data structure
   obPtr->currClk   = 0;
   obPtr->obCount   = 0;

   // Create shared memory filename
   sprintf(obPtr->smemFile,"simlink.%i.%s.%i", getuid(), SHM_NAME, SHM_ID);

   // Open shared memory
   obPtr->smemFd = shm_open(obPtr->smemFile, (O_CREAT | O_RDWR), (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
   obPtr->smem = NULL;

   // Failed to open shred memory
   if ( obPtr->smemFd > 0 ) {

      // Force permissions regardless of umask
      fchmod(obPtr->smemFd, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));

      // Set the size of the shared memory segment
      ftruncate(obPtr->smemFd, sizeof(AxiStreamSimMemory));

      // Map the shared memory
      if((obPtr->smem = (AxiStreamSimMemory *)mmap(0, sizeof(AxiStreamSimMemory),
                (PROT_READ | PROT_WRITE), MAP_SHARED, obPtr->smemFd, 0)) == MAP_FAILED) {
         obPtr->smemFd = -1;
         obPtr->smem   = NULL;
      }

      // Init records
      if ( obPtr->smem != NULL ) {
         obPtr->smem->dsReqCount = 0;
         obPtr->smem->dsAckCount = 0;
      }
   }

   if ( obPtr->smem != NULL ) vhpi_printf("AxiStreamSimOb: Opened shared memory file: %s\n", obPtr->smemFile);
   else vhpi_printf("AxiStreamSimOb: Failed to open shared memory file: %s\n", obPtr->smemFile);

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void AxiStreamSimObUpdate ( void *userPtr ) {

   portDataT *portData = (portDataT*) userPtr;
   AxiStreamSimObData *obPtr = (AxiStreamSimObData*)(portData->stateData);

   // Detect clock edge
   if ( obPtr->currClk != getInt(obClk) ) {
      obPtr->currClk = getInt(obClk);

      // Rising edge
      if ( obPtr->currClk ) {

         // Reset is asserted
         if ( getInt(obReset) == 1 ) {
            obPtr->smem->dsBigEndian = 0;
            obPtr->obCount           = 0;
            setInt(obValid,0);
         } 

         // Not active
         else if ( obPtr->obCount == 0 ) {

            // Check for available data
            if ( obPtr->smem->dsReqCount != obPtr->smem->dsAckCount ) {
               vhpi_printf("AxiStreamSimOb: Frame Start. Size=%i, Dest=%i, Time=%lld\n",
                  obPtr->smem->dsSize,obPtr->smem->dsVc,portData->simTime);
               obPtr->obCount  = 0;

               // Setup frame
               setInt(obEof,0);
               setInt(obDest,obPtr->smem->dsVc);
               setInt(obValid,1);

               // Output first data
               setInt(obData,obPtr->smem->dsData[obPtr->obCount++]);
               if ( obPtr->obCount == obPtr->smem->dsSize ) setInt(obEof,1);
            }
         }

         // Ready is asserted
         else if ( getInt(obReady) ) {

            // Frame is done
            if ( obPtr->obCount == obPtr->smem->dsSize ) {
               obPtr->obCount = 0;
               setInt(obValid,0);

               vhpi_printf("AxiStreamSimOb: Frame Done. Size=%i, Dest=%i, Time=%lld\n",
                  obPtr->smem->dsSize,obPtr->smem->dsVc,portData->simTime);
               obPtr->smem->dsAckCount = obPtr->smem->dsReqCount;
            }

            // Next word
            else {
               setInt(obData,obPtr->smem->dsData[obPtr->obCount++]);
               if ( obPtr->obCount == obPtr->smem->dsSize ) setInt(obEof,1);
            }
         }
      }
   }
}

