//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC Command / Data Model
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcCmd.cpp
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 12/02/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to generate commands and receive data over a PGP2 virtual channel.
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
// 12/02/2009: created.
//----------------------------------------------------------------------------------------
#include "Pgp2VcCmd.h"
#include "Pgp2VcFrame.h"
#include <iomanip>
using namespace std;


// Set Destination
void Pgp2VcCmd::setDest ( unsigned int dest ) { this->dest = dest; }


// Perform Write Operation
void Pgp2VcCmd::sendCommand ( unsigned int opCode ) {
   unsigned int frame[4];
   unsigned int x;

   // Get VC number
   vc = vcNum.read().to_uint();

   // Header word 0
   frame[0]  = (dest << 2) & 0x000000FC;
   frame[0] += vc          & 0x00000003;

   // Opcode
   frame[1] = opCode & 0xFF;

   // Init remaining data
   frame[2] = 0;
   frame[3] = 0;

   // Delete old frame if it exists
   if ( txFrame != NULL ) delete txFrame;

   // Create frame
   txFrame = new Pgp2VcFrame();
   for (x=0; x < 4; x++) {
      txFrame->addData( frame[x]     &0xFF);
      txFrame->addData((frame[x]>> 8)&0xFF);
      txFrame->addData((frame[x]>>16)&0xFF);
      txFrame->addData((frame[x]>>24)&0xFF);
   }

   // Send frame
   txModel.txFrame(txFrame);
}


// Get data
unsigned int Pgp2VcCmd::getData (unsigned int *data, unsigned int max) {
   Pgp2VcFrame  *rxFrame;
   unsigned int length;
   unsigned int x,y;

   // Get response
   while ( (rxFrame = rxModel.rxFrame()) == NULL ) wait(10,SC_NS);

   // Check EOF
   if ( rxFrame->getEofE() ) {
      cout << "Pgp2VcCmd::getData -> Error In Received Packet, EOFE"
           << ", VC=" << dec << vc << endl;
      if ( txFrame != NULL ) delete txFrame;
      txFrame = NULL;
      delete rxFrame;
      return(0);
   }

   // Check Length
   if ( (rxFrame->getSize() % 4) != 0 ) {
      cout << "Pgp2VcCmd::getData -> Error In Received Packet, Length=" << dec << rxFrame->getSize()
           << ", VC=" << dec << vc << endl;
      if ( txFrame != NULL ) delete txFrame;
      txFrame = NULL;
      delete rxFrame;
      return(0);
   }

   // Get length
   length = rxFrame->getSize() / 4;

   // Check Overrun
   if ( length > max ) {
      cout << "Pgp2VcCmd::getData -> Error In Received Packet, Length=" << dec << rxFrame->getSize()
           << ", VC=" << dec << vc << endl;
      if ( txFrame != NULL ) delete txFrame;
      txFrame = NULL;
      delete rxFrame;
      return(0);
   }

   // Extract frame
   y = 0;
   for (x=0; x < length; x++) {
      data[x]  = ( rxFrame->getData(y)        & 0x000000FF); y++;
      data[x] += ((rxFrame->getData(y) <<  8) & 0x0000FF00); y++;
      data[x] += ((rxFrame->getData(y) << 16) & 0x00FF0000); y++;
      data[x] += ((rxFrame->getData(y) << 24) & 0xFF000000); y++;
   }

   // Delete frames
   if ( txFrame != NULL ) delete txFrame;
   txFrame = NULL;
   delete rxFrame;
   return(length);
}

