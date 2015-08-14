//-----------------------------------------------------------------------------
// File          : AtcaDemoBoardSystem.h
// Author        : Uros Legat <ulegat@slac.stanford.edu>
// Created       : 7/10/2015
// Project       : HPS carrier board and LLRF demo board
//-----------------------------------------------------------------------------
// Description :
// AtcaDemoBoardSystem Top Device
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

class AtcaDemoBoardSystem : public System {

   // Software run thread
   //void swRunThread();

   time_t lastMonitor_;

   MultDest *dest_;
   
   public:

      //! Constructor
      AtcaDemoBoardSystem (CommLink *commLink, string defFile, uint addrSize=1);

      //! Deconstructor
      ~AtcaDemoBoardSystem ( );

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
};
#endif
