
#include "VhpiGeneric.h"
#include <vhpi_user.h>
#include <stdlib.h>
#include <time.h>
#include "Vc64SimLinkOb.h"
#include "SimLinkMemory.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>

// Init function
void Vc64SimLinkObInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT         *portData  = (portDataT *)         malloc(sizeof(portDataT));
   Vc64SimLinkObData *obData    = (Vc64SimLinkObData *) malloc(sizeof(Vc64SimLinkObData));

   // Get port count
   portData->portCount = 13;

   // Set port directions
   portData->portDir[obClk]          = vhpiIn; 
   portData->portDir[obReset]        = vhpiIn; 
   portData->portDir[obDataValid]    = vhpiOut;
   portData->portDir[obDataSize]     = vhpiOut;
   portData->portDir[obDataVc]       = vhpiOut;
   portData->portDir[obDataSof]      = vhpiOut;
   portData->portDir[obDataEof]      = vhpiOut;
   portData->portDir[obDataEofe]     = vhpiOut;
   portData->portDir[obDataDataHigh] = vhpiOut;
   portData->portDir[obDataDataLow]  = vhpiOut;
   portData->portDir[obReady]        = vhpiIn; 
   portData->portDir[littleEndian]   = vhpiIn; 
   portData->portDir[vcWidth]        = vhpiIn; 

   // Set port widths
   portData->portWidth[obClk]          = 1;
   portData->portWidth[obReset]        = 1;
   portData->portWidth[obDataValid]    = 1;
   portData->portWidth[obDataSize]     = 1;
   portData->portWidth[obDataVc]       = 4;
   portData->portWidth[obDataSof]      = 1;
   portData->portWidth[obDataEof]      = 1;
   portData->portWidth[obDataEofe]     = 1;
   portData->portWidth[obDataDataHigh] = 32;
   portData->portWidth[obDataDataLow]  = 32;
   portData->portWidth[obReady]        = 1;
   portData->portWidth[littleEndian]   = 1;
   portData->portWidth[vcWidth]        = 7;

   // Create data structure to hold state
   portData->stateData = obData;

   // State update function
   portData->stateUpdate = *Vc64SimLinkObUpdate;

   // Init data structure
   obData->currClk = 0;

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
      ftruncate(obData->smemFd, sizeof(Vc64SimLinkObMemory));

      // Map the shared memory
      if((obData->smem = (Vc64SimLinkObMemory *)mmap(0, sizeof(Vc64SimLinkObMemory),
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

   if ( obData->smem != NULL ) vhpi_printf("Vc64SimLinkOb: Opened shared memory file: %s\n", obData->smemFile);
   else vhpi_printf("Vc64SimLinkOb: Failed to open shared memory file: %s\n", obData->smemFile);

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void Vc64SimLinkObUpdate ( portDataT *portData ) {

   Vc64SimLinkObData *obData = (Vc64SimLinkObData*)(portData->stateData);

   // Detect clock edge
   if ( obData->currClk != getInt(obClk) ) {
      obData->currClk = getInt(obClk);

      // Rising edge
      if ( obData->currClk ) {

         // Reset is asserted
         if ( getInt(rxReset) == 1 ) {
            obData->littleEndian      = getInt(littleEndian);
            obData->smem->dsBigEndian = (obData->littleEndian)?0:1;
            obData->vcWidth           = getInt(vcWidth);
            obData->obSize            = 0;
            obData->obCount           = 0;
            obData->obActive          = 0;
            setInt(obDataValid,0);
         } 

         // Ready
         else if ( getInt(obReady) ) {

            // Frame just ended
            if ( obData->obLast ) {
               obData->oblast   = 0;
               obData->obActive = 0;
               setInt(obDataValid,0);
            }

            // Not active, check for available data
            if ( (! obData->obActive) && (obData->smem->dsReqCount != obData->smem->dsAckCount) ) {
               vhpi_printf("Vc64SimLinkOb: Frame Start. Size=%i, Vc=%i, Time=%lld\n",
                  obData->smem->dsSize,obData->smem->dsVc,portData->simTime);
               ibData->obActive = 1;
               ibData->ibSize   = 0;
               ibData->ibCount  = 0;

               // Setup frame
               setInt(obDataSof,1);
               setInt(obDataEof,0);
               setInt(obDataEofe,0);
               setInt(obDataSize,1);
               setInt(obDataVc,obData->smem->dsVc);
            }

            // Active
            if ( obData->obActive ) {

               // Clear SOF
               if ( obData->obCount > 0 ) setInt(obDataSof,0);

               // Put out data
               switch ( ibData->vcWidth ) {
                  case 64:
                     if ( obData->littleEndian ) {
                        setInt(obDataDataLow,obData->smem->dsData[obData->obSize++]);
                        setInt(obDataDataHigh,obData->smem->dsData[obData->obSize]);
                     } else {
                        setInt(obDataDataHigh,obData->smem->dsData[obData->obSize++]);
                        setInt(obDataDataLow,obData->smem->dsData[obData->obSize]);
                     }
                     if ( obData->obSize == obData->smem->dsSize ) setInt(obDataSize,0);
                     else obData->obSize++;
                     break;

                  case 32:
                     setInt(obDataDataLow,obData->smem->dsData[obData->obSize++]);
                     obData->obCount++;
                     break;

                  case 16:
                     if ( obData->littleEndian ) 
                        setInt(obDataDataLow,(obData->smem->dsData[obData->obSize] >> ((obData->obCount % 2)*16)) & 0xFFFF);
                     else
                        setInt(obDataDataLow,(obData->smem->dsData[obData->obSize] >> ((1-(obData->obCount % 2))*16)) & 0xFFFF);
                     if ( obCount % 2 == 1 ) obData->obSize++;
                     obData->obCount++;
                     break;

                  case 8:
                     if ( obData->littleEndian ) 
                        setInt(obDataDataLow,(obData->smem->dsData[obData->obSize] >> ((obData->obCount % 4)*8)) & 0xFF);
                     else
                        setInt(obDataDataLow,(obData->smem->dsData[obData->obSize] >> ((3-(obData->obCount % 4))*8)) & 0xFF);
                     if ( obCount % 4 == 3 ) obData->obSize++;
                     obData->obCount++;
                     break;
               }

               // Done
               if ( obData->obSize == obData->smem->dsSize ) {
                  setInt(obDataEof,1);
                  obData->obLast = 1;

                  vhpi_printf("Vc64SimLinkOb: Frame Done. Size=%i, Vc=%i, Time=%lld\n",
                     obData->smem->dsSize,obData->smem->dsVc,portData->simTime);
                  obData->smem->dsAckCount = obData->smem->dsReqCount;
               }
            }
         }
      }
   }
}

