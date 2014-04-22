
#include "VhpiGeneric.h"
#include <vhpi_user.h>
#include <stdlib.h>
#include <time.h>
#include "Vc64SimLinkIb.h"
#include "SimLinkMemory.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

// Init function
void Vc64SimLinkIbInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT         *portData  = (portDataT *)         malloc(sizeof(portDataT));
   Vc64SimLinkIbData *ibData    = (Vc64SimLinkIbData *) malloc(sizeof(Vc64SimLinkIbData));

   // Get port count
   portData->portCount = 12;

   // Set port directions
   portData->portDir[ibClk]            = vhpiIn;
   portData->portDir[ibReset]          = vhpiIn;
   portData->portDir[ibDataValid]      = vhpiIn;
   portData->portDir[ibDataSize]       = vhpiIn;
   portData->portDir[ibDataVc]         = vhpiIn;
   portData->portDir[ibDataSof]        = vhpiIn;
   portData->portDir[ibDataEof]        = vhpiIn;
   portData->portDir[ibDataEofe]       = vhpiIn;
   portData->portDir[ibDataDataHigh]   = vhpiIn;
   portData->portDir[ibDataDataLow]    = vhpiIn;
   portData->portDir[littleEndian]     = vhpiIn; 
   portData->portDir[vcWidth]          = vhpiIn;

   // Set port and widths
   portData->portWidth[ibClk]          = 1; 
   portData->portWidth[ibReset]        = 1; 
   portData->portWidth[ibDataValid]    = 1; 
   portData->portWidth[ibDataSize]     = 1; 
   portData->portWidth[ibDataVc]       = 4; 
   portData->portWidth[ibDataSof]      = 1; 
   portData->portWidth[ibDataEof]      = 1; 
   portData->portWidth[ibDataEofe]     = 1; 
   portData->portWidth[ibDataDataHigh] = 32; 
   portData->portWidth[ibDataDataLow]  = 32; 
   portData->portWidth[littleEndian]   = 1; 
   portData->portWidth[vcWidth]        = 7; 

   // Create data structure to hold state
   portData->stateData = ibData;

   // State update function
   portData->stateUpdate = *Vc64SimLinkIbUpdate;

   // Init data structure
   ibData->currClk      = 0;
   ibData->ibActive     = 0;
   ibData->ibCount      = 0;
   ibData->ibSize       = 0;
   ibData->ibVc         = 0;
   ibData->ibError      = 0;
   ibData->littleEnd    = 0;
   ibData->width        = 0;

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

   if ( ibData->smem != NULL ) vhpi_printf("Vc64SimLinkIb: Opened shared memory file: %s\n", ibData->smemFile);
   else vhpi_printf("Vc64SimLinkIb: Failed to open shared memory file: %s\n", ibData->smemFile);

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void Vc64SimLinkIbUpdate ( portDataT *portData ) {

   Vc64SimLinkIbData *ibData = (Vc64SimLinkIbData*)(portData->stateData);

   // Detect clock edge
   if ( ibData->currClk != getInt(ibClk) ) {
      ibData->currClk = getInt(ibClk);

      // Rising edge
      if ( ibData->currClk ) {

         // Reset is asserted, sample modes
         if ( getInt(ibReset) ) {
            ibData->littleEnd         = getInt(littleEndian);
            ibData->smem->usBigEndian = (ibData->littleEnd)?0:1;
            ibData->width             = getInt(vcWidth);
            ibData->ibActive          = 0;
         }

         // Valid is asserted
         else if ( getInt(ibDataValid) == 1 ) {

            // Receive is idle. check for new frame
            if ( ! ibData->ibActive ) {
               ibData->ibSize   = 0;
               ibData->ibCount  = 0;
               ibData->ibError  = 0;
               ibData->ibVc     = getInt(ibDataVc);
               vhpi_printf("Vc64SimLinkIb: Frame Start. Vc=%i, Time=%lld\n",ibData->ibVc,portData->simTime);
               if ( getInt(ibDataSof) == 0 ) {
                  vhpi_printf("Vc64SimLinkIb: SOF error.\n");
                  ibData->ibError = 1;
               }
               ibData->ibActive = 1;
            }

            // VC mismatch
            if ( ibData->ibVc != getInt(ibDataVc) && ibData->ibError == 0 ) {
               vhpi_printf("Vc64SimLinkIb: Vc mismatch error.\n");
               ibData->ibError = 1;
            }

            // Pack data, update count
            switch (ibData->width) {
               case 64 :
                  if ( ibData->littleEnd ) {
                     ibData->smem->usData[ibData->ibSize++] = getInt(ibDataDataLow);
                     ibData->smem->usData[ibData->ibSize++] = getInt(ibDataDataHigh);
                  }
                  else {
                     ibData->smem->usData[ibData->ibSize++] = getInt(ibDataDataLow);
                     ibData->smem->usData[ibData->ibSize++] = getInt(ibDataDataHigh);
                  }
                  break;

               case 32 :
                  ibData->smem->usData[ibData->ibSize++] = getInt(ibDataDataLow);
                  break;

               case 16 :
                  if ( (ibData->ibCount % 2) == 0 ) {
                     if ( ibData->littleEnd ) ibData->smem->usData[ibData->ibSize] = (getInt(ibDataDataLow) & 0xFFFF);
                     else ibData->smem->usData[ibData->ibSize] = ((getInt(ibDataDataLow) << 16) & 0xFFFF0000);
                  } else {
                     if ( ibData->littleEnd ) ibData->smem->usData[ibData->ibSize] |= ((getInt(ibDataDataLow) << 16) & 0xFFFF0000);
                     else ibData->smem->usData[ibData->ibSize] |= (getInt(ibDataDataLow) & 0xFFFF);
                     ibData->ibSize++;
                  }
                  break;

               case 8 :
                  switch ( ibData->ibCount % 4 ) {
                     case 0:
                        if ( ibData->littleEnd ) ibData->smem->usData[ibData->ibSize] = (getInt(ibDataDataLow) & 0xFF);
                        else ibData->smem->usData[ibData->ibSize] = ((getInt(ibDataDataLow) << 24) & 0xFF000000);
                        break;

                     case 1:
                        if ( ibData->littleEnd ) ibData->smem->usData[ibData->ibSize] |= ((getInt(ibDataDataLow) << 8) & 0x0000FF00);
                        else ibData->smem->usData[ibData->ibSize] |= (getInt(ibDataDataLow << 16) & 0xFF0000);
                        break;

                     case 2:
                        if ( ibData->littleEnd ) ibData->smem->usData[ibData->ibSize] |= ((getInt(ibDataDataLow) << 16) & 0x00FF0000);
                        else ibData->smem->usData[ibData->ibSize] |= (getInt(ibDataDataLow << 8) & 0xFF00);
                        break;

                     case 3:
                        if ( ibData->littleEnd ) ibData->smem->usData[ibData->ibSize] |= ((getInt(ibDataDataLow) << 24) & 0xFF000000);
                        else ibData->smem->usData[ibData->ibSize] |= (getInt(ibDataDataLow) & 0xFF);
                        ibData->ibSize++;
                        break;
                  }
                  break;
            }
            ibData->ibCount++;

            // EOF is asserted
            if ( getInt(ibDataEof) ) {

               ibData->smem->usEofe = getInt(ibDataEofe);

               // Force EOFE for bad frame size or error
               if ( (ibData->ibSize * 32) != (ibData->ibCount * ibData->width) ) {
                  vhpi_printf("Vc64SimLinkIb: Unaligned frame size error.\n");
                  ibData->smem->usEofe = 1;
               }
               if ( ibData->ibError ) ibData->smem->usEofe = 1;

               // Send data
               ibData->smem->usVc   = ibData->ibVc;
               ibData->smem->usSize = ibData->ibSize;
               ibData->smem->usReqCount++;

               vhpi_printf("Vc64SimLinkIb: Frame Done. Size=%i, Vc=%i, Time=%lld\n",
                  ibData->smem->usSize,ibData->smem->usVc,portData->simTime);

               // Wait for other end
               int toCount = 0;
               while ( ibData->smem->usReqCount != ibData->smem->usAckCount ) {
                  usleep(100);
                  if ( ++toCount > 10000 ) {
                     vhpi_printf("Vc64SimLinkIb: Timeout waiting\n");
                     break;
                  }
               }

               ibData->ibActive = 0;
            }

            // Show updates for long frames
            else {
               if ( (ibData->ibCount % 100) == 0 ) {

                  vhpi_printf("Vc64SimLinkIb: Frame In Progress. Size=%i, Vc=%i, Payload=%i, Time=%lld\n",
                     ibData->ibSize,ibData->ibVc,ibData->ibCount,portData->simTime);
               }
            }
         }
      }
   }
}

