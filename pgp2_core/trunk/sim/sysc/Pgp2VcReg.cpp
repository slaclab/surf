//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC Register Read/Write Model
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcReg.cpp
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 12/02/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to generate and receive register accesses over a PGP2 virtual channel.
//----------------------------------------------------------------------------------------
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 12/02/2009: created.
//----------------------------------------------------------------------------------------
#include "Pgp2VcReg.h"
#include "Pgp2VcFrame.h"
#include <iomanip>
using namespace std;


// Set Destination
void Pgp2VcReg::setDest ( unsigned int dest ) { this->dest = dest; }


// Init the frame
void Pgp2VcReg::init ( unsigned int address, unsigned int opcode, unsigned int data ) {

   // Get VC number
   vc = vcNum.read().to_uint();

   // Header word 0
   frame[0]  = (dest << 2) & 0x000000FC;
   frame[0] += vc          & 0x00000003;

   // Address & opcode
   frame[1]  = (opcode << 30) & 0xC0000000;
   frame[1] += address        & 0x00FFFFFF;

   // Init remaining data
   frame[2] = data;
   frame[3] = 0;
}


// Send the frame
unsigned int Pgp2VcReg::sendReceive () {
   Pgp2VcFrame  *txFrame;
   Pgp2VcFrame  *rxFrame;
   unsigned int x,y;

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
   
   // Get response
   while ( (rxFrame = rxModel.rxFrame()) == NULL ) wait(10,SC_NS);

   // Check EOF
   if ( rxFrame->getEofE() ) {
      cout << "Pgp2VcReg::sendReceive -> Error In Received Packet, EOFE"
           << ", VC=" << dec << vc << endl;
      delete txFrame;
      delete rxFrame;
      return(1);
   }

   // Check Length
   if ( rxFrame->getSize() != 16 ) {
      cout << "Pgp2VcReg::sendReceive -> Error In Received Packet, Length=" << dec << rxFrame->getSize()
           << ", VC=" << dec << vc << endl;
      delete txFrame;
      delete rxFrame;
      return(2);
   }

   // Extract frame
   y = 0;
   for (x=0; x < 4; x++) {
      frame[x]  = ( rxFrame->getData(y)        & 0x000000FF); y++;
      frame[x] += ((rxFrame->getData(y) <<  8) & 0x0000FF00); y++;
      frame[x] += ((rxFrame->getData(y) << 16) & 0x00FF0000); y++;
      frame[x] += ((rxFrame->getData(y) << 24) & 0xFF000000); y++;
   }

   // Delete frames
   delete txFrame;
   delete rxFrame;
   return(0);
}


// Register Read
unsigned int Pgp2VcReg::regRead ( unsigned int address, unsigned int *data ) {

   // init frame
   init(address,0x0,0);

   // Send data
   if ( sendReceive() != 0 ) return(1);

   // Check result
   if ( frame[3] != 0 ) {
      cout << "Pgp2VcReg::regRead -> Error In Received Packet = " << hex << frame[3]
           << ", Address=" << hex << address
           << ", VC=" << dec << vc << endl;
      return(2);
   }
   *data = frame[2];
   return(0);
}


// Register Write
unsigned int Pgp2VcReg::regWrite ( unsigned int address, unsigned int data ) {

   // init frame
   init(address,0x1,data);

   // Send data
   if ( sendReceive() != 0 ) return(1);

   // Check result
   if ( frame[3] != 0 ) {
      cout << "Pgp2VcReg::regWrite -> Error In Received Packet = " << hex << frame[3]
           << ", Address=" << hex << address
           << ", VC=" << dec << vc << endl;
      return(2);
   }
   return(0);
}


// Bit Clear 
unsigned int Pgp2VcReg::bitClear ( unsigned int address, unsigned int data ) {

   // init frame
   init(address,0x3,data);

   // Send data
   if ( sendReceive() != 0 ) return(1);

   // Check result
   if ( frame[3] != 0 ) {
      cout << "Pgp2VcReg::bitClear -> Error In Received Packet = " << hex << frame[3]
           << ", Address=" << hex << address
           << ", VC=" << dec << vc << endl;
      return(2);
   }
   return(0);
}


// Bit Set 
unsigned int Pgp2VcReg::bitSet ( unsigned int address, unsigned int data ) {

   // init frame
   init(address,0x2,data);

   // Send data
   if ( sendReceive() != 0 ) return(1);

   // Check result
   if ( frame[3] != 0 ) {
      cout << "Pgp2VcReg::bitSet -> Error In Received Packet = " << hex << frame[3]
           << ", Address=" << hex << address
           << ", VC=" << dec << vc << endl;
      return(2);
   }
   return(0);
}

