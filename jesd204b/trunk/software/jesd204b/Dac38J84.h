//-----------------------------------------------------------------------------
// File          : Dac38J84.h
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device Driver for Dac38J84
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#ifndef __DAC_H__
#define __DAC_H__

#include <Device.h>
#include <stdint.h>
using namespace std;

//! Class to contain Dac38J84
class Dac38J84 : public Device {

   public:
      //! Device configuration address range constants
      #define DAC_START_ADDR 0x0      
      #define DAC_END_ADDR   0x7F
      
      //! Constructor
      /*! 
       * \param linkConfig Device linkConfig
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      Dac38J84 ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize=1 );

      //! Deconstructor
      ~Dac38J84 ( );

      //! Method to process a command
      /*!
       * \param name     Command name
       * \param arg      Optional arg
      */
      void command ( string name, string arg );

      //! Clear alarms
      void clrAlarms ();

      //! Initialisation process
      void initDac ();

};

#endif
