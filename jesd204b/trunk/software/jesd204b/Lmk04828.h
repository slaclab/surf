//-----------------------------------------------------------------------------
// File          : Lmk04828.h
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device Driver for Lmk04828
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#ifndef __LMK_H__
#define __LMK_H__

#include <Device.h>
#include <stdint.h>
using namespace std;

//! Class to contain Lmk04828
class Lmk04828 : public Device {

   public:
      //! Device configuration address range constants
      #define START_ADDR 0x100     
      #define END_ADDR   0x17D
      
      //! Constructor
      /*! 
       * \param linkConfig Device linkConfig
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      Lmk04828 ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize=1 );

      //! Deconstructor
      ~Lmk04828 ( );

      //! Method to process a command
      /*!
       * \param name     Command name
       * \param arg      Optional arg
      */
       void command ( string name, string arg );

      //! Synchronise internal counters
       void SyncClks ();

      // //! Powerdown the sysref lines.
      // void syarefOn ();

    
};

#endif
