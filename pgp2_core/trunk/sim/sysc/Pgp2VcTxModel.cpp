//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC Interface Model
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcTxModel.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/16/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to model an entitiy which interfaces to a PGP virtual channel transmit interface.
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
// 04/16/2009: created.
//----------------------------------------------------------------------------------------
#include "Pgp2VcTxModel.h"
using namespace std;


// Thread to transmit data
void Pgp2VcTxModel::vcTxThread(void) {
   Pgp2VcFrame   *frame;
   unsigned int  dataLow;
   unsigned int  dataHigh;
   unsigned int  width, count;
   unsigned long temp;

   // Init
   frame = NULL;
   count = 0;

   // Run forever
   while (1) {

      // Clock Edge
      wait();

      // Reset is asserted
      if ( pgpTxRst.read() == 1 ) {
         vcTxValid.write(SC_LOGIC_0);
         vcTxSOF.write(SC_LOGIC_0);
         vcTxEOF.write(SC_LOGIC_0);
         vcTxEOFE.write(SC_LOGIC_0);
         vcTxDataLow.write(0);
         vcTxDataHigh.write(0);
      } 
      else {

         // Get width value
         width = vcWidth.read().to_uint();

         // Get flow control inputs
         remBuffAFull = (vcRemBuffAFull.read() == 0)?0:1;
         remBuffFull  = (vcRemBuffFull.read() == 0)?0:1;

         // Advance if data moved or no data being output
         if ( vcTxReady.read() == 1 || vcTxValid.read() == 0 ) {

            // Get new frame if null
            if ( frame == NULL && frameFifo.num_available() != 0 ) {
               frameFifo.read(temp);
               frame = (Pgp2VcFrame *)temp;
               count = 0;
            }

            // Frame is valid and we are not at a pause point
            if ( frame != NULL && ( pauseMask == 0 || (random() & pauseMask) == 0 ) ) {

               // Output valid and SOF
               vcTxValid.write(SC_LOGIC_1);
               vcTxSOF.write((count==0)?SC_LOGIC_1:SC_LOGIC_0);

               dataLow  = frame->getData(count++);
               dataLow += (frame->getData(count++) << 8);
               if ( width >= 1 ) {
                  dataLow += (frame->getData(count++) << 16);
                  dataLow += (frame->getData(count++) << 24);
               }
               if ( width >= 2 ) {
                  dataHigh  = frame->getData(count++);
                  dataHigh += (frame->getData(count++) << 8);
               }
               if ( width == 3 ) {
                  dataHigh += (frame->getData(count++) << 16);
                  dataHigh += (frame->getData(count++) << 24);
               }
               vcTxDataLow.write(dataLow);
               vcTxDataHigh.write(dataHigh);
 
               // Done?
               if ( count >= frame->getSize() ) {
                  vcTxEOF.write(SC_LOGIC_1);
                  vcTxEOFE.write((frame->getEofE())?SC_LOGIC_1:SC_LOGIC_0);
                  frame->setTx();
                  frame = NULL;
                  count = 0;
               }
               else {
                  vcTxEOF.write(SC_LOGIC_0);
                  vcTxEOFE.write(SC_LOGIC_0);
               }
            }

            // No Data
            else {
               vcTxValid.write(SC_LOGIC_0);
               vcTxSOF.write(SC_LOGIC_0);
               vcTxEOF.write(SC_LOGIC_0);
               vcTxEOFE.write(SC_LOGIC_0);
               vcTxDataLow.write(dataLow);
               vcTxDataHigh.write(dataHigh);
            }
         } 
      }
   }
}


// Method to check number of pending frames
unsigned int Pgp2VcTxModel::free(void) { return(frameFifo.num_free()); }


// Method to transmit frame
void Pgp2VcTxModel::txFrame(Pgp2VcFrame *frame) { frameFifo.write((unsigned long)frame); }


// Method to get state of flow control
bool Pgp2VcTxModel::getRemBuffAFull(void) { return(remBuffAFull); }


// Method to get state of flow control
bool Pgp2VcTxModel::getRemBuffFull(void) { return(remBuffFull); }


// Method to enable random pauses
void Pgp2VcTxModel::setPauseMask(unsigned int mask) { pauseMask = mask; }


