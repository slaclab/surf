
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <string>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>

#include "../include/SsiPcieMod.h"
#include "../include/SsiPcieWrap.h"
#define DEVNAME "/dev/SsiPcie0"

using namespace std;

int main (int argc, char **argv) {
   int           s;
   int           x;
   int           ret;
   uint          maxSize;
   uint          *data;
   uint          lane;
   uint          vc;
   uint          error;

   if ( (s = open(DEVNAME, O_RDWR)) <= 0 ) {
      cout << "Error opening file" << endl;
      return(1);
   }   

   // Allocate a buffer
   maxSize = 1024*1024*2;
   data = (uint *)malloc(sizeof(uint)*maxSize);

   // DMA Read
   do {
      ret = ssipcie_recv(s,data,maxSize,&lane,&vc,&error);

      if ( ret != 0 ) {

         cout << "Ret=" << dec << ret;
         cout << ", Lane=" << dec << lane;
         cout << ", Vc=" << dec << vc;
         cout << ", Error=" << dec << error;
         cout << endl << "   ";

         for (x=0; x<ret; x++) {
            cout << " 0x" << setw(8) << setfill('0') << hex << data[x];
            if ( ((x+1)%10) == 0 ) cout << endl << "   ";
         }
         cout << endl;
      }
   } while ( ret > 0 );
   
   free(data);

   close(s);
}
