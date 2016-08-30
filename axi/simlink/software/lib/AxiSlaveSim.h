//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef __AXI_SLAVE_SIM_H__
#define __AXI_SLAVE_SIM_H__

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string>
#include <sys/mman.h>
#include <iostream>
#include <AxiSharedMem.h>

#define SLAVE_TYPE "slave"

class AxiSlaveSim  {

      AxiSharedMem * _smem;
      pthread_t      _writeThread;
      pthread_t      _readThread;
      uint           _memorySize;
      uint         * _memorySpace;
      uint           _addrMask;

      // Static Thread routines
      static void * staticWriteRun(void *t);
      static void * staticReadRun(void *t);

      // Static Thread routines
      void writeRun();
      void readRun();

      // Run Enable
      bool _runEnable;

      // Verbose
      bool _verbose;

   public:

      AxiSlaveSim (unsigned char *memSpace, uint memSize, uint addrMask=0xFFFFFFFF);

      ~AxiSlaveSim ();

      // set verbose
      void setVerbose(bool v);

      // Open the port
      bool open (uint id);

      // Close the port
      void close ();

};

#endif
