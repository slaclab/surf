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
   uint              txDest;
   uint              rxDest;
   uint              rxEofe;
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

   txDest = 1;
   for (txSize=120; txSize < 260; txSize++) {
      printf("Transmit Size %i\n",txSize);

      for (x=0; x < txSize; x++) txData[x] = x;

      // transmit 4 frames
      for (x=0; x < 4; x++) dma->write(txData,txSize,txDest);

      printf("Done\n");

      printf("Receive Size %i\n",txSize);

      // receive 4 frames
      for (x=0; x < 4; x++) {
         do {
            rxSize = dma->read(rxData,buffSize,&rxDest,&rxEofe);
            usleep(100);
         } while (rxSize == 0);

         if ( rxSize != txSize ) {
            printf("Rx Size mismatch. Got %i, Exp %i\n",rxSize,txSize);
            return 1;
         }

         if ( rxDest != txDest ) {
            printf("Rx Dest mismatch. Got %i, Exp %i\n",rxDest,txDest);
            return 1;
         }

         if ( rxEofe != 0 ) {
            printf("Rx EOFE\n");
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

