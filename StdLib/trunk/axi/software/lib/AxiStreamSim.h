//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef __AXI_STREAM_SIM_H__
#define __AXI_STREAM_SIM_H__

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string>
#include <sys/mman.h>
#include <iostream>
#include <AxiStreamSharedMem.h>

class AxiStreamSim  {

      AxiStreamSharedMem * _smem;

      // Verbose
      bool _verbose;

   public:

      AxiStreamSim ();
      ~AxiStreamSim ();

      // set verbose
      void setVerbose(bool v);

      // Open the port
      bool open (uint id);

      // Close the port
      void close ();

      // Write a block of data
      void write(uint *data, uint size, uint dest);

      // Read a block of data, return -1 on error, 0 if no data, size if data
      int read(uint *data, uint maxSize, uint *dest, uint *eofe);
      int read(uint *data, uint maxSize);

};

#endif
