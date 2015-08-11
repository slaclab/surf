//-----------------------------------------------------------------------------
// File          : Adc16Dx370.h
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device driver for Adc16Dx370
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#ifndef __ADC_H__
#define __ADC_H__

#include <Device.h>
#include <stdint.h>
using namespace std;

//! Class to contain Adc16Dx370
class Adc16Dx370 : public Device {

   public:
      //! Device configuration address range constants
      #define ADC_START_ADDR 0x0       
      #define ADC_END_ADDR   0x71
      
      //! Constructor
      /*! 
       * \param linkConfig Device linkConfig
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      Adc16Dx370 ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize=1 );

      //! Deconstructor
      ~Adc16Dx370 ( );

      //! Method to process a command
      /*!
       * \param name     Command name
       * \param arg      Optional arg
      */
      //void command ( string name, string arg );

      //! Method to read status registers and update variables
      //void readStatus ( );

      //! Method to read configuration registers and update variables
      /*!
       * Throws string error.
       */
      //void readConfig ( );

      //! Method to write configuration registers
      /*! 
       * Throws string on error.
       * \param force Write all registers if true, only stale if false
      */
      //void writeConfig ( bool force );

    
};

#endif
