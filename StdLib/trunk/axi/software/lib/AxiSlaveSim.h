#ifndef __AXI_SLAVE_SIM_H__
#define __AXI_SLAVE_SIM_H__

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string>
#include <sys/mman.h>
#include <iostream>
#include <AxiSharedMem.h>

class AxiSlaveSim  {

      AxiSharedMem * _smem;
      pthread_t      _writeThread;
      pthread_t      _readThread;
      uint           _memorySize;
      uint         * _memorySpace;

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

      AxiSlaveSim (unsigned char *memSpace, uint memSize);

      ~AxiSlaveSim ();

      // set verbose
      void setVerbose(bool v);

      // Open the port
      bool open (const char *system, uint id, int uid);

      // Close the port
      void close ();

};

#endif
