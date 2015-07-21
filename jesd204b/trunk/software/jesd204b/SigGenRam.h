//-----------------------------------------------------------------------------
// File          : SigGenRam.h
// Author        : Larry Ruckman  <ruckman@slac.stanford.edu>
// Created       : 04/18/2014
// Project       : 
//-----------------------------------------------------------------------------
// Description :
// DAQ Device Driver for the AD5780 DAC IC
//
//-----------------------------------------------------------------------------
// Copyright (c) 2014 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 04/18/2014: created
//-----------------------------------------------------------------------------

#ifndef __GEN_RAM_H__
#define __GEN_RAM_H__

#include <Device.h>
#include <stdint.h>
using namespace std;

//! Class to contain SigGenRam
class SigGenRam : public Device {

   public:
      //! RAM size constant      
      #define RAM_SAMPLE_SIZE 2048
   
      //! Constructor
      /*! 
       * \param linkConfig Device linkConfig
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      SigGenRam ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize=1 );

      //! Deconstructor
      ~SigGenRam ( );

};

#endif
