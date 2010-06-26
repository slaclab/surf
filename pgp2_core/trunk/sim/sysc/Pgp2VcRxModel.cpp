//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC Interface Model
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcRxModel.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/16/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to model an entitiy which interfaces to a PGP virtual channel receive interface.
//----------------------------------------------------------------------------------------
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 04/16/2009: created.
//----------------------------------------------------------------------------------------
#include "Pgp2VcRxModel.h"
using namespace std;


// Thread to recive data
void Pgp2VcRxModel::vcRxThread(void) {
   Pgp2VcFrame  *frame;
   unsigned int dataLow;
   unsigned int dataHigh;
   unsigned int width;

   // Init
   frame = NULL;

   // Run forever
   while (1) {

      // Clock Edge
      wait();

      // Reset is asserted
      if ( pgpRxRst.read() == 1 ) {
         vcLocBuffAFull.write(SC_LOGIC_1);
         vcLocBuffFull.write(SC_LOGIC_1);
      } 
      else {

         // Get width value
         width = vcWidth.read().to_uint();

         // Set flow control outputs
         vcLocBuffAFull.write(locBuffAFull?SC_LOGIC_1:SC_LOGIC_0);
         vcLocBuffFull.write(locBuffFull?SC_LOGIC_1:SC_LOGIC_0);

         // Valid data
         if ( vcRxValid.read() == 1 ) {

            // New frame
            if ( frame == NULL ) {

               // Create new frame
               frame = new Pgp2VcFrame();

               // Frame is in error if this is not an SOF
               if ( vcRxSOF.read() == 0 ) frame->setFrameError();

               // Get data
               dataLow  = vcRxDataLow.read().to_uint();
               dataHigh = vcRxDataHigh.read().to_uint();

               // Store data based upon width
               frame->addData(dataLow&0xFF);
               frame->addData((dataLow>>8)&0xFF);
               if ( width >= 1 ) {
                  frame->addData((dataLow >> 16)&0xFF);
                  frame->addData((dataLow >> 24)&0xFF);
               }
               if ( width >= 2 ) {
                  frame->addData(dataHigh&0xFF);
                  frame->addData((dataHigh>>8)&0xFF);
               }
               if ( width == 3 ) {
                  frame->addData((dataHigh >> 16)&0xFF);
                  frame->addData((dataHigh >> 24)&0xFF);
               }

               // This is end of frame
               if ( vcRxEOF.read() == 1 ) {
                  frame->setFrameError();
              
                  // End of frame error
                  if ( vcRxEOFE.read() == 1 ) frame->setEofE();

                  // Add frame to queue
                  if ( frameFifo.num_free() != 0 ) frameFifo.write((unsigned long)frame);
                  else delete frame;
                  frame = NULL;
               }
            }

            // Existing frame
            else {

               // SOF detected
               if ( vcRxSOF.read() == 1 ) frame->setFrameError();

               // Get data
               dataLow  = vcRxDataLow.read().to_uint();
               dataHigh = vcRxDataHigh.read().to_uint();

               // Store data based upon width
               frame->addData(dataLow&0xFF);
               frame->addData((dataLow>>8)&0xFF);
               if ( width >= 1 ) {
                  frame->addData((dataLow >> 16)&0xFF);
                  frame->addData((dataLow >> 24)&0xFF);
               }
               if ( width >= 2 ) {
                  frame->addData(dataHigh&0xFF);
                  frame->addData((dataHigh>>8)&0xFF);
               }
               if ( width == 3 ) {
                  frame->addData((dataHigh >> 16)&0xFF);
                  frame->addData((dataHigh >> 24)&0xFF);
               }

               // This is end of frame
               if ( vcRxEOF.read() == 1 ) {
              
                  // End of frame error
                  if ( vcRxEOFE.read() == 1 ) frame->setEofE();

                  // Add frame to queue
                  if ( frameFifo.num_free() != 0 ) frameFifo.write((unsigned long)frame);
                  else delete frame;
                  frame = NULL;
               }
            }
         }
      }
   }
}


// Method to read recived frame. 
// Returns pointer to received frame, should be deleted
Pgp2VcFrame *Pgp2VcRxModel::rxFrame(void) {
   unsigned long pointer;

   if ( frameFifo.num_available() != 0 ) {
      frameFifo.read(pointer);
      return((Pgp2VcFrame *)pointer);
   }
   else return(NULL);
}


// Method to set state of flow control
void Pgp2VcRxModel::setLocBuffAFull(bool state) { locBuffAFull = state; }


// Method to set state of flow control
void Pgp2VcRxModel::setLocBuffFull(bool state) { locBuffFull = state; }

