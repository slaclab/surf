//-----------------------------------------------------------------------------
// File          : DevBoard.h
// Author        : Ben Reese <bareese@slac.stanford.edu>
// Created       : 2/1/2014
// Project       : HPS
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
class DevBoard : public Device {
      bool lastEnable;

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param index       Device index
       * \param parent      Parent device
      */
      DevBoard ( uint destination, uint baseAddress, uint index, Device *parent, uint addrSize=1 );

      //! Deconstructor
      ~DevBoard ( );

      //! Method to process a command 
      /*!
       * \param name     Command name
       * \param arg      Optional arg
      */
/*       void command ( string name, string arg ); */

/*       //! Method to read status registers and update variables */
/*       /\*!  */
/*        * Throws string on error. */
/*       *\/ */
/*       void readStatus ( ); */

/*       //! Method to read configuration registers and update variables */
/*       /\*!  */
/*        * Throws string on error. */
/*       *\/ */
/*       void readConfig ( ); */

       void writeConfig ( bool force );

/*       //! Verify hardware state of configuration */
/*       void verifyConfig ( ); */


};
#endif
