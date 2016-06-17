//----------------------------------------------------------------------------------------
// Title         : Simulation Frame Transmit
// Project       : Generic
//----------------------------------------------------------------------------------------
// File          : SimLinkTx.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 09/07/2012
//----------------------------------------------------------------------------------------
// Description:
// Class to transmit frame in simulation.
//----------------------------------------------------------------------------------------
// Copyright (c) 2012 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 09/07/2012: created.
//----------------------------------------------------------------------------------------
#include "SimLinkTx.h"
using namespace std;

// Thread to transmit data
void SimLinkTx::vcThread(void) {
   uint txActive;
   uint txCount;
   uint txVc;
   uint toCount;
   uint txData;

   // Init
   txActive = 0;
   txCount  = 0;
   txVc     = 0;
   toCount  = 0;

   // Run forever
   while (smem_ != NULL) {

      // Clock Edge
      wait();

      // Get ethernet mode flag
      smem_->usEthMode = (ethMode.read() == 0)?0:1;

      // Reset is asserted
      if ( txReset.read() == 1 ) {
         vc0FrameTxReady.write(SC_LOGIC_0);
         vc1FrameTxReady.write(SC_LOGIC_0);
         vc2FrameTxReady.write(SC_LOGIC_0);
         vc3FrameTxReady.write(SC_LOGIC_0);
         txCount = 0;
      }
      else {


         // Receive is idle. check for new frame
         if ( txActive == 0 ) {
            txCount = 0;
           
            // VC0 is ready
            if ( vc0FrameTxValid.read() == 1 ) {
               cout << "SimLinkTx::vcThread -> Frame Start. Vc=0" << ", Time=" << sc_time_stamp() << endl;
               if ( vc0FrameTxSOF.read() == 0 ) cout << "SimLinkTx::vcThread -> SOF error in VC 0" << endl;
               vc0FrameTxReady.write(SC_LOGIC_1);
               txActive = 1;
               txVc     = 0;
            }

            // VC1 is ready
            else if ( vc1FrameTxValid.read() == 1 ) {
               cout << "SimLinkTx::vcThread -> Frame Start. Vc=1" << ", Time=" << sc_time_stamp() << endl;
               if ( vc1FrameTxSOF.read() == 0 ) cout << "SimLinkTx::vcThread -> SOF error in VC 1" << endl;
               vc1FrameTxReady.write(SC_LOGIC_1);
               txActive = 1;
               txVc     = 1;
            }

            // VC2 is ready
            else if ( vc2FrameTxValid.read() == 1 ) {
               cout << "SimLinkTx::vcThread -> Frame Start. Vc=2" << ", Time=" << sc_time_stamp() << endl;
               if ( vc2FrameTxSOF.read() == 0 ) cout << "SimLinkTx::vcThread -> SOF error in VC 2" << endl;
               vc2FrameTxReady.write(SC_LOGIC_1);
               txActive = 1;
               txVc     = 2;
            }

            // VC3 is ready
            else if ( vc3FrameTxValid.read() == 1 ) {
               cout << "SimLinkTx::vcThread -> Frame Start. Vc=3" << ", Time=" << sc_time_stamp() << endl;
               if ( vc3FrameTxSOF.read() == 0 ) cout << "SimLinkTx::vcThread -> SOF error in VC 3" << endl;
               vc3FrameTxReady.write(SC_LOGIC_1);
               txActive = 1;
               txVc     = 3;
            }
         }

         // Transmit is active
         else {

            // Valid is asserted
            if ( (txVc == 0 && vc0FrameTxValid.read() == 1 ) ||
                 (txVc == 1 && vc1FrameTxValid.read() == 1 ) ||
                 (txVc == 2 && vc2FrameTxValid.read() == 1 ) ||
                 (txVc == 3 && vc3FrameTxValid.read() == 1 ) ) {

               // Store data
               switch (txVc) {
                  case 0: txData = vc0FrameTxData.read().to_uint(); break;
                  case 1: txData = vc1FrameTxData.read().to_uint(); break;
                  case 2: txData = vc2FrameTxData.read().to_uint(); break;
                  case 3: txData = vc3FrameTxData.read().to_uint(); break;
                  default: break;
               }

               // Update data
               if ( (txCount % 2) == 0 ) smem_->usData[txCount/2] = txData;
               else smem_->usData[txCount/2] |= (txData << 16) & 0xFFFF0000;
               if ( (txCount/2) < SIM_LINK_TX_BUFF_SIZE ) txCount++;

               // EOF is asserted
               if ( (txVc == 0 && vc0FrameTxEOF.read() == 1 ) ||
                    (txVc == 1 && vc1FrameTxEOF.read() == 1 ) ||
                    (txVc == 2 && vc2FrameTxEOF.read() == 1 ) ||
                    (txVc == 3 && vc3FrameTxEOF.read() == 1 ) ) {

                  // Store EOFE
                  switch (txVc) {
                     case 0: smem_->usEofe = (vc0FrameTxEOFE.read() == 1)?1:0; break;
                     case 1: smem_->usEofe = (vc1FrameTxEOFE.read() == 1)?1:0; break;
                     case 2: smem_->usEofe = (vc2FrameTxEOFE.read() == 1)?1:0; break;
                     case 3: smem_->usEofe = (vc3FrameTxEOFE.read() == 1)?1:0; break;
                     default: break;
                  }
                  vc0FrameTxReady.write(SC_LOGIC_0);
                  vc1FrameTxReady.write(SC_LOGIC_0);
                  vc2FrameTxReady.write(SC_LOGIC_0);
                  vc3FrameTxReady.write(SC_LOGIC_0);

                  // Force EOF for bad frame size
                  if ( (txCount % 2) != 0 ) smem_->usEofe = 1;

                  // Send data
                  smem_->usVc   = txVc;
                  smem_->usSize = txCount/2;
                  smem_->usReqCount++;

                  cout << "SimLinkTx::vcThread -> Frame Done."
                       << " Size=" << dec << smem_->usSize 
                       << ", Vc=" << smem_->usVc
                       << ", Time=" << sc_time_stamp() << endl;

                  // Wait for other end
                  toCount  = 0;
                  while ( smem_->usReqCount != smem_->usAckCount ) {
                     usleep(100);
                     if ( ++toCount > 10000 ) {
                        cout << "SimLinkTx::vcThread -> Timeout waiting." << endl;
                        break;
                     }
                  }

                  // Init
                  txActive = 0;
                  txCount  = 0;
               }
            }
         }
      }
   }
}

