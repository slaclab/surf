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
      uint            _mastOffset;
      unsigned char * _slaveMem;
      uint            _slaveSize;
      uint            _maxSize;

      static const uint _rxEnableAddr  = 0x00000000;
      static const uint _txEnableAddr  = 0x00000004;
      static const uint _fifoClearAddr = 0x00000008;
      static const uint _intEnableAddr = 0x0000000C;
      static const uint _intStatusAddr = 0x00000010;
      static const uint _maxRxSizeAddr = 0x00000014;

      static const uint _rxFreeAddr    = 0x00000600;
      static const uint _txPostAddrA   = 0x00000640;
      static const uint _txPostAddrB   = 0x00000644;
      static const uint _txPostAddrC   = 0x00000648;
      static const uint _txPassAddr    = 0x0000064C;

      static const uint _rxPendAddr    = 0x00000400;
      static const uint _txFreeAddr    = 0x00000404;

      static const uint _rxBuffCount   = 4;
      static const uint _txBuffCount   = 4;

   public:

      AxiStreamDmaSim (AxiMasterSim *mast, uint offset, unsigned char *mem, uint memSize, uint maxSize );
      ~AxiStreamDmaSim ();

      // Write a block of data
      void write(unsigned char *data, uint size, uint dest);

      // Read a block of data, return -1 on error, 0 if no data, size if data
      int read(unsigned char *data, uint maxSize, uint *dest, uint *eofe);

};

#endif
