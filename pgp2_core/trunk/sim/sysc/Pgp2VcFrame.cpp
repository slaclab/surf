//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, Frame Container
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcFrame.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/16/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to contain vritual channel frames for transmit and receive.
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
#include "Pgp2VcFrame.h"
#include <stdlib.h>
#include <iostream>
#include <systemc.h>
using namespace std;


// Constructor
Pgp2VcFrame::Pgp2VcFrame() {
   data       = NULL;
   size       = 0;
   buffer     = 0;
   eofE       = false;
   frameError = false;
   tx         = false;
   init();
}


// DeConstructor
Pgp2VcFrame::~Pgp2VcFrame() {
   if ( data != NULL ) free(data);
   size   = 0;
   buffer = 0;
   data   = NULL;
}


// Method to init frame
void Pgp2VcFrame::init() {
   if ( data != NULL ) free(data);
   buffer = sizeIncrement;
   size = 0;
   data = (unsigned char *) malloc(buffer);
   if ( data == NULL ) {
      cout << "Pgp2VcFrame::init -> Malloc Failed" << endl;
      sc_stop();
   }
}


// Methods to get frame data
void Pgp2VcFrame::addData(unsigned char data) {
   unsigned char *newData;
   unsigned int  x;

   if ( this->data == NULL ) {
      cout << "Pgp2VcFrame::addData -> Error, NULL Record" << endl;
      sc_stop();
   }
   else {

      if ( size == buffer ) {
         buffer += sizeIncrement;
         newData = (unsigned char *) malloc(buffer);
         if ( newData == NULL ) {
            cout << "Pgp2VcFrame::init -> Malloc Failed" << endl;
            sc_stop();
         }
         for ( x=0; x < size; x++ ) newData[x] = this->data[x];
         free(this->data);
         this->data = newData;
      }
      this->data[size] = data;
      size++;
   }
}


// Methods to set frame data
unsigned char Pgp2VcFrame::getData(unsigned int pos) { 
   if ( data == NULL ) {
      cout << "Pgp2VcFrame::getData -> Error, NULL Record" << endl;
      sc_stop();
      return(0);
   }
   else if ( pos >= size ) {
      cout << "Pgp2VcFrame::getData -> Out of bounds." << endl;
      sc_stop();
      return(0);
   }
   else return(data[pos]);
}


// Methods to set EOFE
void Pgp2VcFrame::setEofE() { eofE = true; }


// Methods to get EOFE
bool Pgp2VcFrame::getEofE() { return(eofE); };


// Methods to set error flag
void Pgp2VcFrame::setFrameError() { frameError = true; }


// Methods to get error flag
bool Pgp2VcFrame::getFrameError() { return(frameError); }


// Method to get frame size
unsigned int Pgp2VcFrame::getSize() { return(size); }


// Set tx flag
void Pgp2VcFrame::setTx() { tx = true; }


// Get tx flag
bool Pgp2VcFrame::getTx() { return(tx); }

