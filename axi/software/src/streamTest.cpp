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
#include "../lib/AxiStreamSim.h"
using namespace std;
 
int main(int argc, char **argv) {
   uint          x;
   uint          txData[100];
   uint          rxData[100];
   int           ret;
   uint          dest;
   uint          eofe;
   AxiStreamSim  *stream;

   stream = new AxiStreamSim;
   if ( ! stream->open(1) ) {
      printf("Failed to open stream sim\n");
      return 1;
   }

   for ( x=0; x < 32; x++) txData[x] = x;

   stream->setVerbose(1);
   stream->write(txData,32,100);
   ret = stream->read(rxData,100,&dest,&eofe);

   printf("Read %i dest= %i eofe %i\n",ret,dest,eofe);

   for ( x=0; x < 32; x++) if ( txData[x] != rxData[x] ) printf("Data mismatch\n");
}

