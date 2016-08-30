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
using namespace std;
 
int main(int argc, char **argv) {
   uint          x;
   uint          y;
   unsigned char *mem;
   uint          loopCount = 8;
   uint          buffCount = (loopCount+1)*2;
   uint          buffSize  = 1024;
   uint          addr;
   uint          desc;
   unsigned char data[buffSize];
   uint          size;
   uint          lUser;
   uint          fUser;
   uint          dest;
   AxiSlaveSim   *slave;
   AxiMasterSim  *master;

   uint rxEnableAddr  = 0x00000000;
   uint txEnableAddr  = 0x00000004;
   uint fifoClearAddr = 0x00000008;
   uint intEnableAddr = 0x0000000C;
   //uint intStatusAddr = 0x00000010;
   uint maxRxSizeAddr = 0x00000014;

   uint rxFreeAddr    = 0x00000600;
   uint txPostAddrA   = 0x00000640;
   uint txPostAddrB   = 0x00000644;
   uint txPostAddrC   = 0x00000648;
   uint txPassAddr    = 0x0000064C;

   uint rxPendAddr    = 0x00000400;
   uint txFreeAddr    = 0x00000404;

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

   master->setVerbose(0);
   slave->setVerbose(0);

   usleep(100);
   master->write(fifoClearAddr,0);
   master->write(maxRxSizeAddr,buffSize);
   master->write(intEnableAddr,1);
   master->write(rxEnableAddr,1);
   master->write(txEnableAddr,1);

   for (x=0; x < loopCount; x++) {
      addr = (x * buffSize) + x;
      master->write(txPassAddr,addr);
      printf("Create Tx Addr %x\n",addr);

      addr = (buffSize*(loopCount+1)) + (x * buffSize) + (loopCount-x);
      master->write(rxFreeAddr,addr);
      printf("Create Rx Addr %x\n",addr);
   }

   master->setVerbose(0);
   slave->setVerbose(0);

   printf("Posting done. Start transmit\n");

   lUser = 0x5a;
   fUser = 0x73;
   dest  = 0x11;

   for (size=120; size < 260; size++) {
      lUser++; lUser &= 0xFF;
      fUser++; fUser &= 0xFF;
      dest++;  dest  &= 0xFF;

      memset(mem,0,buffSize*buffCount);

      printf("Transmit Size %i\n",size);

      // transmit frames
      for (x=0; x < loopCount; x++) {
         addr = master->read(txFreeAddr) & 0x7FFFFFFF;
         for (y=0; y < size; y++) data[y] = y;
         memcpy(&(mem[addr]),data,size);

         master->write(txPostAddrA,addr);
         master->write(txPostAddrB,size);
         desc  = lUser << 16;
         desc |= fUser << 8;
         desc |= dest;
         master->write(txPostAddrC,desc);
      }
      printf("Done\n");

      printf("Receive Size %i\n",size);

      // receive 4 frames
      for (x=0; x < loopCount; x++) {

         do {
            desc = master->read(rxPendAddr);
         } while ( (desc & 0x80000000) == 0 );

         addr = desc & 0x7FFFFFFF;

         do {
            desc = master->read(rxPendAddr);
         } while ( (desc & 0x80000000) == 0 );

         if ( size != (desc & 0x00FFFFFF) ) {
            printf("Rx Size mismatch. Size=%i, Loop=%i, Addr=%x, Got %i, Exp %i\n",size,x,addr,(desc&0x00FFFFFF),size);
            return 1;
         }

         do {
            desc = master->read(rxPendAddr);
         } while ( (desc & 0x80000000) == 0 );

         if ( dest != (desc & 0xFF) ) {
            printf("Rx dest mismatch. Size=%i, Loop=%i, Addr=%x, Got %i, Exp %i\n",size,x,addr,(desc&0xFF),dest);
            return 1;
         }

         if ( fUser != ((desc >> 8) & 0xFF) ) {
            printf("Rx fUser mismatch. Size=%i, Loop=%i, Addr=%x, Got %i, Exp %i\n",size,x,addr,((desc>>8)&0xFF),fUser);
            return 1;
         }

         if ( lUser != ((desc >> 16) & 0xFF) ) {
            printf("Rx lUser mismatch. Size=%i, Loop=%i, Addr=%x, Got %i, Exp %i\n",size,x,addr,((desc>>16)&0xFF),lUser);
            return 1;
         }

         if ( desc & 0x02000000 ) {
            printf("Rx overflow error. Size=%i, Loop=%i, Addr=%x\n",size,x,addr);
            return 1;
         }

         if ( desc & 0x01000000 ) {
            printf("Rx write error. Size=%i, Loop=%i, Addr=%x\n",size,x,addr);
            return 1;
         }

         for (y=0; y < size; y++) {
            if ((uint)data[y] != (uint)mem[addr+y]) {
               printf("Rx data mismatch. Size=%i, Loop=%i, Addr=%x, Pos %i, Got %i, Exp %i Got+1 %i, Exp+1 %i\n",
                  size,x,addr,y,(uint)mem[addr+y],(uint)data[y],(uint)mem[addr+y+1],(uint)data[y+1]);
               return 1;
            }
         }

         master->write(rxFreeAddr,addr);
      }
      printf("Done\n");
   }

   cout << "Simulation Pass." << endl;
}

