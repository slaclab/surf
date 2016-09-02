//----------------------------------------------------------------------------------------
// Title         : PNCCD PIC Interface Frame Test
// Project       : PNCCD
//----------------------------------------------------------------------------------------
// File          : RceLoop.cpp
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 08/27/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to send and receive test frames.
//----------------------------------------------------------------------------------------
// This file is part of 'SLAC PGP2 Core'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC PGP2 Core', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//----------------------------------------------------------------------------------------
// Modification history:
// 08/27/2009: created.
//----------------------------------------------------------------------------------------
#include "RceLoop.h"
#include "PicFrame.h"
#include <iomanip>
#include <iostream>
using namespace std;


// Run Thread
void RceLoop::runThread(void) {

   PicFrame     *tempFrame;

   while (1) {

      // Check for received frames
      if ( (tempFrame = picModel.rxFrame()) != NULL ) {
         cout << "Frame Received.";
         cout << " Vc="     << dec << setw(4)  << setfill(' ') << (tempFrame->data[0] & 0x3);
         cout << " Lane="   << dec << setw(4)  << setfill(' ') << ((tempFrame->data[0] >> 6) & 0x3);
         cout << " Size="   << dec << setw(5)  << setfill(' ') << tempFrame->size;
         cout << " Status=" << hex << setw(8)  << setfill(' ') << tempFrame->status;
         cout << " Time="   << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;

         // Echo frame back
         while ( ! picModel.txReady() ) wait(1,SC_US);
         picModel.txFrame(tempFrame);
      }

      // Check for status frames, delete frame
      if ( (tempFrame = picModel.readStatus()) != NULL ) {
         delete tempFrame; 
      }
      wait(1,SC_US);
   }
}

