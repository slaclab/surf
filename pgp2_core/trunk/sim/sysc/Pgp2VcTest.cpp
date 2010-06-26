//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC VC Link Test
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcTest.cpp
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/16/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to generate and receive traffic over a VC link
//----------------------------------------------------------------------------------------
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 04/16/2009: created.
//----------------------------------------------------------------------------------------
#include "Pgp2VcTest.h"
#include <iomanip>
using namespace std;


// Transmit Thread
void Pgp2VcTest::txThread(void) {

   Pgp2VcFrame  *newFrame;
   unsigned int size;
   unsigned int x;
   unsigned int y;
   unsigned int width;
   unsigned int temp;

   wait(100,SC_NS);
   width = vcWidth.read().to_uint();
   txModel.setPauseMask(0);

   while (1) {

      // Is there space for more frames
      if ( pgpLinkReady.read() == 1 && txModel.free() != 0 && frameFifo.num_free() != 0 ) {
         newFrame = new Pgp2VcFrame();
         size = (random() & 0x3FF) * 4;
         if ( size == 1 || size == 0 ) size = 2;
         for (x=0; x< size; x++) {
            //for (y=0; y <= width; y++) {
               if ( (x == 0 && y == 0) || x == (size-1) || x == (size-2)) {
                  newFrame->addData(0);
                  newFrame->addData(0);
               } else {
                  newFrame->addData(random()&0xFF);
                  newFrame->addData(random()&0xFF);
               }
            //}
         }
         txModel.txFrame(newFrame);
         frameFifo.write((unsigned long)newFrame);
      }
      else wait(10,SC_NS);
   }
   //rxModel.setLocBuffAFull(false);
   //rxModel.setLocBuffFull(false);
}


// Receive Thread
void Pgp2VcTest::rxThread(void) {

   Pgp2VcFrame   *gotFrame;
   Pgp2VcFrame   *expFrame;
   unsigned int  size;
   unsigned long temp;
   unsigned int  x;
   unsigned int  count;
   unsigned int  vcNumber;

   wait(100,SC_NS);
   while ( pgpLinkReady.read() != 1 ) { wait(10,SC_NS); }

   vcNumber = vcNum.read().to_uint();
   cout << "VC " << dec << setw(1) << vcNumber << " Starting." << endl;
   count = 0;

   while (1) {

      if ( (gotFrame = rxModel.rxFrame()) != NULL ) {

         // Get expect frame
         frameFifo.read(temp);
         expFrame = (Pgp2VcFrame*)temp;

         // Wait for transmit to complate
         while ( ! expFrame->getTx() ) wait(10,SC_NS);

         //cout << "VC " << dec << setw(1) << vcNumber << " ";
         //cout << "Frame Received: Cnt=" << dec << count << " ";
         //cout << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;

         // Get and compare frame sizes
         size = expFrame->getSize();
         if ( size != gotFrame->getSize() ) {
            cout << "VC " << dec << setw(1) << vcNumber << " "
                 << "Frame size compare error "
                 << "Got=" << dec << gotFrame->getSize()
                 << " Exp=" << dec << size
                 << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;
            if ( size > expFrame->getSize() ) size = expFrame->getSize();
         }
 
         // Compare EOFE flags
         if ( gotFrame->getEofE() != expFrame->getEofE() ) {
            cout << "VC " << dec << setw(1) << vcNumber << " "
                 << "Frame EOFE compare error"
                 << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;
         }

         // Frame Error?
         if ( gotFrame->getFrameError() ) {
            cout << "VC " << dec << setw(1) << vcNumber << " "
                 << "Frame Receive error"
                 << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;
         }

         // Compare frames
         for (x=0; x < size; x++) {
            if ( x != 0 && gotFrame->getData(x) != expFrame->getData(x) ) {
               cout << "VC " << dec << setw(1) << vcNumber << " "
                    << "Frame Compare Error: Cnt=" << dec << count << " "
                    << "X=" << dec << x << " "
                    << hex << setw(2) << setfill('0') << (int)gotFrame->getData(x)
                    << " != "
                    << hex << setw(2) << setfill('0') << (int)expFrame->getData(x)
                    << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;
               break;
            }
         }
         count++;

         //if ( count % 10 == 0 ) {
            cout << "VC " << dec << setw(1) << vcNumber << " "
                 << dec << count << " Frames Received."
                 << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;
         //}

         // Free frames
         delete gotFrame;
         delete expFrame;
      }
      else wait(10,SC_NS);
   }
}

