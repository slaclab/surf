//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC SSI PCI-E Core'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC SSI PCI-E Core', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include <sys/types.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <string>
#include <iomanip>
#include <iostream>

#include "../include/SsiPcieMod.h"
#include "../include/SsiPcieWrap.h"
#define DEVNAME "/dev/SsiPcie0"

using namespace std;

int main (int argc, char **argv) {
   int       fd;

   if ( (fd = open(DEVNAME, O_RDWR)) <= 0 ) {
      cout << "Error opening file" << endl;
      return(1);
   }
   
   cout << "Resetting status counters" << endl;
   ssipcie_rstCount(fd);

   close(fd);
}
