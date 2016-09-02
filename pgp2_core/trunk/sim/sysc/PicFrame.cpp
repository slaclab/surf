//----------------------------------------------------------------------------------------
// Title         : PIC SystemC Frame Container
// Project       : General
//----------------------------------------------------------------------------------------
// File          : PicFrame.cpp
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 08/26/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to contain a PIC frame.
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
// 08/26/2009: created.
//----------------------------------------------------------------------------------------
#include "PicFrame.h"
#include <stdlib.h>
using namespace std;


// Constructor
PicFrame::PicFrame() {
   data       = NULL;
   size       = 0;
   buffer     = 0;
   status     = 0;
   freeList   = 0;
}


// DeConstructor
PicFrame::~PicFrame() {
   if ( data != NULL ) free(data);
}


// Method to add data
void PicFrame::addData(unsigned char data) {
   unsigned char *newData;
   unsigned int  x;

   if ( size == buffer ) {
      buffer += sizeIncrement;
      newData = (unsigned char *) malloc(buffer);
      for ( x=0; x < size; x++ ) newData[x] = this->data[x];
      free(this->data);
      this->data = newData;
   }
   this->data[size] = data;
   size++;
}


