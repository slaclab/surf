
#include <sys/types.h>
#include <linux/types.h>
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
   uint          x;
   int           ret;
   time_t        t;
   uint          lane;
   uint          vc;
   uint          size;
   uint          *data;

   if (argc != 4) {
      cout << "Usage: xwrite lane vc size" << endl;
      return(1);
   }

   // Get args
   lane  = atoi(argv[1]);
   vc    = atoi(argv[2]);
   size  = atoi(argv[3]);

   // Check ranges
   if ( size == 0 || lane > 15 || vc > 15 ) {
      cout << "Invalid size, lane or vc value" << endl;
      return(1);
   }

   if ( (s = open(DEVNAME, O_RDWR)) <= 0 ) {
      cout << "Error opening file" << endl;
      return(1);
   }

   time(&t);
   srandom(t); 

   data = (uint *)malloc(sizeof(uint)*size);

   // DMA Write
   cout << endl;
   cout << "Sending:";
   cout << " Lane=" << dec << lane;
   cout << ", Vc=" << dec << vc << endl;  
      
   for (x=0; x<size; x++) {
      data[x] = random();
      cout << " 0x" << setw(8) << setfill('0') << hex << data[x];
      if ( ((x+1)%10) == 0 ) cout << endl << "   ";
   }
   cout << endl;
   ret = ssipcie_send (s,data,size,lane,vc);
   cout << "Ret=" << dec << ret << endl << endl;
  
   free(data);
   
   /*
   sleep(1);
  
   // Allocate a buffer
   uint          maxSize;
   uint          error; 
   maxSize = 1024*1024*2;
   data = (uint *)malloc(sizeof(uint)*maxSize);

   ret = ssipcie_recv(s,data,maxSize,&lane,&vc,&error);

   if ( ret != 0 ) {
      cout << "Receiving:";
      cout << " Lane=" << dec << lane;
      cout << ", Vc=" << dec << vc;
      cout << ", Error=" << dec << error;

      for (x=0; x<(uint)ret; x++) {
         cout << " 0x" << setw(8) << setfill('0') << hex << data[x];
         if ( ((x+1)%10) == 0 ) cout << endl << "   ";
      }
      cout << endl;
      cout << "Ret=" << dec << ret << endl;
      cout << endl;
   }
  
   free(data);   
   */
   
   close(s);
   return(0);
}
