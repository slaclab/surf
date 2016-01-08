//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef __AXI_STREAM_DMA_SIM_H__
#define __AXI_STREAM_DMA_SIM_H__

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string>
#include <sys/mman.h>
#include <iostream>
#include "AxiSlaveSim.h"
#include "AxiMasterSim.h"

class AxiStreamDmaSim  {

      AxiMasterSim  * _mastMem;
      uint            _regOffset;
      uint            _fifoOffset;
      unsigned char * _slaveMem;
      uint            _slaveSize;
      uint            _maxSize;

      // Reg offset applied, normally 0x000
      static const uint _rxEnableAddr  = 0x00000000;
      static const uint _txEnableAddr  = 0x00000004;
      static const uint _fifoClearAddr = 0x00000008;
      static const uint _intEnableAddr = 0x0000000C;
      static const uint _intStatusAddr = 0x00000010;
      static const uint _maxRxSizeAddr = 0x00000014;

      // Fifo offset applied, normally 0x400
      static const uint _rxFreeAddr    = 0x00000200;
      static const uint _txPostAddrA   = 0x00000240;
      static const uint _txPostAddrB   = 0x00000244;
      static const uint _txPostAddrC   = 0x00000248;
      static const uint _txPassAddr    = 0x0000024C;
      static const uint _rxPendAddr    = 0x00000000;
      static const uint _txFreeAddr    = 0x00000004;

      static const uint _rxBuffCount   = 4;
      static const uint _txBuffCount   = 4;

   public:

      AxiStreamDmaSim (AxiMasterSim *mast, uint regOffset, uint fifoOffset, 
                       unsigned char *mem, uint memSize, uint maxSize );
      ~AxiStreamDmaSim ();

      // Write a block of data
      int write(unsigned char *data, uint size);

      // Read a block of data, return -1 on error, 0 if no data, size if data
      int read(unsigned char *data, uint maxSize);

};

#endif
