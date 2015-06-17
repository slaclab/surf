//-----------------------------------------------------------------------------
// File          : DacBoard.h
// Author        : Ben Reese <bareese@slac.stanford.edu>
// Created       : 2/1/2014
// Project       : HPS
//-----------------------------------------------------------------------------
// Description :
// Device container for jesd TX cores
//-----------------------------------------------------------------------------
// Copyright (c) 2014 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 02/01/2014: created
//-----------------------------------------------------------------------------
#ifndef __DAC_BOARD_H__
#define __DAC_BOARD_H__

#include <Device.h>

using namespace std;

//! Class to contain APV25 
class DacBoard : public Device {
      bool lastEnable;

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param index       Device index
       * \param parent      Parent device
      */
      DacBoard ( uint destination, uint baseAddress, uint index, Device *parent, uint addrSize=1 );

      //! Deconstructor
      ~DacBoard ( );

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
