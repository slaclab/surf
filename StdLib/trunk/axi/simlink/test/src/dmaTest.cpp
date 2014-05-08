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
   if ( ! master->open("SimAxiMaster",1,-1) ) {
      printf("Failed to open sim master\n");
      return 1;
   }

   slave = new AxiSlaveSim(mem,buffSize*buffCount);
   if ( ! slave->open("SimAxiSlave",2,-1) ) {
      printf("Failed to open sim slave\n");
      return 1;
   }

   usleep(100);
   master->write(fifoClearAddr,0);
   master->write(maxRxSizeAddr,buffSize);
   master->write(intEnableAddr,1);
   master->write(rxEnableAddr,1);
   master->write(txEnableAddr,1);

   for (x=0; x < loopCount; x++) {
      addr = (x * buffSize) + x;
      master->write(txPassAddr,addr);
      printf("Post Tx Addr %x\n",addr);

      addr = (buffSize*(loopCount+1)) + (x * buffSize) + (loopCount-x);
      master->write(rxFreeAddr,addr);
      printf("Post Rx Addr %x\n",addr);
   }

   printf("Posting done. Start transmit\n");

   lUser = 0x5a;
   fUser = 0x73;
   dest  = 0x11;

   for (size=128; size < 256; size++) {
      lUser++; lUser &= 0xFF;
      fUser++; fUser &= 0xFF;
      dest++;  dest  &= 0xFF;

      memset(mem,0,buffSize*buffCount);

      // transmit frames
      for (x=0; x < loopCount; x++) {
         addr = master->read(txFreeAddr) & 0x7FFFFFFF;
         for (y=0; y < size; y++) data[y]  = y;
         memcpy(&(mem[addr]),data,size);

         master->write(txPostAddrA,addr);
         master->write(txPostAddrB,size);
         desc  = lUser << 16;
         desc |= fUser << 8;
         desc |= dest;
         master->write(txPostAddrC,desc);
      }

      printf("Transmit done. Start receive\n");

      // receive 4 frames
      for (x=0; x < loopCount; x++) {

         do {
            desc = master->read(rxPendAddr,1);
         } while ( (desc & 0x80000000) == 0 );

         addr = desc & 0x7FFFFFFF;

         do {
            desc = master->read(rxPendAddr,1);
         } while ( (desc & 0x80000000) == 0 );

         if ( size != (desc & 0x00FFFFFF) ) {
            printf("Rx Size mismatch. Addr=%x, Got %i, Exp %i\n",addr,(desc&0x00FFFFFF),size);
            return 1;
         }

         do {
            desc = master->read(rxPendAddr,1);
         } while ( (desc & 0x80000000) == 0 );

         if ( dest != (desc & 0xFF) ) {
            printf("Rx dest mismatch. Addr=%x, Got %i, Exp %i\n",addr,(desc&0xFF),dest);
            return 1;
         }

         if ( fUser != ((desc >> 8) & 0xFF) ) {
            printf("Rx fUser mismatch. Addr=%x, Got %i, Exp %i\n",addr,((desc>>8)&0xFF),fUser);
            return 1;
         }

         if ( lUser != ((desc >> 16) & 0xFF) ) {
            printf("Rx lUser mismatch. Addr=%x, Got %i, Exp %i\n",addr,((desc>>16)&0xFF),lUser);
            return 1;
         }

         if ( desc & 0x02000000 ) {
            printf("Rx overflow error. Addr=%x\n",addr);
            return 1;
         }

         if ( desc & 0x01000000 ) {
            printf("Rx write error. Addr=%x\n",addr);
            return 1;
         }

         for (y=0; y < size; y++) {
            if ((uint)data[y] != (uint)mem[addr+y]) {
               printf("Rx data mismatch. Addr=%x, Pos %i, Got %i, Exp %i Got+1 %i, Exp+1 %i\n",
                  addr,y,(uint)mem[addr+y],(uint)data[y],(uint)mem[addr+y+1],(uint)data[y+1]);
               printf("Raw 0 %x\n",(uint)mem[addr]);
               printf("Raw 1 %x\n",(uint)mem[addr+1]);
               printf("Raw 2 %x\n",(uint)mem[addr+2]);
               printf("Raw 3 %x\n",((uint *)mem)[addr/4]);
               printf("Raw 4 %x\n",((uint *)mem)[(addr/4)+1]);
               printf("Raw 5 %x\n",((uint *)mem)[(addr/4)-1]);
               return 1;
            }
         }

         master->write(rxFreeAddr,addr);
      }
   }

   cout << "Simulation Pass." << endl;
}

