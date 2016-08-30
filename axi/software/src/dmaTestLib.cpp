//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/mman.h>
#include <iostream>
#include <iomanip>
#include "../lib/AxiSlaveSim.h"
#include "../lib/AxiMasterSim.h"
#include "../lib/AxiStreamDmaSim.h"
using namespace std;
 
int main(int argc, char **argv) {
   uint              buffCount = 8;
   uint              buffSize  = 1024;
   unsigned char     rxData[buffSize];
   unsigned char     txData[buffSize];
   unsigned char *   mem;
   uint              x;
   uint              y;
   uint              txSize;
   uint              rxSize;
   AxiSlaveSim     * slave;
   AxiMasterSim    * master;
   AxiStreamDmaSim * dma;

   mem = (unsigned char *)malloc(buffSize*buffCount);

   if ( mem == NULL ) {
      return 1;
      printf("Malloc Failed\n");
   }

   master = new AxiMasterSim;
   if ( ! master->open(1) ) {
      printf("Failed to open sim master\n");
      return 1;
   }

   slave = new AxiSlaveSim(mem,buffSize*buffCount);
   if ( ! slave->open(2) ) {
      printf("Failed to open sim slave\n");
      return 1;
   }

   dma = new AxiStreamDmaSim(master,0,0x400,mem,buffSize*buffCount,buffSize);

   for (txSize=120; txSize < 260; txSize++) {
      printf("Transmit Size %i\n",txSize);

      for (x=0; x < txSize; x++) txData[x] = x;
      txData[0] = 0;
      txData[1] = 0;
      txData[2] = 0;
      txData[3] = 0;

      // transmit 4 frames
      for (x=0; x < 4; x++) dma->write(txData,txSize);

      printf("Done\n");

      printf("Receive Size %i\n",txSize);

      // receive 4 frames
      for (x=0; x < 4; x++) {
         do {
            rxSize = dma->read(rxData,buffSize);
            usleep(100);
         } while (rxSize == 0);

         if ( rxSize != txSize ) {
            printf("Rx Size mismatch. Got %i, Exp %i\n",rxSize,txSize);
            return 1;
         }

         for (y=0; y < rxSize; y++) {
            if (rxData[y] != txData[y]) {
               printf("Rx data mismatch. Size=%i, Pos %i, Got %i, Exp %i\n", txSize,y,(uint)rxData[y],(uint)txData[y]);
               return 1;
            }
         }
      }
      printf("Done\n");
   }

   cout << "Simulation Pass." << endl;
}

