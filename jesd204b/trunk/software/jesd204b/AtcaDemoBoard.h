//-----------------------------------------------------------------------------
// File          : AtcaDemoBoard.h
// Author        : Uros Legat <ulegat@slac.stanford.edu>
// Created       : 7/10/2015
// Project       : HPS carrier board and LLRF demo board
//-----------------------------------------------------------------------------
// Description :
// Control FPGA container
//-----------------------------------------------------------------------------
// Copyright (c) 2014 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 02/01/2014: created
//-----------------------------------------------------------------------------
#ifndef __DEV_BOARD_H__
#define __DEV_BOARD_H__

#include <Device.h>

using namespace std;

//! Class to contain APV25 
class AtcaDemoBoard : public Device {
      bool powerUp;

   public:
     
      //! Constructor
      /*! 
       * \param destination Device destination
       * \param index       Device index
       * \param parent      Parent device
      */
      AtcaDemoBoard ( uint destination, uint baseAddress, uint index, Device *parent, uint addrSize=1 );

      //! Deconstructor
      ~AtcaDemoBoard ( );

       void writeConfig ( bool force );
       
       //! Perform soft or hard reset on powerup and load the defaults
       void softReset();
       void hardReset();
       
     //! Method to process a command
      /*!
       * \param name     Command name
       * \param arg      Optional arg
      */
       void command ( string name, string arg );

      //! Powerup the sysref lines.
       void syarefOff ();

     //! Powerdown the sysref lines.
       void syarefOn ();
};
#endif
