//-----------------------------------------------------------------------------
// File          : DevBoardSystem.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 11/20/2011
// Project       : KPIX Asic
//-----------------------------------------------------------------------------
// Description :
// DevBoardSystem Top Device
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 11/20/2011: created
//-----------------------------------------------------------------------------
#ifndef __FRONT_END_TEST_CONTROL_H__
#define __FRONT_END_TEST_CONTROL_H__

#include <System.h>
#include <MultDest.h>
using namespace std;

class CommLink;

class DevBoardSystem : public System {

   // Software run thread
   void swRunThread();

   time_t lastMonitor_;

   MultDest *dest_;
   
   public:

      //! Constructor
      DevBoardSystem (CommLink *commLink, string defFile, uint addrSize=1);

      //! Deconstructor
      ~DevBoardSystem ( );

      //! Method to process a command
      /*!
       * Returns status string if locally processed. Otherwise
       * an empty string is returned.
       * Throws string on error
       * \param name     Command name
       * \param arg      Optional arg
      */
      void command ( string name, string arg );

      //! Return local state, specific to each implementation
      string localState();

      void periodState();

      //! Method to perform soft reset
      void softReset ( );

      //! Method to perform hard reset
      void hardReset ( );
      
      //! Method to set run state
      void setRunState ( string state );      

};
#endif
