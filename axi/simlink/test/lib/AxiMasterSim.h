//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef __AXI_MASTER_SIM_H__
#define __AXI_MASTER_SIM_H__

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string>
#include <sys/mman.h>
#include <iostream>
#include <AxiSharedMem.h>

class AxiMasterSim  {

      AxiSharedMem * _smem;
      pthread_t      _thread;

      // Static Thread routines
      static void * staticRun(void *t);

      // Read tracking
      uint _readReq;
      uint _readAck;
      uint _readAddr;
      uint _readData;

      // Write tracking
      uint _writeReq;
      uint _writeAck;
      uint _writeAddr;
      uint _writeData;

      // Verbose
      bool _verbose;

      // Static Thread routines
      void run();

      // Run Enable
      bool _runEnable;

   public:

      AxiMasterSim ();
      ~AxiMasterSim ();

      // set verbose
      void setVerbose(bool v);

      // Open the port
      bool open (const char *system, uint id, int uid);

      // Close the port
      void close ();

      // Write a value
      void write(uint address, uint value);

      // Read a value
      uint read(uint address);

};

#endif
