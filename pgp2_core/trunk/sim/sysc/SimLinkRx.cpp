//----------------------------------------------------------------------------------------
// Title         : Simulation Frame Receive
// Project       : Generic
//----------------------------------------------------------------------------------------
// File          : SimLinkRx.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 09/07/2012
//----------------------------------------------------------------------------------------
// Description:
// Class to receive frame in simulation.
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
// 09/07/2012: created.
//----------------------------------------------------------------------------------------
#include "SimLinkRx.h"
using namespace std;

// Thread to transmit data
void SimLinkRx::vcThread(void) {
   uint rxCount;
   uint ethModeInt;

   // Init
   rxCount = 0;

   // Never error
   vcFrameRxEOFE.write(SC_LOGIC_0);

   // Run forever
   while (smem_ != NULL) {

      // Clock Edge
      wait();

      // Get ethernet mode flag
      smem_->dsEthMode = (ethMode.read() == 0)?0:1;

      // Reset is asserted
      if ( rxReset.read() == 1 ) {
         vcFrameRxSOF.write(SC_LOGIC_0);
         vcFrameRxEOF.write(SC_LOGIC_0);
         vcFrameRxData.write(0);
         vc0FrameRxValid.write(SC_LOGIC_0);
         vc1FrameRxValid.write(SC_LOGIC_0);
         vc2FrameRxValid.write(SC_LOGIC_0);
         vc3FrameRxValid.write(SC_LOGIC_0);
      } 
      else {

         // Get ethernet mode flag
         ethModeInt = (ethMode.read() == 0)?0:1;

         // Receive is idle. check for new frame
         if ( rxCount == 0 ) {
            
            // Data is ready in FIFO, start frame
            if ( smem_->dsReqCount != smem_->dsAckCount ) {
               cout << "SimLinkRx::vcThread -> Frame Start."
                    << " Size=" << dec << smem_->dsSize 
                    << ", Vc=" << smem_->dsVc
                    << ", Time=" << sc_time_stamp() << endl;
               vcFrameRxSOF.write(SC_LOGIC_1);
               vcFrameRxEOF.write(SC_LOGIC_0);
               vcFrameRxData.write(smem_->dsData[0] & 0xFFFF);
               vc0FrameRxValid.write((smem_->dsVc==0)?SC_LOGIC_1:SC_LOGIC_0);
               vc1FrameRxValid.write((smem_->dsVc==1)?SC_LOGIC_1:SC_LOGIC_0);
               vc2FrameRxValid.write((smem_->dsVc==2)?SC_LOGIC_1:SC_LOGIC_0);
               vc3FrameRxValid.write((smem_->dsVc==3)?SC_LOGIC_1:SC_LOGIC_0);
               rxCount = 1;
            } else {
               vcFrameRxSOF.write(SC_LOGIC_0);
               vcFrameRxEOF.write(SC_LOGIC_0);
               vcFrameRxData.write(0);
               vc0FrameRxValid.write(SC_LOGIC_0);
               vc1FrameRxValid.write(SC_LOGIC_0);
               vc2FrameRxValid.write(SC_LOGIC_0);
               vc3FrameRxValid.write(SC_LOGIC_0);
            }
         }

         // In Frame
         else {

            // Output current data
            if ( (rxCount % 2) == 0 ) vcFrameRxData.write(smem_->dsData[rxCount/2] & 0xFFFF);
            else vcFrameRxData.write((smem_->dsData[rxCount/2] >> 16) & 0xFFFF);
            vcFrameRxSOF.write(SC_LOGIC_0);
            
            // Backpressure
            if ( ( smem_->dsVc == 0 && vc0LocBuffAFull.read() == 1 ) ||
                 ( smem_->dsVc == 1 && vc1LocBuffAFull.read() == 1 ) ||
                 ( smem_->dsVc == 2 && vc2LocBuffAFull.read() == 1 ) ||
                 ( smem_->dsVc == 3 && vc3LocBuffAFull.read() == 1 ) ) {

               // Stop valid assertion
               vc0FrameRxValid.write(SC_LOGIC_0);
               vc1FrameRxValid.write(SC_LOGIC_0);
               vc2FrameRxValid.write(SC_LOGIC_0);
               vc3FrameRxValid.write(SC_LOGIC_0);
            }

            // Non backpressure
            else {

               // Output valid
               vc0FrameRxValid.write((smem_->dsVc==0)?SC_LOGIC_1:SC_LOGIC_0);
               vc1FrameRxValid.write((smem_->dsVc==1)?SC_LOGIC_1:SC_LOGIC_0);
               vc2FrameRxValid.write((smem_->dsVc==2)?SC_LOGIC_1:SC_LOGIC_0);
               vc3FrameRxValid.write((smem_->dsVc==3)?SC_LOGIC_1:SC_LOGIC_0);

               // End of frame?
               if ( ++rxCount >= (smem_->dsSize*2) ) {
                  cout << "SimLinkRx::vcThread -> Frame Done."
                       << " Size=" << dec << smem_->dsSize 
                       << ", Vc=" << smem_->dsVc
                       << ", Time=" << sc_time_stamp() << endl;
                  smem_->dsAckCount = smem_->dsReqCount;
                  vcFrameRxEOF.write(SC_LOGIC_1);
                  rxCount = 0;
               } else {
                  vcFrameRxEOF.write(SC_LOGIC_0);
               }
            }
         }
      }
   }
}

